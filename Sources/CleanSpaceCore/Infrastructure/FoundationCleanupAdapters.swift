import Foundation

public struct FoundationPermanentDeleter: PermanentDeleting {
    public init() {}

    public func permanentlyDelete(_ url: URL) async throws {
        try await Task.detached(priority: .utility) {
            try FileManager.default.removeItem(at: url)
        }.value
    }
}

public struct FoundationTrashMover: TrashMoving {
    public init() {}

    public func moveToTrash(_ url: URL) async throws -> URL {
        try await Task.detached(priority: .utility) {
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
            guard let resultingURL else { throw FoundationCleanupAdapterError.missingTrashResult }
            return resultingURL as URL
        }.value
    }
}

private enum FoundationCleanupAdapterError: LocalizedError {
    case missingTrashResult

    var errorDescription: String? { "macOS did not return the item's Trash location" }
}
