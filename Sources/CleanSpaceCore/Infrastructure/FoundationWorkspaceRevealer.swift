import AppKit
import Foundation

public struct FoundationWorkspaceRevealer: WorkspaceRevealing {
    public init() {}

    public func reveal(_ url: URL) async {
        await MainActor.run {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}
