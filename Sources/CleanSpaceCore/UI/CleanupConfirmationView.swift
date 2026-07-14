import SwiftUI

struct CleanupConfirmationView: View {
    let plan: CleanupPlan
    let cancel: () -> Void
    let confirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Review Cleanup").font(.title2.weight(.semibold))
                    Text("Check the consequences before CleanSpace changes any files.")
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                totalCard(
                    title: "Permanently Deleted",
                    bytes: plan.estimatedPermanentDeletion,
                    detail: "Estimated · Cannot be undone",
                    color: .red
                )
                totalCard(
                    title: "Moved to Trash",
                    bytes: plan.estimatedMovedToTrash,
                    detail: "Recoverable until Trash is emptied",
                    color: .blue
                )
            }

            List(plan.items) { item in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(item.displayName).font(.body.weight(.medium))
                        Spacer()
                        Text(item.reclaimable.bytes.map(StorageFormatting.bytes) ?? "Unavailable")
                            .monospacedDigit()
                    }
                    Text(item.consequence).font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .frame(minHeight: 180)

            HStack {
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Clean Selected", action: confirm)
                    .buttonStyle(.borderedProminent)
                    .tint(plan.estimatedPermanentDeletion > 0 ? .red : .accentColor)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: 460)
    }

    private func totalCard(title: String, bytes: Int64, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: title.hasPrefix("Permanently") ? "trash.slash.fill" : "trash.fill")
                .font(.headline).foregroundStyle(color)
            Text(StorageFormatting.bytes(bytes))
                .font(.title2.weight(.semibold)).monospacedDigit()
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }
}
