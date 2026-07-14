import SwiftUI

struct StorageRingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let capacity: VolumeCapacity?
    let measurements: [StorageCategory: StorageMeasurement]
    let selectedCategory: StorageCategory?
    let select: (StorageCategory) -> Void

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.07), lineWidth: 28)
                if let capacity, capacity.total > 0 {
                    ForEach(segments, id: \.category) { segment in
                        Circle()
                            .trim(from: segment.start, to: segment.end)
                            .stroke(
                                segment.category.tint.opacity(selectedCategory == nil || selectedCategory == segment.category ? 1 : 0.32),
                                style: .init(lineWidth: selectedCategory == segment.category ? 34 : 28, lineCap: .butt)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(reduceMotion ? nil : .snappy, value: selectedCategory)
                            .contentShape(Circle().stroke(lineWidth: 40))
                            .onTapGesture { select(segment.category) }
                            .accessibilityLabel(segment.category.title)
                            .accessibilityValue(StorageFormatting.measurement(measurements[segment.category]))
                    }

                    VStack(spacing: 4) {
                        Text(StorageFormatting.bytes(capacity.total - capacity.available))
                            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                        Text("Used")
                            .font(.headline)
                        Text("\(StorageFormatting.percentage(usedFraction)) of this disk")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                } else {
                    ProgressView().controlSize(.large)
                }
            }
            .frame(width: 228, height: 228)

            if let capacity {
                HStack(spacing: 0) {
                    metric(title: "Capacity", value: StorageFormatting.bytes(capacity.total))
                    Divider().frame(height: 34).padding(.horizontal, 12)
                    metric(title: "Available", value: StorageFormatting.bytes(capacity.available))
                    Divider().frame(height: 34).padding(.horizontal, 12)
                    metric(title: "Free now", value: StorageFormatting.bytes(capacity.immediatelyAvailable))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .accessibilityIdentifier("storage.ring")
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.medium)).monospacedDigit()
        }
    }

    private var usedFraction: Double {
        guard let capacity, capacity.total > 0 else { return 0 }
        return Double(capacity.total - capacity.available) / Double(capacity.total)
    }

    private var segments: [(category: StorageCategory, start: Double, end: Double)] {
        guard let total = capacity?.total, total > 0 else { return [] }
        var cursor = 0.0
        return StorageCategory.allCases.compactMap { category in
            guard let bytes = measurements[category]?.bytes, bytes > 0 else { return nil }
            let start = cursor
            cursor = min(1, cursor + Double(bytes) / Double(total))
            return (category, start, cursor)
        }
    }
}
