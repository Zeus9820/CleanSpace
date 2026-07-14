import Foundation

public struct CleanupRule: Identifiable, Sendable {
    public let id: String
    public let supportedProfiles: Set<DistributionProfile>
    public let allowedRoot: URL
    public let detectionSignature: String
    public let signatureVersion: Int
    public let action: CleanupAction
    public let safetyCopy: String
    public let excludedPaths: [URL]
    public let allowsRoot: Bool

    public init(id: String, supportedProfiles: Set<DistributionProfile>, allowedRoot: URL, detectionSignature: String, signatureVersion: Int, action: CleanupAction, safetyCopy: String, excludedPaths: [URL] = [], allowsRoot: Bool = false) {
        self.id = id
        self.supportedProfiles = supportedProfiles
        self.allowedRoot = allowedRoot.standardizedFileURL
        self.detectionSignature = detectionSignature
        self.signatureVersion = signatureVersion
        self.action = action
        self.safetyCopy = safetyCopy
        self.excludedPaths = excludedPaths.map(\.standardizedFileURL)
        self.allowsRoot = allowsRoot
    }

    public func contains(_ candidate: URL) -> Bool {
        let root = allowedRoot.resolvingSymlinksInPath().standardizedFileURL.pathComponents
        let path = candidate.resolvingSymlinksInPath().standardizedFileURL.pathComponents
        let isInsideRoot = path.count > root.count && Array(path.prefix(root.count)) == root
        let isRoot = path == root
        let isExcluded = excludedPaths.contains { exclusion in
            let excluded = exclusion.resolvingSymlinksInPath().standardizedFileURL.pathComponents
            return path.count >= excluded.count && Array(path.prefix(excluded.count)) == excluded
        }
        return (isInsideRoot || (allowsRoot && isRoot)) && !isExcluded
    }
}

public struct CleanupPlan: Sendable {
    public let items: [StorageItem]

    public init(items: [StorageItem]) { self.items = items }

    public var estimatedPermanentDeletion: Int64 {
        total(for: .permanentlyDelete)
    }

    public var estimatedMovedToTrash: Int64 {
        total(for: .moveToTrash)
    }

    private func total(for action: CleanupAction) -> Int64 {
        items.filter { $0.action == action }.reduce(0) { $0 + ($1.reclaimable.bytes ?? 0) }
    }
}

public struct CleanupFailure: Identifiable, Equatable, Sendable {
    public let id: String
    public let itemName: String
    public let reason: String

    public init(id: String, itemName: String, reason: String) {
        self.id = id
        self.itemName = itemName
        self.reason = reason
    }
}

public struct CleanupResult: Equatable, Sendable {
    public let measuredCapacityReclaimed: StorageMeasurement
    public let movedToTrash: StorageMeasurement
    public let failures: [CleanupFailure]
    public let estimateDifferenceExplanation: String?

    public init(measuredCapacityReclaimed: StorageMeasurement, movedToTrash: StorageMeasurement, failures: [CleanupFailure], estimateDifferenceExplanation: String?) {
        precondition(measuredCapacityReclaimed.confidence == .measured)
        precondition(movedToTrash.confidence == .measured)
        self.measuredCapacityReclaimed = measuredCapacityReclaimed
        self.movedToTrash = movedToTrash
        self.failures = failures
        self.estimateDifferenceExplanation = estimateDifferenceExplanation
    }
}
