import Combine
import Foundation

public enum CleanupShelfState: Equatable, Sendable {
    case scanning
    case ready
    case confirming(CleanupPlanSummary)
    case cleaning(progress: Double)
    case result(CleanupResult)
}

public struct CleanupPlanSummary: Equatable, Sendable {
    public let permanentBytes: Int64
    public let trashBytes: Int64

    public init(permanentBytes: Int64, trashBytes: Int64) {
        self.permanentBytes = permanentBytes
        self.trashBytes = trashBytes
    }
}

@MainActor
public final class DashboardModel: ObservableObject {
    @Published public private(set) var capacity: VolumeCapacity?
    @Published public private(set) var measurements: [StorageCategory: StorageMeasurement] = [:]
    @Published public private(set) var coverageIssues: [ScanCoverageIssue] = []
    @Published public private(set) var itemsByCategory: [StorageCategory: [StorageItem]] = [:]
    @Published public private(set) var selectedItemIDs: Set<String> = []
    @Published public private(set) var lastScan: Date?
    @Published public private(set) var shelfState: CleanupShelfState = .scanning
    @Published public private(set) var accessState: StorageAccessState
    @Published public var selectedCategory: StorageCategory?
    @Published public var inspectorPresented = false
    @Published public var confirmationPresented = false

    public let profile: DistributionProfile
    private let scanner: any StorageScanning
    private let accessProvider: any StorageAccessProviding
    private let cleanupExecutor: any CleanupExecuting
    private let workspaceRevealer: any WorkspaceRevealing
    private var scanTask: Task<Void, Never>?
    private var cleanupTask: Task<Void, Never>?
    private var resultAfterScan: CleanupResult?

    public init(environment: AppEnvironment) {
        profile = environment.profile
        scanner = environment.scanner
        accessProvider = environment.accessProvider
        cleanupExecutor = environment.cleanupExecutor
        workspaceRevealer = environment.workspaceRevealer
        accessState = environment.profile == .direct
            ? .notRequired(FileManager.default.homeDirectoryForCurrentUser)
            : .selectionRequired
    }

    deinit {
        scanTask?.cancel()
        cleanupTask?.cancel()
    }

    public func startScan(volume: URL = URL(filePath: "/", directoryHint: .isDirectory)) {
        guard accessState.accessibleRoot != nil else {
            shelfState = .ready
            return
        }
        scanTask?.cancel()
        measurements = [:]
        itemsByCategory = [:]
        selectedItemIDs = []
        coverageIssues = []
        lastScan = nil
        shelfState = .scanning
        scanTask = Task { [scanner] in
            do {
                for try await event in scanner.scan(volume: volume) {
                    guard !Task.isCancelled else { return }
                    apply(event)
                }
            } catch {
                coverageIssues.append(.init(root: volume, errorDescription: error.localizedDescription))
                shelfState = .ready
            }
        }
    }

    public func prepareInitialAccess() {
        accessState = accessProvider.restoreAccess()
        if accessState.accessibleRoot != nil {
            startScan()
        } else {
            shelfState = .ready
        }
    }

    public func requestHomeAccess() async {
        accessState = await accessProvider.requestAccess()
        if accessState.accessibleRoot != nil {
            startScan()
        }
    }

    public func select(_ category: StorageCategory) {
        selectedCategory = category
    }

    public func toggleSelection(for item: StorageItem) {
        guard item.action != .revealOnly else { return }
        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }
    }

    public func reveal(_ item: StorageItem) {
        Task { [workspaceRevealer] in
            await workspaceRevealer.reveal(item.path)
        }
    }

    public var selectedItems: [StorageItem] {
        itemsByCategory.values.flatMap { $0 }.filter { selectedItemIDs.contains($0.id) }
    }

    public var selectedPlan: CleanupPlan {
        CleanupPlan(items: selectedItems)
    }

    public var estimatedReclaimableBytes: Int64 {
        selectedItems.reduce(0) { $0 + ($1.reclaimable.bytes ?? 0) }
    }

    public func prepareCleanup() {
        guard !selectedItems.isEmpty else { return }
        confirmationPresented = true
        shelfState = .confirming(.init(
            permanentBytes: selectedPlan.estimatedPermanentDeletion,
            trashBytes: selectedPlan.estimatedMovedToTrash
        ))
    }

    public func cancelCleanupConfirmation() {
        confirmationPresented = false
        shelfState = .ready
    }

    public func executeCleanup() {
        let plan = selectedPlan
        guard !plan.items.isEmpty else { return }
        confirmationPresented = false
        shelfState = .cleaning(progress: 0.1)
        cleanupTask?.cancel()
        cleanupTask = Task { [cleanupExecutor] in
            let result = await cleanupExecutor.execute(plan)
            guard !Task.isCancelled else { return }
            shelfState = .cleaning(progress: 1)
            resultAfterScan = result
            startScan()
        }
    }

    public var unresolvedUsedBytes: Int64 {
        guard let capacity else { return 0 }
        let measured = measurements
            .filter { $0.key != .available && $0.key != .systemUnclassified }
            .reduce(Int64.zero) { $0 + ($1.value.bytes ?? 0) }
        return max(0, capacity.total - capacity.available - measured)
    }

    public var residualShareOfUsed: Double {
        guard let capacity else { return 0 }
        let used = capacity.total - capacity.available
        guard used > 0 else { return 0 }
        return Double(unresolvedUsedBytes) / Double(used)
    }

    private func apply(_ event: ScanEvent) {
        switch event {
        case .capacity(let value):
            capacity = value
            measurements[.available] = .measured(
                value.available,
                explanation: "Available for important usage, including purgeable capacity managed by macOS"
            )
            updateResidual()
        case .category(let category, let bytes, let items, let coverageComplete):
            if coverageComplete || bytes > 0 {
                measurements[category] = .measured(
                    bytes,
                    explanation: coverageComplete
                        ? "Measured from accessible files"
                        : "Measured accessible items only; scan coverage is incomplete"
                )
            } else {
                measurements[category] = .unavailable("CleanSpace could not measure this category because access was denied")
            }
            itemsByCategory[category] = items
            selectedItemIDs.formUnion(items.filter(\.isDefaultSelected).map(\.id))
            updateResidual()
        case .coverageIssue(let issue):
            if !coverageIssues.contains(where: { $0.id == issue.id }) {
                coverageIssues.append(issue)
            }
            updateResidual()
        case .finished(let date):
            lastScan = date
            if let resultAfterScan {
                shelfState = .result(resultAfterScan)
                self.resultAfterScan = nil
            } else {
                shelfState = .ready
            }
            updateResidual()
        }
    }

    private func updateResidual() {
        guard capacity != nil else { return }
        measurements[.systemUnclassified] = .derived(
            unresolvedUsedBytes,
            explanation: "Total capacity minus available capacity and measured accessible categories"
        )
    }
}
