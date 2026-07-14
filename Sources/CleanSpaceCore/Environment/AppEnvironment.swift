import Foundation
import Security

public enum DistributionProfile: String, Hashable, Sendable, Codable {
    case direct
    case store
}

public struct DistributionCapabilities: Sendable {
    public let canInspectSnapshots: Bool
    public let requiresHomeFolderGrant: Bool
    public let canScanProtectedAppData: Bool

    public init(canInspectSnapshots: Bool, requiresHomeFolderGrant: Bool, canScanProtectedAppData: Bool = false) {
        self.canInspectSnapshots = canInspectSnapshots
        self.requiresHomeFolderGrant = requiresHomeFolderGrant
        self.canScanProtectedAppData = canScanProtectedAppData
    }
}

public struct AppEnvironment: Sendable {
    public let profile: DistributionProfile
    public let capabilities: DistributionCapabilities
    public let scanner: any StorageScanning
    public let capacityProvider: any VolumeCapacityProviding
    public let accessProvider: any StorageAccessProviding
    public let cleanupExecutor: any CleanupExecuting
    public let workspaceRevealer: any WorkspaceRevealing

    public init(profile: DistributionProfile, capabilities: DistributionCapabilities, scanner: any StorageScanning, capacityProvider: any VolumeCapacityProviding, accessProvider: any StorageAccessProviding, cleanupExecutor: any CleanupExecuting, workspaceRevealer: any WorkspaceRevealing) {
        self.profile = profile
        self.capabilities = capabilities
        self.scanner = scanner
        self.capacityProvider = capacityProvider
        self.accessProvider = accessProvider
        self.cleanupExecutor = cleanupExecutor
        self.workspaceRevealer = workspaceRevealer
    }

    @MainActor
    public static func live(profile: DistributionProfile) -> Self {
        let capacity = FoundationVolumeCapacityProvider()
        let canScanProtectedAppData = profile == .direct && hasStableTeamSignature
        return Self(
            profile: profile,
            capabilities: .init(
                canInspectSnapshots: profile == .direct,
                requiresHomeFolderGrant: profile == .store,
                canScanProtectedAppData: canScanProtectedAppData
            ),
            scanner: RegisteredRootScanner(
                capacityProvider: capacity,
                includeProtectedAppData: canScanProtectedAppData
            ),
            capacityProvider: capacity,
            accessProvider: profile == .direct ? DirectStorageAccessProvider() : SecurityScopedHomeAccessProvider(),
            cleanupExecutor: RegisteredCleanupExecutor(profile: profile, capacityProvider: capacity),
            workspaceRevealer: FoundationWorkspaceRevealer()
        )
    }

    private static var hasStableTeamSignature: Bool {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(
                  task,
                  "com.apple.developer.team-identifier" as CFString,
                  nil
              ) as? String else {
            return false
        }
        return !value.isEmpty
    }
}
