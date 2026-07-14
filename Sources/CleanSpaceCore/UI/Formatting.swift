import Foundation

enum StorageFormatting {
    static func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }

    static func percentage(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    static func measurement(_ value: StorageMeasurement?) -> String {
        guard let value else { return "Unavailable" }
        guard let bytes = value.bytes else { return "Unavailable · (value.confidence.label)" }
        return "\(Self.bytes(bytes)) · \(value.confidence.label)"
    }
}
