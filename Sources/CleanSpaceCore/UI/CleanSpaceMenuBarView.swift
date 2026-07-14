import AppKit
import SwiftUI

public struct CleanSpaceMenuBarView: View {
    @ObservedObject private var model: DashboardModel
    @Environment(\.openWindow) private var openWindow

    public init(model: DashboardModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "internaldrive.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 1) {
                    Text("CleanSpace").font(.headline)
                    Text(statusText).font(.caption).foregroundStyle(statusColor)
                }
                Spacer()
            }

            if let capacity = model.capacity {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(StorageFormatting.bytes(capacity.total - capacity.available))
                            .font(.title2.weight(.semibold)).monospacedDigit()
                        Text("used").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(StorageFormatting.bytes(capacity.available)) available")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ProgressView(value: usedFraction(capacity))
                        .tint(.accentColor)
                    Text("\(StorageFormatting.bytes(capacity.immediatelyAvailable)) free now; available includes purgeable macOS capacity")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                ProgressView("Reading disk capacity…")
                    .controlSize(.small)
            }

            HStack {
                Label("Selected cleanup", systemImage: "sparkles")
                    .font(.callout)
                Spacer()
                Text("\(StorageFormatting.bytes(model.estimatedReclaimableBytes)) estimated")
                    .font(.callout.weight(.medium)).monospacedDigit()
            }

            if !model.coverageIssues.isEmpty {
                Label("\(model.coverageIssues.count) locations unavailable", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Divider()

            HStack {
                Button("Open CleanSpace") {
                    openWindow(id: "main")
                    NSApplication.shared.activate()
                }
                .buttonStyle(.borderedProminent)

                Button { model.startScan() } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .disabled(model.accessState.accessibleRoot == nil)

                Spacer()

                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 330)
    }

    private var statusText: String {
        switch model.shelfState {
        case .scanning: "Scanning storage…"
        case .cleaning: "Cleaning selected items…"
        default:
            if !model.coverageIssues.isEmpty {
                "Scan complete with limited access"
            } else {
                model.lastScan.map { "Scanned \($0.formatted(date: .omitted, time: .shortened))" } ?? "Ready"
            }
        }
    }

    private var statusColor: Color {
        switch model.shelfState {
        case .scanning, .cleaning: .secondary
        default: model.coverageIssues.isEmpty ? .green : .orange
        }
    }

    private func usedFraction(_ capacity: VolumeCapacity) -> Double {
        guard capacity.total > 0 else { return 0 }
        return Double(capacity.total - capacity.available) / Double(capacity.total)
    }
}
