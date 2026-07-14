import XCTest
@testable import CleanSpaceCore

final class SnapshotInspectorTests: XCTestCase {
    func testDiskUtilityOutputCountsSnapshotIdentifiersWithoutInventingBytes() {
        let output = """
        Snapshots for disk3s1 (2 found)
        |
        +-- 11111111-1111-1111-1111-111111111111
            Snapshot UUID: 11111111-1111-1111-1111-111111111111
        +-- 22222222-2222-2222-2222-222222222222
            Snapshot UUID: 22222222-2222-2222-2222-222222222222
        """

        XCTAssertEqual(DirectSnapshotInspector.snapshotCount(in: output), 2)
    }

    func testStoreSnapshotInspectorExplicitlyReturnsUnsupported() async throws {
        let count = try await UnsupportedSnapshotInspector().localSnapshotCount(on: URL(filePath: "/"))
        XCTAssertNil(count)
    }
}
