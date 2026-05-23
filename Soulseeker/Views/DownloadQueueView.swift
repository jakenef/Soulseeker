import SwiftUI

struct DownloadQueueView: View {
    let queue: [DownloadItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Downloads")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                Spacer()
            }

            if queue.isEmpty {
                Text("No downloads yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(queue) { item in
                            DownloadRowView(item: item)
                            Divider().padding(.horizontal, 12)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}
