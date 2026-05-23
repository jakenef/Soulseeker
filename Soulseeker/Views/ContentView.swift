import SwiftUI

enum SearchTab: String, CaseIterable {
    case track = "Track"
    case album = "Album"
    case playlist = "Playlist"
}

struct ContentView: View {
    @ObservedObject var downloadManager: DownloadManager
    @State private var selectedTab: SearchTab = .track
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tabPicker
            tabContent
            Divider()
            DownloadQueueView(queue: downloadManager.queue)
        }
        .frame(width: 380, height: 500)
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var header: some View {
        HStack {
            Image(systemName: "music.note").font(.headline)
            Text("Soulseeker").font(.headline)
            Spacer()
            Button(action: { showSettings = true }) {
                Image(systemName: "gear")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            ForEach(SearchTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .track:    TrackTabView(downloadManager: downloadManager)
        case .album:    AlbumTabView(downloadManager: downloadManager)
        case .playlist: PlaylistTabView(downloadManager: downloadManager)
        }
    }
}
