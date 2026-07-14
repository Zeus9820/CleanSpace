import Foundation

public struct DirectSnapshotInspector: SnapshotInspecting {
    public init() {}

    public func localSnapshotCount(on volume: URL) async throws -> Int? {
        try await Task.detached(priority: .utility) {
            let process = Process()
            let output = Pipe()
            process.executableURL = URL(filePath: "/usr/sbin/diskutil")
            process.arguments = ["apfs", "listSnapshots", volume.path]
            process.standardOutput = output
            process.standardError = output
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw SnapshotInspectionError.commandFailed(
                    String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            return Self.snapshotCount(in: String(decoding: data, as: UTF8.self))
        }.value
    }

    static func snapshotCount(in output: String) -> Int {
        output.split(separator: "\n").filter {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("Snapshot UUID:")
        }.count
    }
}

public struct UnsupportedSnapshotInspector: SnapshotInspecting {
    public init() {}
    public func localSnapshotCount(on volume: URL) async throws -> Int? { nil }
}

private enum SnapshotInspectionError: LocalizedError {
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            message.isEmpty ? "macOS snapshot inspection failed" : message
        }
    }
}
