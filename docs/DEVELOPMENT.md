# Develop & release

## Requirements

- macOS with Xcode and its macOS SDK; select it with `xcode-select` if needed.
- Swift 6+, system Perl, Python 3 for repository checks/bridge setup, Node.js for browser tests.
- No downloaded Swift packages, app backend, Yandex credentials, or CMake required. Helper source is vendored.

The app targets macOS 14+. Recent Xcode is recommended; GitHub workflows use `macos-26` runners. A successful build on a new Xcode does not establish private MediaRemote compatibility on every older OS.

## Build

```sh
Scripts/build.sh                       # Current Mac architecture
VINYL_UNIVERSAL=1 Scripts/build.sh     # Apple Silicon + Intel
open build/Vinyl.app
```

The script builds and ad-hoc signs the helper and app, installs the icon and resources, and outputs `build/Vinyl.app`. Open `Package.swift` in Xcode to edit; running the bare SwiftPM executable does not provide bundled helper resources. The internal Swift module remains `SideA` for compatibility; the app is named Vinyl.

## Check

```sh
python3 Scripts/check-publication.py
Scripts/scan-secrets.sh
swift test --disable-sandbox
node Scripts/test-browser.mjs
bash -n Scripts/build.sh Scripts/package-dmg.sh
```

The publication check reports file names and categories without printing possible secrets. It is a targeted pattern check, not a comprehensive scanner or proof of absence. Inspect `git diff --cached` before publishing. The secret-scan script downloads Gitleaks 8.30.1 from its official release, verifies a pinned SHA-256, and scans only publishable files. Its sole exception is the exact public extension identifier. It does not scan old Git history. Enable GitHub secret scanning and push protection where available.

For native rendering, run the complete app with `--render-preview`, an optional `--night` or `--transparent`, and an absolute output path. Add `--sample-artwork` for synthetic artwork. Preview without that flag shows an empty sleeve. These preview modes do not prove real-player integration.

The `--render-live-preview` diagnostic reads your active track and writes its title/artist into a JSON report alongside the image. Keep these outputs private; `build/` is ignored. Do not upload live reports or screenshots without reviewing them.

`--verify-wallpaper` followed by an absolute JSON output path exercises wallpaper configuration and synthetic play/pause, then exits. Its short CPU test excludes helper/GPU usage. Physical Spaces, monitors, Stage Manager and long battery use still need manual checks.

## Create a DMG locally

```sh
VINYL_UNIVERSAL=1 Scripts/build.sh
Scripts/package-dmg.sh
```

Outputs are `dist/Vinyl-<version>.dmg` and `.dmg.sha256`. Do not commit generated installers. The disk contains the app, an Applications shortcut and installation notes.

## Publish a GitHub release

1. Merge reviewed changes into `main`; wait for **Checks**.
2. Update `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist` for a new version.
3. Commit that change, create a matching version tag, and push it:

   ```sh
   git tag v0.1.0
   git push origin v0.1.0
   ```

4. **Release DMG** validates that tag against the app version, runs checks, builds universal binaries and publishes the DMG plus checksum to a GitHub Release.

Use a new tag/version for later releases. The workflow does not overwrite an existing release. Do not tag unreviewed branches. It uses the repository-scoped built-in token only during publication; no personal token or Apple credentials are required. The checkout action is pinned to a commit, with persisted credentials disabled. Dependabot proposes action updates.

The release is a development distribution: no Developer ID signature or notarization. Add those separately using approved signing credentials, never committed certificates/passwords, before describing a release as notarized.
