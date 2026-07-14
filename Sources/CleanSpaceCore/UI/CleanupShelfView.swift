import SwiftUI

struct CleanupShelfView: View {
    let state: CleanupShelfState
    let capacity: VolumeCapacity?
    let reclaimableEstimate: Int64
    let review: () -> Void

    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(spacing: 18) {
            shelfContent
                .padding(.horizontal, 18)
                .frame(height: 64)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
                .glassEffectID(stateID, in: glassNamespace)
                .glassEffectTransition(.matchedGeometry)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var shelfContent: some View {
        HStack(spacing: 12) {
            switch state {
            case .scanning:
                ProgressView().controlSize(.small)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scanning your storage").font(.headline)
                    Text("Cleanup stays unavailable until measurement finishes.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            case .ready:
                Image(systemName: isLowReclaim ? "checkmark.circle.fill" : "sparkles")
                    .font(.title3)
                    .foregroundStyle(isLowReclaim ? Color.green : Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isLowReclaim ? "Your disk is in good shape" : "Cleanup is ready to review")
                        .font(.headline)
                    Text(readyDetail)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if reclaimableEstimate > 0 {
                    Button("Review Cleanup", action: review)
                        .buttonStyle(.glassProminent)
                } else {
                    Button("View Scan Details", action: review)
                        .buttonStyle(.glass)
                }
            case .confirming(let summary):
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.title3).foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Confirm cleanup").font(.headline)
                    Text("Permanent: \(StorageFormatting.bytes(summary.permanentBytes)) · To Trash: \(StorageFormatting.bytes(summary.trashBytes))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Confirm Cleanup") { }.buttonStyle(.glassProminent)
            case .cleaning(let progress):
                ProgressView(value: progress).frame(width: 120)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cleaning…").font(.headline)
                    Text("\(Int(progress * 100)) percent complete").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            case .result(let result):
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3).foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cleanup complete").font(.headline)
                    Text("\(StorageFormatting.measurement(result.measuredCapacityReclaimed)) reclaimed")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private var readyDetail: String {
        if reclaimableEstimate == 0 {
            return "No registered cleanup items are currently eligible."
        }
        return "\(StorageFormatting.bytes(reclaimableEstimate)) estimated reclaimable."
    }

    private var isLowReclaim: Bool {
        guard let total = capacity?.total, total > 0 else { return true }
        return Double(reclaimableEstimate) / Double(total) < 0.02
    }

    private var stateID: String {
        switch state {
        case .scanning: "scanning"
        case .ready: "ready"
        case .confirming: "confirming"
        case .cleaning: "cleaning"
        case .result: "result"
        }
    }
}
