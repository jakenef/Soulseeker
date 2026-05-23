import XCTest
@testable import Soulseeker

final class DownloadManagerTests: XCTestCase {
    @MainActor func testEnqueueTrack_addsToQueue() {
        let manager = DownloadManager()
        manager.enqueueTrack(artist: "Radiohead", title: "Creep",
                             user: "u", pass: "p", path: "/tmp",
                             format: "Any", sldlPath: "/fake/sldl")
        XCTAssertEqual(manager.queue.count, 1)
        XCTAssertEqual(manager.queue[0].label, "Radiohead \u{2013} Creep")
    }

    @MainActor func testEnqueueAlbum_addsToQueue() {
        let manager = DownloadManager()
        manager.enqueueAlbum(artist: "Radiohead", album: "OK Computer",
                             user: "u", pass: "p", path: "/tmp",
                             format: "Any", sldlPath: "/fake/sldl")
        XCTAssertEqual(manager.queue.count, 1)
        XCTAssertEqual(manager.queue[0].label, "Radiohead \u{2013} OK Computer")
    }

    @MainActor func testEnqueuePlaylist_addsToQueue() {
        let manager = DownloadManager()
        let url = "https://open.spotify.com/playlist/123"
        manager.enqueuePlaylist(url: url, user: "u", pass: "p",
                                path: "/tmp", format: "Any", sldlPath: "/fake/sldl")
        XCTAssertEqual(manager.queue.count, 1)
        XCTAssertEqual(manager.queue[0].label, url)
    }

    @MainActor func testFormatFlagIncluded_whenNotAny() {
        let manager = DownloadManager()
        manager.enqueueTrack(artist: "Radiohead", title: "Creep",
                             user: "u", pass: "p", path: "/tmp",
                             format: "FLAC", sldlPath: "/fake/sldl")
        let cmd = manager.queue[0].command
        XCTAssertTrue(cmd.contains("--pref-format"))
        XCTAssertTrue(cmd.contains("flac"))
    }

    @MainActor func testFormatFlagOmitted_whenAny() {
        let manager = DownloadManager()
        manager.enqueueTrack(artist: "Radiohead", title: "Creep",
                             user: "u", pass: "p", path: "/tmp",
                             format: "Any", sldlPath: "/fake/sldl")
        XCTAssertFalse(manager.queue[0].command.contains("--pref-format"))
    }

    @MainActor func testDetectSldlPath_matchesSearchPaths() {
        let detected = DownloadManager.detectSldlPath()
        let expected = DownloadManager.sldlSearchPaths.first {
            FileManager.default.isExecutableFile(atPath: $0)
        }
        XCTAssertEqual(detected, expected)
    }
}
