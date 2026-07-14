import SwiftUI

public struct CleanSpaceRootView: View {
    @ObservedObject private var model: DashboardModel
    @State private var infoPresented = false

    public init(model: DashboardModel) {
        self.model = model
    }

    public var body: some View {
        NavigationSplitView {
            storageSidebar
                .navigationSplitViewColumnWidth(min: 270, ideal: 310, max: 360)
        } detail: {
            centerContent
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 600)
        .toolbar { toolbar }
        .inspector(isPresented: $model.inspectorPresented) {
            InspectorView(
                category: model.selectedCategory,
                measurement: model.selectedCategory.flatMap { model.measurements[$0] },
                items: model.selectedCategory.flatMap { model.itemsByCategory[$0] } ?? [],
                selectedItemIDs: model.selectedItemIDs,
                coverageIssues: model.coverageIssues,
                snapshotInspection: model.snapshotInspection,
                toggleSelection: model.toggleSelection,
                reveal: model.reveal
            )
            .inspectorColumnWidth(min: 300, ideal: 340, max: 420)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CleanupShelfView(
                state: model.shelfState,
                capacity: model.capacity,
                reclaimableEstimate: model.estimatedReclaimableBytes,
                review: reviewCleanup
            )
        }
        .sheet(isPresented: $model.confirmationPresented) {
            CleanupConfirmationView(
                plan: model.selectedPlan,
                cancel: model.cancelCleanupConfirmation,
                confirm: model.executeCleanup
            )
        }
        .task { model.prepareInitialAccess() }
        .accessibilityIdentifier("dashboard.root")
    }

    @ViewBuilder
    private var centerContent: some View {
        if model.selectedCategory != nil {
            selectedCategoryContent
        } else {
            overviewCenterContent
        }
    }

    private var overviewCenterContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                accessBanner
                overviewHeader
                overviewContent
                residualNotice
            }
            .frame(maxWidth: 860, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 104)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.automatic)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("dashboard.overview")
    }

    private var selectedCategoryContent: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(.snappy) { model.selectedCategory = nil }
                } label: {
                    Label("Storage Overview", systemImage: "chevron.left")
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.leftArrow, modifiers: .command)

                Spacer()

                Text("Category Details")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            Divider()

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                InspectorView(
                    category: model.selectedCategory,
                    measurement: model.selectedCategory.flatMap { model.measurements[$0] },
                    items: model.selectedCategory.flatMap { model.itemsByCategory[$0] } ?? [],
                    selectedItemIDs: model.selectedItemIDs,
                    coverageIssues: model.coverageIssues,
                    snapshotInspection: model.snapshotInspection,
                    toggleSelection: model.toggleSelection,
                    reveal: model.reveal
                )
                .frame(maxWidth: 820)
                Spacer(minLength: 0)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("dashboard.categoryDetail")
    }

    private var overviewHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Macintosh HD")
                    .font(.largeTitle.weight(.semibold))
                Text("A clear view of what is using space on this Mac")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.lastScan != nil {
                Label(model.coverageIssues.isEmpty ? "Scan complete" : "Scan incomplete", systemImage: model.coverageIssues.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(model.coverageIssues.isEmpty ? Color.green : Color.orange)
            }
        }
    }

    private var overviewContent: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) {
                storageCard.frame(minWidth: 330, idealWidth: 380, maxWidth: 410)
                summaryColumn.frame(minWidth: 260, maxWidth: .infinity)
            }
            VStack(spacing: 18) {
                storageCard
                summaryColumn
            }
        }
    }

    private var storageCard: some View {
        GroupBox {
            StorageRingView(
                capacity: model.capacity,
                measurements: model.measurements,
                selectedCategory: model.selectedCategory,
                select: model.select
            )
        } label: {
            Label("Storage Overview", systemImage: "chart.pie.fill")
                .font(.headline)
        }
        .groupBoxStyle(.automatic)
    }

    private var summaryColumn: some View {
        VStack(spacing: 14) {
            availabilityCard
            cleanupSummaryCard
        }
    }

    private var availabilityCard: some View {
        GroupBox {
            if let capacity = model.capacity {
                VStack(spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(StorageFormatting.bytes(capacity.available))
                                .font(.system(.title, design: .rounded, weight: .semibold))
                                .monospacedDigit()
                            Text("Available").font(.callout.weight(.medium))
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    }
                    Divider()
                    LabeledContent("Free now") {
                        Text(StorageFormatting.bytes(capacity.immediatelyAvailable))
                            .fontWeight(.medium).monospacedDigit()
                    }
                    LabeledContent("Purgeable by macOS") {
                        Text(StorageFormatting.bytes(max(0, capacity.available - capacity.immediatelyAvailable)))
                            .fontWeight(.medium).monospacedDigit()
                    }
                    Text("Available includes space macOS can reclaim automatically when an app needs it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 4)
            } else {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Reading volume capacity…").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 112, alignment: .center)
            }
        } label: {
            Label("Space Available", systemImage: "internaldrive")
                .font(.headline)
        }
        .groupBoxStyle(.automatic)
    }

    private var cleanupSummaryCard: some View {
        GroupBox {
            HStack(spacing: 14) {
                Image(systemName: model.estimatedReclaimableBytes > 0 ? "sparkles" : "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(model.estimatedReclaimableBytes > 0 ? Color.accentColor : Color.green)
                    .frame(width: 38, height: 38)
                    .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.estimatedReclaimableBytes > 0
                         ? "\(StorageFormatting.bytes(model.estimatedReclaimableBytes)) estimated"
                         : "No cleanup selected")
                        .font(.headline)
                        .monospacedDigit()
                    Text(model.estimatedReclaimableBytes > 0
                         ? "Review selected registered items before cleanup."
                         : "Safe caches appear here as scanning completes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 5)
        } label: {
            Label("Cleanup", systemImage: "trash.slash")
                .font(.headline)
        }
        .groupBoxStyle(.automatic)
    }

    private var storageSidebar: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Label("Storage", systemImage: "internaldrive.fill")
                    .font(.title2.weight(.semibold))
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("CATEGORIES")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                    CategoryListView(
                        measurements: model.measurements,
                        itemsByCategory: model.itemsByCategory,
                        selectedItemIDs: model.selectedItemIDs,
                        totalCapacity: model.capacity?.total ?? 0,
                        selected: model.selectedCategory,
                        select: model.select,
                        compact: true
                    )
                }
                .padding(8)
            }
        }
        .background(.bar)
        .accessibilityIdentifier("dashboard.sidebar")
    }

    @ViewBuilder
    private var residualNotice: some View {
        if model.residualShareOfUsed > 0.25, model.lastScan != nil {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("A large portion of used space is unclassified")
                        .font(.headline)
                    Text("This derived amount can include macOS system data, APFS snapshots, protected files, and locations CleanSpace could not measure. It is not assumed to be removable.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Learn More") { model.select(.systemUnclassified) }
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08)))
        }
    }

    @ViewBuilder
    private var accessBanner: some View {
        switch model.accessState {
        case .notRequired:
            EmptyView()
        case .granted(let url):
            Label("Home-folder access active: \(url.path)", systemImage: "checkmark.shield")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .selectionRequired:
            accessMessage(title: "Home-folder access required", detail: "Choose your Home folder so CleanSpace can measure current-user storage.", icon: "folder.badge.questionmark")
        case .staleBookmark:
            accessMessage(title: "Home-folder access expired", detail: "Choose your Home folder again to restore scanning.", icon: "clock.badge.exclamationmark")
        case .denied(let reason):
            accessMessage(title: "Storage access unavailable", detail: reason, icon: "exclamationmark.shield")
        }
    }

    private func accessMessage(title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Choose Home Folder") { Task { await model.requestHomeAccess() } }
                .buttonStyle(.glassProminent)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }

    private var headerSubtitle: String {
        guard let capacity = model.capacity else { return "Reading volume capacity…" }
        return "\(StorageFormatting.bytes(capacity.total)) total · \(StorageFormatting.bytes(capacity.available)) available · \(StorageFormatting.bytes(capacity.immediatelyAvailable)) free now"
    }

    private func showMostRelevantDetails() {
        if model.measurements[.caches] != nil {
            model.select(.caches)
        } else {
            model.select(.systemUnclassified)
        }
    }

    private func reviewCleanup() {
        if model.estimatedReclaimableBytes > 0 {
            model.prepareCleanup()
        } else {
            showMostRelevantDetails()
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Picker("Volume", selection: .constant("Macintosh HD")) {
                Text("Macintosh HD").tag("Macintosh HD")
            }
            .frame(width: 175)

            Button { model.startScan() } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .disabled(model.accessState.accessibleRoot == nil)
            .keyboardShortcut("r", modifiers: .command)
            .accessibilityIdentifier("toolbar.rescan")

            Button {
                if model.selectedCategory == nil { showMostRelevantDetails() }
                withAnimation(.snappy) { model.inspectorPresented.toggle() }
            } label: {
                Label("Inspector", systemImage: "sidebar.right")
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            .accessibilityIdentifier("toolbar.inspector")

            Button { infoPresented.toggle() } label: {
                Label("About CleanSpace", systemImage: "info.circle")
            }
            .popover(isPresented: $infoPresented, arrowEdge: .bottom) {
                informationPopover
            }
            .accessibilityIdentifier("toolbar.information")
        }
    }

    private var informationPopover: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 11) {
                Image(systemName: "internaldrive.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 38, height: 38)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text("CleanSpace").font(.headline)
                    Text("Storage visibility and user-directed cleanup")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 9) {
                infoRow(icon: "wifi.slash", title: "Fully offline", detail: "Storage information never leaves this Mac")
                infoRow(icon: "person.crop.circle", title: "Current user only", detail: "No administrator access or privileged helper")
                infoRow(icon: "lock.shield", title: "Registered cleanup rules", detail: "Unknown data is reveal-only")
                infoRow(
                    icon: model.coverageIssues.isEmpty ? "checkmark.circle" : "exclamationmark.triangle",
                    title: model.coverageIssues.isEmpty ? "Scan coverage complete" : "Scan coverage incomplete",
                    detail: model.coverageIssues.isEmpty ? "All requested locations were accessible" : "\(model.coverageIssues.count) protected or unavailable locations"
                )
            }

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                Text("Size labels").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                confidenceRow("Measured", detail: "Read from accessible files")
                confidenceRow("Estimated", detail: "Expected cleanup amount")
                confidenceRow("Derived", detail: "Calculated from capacity totals")
                confidenceRow("Unavailable", detail: "No trustworthy byte count")
            }

            Text(model.profile == .direct ? "Direct build · Full current-user capability" : "App Store build · Home-folder access required")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(18)
        .frame(width: 330)
    }

    private func infoRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func confidenceRow(_ title: String, detail: String) -> some View {
        HStack {
            Text(title).font(.caption.weight(.medium)).frame(width: 76, alignment: .leading)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }
}
