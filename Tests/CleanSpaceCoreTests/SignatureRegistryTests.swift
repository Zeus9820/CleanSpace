import Foundation
import XCTest
@testable import CleanSpaceCore

final class SignatureRegistryTests: XCTestCase {
    func testStandardModelLocationsComeOnlyFromVersionedRegistry() {
        let registry = ModelSignatureRegistry.standard
        let modelLocations = StorageScanCatalog.standard.locations.filter { $0.category == .modelCaches }

        XCTAssertEqual(Set(modelLocations.map(\.id)), Set(registry.signatures.map(\.id)))
        XCTAssertTrue(registry.signatures.allSatisfy { $0.version > 0 && !$0.detectionSignature.isEmpty })
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: modelLocations.map { ($0.id, $0.signatureVersion) }),
            Dictionary(uniqueKeysWithValues: registry.signatures.map { ($0.id, $0.version) })
        )
    }

    func testToolMetadataTakesPriorityForLastActivityEvidence() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let metadata = root.appending(path: "activity.json")
        try Data("{}".utf8).write(to: metadata)
        let expected = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes([.modificationDate: expected], ofItemAtPath: metadata.path)
        let signature = ModelCacheSignature(
            id: "fixture-v2", version: 2, displayName: "Fixture", relativePath: "fixture",
            detectionSignature: "fixture-layout:v2", metadataRelativePaths: ["activity.json"]
        )

        let evidence = ModelActivityEvidenceProvider().evidence(for: root, signature: signature)

        guard case .toolMetadata(let date) = evidence else {
            return XCTFail("Expected tool-owned metadata evidence")
        }
        XCTAssertEqual(date.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1)
    }

    func testMissingActivityEvidenceIsExplicitlyUnknown() {
        let missing = URL(filePath: "/temporary-fixture-that-does-not-exist/never-created")
        let signature = ModelCacheSignature(
            id: "fixture-v1", version: 1, displayName: "Fixture", relativePath: "fixture",
            detectionSignature: "fixture-layout:v1"
        )

        XCTAssertEqual(ModelActivityEvidenceProvider().evidence(for: missing, signature: signature), .unknown)
    }
}
