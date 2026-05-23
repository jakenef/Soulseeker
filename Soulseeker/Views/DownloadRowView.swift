import SwiftUI

struct DownloadRowView: View {
    let item: DownloadItem

    var body: some View {
        HStack(spacing: 8) {
            statusIcon.frame(width: 20)
            Text(item.label)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            statusLabel
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .queued:
            Image(systemName: "circle").foregroundStyle(.secondary).font(.caption)
        case .searching:
            ProgressView().scaleEffect(0.55)
        case .downloading(let pct):
            ProgressView(value: pct).frame(width: 36).scaleEffect(0.8)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red).font(.caption)
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch item.status {
        case .queued:
            Text("Queued").font(.caption2).foregroundStyle(.secondary)
        case .searching:
            Text("Searching…").font(.caption2).foregroundStyle(.secondary)
        case .downloading(let pct):
            Text("\(Int(pct * 100))%").font(.caption2).monospacedDigit().foregroundStyle(.secondary)
        case .done:
            Text("Done").font(.caption2).foregroundStyle(.green)
        case .failed(let msg):
            Text("Failed").font(.caption2).foregroundStyle(.red).help(msg)
        }
    }
}
