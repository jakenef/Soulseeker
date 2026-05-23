import SwiftUI

struct PlaylistTabView: View {
    @ObservedObject var downloadManager: DownloadManager
    @State private var url = ""
    @AppStorage("downloadPath") private var downloadPath = "~/Music"
    @AppStorage("preferredFormat") private var preferredFormat = "Any"
    @AppStorage("sldlPath") private var sldlPath = ""

    private var credentials: (user: String, pass: String) {
        (KeychainHelper.load(for: "username") ?? "",
         KeychainHelper.load(for: "password") ?? "")
    }

    private var canDownload: Bool {
        let c = credentials
        return !c.user.isEmpty && !c.pass.isEmpty && !url.isEmpty
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Playlist URL").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)

            TextField("https://open.spotify.com/playlist/\u{2026}", text: $url)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16)

            Button(action: download) {
                Text("Download").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canDownload)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .padding(.top, 6)
    }

    private func download() {
        let c = credentials
        let resolvedPath = downloadPath.replacingOccurrences(
            of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
        let resolvedSldl = sldlPath.isEmpty
            ? (DownloadManager.detectSldlPath() ?? "sldl")
            : sldlPath
        downloadManager.enqueuePlaylist(
            url: url, user: c.user, pass: c.pass,
            path: resolvedPath, format: preferredFormat,
            sldlPath: resolvedSldl)
        url = ""
    }
}
