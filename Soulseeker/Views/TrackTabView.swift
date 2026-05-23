import SwiftUI
import UniformTypeIdentifiers

struct TrackTabView: View {
    @ObservedObject var downloadManager: DownloadManager
    @State private var entries: [TrackEntry] = [TrackEntry()]
    @AppStorage("downloadPath") private var downloadPath = "~/Music"
    @AppStorage("preferredFormat") private var preferredFormat = "Any"
    @AppStorage("sldlPath") private var sldlPath = ""

    private var credentials: (user: String, pass: String) {
        (KeychainHelper.load(for: "username") ?? "",
         KeychainHelper.load(for: "password") ?? "")
    }

    private var canDownload: Bool {
        let c = credentials
        return !c.user.isEmpty && !c.pass.isEmpty
            && entries.contains { !$0.artist.isEmpty && !$0.title.isEmpty }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Artist").font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Title").font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(width: 20)
            }
            .padding(.horizontal, 16)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach($entries) { $entry in
                        HStack(spacing: 6) {
                            TextField("Artist", text: $entry.artist)
                                .textFieldStyle(.roundedBorder)
                            TextField("Title", text: $entry.title)
                                .textFieldStyle(.roundedBorder)
                            Button(action: { remove(entry) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .opacity(entries.count > 1 ? 1 : 0)
                            }
                            .buttonStyle(.plain)
                            .disabled(entries.count <= 1)
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .frame(maxHeight: 140)

            HStack {
                Button(action: { entries.append(TrackEntry()) }) {
                    Label("Add Track", systemImage: "plus").font(.caption)
                }
                .buttonStyle(.plain)

                Button(action: importCSV) {
                    Label("Import CSV", systemImage: "doc.text").font(.caption)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 16)

            Button(action: downloadAll) {
                Text("Download All").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canDownload)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .padding(.top, 6)
    }

    private func remove(_ entry: TrackEntry) {
        entries.removeAll { $0.id == entry.id }
    }

    private func importCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText, UTType.plainText]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK,
              let url = panel.url,
              let content = try? String(contentsOf: url) else { return }
        let imported = CSVImporter.parse(content)
        if !imported.isEmpty { entries = imported }
    }

    private func downloadAll() {
        let c = credentials
        let resolvedPath = downloadPath.replacingOccurrences(
            of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
        let resolvedSldl = sldlPath.isEmpty
            ? (DownloadManager.detectSldlPath() ?? "sldl")
            : sldlPath
        for entry in entries where !entry.artist.isEmpty && !entry.title.isEmpty {
            downloadManager.enqueueTrack(
                artist: entry.artist, title: entry.title,
                user: c.user, pass: c.pass,
                path: resolvedPath, format: preferredFormat,
                sldlPath: resolvedSldl)
        }
        entries = [TrackEntry()]
    }
}
