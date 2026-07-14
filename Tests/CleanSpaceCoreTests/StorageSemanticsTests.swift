import Foundation
import XCTest
@testable import CleanSpaceCore

final class StorageSemanticsTests: XCTestCase {
    func testRegisteredScannerFindsTopLevelItemsWithoutUsingRealHome() async throws {
        let fixture = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let cache = fixture.appending(path: "Library/Caches", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 8_192).write(to: cache.appending(path: "sample.cache"))
        defer { try? FileManager.default.removeItem(at: fixture) }

        let catalog = StorageScanCatalog(locations: [
            .init(
                id: "fixture-cache-v1", displayName: "Fixture Cache", relativePath: "Library/Caches",
                category: .caches, action: .permanentlyDelete, safety: .safeToRegenerate,
                consequence: "Recreated by the fixture", regenerationCost: "Low", isDefaultSelected: true
            )
        ])
        let scanner = RegisteredRootScanner(
            capacityProvider: FixedCapacityProvider(total: 1_000_000, available: 500_000),
            catalog: catalog,
            home: fixture
        )
        var cacheEvent: (Int64, [StorageItem])?
        for try await event in scanner.scan(volume: fixture) {
            if case .category(.caches, let bytes, let items, _) = event {
                cacheEvent = (bytes, items)
            }
        }

        XCTAssertGreaterThan(cacheEvent?.0 ?? 0, 0)
        XCTAssertEqual(cacheEvent?.1.first?.displayName, "sample.cache")
        XCTAssertEqual(cacheEvent?.1.first?.cleanupRuleID, "fixture-cache-v1")
        XCTAssertEqual(cacheEvent?.1.first?.isDefaultSelected, true)
    }

    func testRegisteredScannerAutomaticallyExcludesNestedRegisteredRoots() async throws {
        let fixture = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let broadRoot = fixture.appending(path: "Root", directoryHint: .isDirectory)
        let nestedRoot = broadRoot.appending(path: "Nested", directoryHint: .isDirectory)
        let siblingRoot = broadRoot.appending(path: "Visible", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: nestedRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: siblingRoot, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 8_192).write(to: nestedRoot.appending(path: "nested.data"))
        try Data(repeating: 2, count: 8_192).write(to: siblingRoot.appending(path: "visible.data"))
        defer { try? FileManager.default.removeItem(at: fixture) }

        let catalog = StorageScanCatalog(locations: [
            .init(
                id: "broad-v1", displayName: "Broad", relativePath: "Root",
                category: .applicationData, action: .revealOnly, safety: .revealOnly,
                consequence: "Fixture", regenerationCost: "Unknown"
            ),
            .init(
                id: "nested-v1", displayName: "Nested", relativePath: "Root/Nested",
                category: .backups, action: .moveToTrash, safety: .destructive,
                consequence: "Fixture", regenerationCost: "Unknown", aggregateAsSingleItem: true
            )
        ])
        let scanner = RegisteredRootScanner(
            capacityProvider: FixedCapacityProvider(total: 1_000_000, available: 500_000),
            catalog: catalog,
            home: fixture,
            maximumConcurrentMeasurements: 4
        )
        var applicationItems: [StorageItem] = []
        var backupItems: [StorageItem] = []
        for try await event in scanner.scan(volume: fixture) {
            if case .category(.applicationData, _, let items, _) = event { applicationItems = items }
            if case .category(.backups, _, let items, _) = event { backupItems = items }
        }

        XCTAssertEqual(applicationItems.map(\.displayName), ["Visible"])
        XCTAssertEqual(backupItems.map(\.displayName), ["Nested"])
    }

    func testConcurrentScannerCountsHardLinkedFileOnce() async throws {
        let fixture = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let root = fixture.appending(path: "Caches", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let original = root.appending(path: "original.cache")
        try Data(repeating: 3, count: 16_384).write(to: original)
        try FileManager.default.linkItem(at: original, to: root.appending(path: "linked.cache"))
        defer { try? FileManager.default.removeItem(at: fixture) }

        let catalog = StorageScanCatalog(locations: [
            .init(
                id: "hardlink-v1", displayName: "Hard links", relativePath: "Caches",
                category: .caches, action: .permanentlyDelete, safety: .safeToRegenerate,
                consequence: "Fixture", regenerationCost: "Low"
            )
        ])
        let scanner = RegisteredRootScanner(
            capacityProvider: FixedCapacityProvider(total: 1_000_000, available: 500_000),
            catalog: catalog,
            home: fixture,
            maximumConcurrentMeasurements: 4
        )
        var result: (bytes: Int64, items: [StorageItem])?
        for try await event in scanner.scan(volume: fixture) {
            if case .category(.caches, let bytes, let items, _) = event { result = (bytes, items) }
        }

        XCTAssertGreaterThan(result?.bytes ?? 0, 0)
        XCTAssertEqual(result?.items.count, 1)
    }

    func testCapacityDistinguishesFinderAvailableFromImmediatelyFree() {
        let capacity = VolumeCapacity(total: 500, available: 109, immediatelyAvailable: 73)

        XCTAssertEqual(capacity.available, 109)
        XCTAssertEqual(capacity.immediatelyAvailable, 73)
    }

    func testUnsignedScannerSkipsProtectedAppDataWithoutTouchingRoot() async throws {
        let fixture = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let protectedRoot = fixture.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: protectedRoot, withIntermediateDirectories: true)
        try Data(repeating: 7, count: 8_192).write(to: protectedRoot.appending(path: "private.data"))
        defer { try? FileManager.default.removeItem(at: fixture) }

        let catalog = StorageScanCatalog(locations: [
            .init(
                id: "protected-v1", displayName: "Protected", relativePath: "Library/Application Support",
                category: .applicationData, action: .revealOnly, safety: .revealOnly,
                consequence: "Fixture", regenerationCost: "Unknown", requiresProtectedAppDataAccess: true
            )
        ])
        let scanner = RegisteredRootScanner(
            capacityProvider: FixedCapacityProvider(total: 1_000_000, available: 500_000),
            catalog: catalog,
            home: fixture,
            includeProtectedAppData: false
        )
        var categoryMeasurement: (bytes: Int64, complete: Bool)?
        var issues: [ScanCoverageIssue] = []
        for try await event in scanner.scan(volume: fixture) {
            if case .category(.applicationData, let bytes, _, let complete) = event {
                categoryMeasurement = (bytes, complete)
            }
            if case .coverageIssue(let issue) = event { issues.append(issue) }
        }

        XCTAssertEqual(categoryMeasurement?.bytes, 0)
        XCTAssertEqual(categoryMeasurement?.complete, false)
        XCTAssertEqual(issues.map(\.root.standardizedFileURL), [protectedRoot.standardizedFileURL])
        XCTAssertTrue(issues.first?.errorDescription.contains("not scanned automatically") == true)
    }

    func testStandardCatalogNeverPreselectsModelsBackupsOrTrash() {
        let protectedCategories: Set<StorageCategory> = [.modelCaches, .backups, .applicationData, .trash]
        let protectedLocations = StorageScanCatalog.standard.locations.filter { protectedCategories.contains($0.category) }
        let safeCaches = StorageScanCatalog.standard.locations.filter { $0.category == .caches }

        XCTAssertTrue(protectedLocations.allSatisfy { !$0.isDefaultSelected })
        XCTAssertTrue(safeCaches.allSatisfy(\.isDefaultSelected))
    }

    func testStandardCatalogProvidesNoCleanupRulesForRevealOnlyLocations() {
        let home = URL(filePath: "/temporary-fixture-home", directoryHint: .isDirectory)
        let rules = StorageScanCatalog.standard.cleanupRules(home: home, profile: .direct)
        let ruleIDs = Set(rules.map(\.id))
        let revealOnlyIDs = StorageScanCatalog.standard.locations
            .filter { $0.action == .revealOnly }
            .map(\.id)

        XCTAssertTrue(revealOnlyIDs.allSatisfy { !ruleIDs.contains($0) })
    }

    func testRegisteredModelRuleAllowsOnlyItsExactRootAndDescendants() {
        let home = URL(filePath: "/temporary-fixture-home", directoryHint: .isDirectory)
        let location = StorageScanCatalog.standard.locations.first { $0.id == "ollama-models-v1" }!
        let rule = StorageScanCatalog.standard.cleanupRules(home: home, profile: .direct).first { $0.id == location.id }!
        let root = location.root(in: home)

        XCTAssertTrue(rule.contains(root))
        XCTAssertTrue(rule.contains(root.appending(path: "blobs/model")))
        XCTAssertFalse(rule.contains(home.appending(path: ".ollama")))
        XCTAssertFalse(rule.contains(home.appending(path: ".ollama-other/models")))
    }

    func testRegisteredCleanupDeletesOnlyContainedTemporaryFixture() async throws {
        let fixture = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let cache = fixture.appending(path: "Library/Caches", directoryHint: .isDirectory)
        let itemURL = cache.appending(path: "safe-item", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: itemURL, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 4_096).write(to: itemURL.appending(path: "data"))
        defer { try? FileManager.default.removeItem(at: fixture) }

        let catalog = StorageScanCatalog(locations: [
            .init(
                id: "fixture-cleanup-v1", displayName: "Fixture", relativePath: "Library/Caches",
                category: .caches, action: .permanentlyDelete, safety: .safeToRegenerate,
                consequence: "Fixture only", regenerationCost: "Low"
            )
        ])
        let item = StorageItem(
            id: "fixture-item", displayName: "safe-item", path: itemURL, category: .caches,
            size: .measured(4_096), reclaimable: .estimated(4_096, explanation: "Fixture estimate"),
            safety: .safeToRegenerate, action: .permanentlyDelete, cleanupRuleID: "fixture-cleanup-v1"
        )
        let executor = RegisteredCleanupExecutor(
            profile: .direct,
            home: fixture,
            catalog: catalog,
            capacityProvider: FixedCapacityProvider(total: 1_000_000, available: 500_000),
            volume: fixture
        )

        let result = await executor.execute(.init(items: [item]))

        XCTAssertFalse(FileManager.default.fileExists(atPath: itemURL.path))
        XCTAssertTrue(result.failures.isEmpty)
        XCTAssertEqual(result.measuredCapacityReclaimed.confidence, .measured)
    }

    @MainActor
    func testDirectAccessDoesNotRequireFolderSelection() {
        let fixtureHome = URL(filePath: "/temporary-fixture-home", directoryHint: .isDirectory)
        let state = DirectStorageAccessProvider(home: fixtureHome).restoreAccess()

        XCTAssertEqual(state.accessibleRoot, fixtureHome)
    }

    @MainActor
    func testStoreAccessRequiresSelectionWithoutSavedBookmark() {
        let suiteName = "CleanSpaceCoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let provider = SecurityScopedHomeAccessProvider(defaults: defaults, bookmarkKey: "testBookmark")

        XCTAssertEqual(provider.restoreAccess(), .selectionRequired)
    }

    func testResidualIsDerivedFromCapacityAndAccessibleMeasurements() {
        let snapshot = ScanSnapshot(
            totalCapacity: 1_000,
            availableCapacity: 300,
            measuredCategories: [.caches: 100, .trash: 50]
        )

        XCTAssertEqual(snapshot.measurements[.systemUnclassified]?.bytes, 550)
        XCTAssertEqual(snapshot.measurements[.systemUnclassified]?.confidence, .derived)
        XCTAssertEqual(snapshot.measurements[.available]?.confidence, .measured)
    }

    func testCallerCannotOverrideAvailableOrResidualSemantics() {
        let snapshot = ScanSnapshot(
            totalCapacity: 1_000,
            availableCapacity: 300,
            measuredCategories: [.available: 1, .systemUnclassified: 1, .caches: 100]
        )

        XCTAssertEqual(snapshot.measurements[.available]?.bytes, 300)
        XCTAssertEqual(snapshot.measurements[.systemUnclassified]?.bytes, 600)
    }

    func testIncompleteRootsRemainUnsizedCoverageIssues() {
        let issue = ScanCoverageIssue(
            root: URL(filePath: "/protected"),
            errorDescription: "Permission denied",
            accessAction: "Grant access"
        )
        let snapshot = ScanSnapshot(
            totalCapacity: 1_000,
            availableCapacity: 300,
            measuredCategories: [:],
            coverage: .init(issues: [issue])
        )

        XCTAssertFalse(snapshot.coverage.isComplete)
        XCTAssertEqual(snapshot.coverage.issues.first?.errorDescription, "Permission denied")
        XCTAssertEqual(snapshot.measurements[.systemUnclassified]?.bytes, 700)
    }

    func testCleanupRuleRejectsRootAndSiblingPrefix() {
        let rule = CleanupRule(
            id: "cache.v1",
            supportedProfiles: [.direct, .store],
            allowedRoot: URL(filePath: "/Users/test/Library/Caches/App"),
            detectionSignature: "bundle-id",
            signatureVersion: 1,
            action: .permanentlyDelete,
            safetyCopy: "The app may recreate this cache."
        )

        XCTAssertFalse(rule.contains(URL(filePath: "/Users/test/Library/Caches/App")))
        XCTAssertTrue(rule.contains(URL(filePath: "/Users/test/Library/Caches/App/file.bin")))
        XCTAssertFalse(rule.contains(URL(filePath: "/Users/test/Library/Caches/Application/file.bin")))
    }

    func testCleanupPlanSeparatesPermanentAndTrashEstimates() {
        let permanent = item(id: "a", bytes: 10, action: .permanentlyDelete)
        let trash = item(id: "b", bytes: 20, action: .moveToTrash)
        let reveal = item(id: "c", bytes: 30, action: .revealOnly)
        let plan = CleanupPlan(items: [permanent, trash, reveal])

        XCTAssertEqual(plan.estimatedPermanentDeletion, 10)
        XCTAssertEqual(plan.estimatedMovedToTrash, 20)
    }

    private func item(id: String, bytes: Int64, action: CleanupAction) -> StorageItem {
        StorageItem(
            id: id,
            displayName: id,
            path: URL(filePath: "/tmp/\(id)"),
            category: .caches,
            size: .measured(bytes),
            reclaimable: .estimated(bytes, explanation: "Logical allocated size before cleanup"),
            safety: action == .revealOnly ? .revealOnly : .safeToRegenerate,
            action: action
        )
    }
}

private struct FixedCapacityProvider: VolumeCapacityProviding {
    let total: Int64
    let available: Int64

    func capacity(for volume: URL) throws -> VolumeCapacity {
        VolumeCapacity(total: total, available: available)
    }
}
