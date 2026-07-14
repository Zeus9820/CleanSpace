import Foundation

public struct VolumeCapacity: Equatable, Sendable {
    public let total: Int64
    public let available: Int64
    public let immediatelyAvailable: Int64

    public init(total: Int64, available: Int64, immediatelyAvailable: Int64? = nil) {
        self.total = total
        self.available = available
        self.immediatelyAvailable = immediatelyAvailable ?? available
    }
}

public enum ScanEvent: Sendable {
    case capacity(VolumeCapacity)
    case category(StorageCategory, bytes: Int64, items: [StorageItem], coverageComplete: Bool)
    case coverageIssue(ScanCoverageIssue)
    case finished(Date)
}

public protocol StorageScanning: Sendable {
    func scan(volume: URL) -> AsyncThrowingStream<ScanEvent, Error>
}

public protocol CleanupExecuting: Sendable { func execute(_ plan: CleanupPlan) async -> CleanupResult }
public enum StorageAccessState: Equatable, Sendable {
    case notRequired(URL)
    case selectionRequired
    case granted(URL)
    case staleBookmark
    case denied(String)

    public var accessibleRoot: URL? {
        switch self {
        case .notRequired(let url), .granted(let url): url
        case .selectionRequired, .staleBookmark, .denied: nil
        }
    }
}

@MainActor
public protocol StorageAccessProviding: Sendable {
    func restoreAccess() -> StorageAccessState
    func requestAccess() async -> StorageAccessState
}
public protocol VolumeCapacityProviding: Sendable { func capacity(for volume: URL) throws -> VolumeCapacity }
public protocol ApplicationDiscovering: Sendable { func isRunning(bundleIdentifier: String) async -> Bool }
public protocol SnapshotInspecting: Sendable { func localSnapshotCount(on volume: URL) async throws -> Int? }
public protocol WorkspaceRevealing: Sendable { func reveal(_ url: URL) async }
public protocol TrashMoving: Sendable { func moveToTrash(_ url: URL) async throws -> URL }
