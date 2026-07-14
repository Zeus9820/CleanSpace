import Foundation
import XCTest
@testable import CleanSpaceCore

final class CleanupExecutorTests: XCTestCase {
    func testExecutorRoutesPermanentAndTrashActionsToSeparateAdapters() async {
        let permanent = RecordingPermanentDeleter()
        let trash = RecordingTrashMover()
        let fixture = CleanupFixture()
        let executor = fixture.executor(permanent: permanent, trash: trash)

        let result = await executor.execute(.init(items: [
            fixture.item(name: "cache", ruleID: "delete-v1", action: .permanentlyDelete),
            fixture.item(name: "backup", ruleID: "trash-v1", action: .moveToTrash)
        ]))

        let permanentPaths = await permanent.paths()
        let trashPaths = await trash.paths()
        XCTAssertEqual(permanentPaths, [fixture.root.appending(path: "Delete/cache")])
        XCTAssertEqual(trashPaths, [fixture.root.appending(path: "Trash/backup")])
        XCTAssertTrue(result.failures.isEmpty)
        XCTAssertEqual(result.movedToTrash.bytes, 4_096)
    }

    func testAdapterFailureIsReportedWithoutTryingAnotherAction() async {
        let permanent = RecordingPermanentDeleter(error: FixtureError.expected)
        let trash = RecordingTrashMover()
        let fixture = CleanupFixture()
        let executor = fixture.executor(permanent: permanent, trash: trash)

        let result = await executor.execute(.init(items: [
            fixture.item(name: "cache", ruleID: "delete-v1", action: .permanentlyDelete)
        ]))

        XCTAssertEqual(result.failures.count, 1)
        XCTAssertTrue(result.failures[0].reason.contains("fixture failure"))
        let trashPaths = await trash.paths()
        XCTAssertTrue(trashPaths.isEmpty)
    }

    func testRunningApplicationBlocksApplicationDataCleanup() async {
        let permanent = RecordingPermanentDeleter()
        let trash = RecordingTrashMover()
        let fixture = CleanupFixture()
        let executor = fixture.executor(
            permanent: permanent,
            trash: trash,
            applicationDiscoverer: FixedApplicationDiscoverer(isRunning: true)
        )
        let item = StorageItem(
            id: "app", displayName: "App Data", path: fixture.root.appending(path: "App/app"),
            category: .applicationData, size: .measured(4_096),
            reclaimable: .estimated(4_096, explanation: "Fixture"),
            safety: .requiresApplicationClosed, action: .moveToTrash,
            relatedApplication: .init(bundleIdentifier: "com.example.app", isRunning: false),
            cleanupRuleID: "app-v1"
        )

        let result = await executor.execute(.init(items: [item]))

        let trashPaths = await trash.paths()
        XCTAssertTrue(trashPaths.isEmpty)
        XCTAssertEqual(result.failures.count, 1)
        XCTAssertTrue(result.failures[0].reason.contains("Quit"))
    }
}

private struct CleanupFixture {
    let root = URL(filePath: "/temporary-cleanup-fixture", directoryHint: .isDirectory)

    var catalog: StorageScanCatalog {
        .init(locations: [
            .init(
                id: "delete-v1", displayName: "Delete", relativePath: "Delete", category: .caches,
                action: .permanentlyDelete, safety: .safeToRegenerate,
                consequence: "Fixture", regenerationCost: "Low"
            ),
            .init(
                id: "trash-v1", displayName: "Trash", relativePath: "Trash", category: .backups,
                action: .moveToTrash, safety: .destructive,
                consequence: "Fixture", regenerationCost: "Low"
            ),
            .init(
                id: "app-v1", displayName: "App", relativePath: "App", category: .applicationData,
                action: .moveToTrash, safety: .requiresApplicationClosed,
                consequence: "Fixture", regenerationCost: "Low", relatedBundleIdentifier: "com.example.app"
            )
        ])
    }

    func executor(
        permanent: any PermanentDeleting,
        trash: any TrashMoving,
        applicationDiscoverer: any ApplicationDiscovering = FixedApplicationDiscoverer(isRunning: false)
    ) -> RegisteredCleanupExecutor {
        RegisteredCleanupExecutor(
            profile: .direct, home: root, catalog: catalog,
            capacityProvider: CleanupCapacityProvider(), volume: root,
            permanentDeleter: permanent, trashMover: trash,
            applicationDiscoverer: applicationDiscoverer
        )
    }

    func item(name: String, ruleID: String, action: CleanupAction) -> StorageItem {
        let directory = action == .permanentlyDelete ? "Delete" : "Trash"
        return StorageItem(
            id: name, displayName: name, path: root.appending(path: "\(directory)/\(name)"),
            category: action == .permanentlyDelete ? .caches : .backups,
            size: .measured(4_096), reclaimable: .estimated(4_096, explanation: "Fixture"),
            safety: action == .permanentlyDelete ? .safeToRegenerate : .destructive,
            action: action, cleanupRuleID: ruleID
        )
    }
}

private actor RecordingPermanentDeleter: PermanentDeleting {
    private var recorded: [URL] = []
    private let error: Error?

    init(error: Error? = nil) { self.error = error }

    func permanentlyDelete(_ url: URL) async throws {
        recorded.append(url)
        if let error { throw error }
    }

    func paths() -> [URL] { recorded }
}

private actor RecordingTrashMover: TrashMoving {
    private var recorded: [URL] = []

    func moveToTrash(_ url: URL) async throws -> URL {
        recorded.append(url)
        return URL(filePath: "/Trash").appending(path: url.lastPathComponent)
    }

    func paths() -> [URL] { recorded }
}

private struct FixedApplicationDiscoverer: ApplicationDiscovering {
    let isRunning: Bool
    func isRunning(bundleIdentifier: String) async -> Bool { isRunning }
}

private struct CleanupCapacityProvider: VolumeCapacityProviding {
    func capacity(for volume: URL) throws -> VolumeCapacity {
        .init(total: 1_000_000, available: 500_000)
    }
}

private enum FixtureError: LocalizedError {
    case expected
    var errorDescription: String? { "fixture failure" }
}
