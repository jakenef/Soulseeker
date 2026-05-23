# Soulseeker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menubar app (SwiftUI + AppKit) that wraps the `sldl` CLI to download music from Soulseek, supporting single tracks, albums, playlists, batch track entry, and CSV import.

**Architecture:** A SwiftUI app with `LSUIElement=YES` (no Dock icon) driven by an `NSApplicationDelegateAdaptor`-connected `AppDelegate` that owns the `NSStatusItem` and a custom `NSPanel`. `DownloadManager` is a `@MainActor ObservableObject` that spawns `sldl` as child `Process` instances, pipes stdout line-by-line for progress, and maintains the download queue state. Settings persist via `@AppStorage` (UserDefaults) and macOS Keychain.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, Foundation (`Process`/`Pipe`), Security framework (Keychain), XcodeGen (project generation), GitHub Actions (CI/release)

---

## File Map

| Path | Purpose |
|---|---|
| `project.yml` | XcodeGen project spec |
| `Soulseeker/Resources/Info.plist` | Bundle metadata; `LSUIElement=YES` |
| `Soulseeker/SoulseekerApp.swift` | `@main` entry; wires `AppDelegate` |
| `Soulseeker/AppDelegate.swift` | `NSStatusItem`, `FloatingPanel`, panel toggle |
| `Soulseeker/FloatingPanel.swift` | Custom `NSPanel` subclass |
| `Soulseeker/Models/DownloadItem.swift` | Download queue item + status enum |
| `Soulseeker/Models/TrackEntry.swift` | Artist/title pair for Track tab |
| `Soulseeker/Services/KeychainHelper.swift` | Keychain read/write/delete |
| `Soulseeker/Services/CSVImporter.swift` | CSV → `[TrackEntry]` parser |
| `Soulseeker/Services/DownloadManager.swift` | Queue, process management, stdout parsing |
| `Soulseeker/Views/ContentView.swift` | Root view: tabs + queue |
| `Soulseeker/Views/TrackTabView.swift` | Multi-row track form + CSV import |
| `Soulseeker/Views/AlbumTabView.swift` | Album search form |
| `Soulseeker/Views/PlaylistTabView.swift` | Playlist URL form |
| `Soulseeker/Views/DownloadQueueView.swift` | Scrollable queue list |
| `Soulseeker/Views/DownloadRowView.swift` | Single queue row with status |
| `Soulseeker/Views/SettingsView.swift` | Credentials, path, format, sldl path |
| `SoulseekerTests/KeychainHelperTests.swift` | Keychain unit tests |
| `SoulseekerTests/CSVImporterTests.swift` | CSV parser unit tests |
| `SoulseekerTests/DownloadManagerTests.swift` | Queue + command-building tests |
| `.github/workflows/release.yml` | GitHub Actions release workflow |
| `README.md` | Install and usage instructions |

---

## Task 1: Project Scaffold

**Files:**
- Create: `project.yml`
- Create: `Soulseeker/Resources/Info.plist`
- Create: `Soulseeker/` (source dir stubs)
- Create: `SoulseekerTests/` (test dir stub)

- [ ] **Step 1: Install xcodegen**

```bash
brew install xcodegen
```

Expected: `xcodegen` available at `/opt/homebrew/bin/xcodegen`

- [ ] **Step 2: Create directory structure**

```bash
mkdir -p Soulseeker/Models Soulseeker/Services Soulseeker/Views Soulseeker/Resources SoulseekerTests .github/workflows
```

- [ ] **Step 3: Write Info.plist**

Create `Soulseeker/Resources/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Soulseeker</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
```

- [ ] **Step 4: Write project.yml**

Create `project.yml`:

```yaml
name: Soulseeker
options:
  deploymentTarget:
    macOS: "13.0"
  defaultConfig: Debug
settings:
  base:
    SWIFT_VERSION: "5.9"
    MACOSX_DEPLOYMENT_TARGET: "13.0"
targets:
  Soulseeker:
    type: application
    platform: macOS
    deploymentTarget: "13.0"
    sources:
      - path: Soulseeker
    settings:
      base:
        INFOPLIST_FILE: Soulseeker/Resources/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.jakenef.soulseeker
        CODE_SIGN_IDENTITY: ""
        CODE_SIGNING_REQUIRED: "NO"
        CODE_SIGNING_ALLOWED: "NO"
  SoulseekerTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: SoulseekerTests
    dependencies:
      - target: Soulseeker
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.jakenef.soulseekerTests
```

- [ ] **Step 5: Generate Xcode project**

```bash
xcodegen generate
```

Expected: `Soulseeker.xcodeproj` created with no errors.

- [ ] **Step 6: Commit**

```bash
git add project.yml Soulseeker/Resources/Info.plist
git commit -m "feat: add xcodegen project scaffold"
```

---

## Task 2: Models

**Files:**
- Create: `Soulseeker/Models/DownloadItem.swift`
- Create: `Soulseeker/Models/TrackEntry.swift`

- [ ] **Step 1: Write DownloadItem.swift**

```swift
import Foundation

enum DownloadStatus {
    case queued
    case searching
    case downloading(progress: Double)
    case done
    case failed(message: String)
}

extension DownloadStatus: Equatable {
    static func == (lhs: DownloadStatus, rhs: DownloadStatus) -> Bool {
        switch (lhs, rhs) {
        case (.queued, .queued): return true
        case (.searching, .searching): return true
        case (.downloading(let a), .downloading(let b)): return a == b
        case (.done, .done): return true
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }

    var isQueued: Bool {
        if case .queued = self { return true }
        return false
    }
}

struct DownloadItem: Identifiable {
    let id = UUID()
    let label: String
    let command: [String]
    var status: DownloadStatus = .queued
    var rawLog: [String] = []
}
```

- [ ] **Step 2: Write TrackEntry.swift**

```swift
import Foundation

struct TrackEntry: Identifiable, Equatable {
    var id = UUID()
    var artist: String = ""
    var title: String = ""
}
```

- [ ] **Step 3: Verify project builds**

```bash
xcodebuild build -scheme Soulseeker -configuration Debug CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Soulseeker/Models/
git commit -m "feat: add DownloadItem and TrackEntry models"
```

---

## Task 3: KeychainHelper + Tests

**Files:**
- Create: `Soulseeker/Services/KeychainHelper.swift`
- Create: `SoulseekerTests/KeychainHelperTests.swift`

- [ ] **Step 1: Write failing tests**

Create `SoulseekerTests/KeychainHelperTests.swift`:

```swift
import XCTest
@testable import Soulseeker

final class KeychainHelperTests: XCTestCase {
    let testKey = "soulseeker.test.key"

    override func tearDown() {
        KeychainHelper.delete(for: testKey)
    }

    func testSaveAndLoad() throws {
        try KeychainHelper.save("hello", for: testKey)
        XCTAssertEqual(KeychainHelper.load(for: testKey), "hello")
    }

    func testOverwrite() throws {
        try KeychainHelper.save("first", for: testKey)
        try KeychainHelper.save("second", for: testKey)
        XCTAssertEqual(KeychainHelper.load(for: testKey), "second")
    }

    func testLoadMissingReturnsNil() {
        XCTAssertNil(KeychainHelper.load(for: "soulseeker.definitely.not.here.xyz"))
    }

    func testDelete() throws {
        try KeychainHelper.save("value", for: testKey)
        KeychainHelper.delete(for: testKey)
        XCTAssertNil(KeychainHelper.load(for: testKey))
    }
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
xcodebuild test -scheme Soulseeker -destination 'platform=macOS' 2>&1 | grep -E "(FAILED|error:)"
```

Expected: compile error — `KeychainHelper` not defined.

- [ ] **Step 3: Write KeychainHelper.swift**

Create `Soulseeker/Services/KeychainHelper.swift`:

```swift
import Foundation
import Security

enum KeychainError: Error {
    case saveFailed(OSStatus)
}

struct KeychainHelper {
    static let service = "com.jakenef.soulseeker"

    static func save(_ value: String, for key: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }

    static func load(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
xcodebuild test -scheme Soulseeker -destination 'platform=macOS' -only-testing:SoulseekerTests/KeychainHelperTests 2>&1 | grep -E "(PASSED|FAILED|error:)"
```

Expected: `Test Suite 'KeychainHelperTests' passed`

- [ ] **Step 5: Commit**

```bash
git add Soulseeker/Services/KeychainHelper.swift SoulseekerTests/KeychainHelperTests.swift
git commit -m "feat: add KeychainHelper with save/load/delete"
```

---

## Task 4: CSVImporter + Tests

**Files:**
- Create: `Soulseeker/Services/CSVImporter.swift`
- Create: `SoulseekerTests/CSVImporterTests.swift`

- [ ] **Step 1: Write failing tests**

Create `SoulseekerTests/CSVImporterTests.swift`:

```swift
import XCTest
@testable import Soulseeker

final class CSVImporterTests: XCTestCase {
    func testBasicParse() {
        let result = CSVImporter.parse("Radiohead,Creep\nPink Floyd,Time")
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].artist, "Radiohead")
        XCTAssertEqual(result[0].title, "Creep")
        XCTAssertEqual(result[1].artist, "Pink Floyd")
        XCTAssertEqual(result[1].title, "Time")
    }

    func testHeaderRowSkipped() {
        let result = CSVImporter.parse("artist,title\nRadiohead,Creep")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].artist, "Radiohead")
    }

    func testCaseInsensitiveHeader() {
        let result = CSVImporter.parse("Artist,Title\nRadiohead,Creep")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].artist, "Radiohead")
    }

    func testTitleWithComma() {
        let result = CSVImporter.parse("Radiohead,Karma Police, Part 2")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].title, "Karma Police, Part 2")
    }

    func testEmptyLinesIgnored() {
        let result = CSVImporter.parse("Radiohead,Creep\n\nPink Floyd,Time\n")
        XCTAssertEqual(result.count, 2)
    }

    func testEmptyInputReturnsEmpty() {
        XCTAssertEqual(CSVImporter.parse("").count, 0)
    }

    func testRowMissingTitleSkipped() {
        let result = CSVImporter.parse("Radiohead\nPink Floyd,Time")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].artist, "Pink Floyd")
    }
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
xcodebuild test -scheme Soulseeker -destination 'platform=macOS' -only-testing:SoulseekerTests/CSVImporterTests 2>&1 | grep -E "(FAILED|error:)"
```

Expected: compile error — `CSVImporter` not defined.

- [ ] **Step 3: Write CSVImporter.swift**

Create `Soulseeker/Services/CSVImporter.swift`:

```swift
import Foundation

struct CSVImporter {
    static func parse(_ content: String) -> [TrackEntry] {
        let lines = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return [] }

        var startIndex = 0
        let first = lines[0].lowercased()
        if first.contains("artist") && first.contains("title") {
            startIndex = 1
        }

        return lines[startIndex...].compactMap { line -> TrackEntry? in
            let parts = line.components(separatedBy: ",")
            guard parts.count >= 2 else { return nil }
            let artist = parts[0].trimmingCharacters(in: .whitespaces)
            let title = parts[1...].joined(separator: ",").trimmingCharacters(in: .whitespaces)
            guard !artist.isEmpty && !title.isEmpty else { return nil }
            return TrackEntry(artist: artist, title: title)
        }
    }
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
xcodebuild test -scheme Soulseeker -destination 'platform=macOS' -only-testing:SoulseekerTests/CSVImporterTests 2>&1 | grep -E "(PASSED|FAILED|error:)"
```

Expected: `Test Suite 'CSVImporterTests' passed`

- [ ] **Step 5: Commit**

```bash
git add Soulseeker/Services/CSVImporter.swift SoulseekerTests/CSVImporterTests.swift
git commit -m "feat: add CSVImporter with header detection and comma-in-title support"
```

---

## Task 5: DownloadManager + Tests

**Files:**
- Create: `Soulseeker/Services/DownloadManager.swift`
- Create: `SoulseekerTests/DownloadManagerTests.swift`

- [ ] **Step 1: Write failing tests**

Create `SoulseekerTests/DownloadManagerTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
xcodebuild test -scheme Soulseeker -destination 'platform=macOS' -only-testing:SoulseekerTests/DownloadManagerTests 2>&1 | grep -E "(FAILED|error:)"
```

Expected: compile error — `DownloadManager` not defined.

- [ ] **Step 3: Write DownloadManager.swift**

Create `Soulseeker/Services/DownloadManager.swift`:

```swift
import Foundation
import Combine

@MainActor
class DownloadManager: ObservableObject {
    @Published var queue: [DownloadItem] = []

    private var activeProcess: Process?
    private var isRunning = false

    static let sldlSearchPaths: [String] = [
        "/opt/homebrew/bin/sldl",
        "/usr/local/bin/sldl",
        "/usr/bin/sldl",
        (ProcessInfo.processInfo.environment["HOME"] ?? "") + "/bin/sldl"
    ]

    static func detectSldlPath() -> String? {
        sldlSearchPaths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func enqueueTrack(artist: String, title: String,
                      user: String, pass: String,
                      path: String, format: String, sldlPath: String) {
        var args = [sldlPath, "artist=\(artist), title=\(title)",
                    "--user", user, "--pass", pass, "-p", path]
        if format != "Any" { args += ["--pref-format", format.lowercased()] }
        append(DownloadItem(label: "\(artist) \u{2013} \(title)", command: args))
    }

    func enqueueAlbum(artist: String, album: String,
                      user: String, pass: String,
                      path: String, format: String, sldlPath: String) {
        var args = [sldlPath, "artist=\(artist), album=\(album)",
                    "--user", user, "--pass", pass, "-p", path]
        if format != "Any" { args += ["--pref-format", format.lowercased()] }
        append(DownloadItem(label: "\(artist) \u{2013} \(album)", command: args))
    }

    func enqueuePlaylist(url: String,
                         user: String, pass: String,
                         path: String, format: String, sldlPath: String) {
        var args = [sldlPath, url, "--user", user, "--pass", pass, "-p", path]
        if format != "Any" { args += ["--pref-format", format.lowercased()] }
        append(DownloadItem(label: url, command: args))
    }

    private func append(_ item: DownloadItem) {
        queue.append(item)
        startNextIfIdle()
    }

    private func startNextIfIdle() {
        guard !isRunning,
              let idx = queue.indices.first(where: { queue[$0].status.isQueued }) else { return }
        run(index: idx)
    }

    private func run(index: Int) {
        isRunning = true
        queue[index].status = .searching

        let item = queue[index]
        guard !item.command.isEmpty else {
            queue[index].status = .failed(message: "Empty command")
            isRunning = false
            startNextIfIdle()
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: item.command[0])
        process.arguments = Array(item.command.dropFirst())

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let text = String(data: handle.availableData, encoding: .utf8) ?? ""
            guard !text.isEmpty else { return }
            Task { @MainActor [weak self] in self?.handleOutput(text, index: index) }
        }

        process.terminationHandler = { [weak self] p in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if p.terminationStatus == 0 {
                    self.queue[index].status = .done
                } else {
                    let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let msg = String(data: errData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
                    self.queue[index].status = .failed(message: msg)
                }
                self.isRunning = false
                self.startNextIfIdle()
            }
        }

        do {
            try process.run()
            activeProcess = process
        } catch {
            queue[index].status = .failed(message: error.localizedDescription)
            isRunning = false
            startNextIfIdle()
        }
    }

    private func handleOutput(_ text: String, index: Int) {
        queue[index].rawLog.append(text)
        for line in text.components(separatedBy: .newlines) {
            if line.localizedCaseInsensitiveContains("Searching") {
                queue[index].status = .searching
            } else if let pct = parsePercent(from: line) {
                queue[index].status = .downloading(progress: pct)
            }
        }
    }

    private func parsePercent(from line: String) -> Double? {
        guard let range = line.range(of: #"\d+(?=\s*%)"#, options: .regularExpression) else { return nil }
        return Double(line[range]).map { $0 / 100.0 }
    }
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
xcodebuild test -scheme Soulseeker -destination 'platform=macOS' -only-testing:SoulseekerTests/DownloadManagerTests 2>&1 | grep -E "(PASSED|FAILED|error:)"
```

Expected: `Test Suite 'DownloadManagerTests' passed`

- [ ] **Step 5: Commit**

```bash
git add Soulseeker/Services/DownloadManager.swift SoulseekerTests/DownloadManagerTests.swift
git commit -m "feat: add DownloadManager with process queue and stdout parsing"
```

---

## Task 6: FloatingPanel

**Files:**
- Create: `Soulseeker/FloatingPanel.swift`

- [ ] **Step 1: Write FloatingPanel.swift**

```swift
import AppKit

class FloatingPanel: NSPanel {
    init(width: CGFloat = 380, height: CGFloat = 500) {
        let rect = NSRect(x: 0, y: 0, width: width, height: height)
        super.init(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .titled, .closable],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false

        let blur = NSVisualEffectView()
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.material = .hudWindow
        contentView = blur
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
```

- [ ] **Step 2: Verify project builds**

```bash
xcodebuild build -scheme Soulseeker -configuration Debug CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Soulseeker/FloatingPanel.swift
git commit -m "feat: add FloatingPanel NSPanel subclass with blur background"
```

---

## Task 7: SettingsView

**Files:**
- Create: `Soulseeker/Views/SettingsView.swift`

- [ ] **Step 1: Write SettingsView.swift**

```swift
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
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild build -scheme Soulseeker -configuration Debug CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Soulseeker/Views/SettingsView.swift
git commit -m "feat: add SettingsView with credentials, path picker, and sldl detection"
```

---

## Task 8: DownloadRowView

**Files:**
- Create: `Soulseeker/Views/DownloadRowView.swift`

- [ ] **Step 1: Write DownloadRowView.swift**

```swift
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
```

- [ ] **Step 2: Commit**

```bash
git add Soulseeker/Views/DownloadRowView.swift
git commit -m "feat: add DownloadRowView with status icon and progress label"
```

---

## Task 9: DownloadQueueView

**Files:**
- Create: `Soulseeker/Views/DownloadQueueView.swift`

- [ ] **Step 1: Write DownloadQueueView.swift**

```swift
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
```

- [ ] **Step 2: Commit**

```bash
git add Soulseeker/Views/DownloadQueueView.swift
git commit -m "feat: add DownloadQueueView with lazy scrolling list"
```

---

## Task 10: TrackTabView

**Files:**
- Create: `Soulseeker/Views/TrackTabView.swift`

- [ ] **Step 1: Write TrackTabView.swift**

```swift
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
                                    .foregroundStyle(entries.count > 1 ? .secondary : .clear)
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
```

- [ ] **Step 2: Commit**

```bash
git add Soulseeker/Views/TrackTabView.swift
git commit -m "feat: add TrackTabView with multi-row entry and CSV import"
```

---

## Task 11: AlbumTabView

**Files:**
- Create: `Soulseeker/Views/AlbumTabView.swift`

- [ ] **Step 1: Write AlbumTabView.swift**

```swift
import SwiftUI

struct AlbumTabView: View {
    @ObservedObject var downloadManager: DownloadManager
    @State private var artist = ""
    @State private var album = ""
    @AppStorage("downloadPath") private var downloadPath = "~/Music"
    @AppStorage("preferredFormat") private var preferredFormat = "Any"
    @AppStorage("sldlPath") private var sldlPath = ""

    private var credentials: (user: String, pass: String) {
        (KeychainHelper.load(for: "username") ?? "",
         KeychainHelper.load(for: "password") ?? "")
    }

    private var canDownload: Bool {
        let c = credentials
        return !c.user.isEmpty && !c.pass.isEmpty && !artist.isEmpty && !album.isEmpty
    }

    var body: some View {
        VStack(spacing: 6) {
            fieldLabel("Artist")
            TextField("Artist", text: $artist)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16)

            fieldLabel("Album")
            TextField("Album", text: $album)
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

    private func fieldLabel(_ text: String) -> some View {
        HStack {
            Text(text).font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private func download() {
        let c = credentials
        let resolvedPath = downloadPath.replacingOccurrences(
            of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
        let resolvedSldl = sldlPath.isEmpty
            ? (DownloadManager.detectSldlPath() ?? "sldl")
            : sldlPath
        downloadManager.enqueueAlbum(
            artist: artist, album: album,
            user: c.user, pass: c.pass,
            path: resolvedPath, format: preferredFormat,
            sldlPath: resolvedSldl)
        artist = ""; album = ""
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Soulseeker/Views/AlbumTabView.swift
git commit -m "feat: add AlbumTabView"
```

---

## Task 12: PlaylistTabView

**Files:**
- Create: `Soulseeker/Views/PlaylistTabView.swift`

- [ ] **Step 1: Write PlaylistTabView.swift**

```swift
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

            TextField("https://open.spotify.com/playlist/…", text: $url)
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
```

- [ ] **Step 2: Commit**

```bash
git add Soulseeker/Views/PlaylistTabView.swift
git commit -m "feat: add PlaylistTabView"
```

---

## Task 13: ContentView

**Files:**
- Create: `Soulseeker/Views/ContentView.swift`

- [ ] **Step 1: Write ContentView.swift**

```swift
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
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild build -scheme Soulseeker -configuration Debug CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Soulseeker/Views/ContentView.swift
git commit -m "feat: add ContentView with segmented tabs and settings sheet"
```

---

## Task 14: AppDelegate + SoulseekerApp

**Files:**
- Create: `Soulseeker/AppDelegate.swift`
- Create: `Soulseeker/SoulseekerApp.swift`

- [ ] **Step 1: Write AppDelegate.swift**

```swift
import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private var downloadManager: DownloadManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        downloadManager = DownloadManager()
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "music.note",
                                   accessibilityDescription: "Soulseeker")
            button.action = #selector(togglePanel)
            button.target = self
        }

        panel = FloatingPanel()
        let content = NSHostingView(rootView: ContentView(downloadManager: downloadManager))
        content.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView?.addSubview(content)
        if let cv = panel.contentView {
            NSLayoutConstraint.activate([
                content.topAnchor.constraint(equalTo: cv.topAnchor),
                content.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
                content.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
                content.trailingAnchor.constraint(equalTo: cv.trailingAnchor)
            ])
        }
    }

    @objc private func togglePanel() {
        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }

        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            let buttonFrame = buttonWindow.convertToScreen(
                button.convert(button.bounds, to: nil))
            let x = buttonFrame.midX - panel.frame.width / 2
            let y = buttonFrame.minY - panel.frame.height - 4
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationDidResignActive(_ notification: Notification) {
        panel.orderOut(nil)
    }
}
```

- [ ] **Step 2: Write SoulseekerApp.swift**

```swift
import SwiftUI

@main
struct SoulseekerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
```

- [ ] **Step 3: Full build and run**

```bash
xcodebuild build -scheme Soulseeker -configuration Debug CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

Open `build/Build/Products/Debug/Soulseeker.app` — a music note icon should appear in the menu bar. Clicking it should reveal the floating panel.

- [ ] **Step 4: Run all tests**

```bash
xcodebuild test -scheme Soulseeker -destination 'platform=macOS' 2>&1 | grep -E "(PASSED|FAILED)"
```

Expected: all test suites pass.

- [ ] **Step 5: Commit**

```bash
git add Soulseeker/AppDelegate.swift Soulseeker/SoulseekerApp.swift
git commit -m "feat: wire up AppDelegate, NSStatusItem, and floating panel"
```

---

## Task 15: GitHub Actions Release Workflow

**Files:**
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: Write release.yml**

Create `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-14
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install xcodegen
        run: brew install xcodegen

      - name: Generate Xcode project
        run: xcodegen generate

      - name: Build
        run: |
          xcodebuild build \
            -scheme Soulseeker \
            -configuration Release \
            -derivedDataPath build \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO

      - name: Zip app
        run: |
          cd "build/Build/Products/Release"
          zip -r "../../../../Soulseeker-${{ github.ref_name }}.zip" "Soulseeker.app"

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: "Soulseeker-${{ github.ref_name }}.zip"
          generate_release_notes: true
```

- [ ] **Step 2: Add .gitignore**

Create `.gitignore`:

```
*.xcodeproj/
build/
.DS_Store
*.xcworkspace/xcuserdata/
DerivedData/
```

Note: `*.xcodeproj` is gitignored because it is generated by xcodegen from `project.yml`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/release.yml .gitignore
git commit -m "ci: add GitHub Actions release workflow"
```

---

## Task 16: README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README.md**

```markdown
# Soulseeker

A native macOS menubar app for downloading music from [Soulseek](https://www.slsknet.org) via [sldl](https://github.com/fiso64/sldl).

## Install

1. **Install sldl**

   ```bash
   brew install sldl
   ```

   Or download a binary from the [sldl releases page](https://github.com/fiso64/sldl/releases).

2. **Download Soulseeker**

   Grab the latest `Soulseeker-vX.Y.Z.zip` from [Releases](../../releases), unzip it, and move `Soulseeker.app` to your `/Applications` folder.

3. **First launch**

   Right-click `Soulseeker.app` → **Open** (one-time bypass for unsigned apps).

4. **Configure**

   Click the 🎵 menu bar icon → gear icon → enter your Soulseek username and password.

## Usage

| Tab | What it does |
|---|---|
| **Track** | Search by artist + title. Hit `+` to add more rows, or click **Import CSV** to bulk-load from a file. |
| **Album** | Download a full album by artist + album name. |
| **Playlist** | Paste a Spotify or YouTube playlist URL. |

### CSV format

```csv
artist,title
Radiohead,Creep
Pink Floyd,Time
Portishead,Glory Box
```

Header row is optional. Titles that contain commas are handled correctly.

## Build from source

Requirements: Xcode 15+, [xcodegen](https://github.com/yonaskolb/XcodeGen)

```bash
brew install xcodegen
git clone <this-repo>
cd Soulseeker
xcodegen generate
open Soulseeker.xcodeproj
```

Press **⌘R** in Xcode to build and run.

## Release a new version

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions will build the app and attach a zip to the release automatically.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with install, usage, and release instructions"
```
