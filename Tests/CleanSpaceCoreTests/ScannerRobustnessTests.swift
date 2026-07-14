import Foundation
import XCTest
@testable import CleanSpaceCore

final class ScannerRobustnessTests: XCTestCase {
    func testScannerDoesNotFollowSymbolicLinks() async throws {
        let fixture = try TemporaryScanFixture()
        defer { fixture.remove() }
        let root = fixture.home.appending(path: "Caches", directoryHint: .isDirectory)
        let outside = fixture.home.appending(path: "Outside", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 16_384).write(to: outside.appending(path: "must-not-count.bin"))
        try FileManager.default.createSymbolicLink(
            at: root.appending(path: "linked-outside"),
            withDestinationURL: outside
        )

        let result = try await scanCategory(.caches, scanner: fixture.scanner(relativePath: "Caches"))

        XCTAssertEqual(result.bytes, 0)
        XCTAssertTrue(result.items.isEmpty)
    }

    func testVolumeAndSymlinkAdmissionPolicy() {
        XCTAssertFalse(RegisteredRootScanner.shouldMeasure(
            isSymbolicLink: true, expectedVolume: "volume-a", foundVolume: "volume-a"
        ))
        XCTAssertFalse(RegisteredRootScanner.shouldMeasure(
            isSymbolicLink: false, expectedVolume: "volume-a", foundVolume: "volume-b"
        ))
        XCTAssertTrue(RegisteredRootScanner.shouldMeasure(
            isSymbolicLink: false, expectedVolume: "volume-a", foundVolume: "volume-a"
        ))
        XCTAssertTrue(RegisteredRootScanner.shouldMeasure(
            isSymbolicLink: false, expectedVolume: nil, foundVolume: nil
        ))
    }

    func testCancellationStopsBeforeFinishedEvent() async throws {
        let fixture = try TemporaryScanFixture()
        defer { fixture.remove() }
        let root = fixture.home.appending(path: "Caches", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for index in 0..<4_000 {
            try Data(repeating: UInt8(index % 255), count: 512).write(
                to: root.appending(path: "file-\(index).cache")
            )
        }

        let scanner = fixture.scanner(relativePath: "Caches", aggregateAsSingleItem: true)
        let consumer = Task { () -> Bool in
            for try await event in scanner.scan(volume: fixture.home) {
                if case .finished = event { return true }
            }
            return false
        }
        consumer.cancel()

        let emittedFinished = try await consumer.value
        XCTAssertFalse(emittedFinished)
    }

    func testFileRaceDoesNotAbortTheWholeScan() async throws {
        let fixture = try TemporaryScanFixture()
        defer { fixture.remove() }
        let root = fixture.home.appending(path: "Caches", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var files: [URL] = []
        for index in 0..<1_000 {
            let file = root.appending(path: "race-\(index).cache")
            try Data(repeating: 7, count: 1_024).write(to: file)
            files.append(file)
        }

        let scanner = fixture.scanner(relativePath: "Caches", aggregateAsSingleItem: true)
        let deletion = Task.detached(priority: .utility) {
            for file in files.stride(from: 0, by: 2) {
                try? FileManager.default.removeItem(at: file)
            }
        }
        let result = try await scanCategory(.caches, scanner: scanner)
        _ = await deletion.result

        XCTAssertGreaterThanOrEqual(result.bytes, 0)
        XCTAssertLessThanOrEqual(result.items.count, 1)
    }

    private func scanCategory(
        _ category: StorageCategory,
        scanner: RegisteredRootScanner
    ) async throws -> (bytes: Int64, items: [StorageItem]) {
        for try await event in scanner.scan(volume: URL(filePath: "/", directoryHint: .isDirectory)) {
            if case .category(category, let bytes, let items, _) = event {
                return (bytes, items)
            }
        }
        return (0, [])
    }
}

private struct TemporaryScanFixture {
    let home: URL

    init() throws {
        home = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    func scanner(relativePath: String, aggregateAsSingleItem: Bool = false) -> RegisteredRootScanner {
        let catalog = StorageScanCatalog(locations: [
            .init(
                id: "fixture-v1",
                displayName: "Fixture",
                relativePath: relativePath,
                category: .caches,
                action: .permanentlyDelete,
                safety: .safeToRegenerate,
                consequence: "Fixture only",
                regenerationCost: "Low",
                aggregateAsSingleItem: aggregateAsSingleItem
            )
        ])
        return RegisteredRootScanner(
            capacityProvider: RobustnessCapacityProvider(),
            catalog: catalog,
            home: home,
            maximumConcurrentMeasurements: 4
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: home)
    }
}

private struct RobustnessCapacityProvider: VolumeCapacityProviding {
    func capacity(for volume: URL) throws -> VolumeCapacity {
        VolumeCapacity(total: 1_000_000, available: 500_000)
    }
}

private extension Array {
    func stride(from start: Int, by step: Int) -> [Element] {
        Swift.stride(from: start, to: count, by: step).map { self[$0] }
    }
}
