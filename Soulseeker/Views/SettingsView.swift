import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var username = KeychainHelper.load(for: "username") ?? ""
    @State private var password = KeychainHelper.load(for: "password") ?? ""
    @AppStorage("downloadPath") private var downloadPath = "~/Music"
    @AppStorage("preferredFormat") private var preferredFormat = "Any"
    @AppStorage("sldlPath") private var sldlPath = ""

    private var detectedPath: String {
        DownloadManager.detectSldlPath() ?? "Not found — run: brew install sldl"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings").font(.headline)

            sectionHeader("Soulseek Account")
            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            sectionHeader("Downloads")
            HStack {
                TextField("Download Folder", text: $downloadPath)
                    .textFieldStyle(.roundedBorder)
                Button("Browse") { browseFolder() }
            }
            Picker("Format", selection: $preferredFormat) {
                ForEach(["Any", "MP3", "FLAC"], id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)

            sectionHeader("sldl Binary")
            if DownloadManager.detectSldlPath() == nil && sldlPath.isEmpty {
                Label("sldl not found. Install: brew install sldl",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
            TextField("Path override (leave blank to auto-detect)", text: $sldlPath)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
            Text("Auto-detected: \(detectedPath)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Save") { save() }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .frame(width: 360, height: 460)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title).font(.subheadline).bold()
    }

    private func browseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            downloadPath = url.path
        }
    }

    private func save() {
        try? KeychainHelper.save(username, for: "username")
        try? KeychainHelper.save(password, for: "password")
        dismiss()
    }
}
