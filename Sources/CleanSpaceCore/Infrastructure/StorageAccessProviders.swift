import AppKit
import Foundation

public struct DirectStorageAccessProvider: StorageAccessProviding {
    private let home: URL

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home
    }

    public func restoreAccess() -> StorageAccessState {
        .notRequired(home)
    }

    public func requestAccess() async -> StorageAccessState {
        restoreAccess()
    }
}

@MainActor
public final class SecurityScopedHomeAccessProvider: StorageAccessProviding {
    private let defaults: UserDefaults
    private let bookmarkKey: String
    private var activeURL: URL?

    public init(defaults: UserDefaults = .standard, bookmarkKey: String = "CleanSpace.homeFolderBookmark") {
        self.defaults = defaults
        self.bookmarkKey = bookmarkKey
    }

    deinit {
        activeURL?.stopAccessingSecurityScopedResource()
    }

    public func restoreAccess() -> StorageAccessState {
        guard let data = defaults.data(forKey: bookmarkKey) else {
            return .selectionRequired
        }
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            guard !isStale else {
                releaseAccess()
                defaults.removeObject(forKey: bookmarkKey)
                return .staleBookmark
            }
            guard url.startAccessingSecurityScopedResource() else {
                releaseAccess()
                return .denied("macOS did not restore access to the selected Home folder.")
            }
            releaseAccess()
            activeURL = url
            return .granted(url)
        } catch {
            releaseAccess()
            defaults.removeObject(forKey: bookmarkKey)
            return .denied(error.localizedDescription)
        }
    }

    public func requestAccess() async -> StorageAccessState {
        let panel = NSOpenPanel()
        panel.title = "Choose Your Home Folder"
        panel.message = "CleanSpace needs access to measure storage in your Home folder. It works fully offline and only cleans items you explicitly confirm."
        panel.prompt = "Grant Access"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return .denied("Home-folder access was not granted. Storage outside the app container remains unavailable.")
        }
        guard selectedURL.standardizedFileURL == FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL else {
            return .denied("Select your Home folder to continue.")
        }
        do {
            let data = try selectedURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(data, forKey: bookmarkKey)
            return restoreAccess()
        } catch {
            return .denied("CleanSpace could not save folder access: \(error.localizedDescription)")
        }
    }

    private func releaseAccess() {
        activeURL?.stopAccessingSecurityScopedResource()
        activeURL = nil
    }
}
