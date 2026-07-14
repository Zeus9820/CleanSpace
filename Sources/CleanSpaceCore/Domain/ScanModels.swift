import Foundation

public struct ScanCoverageIssue: Identifiable, Equatable, Sendable {
    public let id: String
    public let root: URL
    public let errorDescription: String
    public let accessAction: String?

    public init(root: URL, errorDescription: String, accessAction: String? = nil) {
        self.id = root.standardizedFileURL.path
        self.root = root
        self.errorDescription = errorDescription
        self.accessAction = accessAction
    }
}

public struct ScanCoverage: Equatable, Sendable {
    public let issues: [ScanCoverageIssue]
    public let completedRoots: Set<URL>

    public init(issues: [ScanCoverageIssue] = [], completedRoots: Set<URL> = []) {
        self.issues = issues
        self.completedRoots = completedRoots
    }

    public var isComplete: Bool { issues.isEmpty }
}

public struct ScanSnapshot: Equatable, Sendable {
    public let totalCapacity: Int64
    public let availableCapacity: Int64
    public let measurements: [StorageCategory: StorageMeasurement]
    public let items: [StorageItem]
    public let coverage: ScanCoverage
    public let scannedAt: Date

    public init(
        totalCapacity: Int64,
        availableCapacity: Int64,
        measuredCategories: [StorageCategory: Int64],
        items: [StorageItem] = [],
        coverage: ScanCoverage = .init(),
        scannedAt: Date = .now
    ) {
        let total = max(0, totalCapacity)
        let available = min(max(0, availableCapacity), total)
        let accessible = measuredCategories
            .filter { $0.key != .available && $0.key != .systemUnclassified }
            .reduce(Int64.zero) { partial, entry in partial + max(0, entry.value) }
        let residual = max(0, total - available - accessible)
        var values = measuredCategories.reduce(into: [StorageCategory: StorageMeasurement]()) {
            guard $1.key != .available && $1.key != .systemUnclassified else { return }
            $0[$1.key] = .measured(max(0, $1.value))
        }
        values[.available] = .measured(available, explanation: "Reported by the selected volume")
        values[.systemUnclassified] = .derived(
            residual,
            explanation: "Total capacity minus available capacity and measured accessible categories"
        )
        self.totalCapacity = total
        self.availableCapacity = available
        self.measurements = values
        self.items = items
        self.coverage = coverage
        self.scannedAt = scannedAt
    }

    public var usedCapacity: Int64 { totalCapacity - availableCapacity }

    public var residualShareOfUsed: Double {
        guard usedCapacity > 0 else { return 0 }
        return Double(measurements[.systemUnclassified]?.bytes ?? 0) / Double(usedCapacity)
    }
}
