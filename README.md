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
