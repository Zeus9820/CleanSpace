import Foundation
import XCTest
@testable import CleanSpaceCore

@MainActor
final class DashboardStateTests: XCTestCase {
    func testFirstLaunchShowsCapacityAndResidualBeforeCategoriesResolve() async throws {
        let item = dashboardItem(defaultSelected: true)
        let scanner = TimedScanner(events: [
            (.milliseconds(0), .capacity(.init(total: 1_000, available: 300, immediatelyAvailable: 200))),
            (.milliseconds(120), .category(.caches, bytes: 100, items: [item], coverageComplete: true)),
            (.milliseconds(10), .finished(.now))
        ])
        let model = DashboardModel(environment: environment(scanner: scanner))

        model.startScan(volume: URL(filePath: "/"))
        try await Task.sleep(for: .milliseconds(30))

        XCTAssertEqual(model.measurements[.available]?.bytes, 300)
        XCTAssertEqual(model.measurements[.systemUnclassified]?.bytes, 700)
        XCTAssertNil(model.measurements[.caches])

        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(model.measurements[.caches]?.bytes, 100)
        XCTAssertEqual(model.measurements[.systemUnclassified]?.bytes, 600)
        XCTAssertTrue(model.selectedItemIDs.contains(item.id))
        XCTAssertEqual(model.shelfState, .ready)
    }

    func testPartialCategoryKeepsMeasuredAccessibleBytesAndCoverageIssue() async throws {
        let issue = ScanCoverageIssue(root: URL(filePath: "/protected"), errorDescription: "Permission denied")
        let scanner = TimedScanner(events: [
            (.milliseconds(0), .capacity(.init(total: 1_000, available: 300))),
            (.milliseconds(0), .coverageIssue(issue)),
            (.milliseconds(0), .category(.applicationData, bytes: 200, items: [], coverageComplete: false)),
            (.milliseconds(0), .finished(.now))
        ])
        let model = DashboardModel(environment: environment(scanner: scanner))

        model.startScan(volume: URL(filePath: "/"))
        try await Task.sleep(for: .milliseconds(30))

        XCTAssertEqual(model.measurements[.applicationData]?.confidence, .measured)
        XCTAssertTrue(model.measurements[.applicationData]?.explanation.contains("incomplete") == true)
        XCTAssertEqual(model.coverageIssues, [issue])
    }

    private func dashboardItem(defaultSelected: Bool) -> StorageItem {
        StorageItem(
            id: "cache", displayName: "Cache", path: URL(filePath: "/fixture/cache"), category: .caches,
            size: .measured(100), reclaimable: .estimated(100, explanation: "Fixture"),
            safety: .safeToRegenerate, action: .permanentlyDelete,
            cleanupRuleID: "cache-v1", isDefaultSelected: defaultSelected
        )
    }

    private func environment(scanner: any StorageScanning) -> AppEnvironment {
        AppEnvironment(
            profile: .direct,
            capabilities: .init(canInspectSnapshots: false, requiresHomeFolderGrant: false),
            scanner: scanner,
            capacityProvider: DashboardCapacityProvider(),
            accessProvider: DashboardAccessProvider(),
            cleanupExecutor: DashboardCleanupExecutor(),
            workspaceRevealer: DashboardWorkspaceRevealer()
        )
    }
}

private struct TimedScanner: StorageScanning {
    let events: [(Duration, ScanEvent)]

    func scan(volume: URL) -> AsyncThrowingStream<ScanEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task.detached {
                do {
                    for (delay, event) in events {
                        try await Task.sleep(for: delay)
                        try Task.checkCancellation()
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

private struct DashboardCapacityProvider: VolumeCapacityProviding {
    func capacity(for volume: URL) throws -> VolumeCapacity { .init(total: 1_000, available: 300) }
}

@MainActor
private struct DashboardAccessProvider: StorageAccessProviding {
    func restoreAccess() -> StorageAccessState { .notRequired(URL(filePath: "/fixture")) }
    func requestAccess() async -> StorageAccessState { restoreAccess() }
}

private struct DashboardCleanupExecutor: CleanupExecuting {
    func execute(_ plan: CleanupPlan) async -> CleanupResult {
        .init(
            measuredCapacityReclaimed: .measured(0), movedToTrash: .measured(0),
            failures: [], estimateDifferenceExplanation: nil
        )
    }
}

private struct DashboardWorkspaceRevealer: WorkspaceRevealing {
    func reveal(_ url: URL) async {}
}
