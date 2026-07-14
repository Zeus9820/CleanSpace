import SwiftUI

struct CategoryListView: View {
    let measurements: [StorageCategory: StorageMeasurement]
    let itemsByCategory: [StorageCategory: [StorageItem]]
    let selectedItemIDs: Set<String>
    let totalCapacity: Int64
    let selected: StorageCategory?
    let select: (StorageCategory) -> Void
    var compact = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(visibleCategories) { category in
                categoryRow(category)
                if category != visibleCategories.last {
                    Divider().padding(.leading, 50)
                }
            }

            if visibleCategories.count < StorageCategory.allCases.count {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                    Text("Additional categories appear when recognized data is measured.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 14)
            }
        }
    }

    private func categoryRow(_ category: StorageCategory) -> some View {
        Button { select(category) } label: {
            HStack(spacing: 12) {
                Image(systemName: category.symbolName)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(category.tint)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(category.title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(compact ? 2 : 1)
                        if !compact {
                            confidenceBadge(measurements[category]?.confidence)
                        }
                    }
                    if compact {
                        confidenceBadge(measurements[category]?.confidence)
                    }
                    if !compact {
                        Text(category.shortDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    ProgressView(value: fraction(for: category))
                        .tint(category.tint)
                        .controlSize(.mini)
                }

                Spacer(minLength: compact ? 4 : 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(measurements[category]?.bytes.map(StorageFormatting.bytes) ?? "Unavailable")
                        .font(compact ? .caption.weight(.semibold) : .callout.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    if !compact, estimatedReclaimable(for: category) > 0 {
                        Text("\(StorageFormatting.bytes(estimatedReclaimable(for: category))) estimated")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if !compact {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.vertical, compact ? 9 : 11)
            .padding(.horizontal, compact ? 8 : 10)
            .background(selected == category ? Color.accentColor.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("storage.category.\(category.rawValue)")
        .accessibilityLabel("\(category.title), \(StorageFormatting.measurement(measurements[category]))")
        .accessibilityHint("Shows details in the inspector")
    }

    private func estimatedReclaimable(for category: StorageCategory) -> Int64 {
        itemsByCategory[category, default: []]
            .filter { selectedItemIDs.contains($0.id) }
            .reduce(0) { $0 + ($1.reclaimable.bytes ?? 0) }
    }

    @ViewBuilder
    private func confidenceBadge(_ confidence: MeasurementConfidence?) -> some View {
        if let confidence {
            Text(confidence.label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(nsColor: .quaternaryLabelColor).opacity(0.14), in: Capsule())
        }
    }

    private var visibleCategories: [StorageCategory] {
        StorageCategory.allCases.filter { measurements[$0] != nil }
    }

    private func fraction(for category: StorageCategory) -> Double {
        guard totalCapacity > 0 else { return 0 }
        return Double(measurements[category]?.bytes ?? 0) / Double(totalCapacity)
    }
}
