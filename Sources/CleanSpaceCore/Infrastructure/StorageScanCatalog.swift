import Foundation

public struct StorageScanLocation: Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let relativePath: String
    public let category: StorageCategory
    public let action: CleanupAction
    public let safety: CleanupSafety
    public let consequence: String
    public let regenerationCost: String
    public let isDefaultSelected: Bool
    public let excludedRelativePaths: [String]
    public let aggregateAsSingleItem: Bool
    public let requiresProtectedAppDataAccess: Bool

    public init(
        id: String,
        displayName: String,
        relativePath: String,
        category: StorageCategory,
        action: CleanupAction,
        safety: CleanupSafety,
        consequence: String,
        regenerationCost: String,
        isDefaultSelected: Bool = false,
        excludedRelativePaths: [String] = [],
        aggregateAsSingleItem: Bool = false,
        requiresProtectedAppDataAccess: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.relativePath = relativePath
        self.category = category
        self.action = action
        self.safety = safety
        self.consequence = consequence
        self.regenerationCost = regenerationCost
        self.isDefaultSelected = isDefaultSelected
        self.excludedRelativePaths = excludedRelativePaths
        self.aggregateAsSingleItem = aggregateAsSingleItem
        self.requiresProtectedAppDataAccess = requiresProtectedAppDataAccess
    }

    public func root(in home: URL) -> URL {
        home.appending(path: relativePath, directoryHint: .isDirectory)
    }

    public func exclusions(in home: URL) -> [URL] {
        excludedRelativePaths.map { home.appending(path: $0, directoryHint: .isDirectory) }
    }
}

public struct StorageScanCatalog: Sendable {
    public let locations: [StorageScanLocation]

    public init(locations: [StorageScanLocation]) {
        self.locations = locations
    }

    public static let standard = StorageScanCatalog(locations: [
        .init(
            id: "user-caches-v1", displayName: "Application Caches", relativePath: "Library/Caches",
            category: .caches, action: .permanentlyDelete, safety: .safeToRegenerate,
            consequence: "The related application may rebuild or download these temporary files.",
            regenerationCost: "Usually seconds to minutes", isDefaultSelected: true
        ),
        .init(
            id: "npm-cache-v1", displayName: "npm Cache", relativePath: ".npm",
            category: .caches, action: .permanentlyDelete, safety: .safeToRegenerate,
            consequence: "npm will download required packages again.", regenerationCost: "Requires re-downloading packages",
            isDefaultSelected: true
        ),
        .init(
            id: "gradle-cache-v1", displayName: "Gradle Caches", relativePath: ".gradle/caches",
            category: .caches, action: .permanentlyDelete, safety: .safeToRegenerate,
            consequence: "Gradle will rebuild dependency and build caches.", regenerationCost: "The next build will be slower",
            isDefaultSelected: true
        ),
        .init(
            id: "maven-cache-v1", displayName: "Maven Repository Cache", relativePath: ".m2/repository",
            category: .caches, action: .permanentlyDelete, safety: .safeToRegenerate,
            consequence: "Maven will download project dependencies again.", regenerationCost: "Requires re-downloading dependencies",
            isDefaultSelected: true
        ),
        .init(
            id: "xcode-derived-data-v1", displayName: "Xcode Derived Data", relativePath: "Library/Developer/Xcode/DerivedData",
            category: .caches, action: .permanentlyDelete, safety: .safeToRegenerate,
            consequence: "Xcode will rebuild indexes and compiled intermediates.", regenerationCost: "The next build and index will be slower",
            isDefaultSelected: true
        ),
        .init(
            id: "huggingface-models-v1", displayName: "Hugging Face Models", relativePath: ".cache/huggingface",
            category: .modelCaches, action: .permanentlyDelete, safety: .destructive,
            consequence: "Selected models are permanently removed and must be downloaded again.", regenerationCost: "Potentially many gigabytes and hours",
            aggregateAsSingleItem: true
        ),
        .init(
            id: "ollama-models-v1", displayName: "Ollama Models", relativePath: ".ollama/models",
            category: .modelCaches, action: .permanentlyDelete, safety: .destructive,
            consequence: "Selected models are permanently removed from Ollama.", regenerationCost: "Potentially many gigabytes and hours",
            aggregateAsSingleItem: true
        ),
        .init(
            id: "lmstudio-cache-v1", displayName: "LM Studio Cache", relativePath: ".cache/lm-studio",
            category: .modelCaches, action: .permanentlyDelete, safety: .destructive,
            consequence: "Selected LM Studio downloads are permanently removed.", regenerationCost: "Requires re-downloading models",
            aggregateAsSingleItem: true
        ),
        .init(
            id: "lmstudio-models-v1", displayName: "LM Studio Models", relativePath: "Library/Application Support/LM Studio/models",
            category: .modelCaches, action: .permanentlyDelete, safety: .destructive,
            consequence: "Selected LM Studio models are permanently removed.", regenerationCost: "Requires re-downloading models",
            aggregateAsSingleItem: true
        ),
        .init(
            id: "mobile-backups-v1", displayName: "Device Backups", relativePath: "Library/Application Support/MobileSync/Backup",
            category: .backups, action: .moveToTrash, safety: .destructive,
            consequence: "The selected iPhone or iPad backup moves to Trash and will no longer be available for restore.",
            regenerationCost: "A new device backup may take significant time"
        ),
        .init(
            id: "application-support-visibility-v1", displayName: "Application Support", relativePath: "Library/Application Support",
            category: .applicationData, action: .revealOnly, safety: .revealOnly,
            consequence: "Application data is shown for review only because its contents may include projects, settings, or databases.",
            regenerationCost: "May be irreplaceable",
            excludedRelativePaths: ["Library/Application Support/MobileSync/Backup", "Library/Application Support/LM Studio/models"],
            requiresProtectedAppDataAccess: true
        ),
        .init(
            id: "containers-visibility-v1", displayName: "Application Containers", relativePath: "Library/Containers",
            category: .applicationData, action: .revealOnly, safety: .revealOnly,
            consequence: "Container data is shown for review only because it can contain projects and application databases.",
            regenerationCost: "May be irreplaceable", requiresProtectedAppDataAccess: true
        ),
        .init(
            id: "group-containers-visibility-v1", displayName: "Shared Application Data", relativePath: "Library/Group Containers",
            category: .applicationData, action: .revealOnly, safety: .revealOnly,
            consequence: "Shared container data is shown for review only.", regenerationCost: "May be irreplaceable",
            requiresProtectedAppDataAccess: true
        ),
        .init(
            id: "simulators-visibility-v1", displayName: "Apple Platform Simulators", relativePath: "Library/Developer/CoreSimulator",
            category: .applicationData, action: .revealOnly, safety: .revealOnly,
            consequence: "Simulator devices and their app data are shown for review only.", regenerationCost: "May contain development test data"
        ),
        .init(
            id: "xcode-archives-visibility-v1", displayName: "Xcode Archives", relativePath: "Library/Developer/Xcode/Archives",
            category: .applicationData, action: .revealOnly, safety: .revealOnly,
            consequence: "Signed build archives are shown for review only.", regenerationCost: "Rebuilding may require old source and signing assets"
        ),
        .init(
            id: "documents-visibility-v1", displayName: "Documents", relativePath: "Documents",
            category: .otherMeasured, action: .revealOnly, safety: .revealOnly,
            consequence: "Personal files are never deleted by CleanSpace.", regenerationCost: "May be irreplaceable"
        ),
        .init(
            id: "downloads-visibility-v1", displayName: "Downloads", relativePath: "Downloads",
            category: .otherMeasured, action: .revealOnly, safety: .revealOnly,
            consequence: "Downloads are measured and revealed for manual review.", regenerationCost: "Varies"
        ),
        .init(
            id: "desktop-visibility-v1", displayName: "Desktop", relativePath: "Desktop",
            category: .otherMeasured, action: .revealOnly, safety: .revealOnly,
            consequence: "Desktop files are never deleted by CleanSpace.", regenerationCost: "May be irreplaceable"
        ),
        .init(
            id: "media-visibility-v1", displayName: "Pictures", relativePath: "Pictures",
            category: .otherMeasured, action: .revealOnly, safety: .revealOnly,
            consequence: "Photos and image libraries are measured and revealed only.", regenerationCost: "May be irreplaceable"
        ),
        .init(
            id: "movies-visibility-v1", displayName: "Movies", relativePath: "Movies",
            category: .otherMeasured, action: .revealOnly, safety: .revealOnly,
            consequence: "Videos and editing libraries are measured and revealed only.", regenerationCost: "May be irreplaceable"
        ),
        .init(
            id: "music-visibility-v1", displayName: "Music", relativePath: "Music",
            category: .otherMeasured, action: .revealOnly, safety: .revealOnly,
            consequence: "Music and audio libraries are measured and revealed only.", regenerationCost: "May be irreplaceable"
        ),
        .init(
            id: "trash-v1", displayName: "Trash", relativePath: ".Trash",
            category: .trash, action: .permanentlyDelete, safety: .destructive,
            consequence: "Selected items are permanently deleted and cannot be recovered from Trash.", regenerationCost: "Irrecoverable"
        )
    ])

    public func cleanupRules(home: URL, profile: DistributionProfile) -> [CleanupRule] {
        locations.compactMap { location in
            guard location.action != .revealOnly else { return nil }
            return CleanupRule(
                id: location.id,
                supportedProfiles: [profile],
                allowedRoot: location.root(in: home),
                detectionSignature: "registered-path:\(location.relativePath)",
                signatureVersion: 1,
                action: location.action,
                safetyCopy: location.consequence,
                allowsRoot: location.aggregateAsSingleItem
            )
        }
    }
}
