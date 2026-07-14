import Foundation

public struct RegisteredRootScanner: StorageScanning {
    private let capacityProvider: any VolumeCapacityProviding
    private let catalog: StorageScanCatalog
    private let home: URL
    private let maximumConcurrentMeasurements: Int
    private let includeProtectedAppData: Bool

    public init(
        capacityProvider: any VolumeCapacityProviding,
        catalog: StorageScanCatalog = .standard,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        maximumConcurrentMeasurements: Int = 4,
        includeProtectedAppData: Bool = false
    ) {
        self.capacityProvider = capacityProvider
        self.catalog = catalog
        self.home = home.standardizedFileURL
        self.maximumConcurrentMeasurements = max(1, maximumConcurrentMeasurements)
        self.includeProtectedAppData = includeProtectedAppData
    }

    public func scan(volume: URL) -> AsyncThrowingStream<ScanEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .utility) {
                do {
                    continuation.yield(.capacity(try capacityProvider.capacity(for: volume)))
                    let expectedVolume = try volume.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier
                        .map { String(describing: $0) }
                    let seenFileIdentifiers = FileIdentityRegistry()

                    for category in StorageCategory.allCases where category != .available && category != .systemUnclassified {
                        try Task.checkCancellation()
                        let locations = catalog.locations.filter { $0.category == category }
                        guard !locations.isEmpty else { continue }
                        var categoryBytes: Int64 = 0
                        var categoryItems: [StorageItem] = []
                        var coverageComplete = true

                        for location in locations {
                            try Task.checkCancellation()
                            let root = location.root(in: home)
                            if location.requiresProtectedAppDataAccess && !includeProtectedAppData {
                                coverageComplete = false
                                continuation.yield(.coverageIssue(.init(
                                    root: root,
                                    errorDescription: "Protected app data was not scanned automatically because this build cannot persist macOS App Data permission.",
                                    accessAction: "Use a Developer ID signed Direct build"
                                )))
                                continue
                            }
                            guard FileManager.default.fileExists(atPath: root.path) else { continue }
                            do {
                                let results = try await measureLocation(
                                    location,
                                    expectedVolume: expectedVolume,
                                    seenFileIdentifiers: seenFileIdentifiers
                                )
                                for result in results {
                                    if !result.issues.isEmpty { coverageComplete = false }
                                    result.issues.forEach { continuation.yield(.coverageIssue($0)) }
                                    guard result.bytes > 0 else { continue }
                                    categoryBytes += result.bytes
                                    categoryItems.append(makeItem(
                                        result.url,
                                        displayName: result.displayName,
                                        bytes: result.bytes,
                                        location: location
                                    ))
                                }
                            } catch {
                                coverageComplete = false
                                continuation.yield(.coverageIssue(.init(
                                    root: root,
                                    errorDescription: error.localizedDescription,
                                    accessAction: "Review folder access"
                                )))
                            }
                        }

                        categoryItems.sort { ($0.size.bytes ?? 0) > ($1.size.bytes ?? 0) }
                        continuation.yield(.category(category, bytes: categoryBytes, items: categoryItems, coverageComplete: coverageComplete))
                    }
                    continuation.yield(.finished(.now))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func measureLocation(
        _ location: StorageScanLocation,
        expectedVolume: String?,
        seenFileIdentifiers: FileIdentityRegistry
    ) async throws -> [MeasuredRoot] {
        let root = location.root(in: home)
        let exclusions = exclusions(for: location)
        if location.aggregateAsSingleItem {
            let result = measure(
                root,
                expectedVolume: expectedVolume,
                exclusions: exclusions,
                seenFileIdentifiers: seenFileIdentifiers
            )
            return [.init(url: root, displayName: location.displayName, bytes: result.bytes, issues: result.issues)]
        }

        let children = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: []
        )
        var iterator = children.makeIterator()
        var results: [MeasuredRoot] = []
        results.reserveCapacity(children.count)

        try await withThrowingTaskGroup(of: MeasuredRoot.self) { group in
            for _ in 0..<min(maximumConcurrentMeasurements, children.count) {
                guard let child = iterator.next() else { break }
                group.addTask(priority: .utility) {
                    let result = measure(
                        child,
                        expectedVolume: expectedVolume,
                        exclusions: exclusions,
                        seenFileIdentifiers: seenFileIdentifiers
                    )
                    return .init(url: child, displayName: child.lastPathComponent, bytes: result.bytes, issues: result.issues)
                }
            }

            while let result = try await group.next() {
                try Task.checkCancellation()
                results.append(result)
                if let child = iterator.next() {
                    group.addTask(priority: .utility) {
                        let measured = measure(
                            child,
                            expectedVolume: expectedVolume,
                            exclusions: exclusions,
                            seenFileIdentifiers: seenFileIdentifiers
                        )
                        return .init(url: child, displayName: child.lastPathComponent, bytes: measured.bytes, issues: measured.issues)
                    }
                }
            }
        }
        return results
    }

    /// A broad registered root never owns a more specific registered root. This
    /// keeps categories disjoint even when the catalog grows and a manual
    /// exclusion is accidentally omitted.
    private func exclusions(for location: StorageScanLocation) -> [URL] {
        let root = location.root(in: home)
        let automatic = catalog.locations
            .filter { $0.id != location.id }
            .map { $0.root(in: home) }
            .filter { isStrictDescendant($0, of: root) }
        let all = location.exclusions(in: home) + automatic
        return Array(Dictionary(grouping: all, by: { $0.standardizedFileURL.path }).values.compactMap(\.first))
    }

    private func makeItem(_ url: URL, displayName: String, bytes: Int64, location: StorageScanLocation) -> StorageItem {
        let activity: ModelActivityEvidence? = location.category == .modelCaches
            ? modificationEvidence(for: url)
            : nil
        return StorageItem(
            id: "\(location.id):\(url.standardizedFileURL.path)",
            displayName: displayName,
            path: url,
            category: location.category,
            size: .measured(bytes),
            reclaimable: location.action == .revealOnly
                ? .unavailable("This location is reveal-only")
                : .estimated(bytes, explanation: "Allocated size before cleanup; APFS behavior may change the actual reclaimed capacity"),
            safety: location.safety,
            action: location.action,
            activity: activity,
            cleanupRuleID: location.action == .revealOnly ? nil : location.id,
            consequence: location.consequence,
            regenerationCost: location.regenerationCost,
            isDefaultSelected: location.isDefaultSelected
        )
    }

    private func modificationEvidence(for url: URL) -> ModelActivityEvidence {
        guard let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
            return .unknown
        }
        return .modification(date: date)
    }

    private func measure(
        _ root: URL,
        expectedVolume: String?,
        exclusions: [URL],
        seenFileIdentifiers: FileIdentityRegistry
    ) -> (bytes: Int64, issues: [ScanCoverageIssue]) {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey,
            .fileAllocatedSizeKey, .totalFileAllocatedSizeKey,
            .volumeIdentifierKey, .fileResourceIdentifierKey
        ]
        var issues: [ScanCoverageIssue] = []
        if exclusions.contains(where: { containsOrEquals($0, root) }) {
            return (0, [])
        }
        if let values = try? root.resourceValues(forKeys: keys), values.isRegularFile == true {
            guard values.isSymbolicLink != true else { return (0, []) }
            if let expectedVolume, let found = values.volumeIdentifier,
               expectedVolume != String(describing: found) {
                return (0, [])
            }
            if let identifier = values.fileResourceIdentifier {
                guard seenFileIdentifiers.insert(String(describing: identifier)) else { return (0, []) }
            }
            return (Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0), [])
        }
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { url, error in
                issues.append(.init(root: url, errorDescription: error.localizedDescription, accessAction: "Review folder access"))
                return true
            }
        ) else {
            return (0, [.init(root: root, errorDescription: "The folder could not be enumerated", accessAction: "Review folder access")])
        }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            if Task.isCancelled { break }
            if exclusions.contains(where: { containsOrEquals($0, url) }) {
                enumerator.skipDescendants()
                continue
            }
            do {
                let values = try url.resourceValues(forKeys: keys)
                if values.isSymbolicLink == true {
                    enumerator.skipDescendants()
                    continue
                }
                if let expectedVolume, let found = values.volumeIdentifier,
                   expectedVolume != String(describing: found) {
                    enumerator.skipDescendants()
                    continue
                }
                guard values.isRegularFile == true else { continue }
                if let identifier = values.fileResourceIdentifier {
                    let key = String(describing: identifier)
                    guard seenFileIdentifiers.insert(key) else { continue }
                }
                total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            } catch {
                issues.append(.init(root: url, errorDescription: error.localizedDescription))
            }
        }
        return (total, issues)
    }

    private func containsOrEquals(_ root: URL, _ candidate: URL) -> Bool {
        let rootComponents = root.standardizedFileURL.pathComponents
        let candidateComponents = candidate.standardizedFileURL.pathComponents
        return candidateComponents.count >= rootComponents.count
            && Array(candidateComponents.prefix(rootComponents.count)) == rootComponents
    }

    private func isStrictDescendant(_ candidate: URL, of root: URL) -> Bool {
        let rootComponents = root.standardizedFileURL.pathComponents
        let candidateComponents = candidate.standardizedFileURL.pathComponents
        return candidateComponents.count > rootComponents.count
            && Array(candidateComponents.prefix(rootComponents.count)) == rootComponents
    }
}

private struct MeasuredRoot: Sendable {
    let url: URL
    let displayName: String
    let bytes: Int64
    let issues: [ScanCoverageIssue]
}

/// NSLock is intentionally kept behind this tiny API. The registry is shared by
/// scan workers so APFS hard links are counted exactly once across all roots.
private final class FileIdentityRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var identities = Set<String>()

    func insert(_ identity: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return identities.insert(identity).inserted
    }
}
