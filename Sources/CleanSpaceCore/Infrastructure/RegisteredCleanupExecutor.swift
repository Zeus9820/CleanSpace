import Foundation

public struct RegisteredCleanupExecutor: CleanupExecuting {
    private let profile: DistributionProfile
    private let rules: [String: CleanupRule]
    private let capacityProvider: any VolumeCapacityProviding
    private let volume: URL
    private let permanentDeleter: any PermanentDeleting
    private let trashMover: any TrashMoving
    private let applicationDiscoverer: any ApplicationDiscovering

    public init(
        profile: DistributionProfile,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        catalog: StorageScanCatalog = .standard,
        capacityProvider: any VolumeCapacityProviding,
        volume: URL = URL(filePath: "/", directoryHint: .isDirectory),
        permanentDeleter: any PermanentDeleting = FoundationPermanentDeleter(),
        trashMover: any TrashMoving = FoundationTrashMover(),
        applicationDiscoverer: any ApplicationDiscovering = FoundationApplicationDiscoverer()
    ) {
        self.profile = profile
        self.rules = Dictionary(uniqueKeysWithValues: catalog.cleanupRules(home: home, profile: profile).map { ($0.id, $0) })
        self.capacityProvider = capacityProvider
        self.volume = volume
        self.permanentDeleter = permanentDeleter
        self.trashMover = trashMover
        self.applicationDiscoverer = applicationDiscoverer
    }

    public func execute(_ plan: CleanupPlan) async -> CleanupResult {
        let before = try? capacityProvider.capacity(for: volume)
        var movedBytes: Int64 = 0
        var estimatedPermanentBytes: Int64 = 0
        var failures: [CleanupFailure] = []

        for (index, item) in plan.items.enumerated() {
            guard !Task.isCancelled else {
                failures.append(contentsOf: plan.items[index...].map {
                    .init(id: $0.id, itemName: $0.displayName, reason: "Cleanup was cancelled before this item was changed")
                })
                break
            }
            guard let ruleID = item.cleanupRuleID,
                  let rule = rules[ruleID],
                  rule.supportedProfiles.contains(profile),
                  rule.action == item.action,
                  rule.contains(item.path) else {
                failures.append(.init(id: item.id, itemName: item.displayName, reason: "No matching registered cleanup rule"))
                continue
            }

            if item.safety == .requiresApplicationClosed {
                guard let bundleIdentifier = item.relatedApplication?.bundleIdentifier else {
                    failures.append(.init(
                        id: item.id, itemName: item.displayName,
                        reason: "CleanSpace could not identify the related application to verify that it is closed"
                    ))
                    continue
                }
                if await applicationDiscoverer.isRunning(bundleIdentifier: bundleIdentifier) {
                    failures.append(.init(
                        id: item.id, itemName: item.displayName,
                        reason: "Quit the related application before moving its data to Trash"
                    ))
                    continue
                }
            }

            do {
                switch item.action {
                case .permanentlyDelete:
                    estimatedPermanentBytes += item.reclaimable.bytes ?? 0
                    try await permanentDeleter.permanentlyDelete(item.path)
                case .moveToTrash:
                    _ = try await trashMover.moveToTrash(item.path)
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
