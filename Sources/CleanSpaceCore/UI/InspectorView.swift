import SwiftUI

struct InspectorView: View {
    let category: StorageCategory?
    let measurement: StorageMeasurement?
    let items: [StorageItem]
    let selectedItemIDs: Set<String>
    let coverageIssues: [ScanCoverageIssue]
    let toggleSelection: (StorageItem) -> Void
    let reveal: (StorageItem) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if let category {
                    measurementSection(category)
                    Divider()
                    explanationSection(category)
                    if !items.isEmpty {
                        Divider()
                        contributorsSection
                    }
                } else {
                    ContentUnavailableView(
                        "No Category Selected",
                        systemImage: "sidebar.right",
                        description: Text("Select a storage category to see how it was measured and what actions are safe.")
                    )
                }
                coverageSection
            }
            .padding(20)
        }
        .background(.clear)
    }

    private var contributorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Largest Contributors").font(.headline)
                Spacer()
                Text("\(items.count) items").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Array(items.prefix(50))) { item in
                itemRow(item)
                if item.id != items.prefix(50).last?.id { Divider() }
            }
            if items.count > 50 {
                Text("Showing the 50 largest items.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func itemRow(_ item: StorageItem) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 9) {
                if item.action != .revealOnly {
                    Button { toggleSelection(item) } label: {
                        Image(systemName: selectedItemIDs.contains(item.id) ? "checkmark.square.fill" : "square")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedItemIDs.contains(item.id) ? Color.accentColor : Color.secondary)
                    .accessibilityLabel(selectedItemIDs.contains(item.id) ? "Deselect \(item.displayName)" : "Select \(item.displayName)")
                } else {
                    Image(systemName: "eye")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.displayName)
                        .font(.callout.weight(.medium))
                        .lineLimit(2)
                    Text(StorageFormatting.measurement(item.size))
                        .font(.caption).foregroundStyle(.secondary)
                    Text(item.consequence)
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Button { reveal(item) } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help("Reveal in Finder")
            }

            HStack(spacing: 6) {
                actionBadge(item.action)
                if let activity = item.activity {
                    Text(activityText(activity))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.leading, item.action == .revealOnly ? 29 : 31)
        }
    }

    private func actionBadge(_ action: CleanupAction) -> some View {
        Text(actionLabel(action))
            .font(.caption2.weight(.medium))
            .foregroundStyle(action == .permanentlyDelete ? Color.red : Color.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.06), in: Capsule())
    }

    private func actionLabel(_ action: CleanupAction) -> String {
        switch action {
        case .permanentlyDelete: "Permanent deletion"
        case .moveToTrash: "Move to Trash"
        case .revealOnly: "Reveal only"
        }
    }

    private func activityText(_ evidence: ModelActivityEvidence) -> String {
        switch evidence {
        case .toolMetadata(let date), .filesystemAccess(let date), .modification(let date):
            "Last activity \(date.formatted(date: .abbreviated, time: .omitted)) · \(evidence.sourceLabel)"
        case .unknown:
            "Last activity unknown"
        }
    }

    @ViewBuilder
    private var header: some View {
        if let category {
            HStack(spacing: 12) {
                Image(systemName: category.symbolName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(category.tint)
                    .frame(width: 42, height: 42)
                    .background(category.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.title).font(.title2.weight(.semibold))
                    Text(category.shortDescription).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func measurementSection(_ category: StorageCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Measurement").font(.headline)
            LabeledContent("Size") {
                Text(measurement?.bytes.map(StorageFormatting.bytes) ?? "Unavailable")
                    .monospacedDigit()
            }
            LabeledContent("Confidence") {
                Text(measurement?.confidence.label ?? "Unavailable")
            }
            if let measurement {
                Text(measurement.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func explanationSection(_ category: StorageCategory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About This Category").font(.headline)
            Text(explanation(for: category))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if category == .systemUnclassified {
                Label("Reveal only · Not eligible for cleanup", systemImage: "lock.shield")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var coverageSection: some View {
        if !coverageIssues.isEmpty {
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Label("Incomplete Scan", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                ForEach(coverageIssues) { issue in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(issue.root.path).font(.callout).lineLimit(2)
                        Text(issue.errorDescription).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func explanation(for category: StorageCategory) -> String {
        switch category {
        case .systemUnclassified: "This is a derived residual, not a measured folder size. It can include macOS system data, APFS snapshots, protected data, and folders CleanSpace could not measure."
        case .available: "Space available for important usage, including purgeable capacity that macOS can reclaim automatically. The overview separately reports immediately free space as ‘Free now’."
        case .caches: "Temporary data created by applications. Only registered cache locations can become eligible for cleanup."
        case .modelCaches: "Locally stored AI model data detected through versioned tool signatures. Models are never preselected."
        case .backups: "Recognized device backups. Individual backups move to Trash instead of being directly deleted."
        case .applicationData: "Recognized application data. Cleanup requires confirmation that the related application is closed."
        case .trash: "Items already in Trash. Emptying them is permanent and always requires destructive confirmation."
        case .otherMeasured: "Accessible user data measured during scanning. Unknown data remains reveal-only."
        }
    }
}
