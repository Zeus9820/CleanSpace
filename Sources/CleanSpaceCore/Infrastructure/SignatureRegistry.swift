import Foundation

public struct ModelCacheSignature: Identifiable, Equatable, Sendable {
    public let id: String
    public let version: Int
    public let displayName: String
    public let relativePath: String
    public let detectionSignature: String
    public let metadataRelativePaths: [String]
    public let relatedBundleIdentifier: String?

    public init(
        id: String,
        version: Int,
        displayName: String,
        relativePath: String,
        detectionSignature: String,
        metadataRelativePaths: [String] = [],
        relatedBundleIdentifier: String? = nil
    ) {
        self.id = id
        self.version = version
        self.displayName = displayName
        self.relativePath = relativePath
        self.detectionSignature = detectionSignature
        self.metadataRelativePaths = metadataRelativePaths
        self.relatedBundleIdentifier = relatedBundleIdentifier
    }
}

public struct ModelSignatureRegistry: Sendable {
    public let registryVersion: Int
    public let signatures: [ModelCacheSignature]

    public init(registryVersion: Int, signatures: [ModelCacheSignature]) {
        self.registryVersion = registryVersion
        self.signatures = signatures
    }

    /// This registry is shipped with the application. Changing a path or its
    /// cleanup meaning requires a new signature version and application release.
    public static let standard = ModelSignatureRegistry(registryVersion: 1, signatures: [
        .init(
            id: "huggingface-models-v1", version: 1, displayName: "Hugging Face Models",
            relativePath: ".cache/huggingface", detectionSignature: "huggingface-cache-layout:v1"
        ),
        .init(
            id: "ollama-models-v1", version: 1, displayName: "Ollama Models",
            relativePath: ".ollama/models", detectionSignature: "ollama-model-store:v1",
            relatedBundleIdentifier: "com.electron.ollama"
        ),
        .init(
            id: "lmstudio-cache-v1", version: 1, displayName: "LM Studio Cache",
            relativePath: ".cache/lm-studio", detectionSignature: "lm-studio-cache-layout:v1"
        ),
        .init(
            id: "lmstudio-models-v1", version: 1, displayName: "LM Studio Models",
            relativePath: "Library/Application Support/LM Studio/models",
            detectionSignature: "lm-studio-model-store:v1"
        )
    ])
}

public struct ModelActivityEvidenceProvider: Sendable {
    public init() {}

    public func evidence(for root: URL, signature: ModelCacheSignature) -> ModelActivityEvidence {
        for relativePath in signature.metadataRelativePaths {
            let metadata = root.appending(path: relativePath)
            if let date = try? metadata.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                return .toolMetadata(date: date)
            }
        }
        if let date = try? root.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate {
            return .filesystemAccess(date: date)
        }
        if let date = try? root.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
            return .modification(date: date)
        }
        return .unknown
    }
}
