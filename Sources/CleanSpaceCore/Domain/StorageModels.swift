import Foundation

public enum MeasurementConfidence: String, Sendable, Codable, CaseIterable {
    case measured
    case estimated
    case derived
    case unavailable

    public var label: String { rawValue.capitalized }
}

public struct StorageMeasurement: Equatable, Sendable, Codable {
    public let bytes: Int64?
    public let confidence: MeasurementConfidence
    public let explanation: String

    private init(bytes: Int64?, confidence: MeasurementConfidence, explanation: String) {
        precondition((bytes == nil) == (confidence == .unavailable))
        precondition(bytes.map { $0 >= 0 } ?? true)
        self.bytes = bytes
        self.confidence = confidence
        self.explanation = explanation
    }

    public static func measured(_ bytes: Int64, explanation: String = "Measured from accessible files") -> Self {
        Self(bytes: bytes, confidence: .measured, explanation: explanation)
    }

    public static func estimated(_ bytes: Int64, explanation: String) -> Self {
        Self(bytes: bytes, confidence: .estimated, explanation: explanation)
    }

    public static func derived(_ bytes: Int64, explanation: String) -> Self {
        Self(bytes: bytes, confidence: .derived, explanation: explanation)
    }

    public static func unavailable(_ explanation: String) -> Self {
        Self(bytes: nil, confidence: .unavailable, explanation: explanation)
    }
}

public enum StorageCategory: String, CaseIterable, Identifiable, Sendable, Codable {
    case caches
    case modelCaches
    case backups
    case applicationData
    case trash
    case otherMeasured
    case systemUnclassified
    case available

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .caches: "Caches"
        case .modelCaches: "AI / Model Caches"
        case .backups: "Backups"
        case .applicationData: "Application Data"
        case .trash: "Trash"
        case .otherMeasured: "Other Measured User Data"
        case .systemUnclassified: "System & Unclassified"
        case .available: "Available Space"
        }
    }
}

public enum CleanupSafety: String, Sendable, Codable {
    case safeToRegenerate
    case requiresApplicationClosed
    case destructive
    case revealOnly
}

public enum CleanupAction: String, Sendable, Codable {
    case permanentlyDelete
    case moveToTrash
    case revealOnly
}

public enum ModelActivityEvidence: Equatable, Sendable, Codable {
    case toolMetadata(date: Date)
    case filesystemAccess(date: Date)
    case modification(date: Date)
    case unknown

    public var sourceLabel: String {
        switch self {
        case .toolMetadata: "Tool metadata"
        case .filesystemAccess: "Filesystem access evidence"
        case .modification: "Modification activity"
        case .unknown: "Unknown"
        }
    }
}

public struct RelatedApplication: Equatable, Sendable {
    public let bundleIdentifier: String
    public let isRunning: Bool

    public init(bundleIdentifier: String, isRunning: Bool) {
        self.bundleIdentifier = bundleIdentifier
        self.isRunning = isRunning
    }
}

public struct StorageItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let path: URL
    public let category: StorageCategory
    public let size: StorageMeasurement
    public let reclaimable: StorageMeasurement
    public let safety: CleanupSafety
    public let action: CleanupAction
    public let activity: ModelActivityEvidence?
    public let relatedApplication: RelatedApplication?
    public let cleanupRuleID: String?
    public let consequence: String
    public let regenerationCost: String
    public let isDefaultSelected: Bool

    public init(
        id: String,
        displayName: String,
        path: URL,
        category: StorageCategory,
        size: StorageMeasurement,
        reclaimable: StorageMeasurement,
        safety: CleanupSafety,
        action: CleanupAction,
        activity: ModelActivityEvidence? = nil,
        relatedApplication: RelatedApplication? = nil,
        cleanupRuleID: String? = nil,
        consequence: String = "Review this location before taking action.",
        regenerationCost: String = "Unknown",
        isDefaultSelected: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.path = path
        self.category = category
        self.size = size
        self.reclaimable = reclaimable
        self.safety = safety
        self.action = action
        self.activity = activity
        self.relatedApplication = relatedApplication
        self.cleanupRuleID = cleanupRuleID
        self.consequence = consequence
        self.regenerationCost = regenerationCost
        self.isDefaultSelected = isDefaultSelected
    }
}
