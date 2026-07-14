import Foundation

public struct RegisteredCleanupExecutor: CleanupExecuting {
    private let profile: DistributionProfile
    private let rules: [String: CleanupRule]
    private let capacityProvider: any VolumeCapacityProviding
    private let volume: URL

    public init(
        profile: DistributionProfile,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        catalog: StorageScanCatalog = .standard,
        capacityProvider: any VolumeCapacityProviding,
        volume: URL = URL(filePath: "/", directoryHint: .isDirectory)
    ) {
        self.profile = profile
        self.rules = Dictionary(uniqueKeysWithValues: catalog.cleanupRules(home: home, profile: profile).map { ($0.id, $0) })
        self.capacityProvider = capacityProvider
        self.volume = volume
    }

    public func execute(_ plan: CleanupPlan) async -> CleanupResult {
        let before = try? capacityProvider.capacity(for: volume)
        var movedBytes: Int64 = 0
        var estimatedPermanentBytes: Int64 = 0
        var failures: [CleanupFailure] = []

        for item in plan.items {
            guard !Task.isCancelled else {
                failures.append(.init(id: item.id, itemName: item.displayName, reason: "Cleanup was cancelled"))
                continue
            }
            guard let ruleID = item.cleanupRuleID,
                  let rule = rules[ruleID],
                  rule.supportedProfiles.contains(profile),
                  rule.action == item.action,
                  rule.contains(item.path) else {
                failures.append(.init(id: item.id, itemName: item.displayName, reason: "No matching registered cleanup rule"))
                continue
            }

            do {
                switch item.action {
                case .permanentlyDelete:
                    estimatedPermanentBytes += item.reclaimable.bytes ?? 0
                    try FileManager.default.removeItem(at: item.path)
                case .moveToTrash:
                    var resultingURL: NSURL?
                    try FileManager.default.trashItem(at: item.path, resultingItemURL: &resultingURL)
                    movedBytes += item.size.bytes ?? 0
                case .revealOnly:
                    throw CleanupExecutionError.revealOnly
                }
            } catch {
                failures.append(.init(id: item.id, itemName: item.displayName, reason: error.localizedDescription))
            }
        }

        try? await Task.sleep(for: .milliseconds(500))
        let after = try? capacityProvider.capacity(for: volume)
        let reclaimed = max(0, (after?.immediatelyAvailable ?? 0) - (before?.immediatelyAvailable ?? 0))
        return CleanupResult(
            measuredCapacityReclaimed: .measured(reclaimed, explanation: "Measured from volume available capacity before and after cleanup"),
            movedToTrash: .measured(movedBytes, explanation: "Measured allocated size moved to Trash; this is not reclaimed capacity"),
            failures: failures,
            estimateDifferenceExplanation: differenceExplanation(estimated: estimatedPermanentBytes, measured: reclaimed)
        )
    }

    private func differenceExplanation(estimated: Int64, measured: Int64) -> String? {
        let difference = abs(estimated - measured)
        guard difference > max(100_000_000, estimated / 10) else { return nil }
        return "The measured result differs from the earlier estimate. APFS clones, hard links, snapshots, purgeable space, and active processes can change how much capacity becomes available."
    }
}

private enum CleanupExecutionError: LocalizedError {
    case revealOnly

    var errorDescription: String? {
        "Reveal-only items cannot be cleaned by CleanSpace"
    }
}
