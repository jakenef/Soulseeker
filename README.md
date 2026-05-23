# Soulseeker
<img width="758" height="564" alt="Screenshot 2026-05-22 at 6 57 08 PM" src="https://github.com/user-attachments/assets/e7f1d4c7-a848-4585-af17-654be73d9339" />

A native macOS menubar app for downloading music from [Soulseek](https://www.slsknet.org) via [sldl](https://github.com/fiso64/sldl).

## Install

1. **Install sldl**

   Download the latest macOS binary from the [sldl releases page](https://github.com/fiso64/sldl/releases), unzip it, and move the `sldl` binary somewhere on your `$PATH` (e.g. `/usr/local/bin/sldl`). Make it executable:

   ```bash
   chmod +x /usr/local/bin/sldl
   ```

   > Note: sldl is not available via Homebrew. Manual download is required.

   **macOS 26 (Tahoe) and later — fix "zsh: killed" on first run:**

   macOS 26 enforces code signing more strictly. If `sldl --version` is silently killed, run:

   ```bash
   sudo xattr -d com.apple.quarantine /usr/local/bin/sldl
   sudo codesign --force --deep -s - /usr/local/bin/sldl
   ```

   The first command removes the quarantine flag set by your browser. The second applies an ad-hoc signature that satisfies macOS's signing requirement.

2. **Download Soulseeker**

   Grab the latest `Soulseeker-vX.Y.Z.zip` from [Releases](https://github.com/jakenef/Soulseeker/releases), unzip it, and move `Soulseeker.app` to your `/Applications` folder.

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
git clone https://github.com/jakenef/Soulseeker.git
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

GitHub Actions builds the app, zips it, and attaches it to the release automatically.
