import Foundation

public struct FoundationVolumeCapacityProvider: VolumeCapacityProviding {
    public init() {}

    public func capacity(for volume: URL) throws -> VolumeCapacity {
        let values = try volume.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ])
        let immediatelyAvailable = Int64(values.volumeAvailableCapacity ?? 0)
        let importantUsageAvailable = values.volumeAvailableCapacityForImportantUsage ?? immediatelyAvailable
        return VolumeCapacity(
            total: Int64(values.volumeTotalCapacity ?? 0),
            available: max(immediatelyAvailable, importantUsageAvailable),
            immediatelyAvailable: immediatelyAvailable
        )
    }
}
