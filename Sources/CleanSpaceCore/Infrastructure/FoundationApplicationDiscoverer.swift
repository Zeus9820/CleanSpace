import AppKit
import Foundation

public struct FoundationApplicationDiscoverer: ApplicationDiscovering {
    public init() {}

    public func isRunning(bundleIdentifier: String) async -> Bool {
        await MainActor.run {
            !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
        }
    }
}

public struct UnavailableApplicationDiscoverer: ApplicationDiscovering {
    public init() {}
    public func isRunning(bundleIdentifier: String) async -> Bool { false }
}
