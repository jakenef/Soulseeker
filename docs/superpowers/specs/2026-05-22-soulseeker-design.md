# Soulseeker — Design Spec
*Date: 2026-05-22*

## Overview

Soulseeker is a native macOS menubar app that wraps `sldl`, a CLI downloader for the Soulseek peer-to-peer music network. It provides a polished floating-panel UI for downloading individual tracks, albums, and playlists — including batch track downloads via manual entry or CSV import.

---

## Architecture

The app is a SwiftUI macOS application with `LSUIElement = YES` (no Dock icon). It lives entirely in the menu bar.

### Component Map

| File | Role |
|---|---|
| `SoulseekerApp.swift` | `@main` entry point; creates `NSStatusItem` and owns the floating panel |
| `FloatingPanel.swift` | Custom `NSPanel` subclass — borderless, always-on-top, closes on outside click |
| `ContentView.swift` | Root SwiftUI view: segmented tabs + context-sensitive form + download queue |
| `DownloadManager.swift` | `ObservableObject`; spawns `sldl` as `Process`, streams stdout, owns queue state |
| `KeychainHelper.swift` | Stores and retrieves Soulseek credentials from macOS Keychain |
| `SettingsView.swift` | Sheet for credentials, download path, format preference, sldl path |
| `DownloadRowView.swift` | Single row in the queue: track name + status badge + progress bar |

### Data Flow

1. User fills in the form and taps **Download All**
2. `DownloadManager` builds one `sldl` invocation per item
3. Each item runs as its own `Process` (queued sequentially by default)
4. stdout is piped line-by-line on a background thread
5. Known output patterns are regex-matched → `DownloadItem` state updated
6. `@Published` queue array triggers SwiftUI re-render

---

## UI Layout

Panel size: ~380×500px, borderless, with `NSVisualEffectView` background blur.

```
┌─────────────────────────────────────┐
│  🎵 Soulseeker          ⚙           │  ← title + settings gear
├─────────────────────────────────────┤
│  [ Track ]  [ Album ]  [ Playlist ] │  ← segmented control
├─────────────────────────────────────┤
│  (Track tab shown)                  │
│  Artist              Title          │
│  [________________] [___________] ✕ │
│  [________________] [___________] ✕ │
│  [________________] [___________] ✕ │
│                                     │
│  [ + Add Track ]  [ Import CSV ]    │
│                                     │
│           [ Download All ]          │
├─────────────────────────────────────┤
│  ↓ Downloads                        │
│  ┌─────────────────────────────┐    │
│  │ ● Radiohead – Creep   Done  │    │
│  │ ◌ Pink Floyd – Time   ████░ │    │
│  │ ○ Portishead – Glory  Queue │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

### Tab Modes

| Tab | Fields |
|---|---|
| Track | Multiple rows of Artist + Title; `+` button to add rows; CSV import button |
| Album | Single Artist + Album Name |
| Playlist | Single URL field |

### Settings Sheet

- Soulseek username + password (stored in macOS Keychain)
- Download folder (native `NSOpenPanel` folder picker)
- Preferred format: Any / MP3 / FLAC
- sldl binary path (auto-detected at common locations, manual override field)

---

## sldl Command Construction

| Mode | Command |
|---|---|
| Track | `sldl "artist=X, title=Y" --user U --pass P -p /path [--pref-format fmt]` |
| Album | `sldl "artist=X, album=Y" --user U --pass P -p /path [--pref-format fmt]` |
| Playlist | `sldl "URL" --user U --pass P -p /path [--pref-format fmt]` |

Batch Track mode fires one `sldl` invocation per row, queued sequentially (one at a time).

---

## CSV Import

Format: two-column CSV, header row optional.

```
artist,title
Radiohead,Creep
Pink Floyd,Time
Portishead,Glory Box
```

The importer strips whitespace, skips blank lines, and treats the first row as a header if it contains the literal strings `artist` and `title` (case-insensitive). Each valid row becomes a new entry in the Track tab's list.

---

## Progress Parsing

`DownloadManager` reads sldl stdout line-by-line on a background thread. Known patterns:

- Searching line → status: `.searching`
- Per-file download progress → status: `.downloading(progress: Double)`
- Completion line → status: `.done`
- Process exits non-zero → status: `.failed(message: String)` (last stderr line)

Unknown lines are buffered as raw log, accessible in a detail view per row.

---

## Error Handling

| Condition | Behavior |
|---|---|
| `sldl` binary not found at launch | Yellow banner in Settings with install instructions |
| No credentials set | Download button disabled; tooltip: "Add credentials in Settings" |
| sldl exits non-zero | Row turns red; last stderr line shown as error message |
| Empty track row submitted | Row is skipped silently before dispatch |

---

## Distribution

- **Source:** GitHub repository with Xcode project
- **Releases:** GitHub Actions workflow triggers on version tag push (`v*`)
  - Runs `xcodebuild archive` → export → zip `.app`
  - Uploads zip as GitHub Release asset
- **Installation for end users:**
  1. Install `sldl` (`brew install sldl` or download from GitHub releases)
  2. Download `Soulseeker.zip` from Releases, unzip
  3. Right-click → Open (one-time Gatekeeper bypass for unsigned apps)
  4. Enter Soulseek credentials in Settings

---

## Prerequisites (for building from source)

- Xcode 15+
- macOS 13 Ventura or later target
- `sldl` installed separately (app detects and guides if missing)
- Soulseek account credentials
