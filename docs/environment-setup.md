# DeepLogger Development Environment Setup

This documents the full toolchain setup performed on this machine (macOS 26.5 arm64) so you can understand what's installed, where it lives, and how to verify it.

## Design Principles

1. **No global Flutter/Dart** — the SDK is pinned per-project via `fvm`. The only global binary installed is `fvm` itself.
2. **No Android Studio** — command-line tools only (lighter, scriptable).
3. **No shell-profile edits** — `ANDROID_HOME` is set per-session; Flutter stores the SDK path in its own config.
4. **Everything is reproducible from `.fvmrc` + `opencode.json`** — both committed to git.

## What's Installed

### 1. fvm (Flutter Version Manager)

- **Location**: `/opt/homebrew/bin/fvm` (Homebrew formula `leoafarias/fvm/fvm`)
- **Version**: 4.1.2
- **Why**: The only global binary. Manages per-project Flutter SDK versions without polluting the system PATH. Each project pins its version in `.fvmrc`; the SDK itself lives in `~/fvm/versions/<version>/` and is symlinked into the repo as `.fvm/flutter_sdk` (gitignored).

```bash
fvm --version        # verify
```

### 2. Flutter SDK (pinned via fvm)

- **Version**: 3.44.9 (stable, Aug 2026)
- **Dart version**: 3.12.2
- **Pinned in**: `.fvmrc` (committed to git)
- **SDK location**: `~/fvm/versions/3.44.9/`
- **Project symlink**: `.fvm/flutter_sdk` → above (gitignored)

**Rule**: always use `fvm flutter ...` / `fvm dart ...`, never bare `flutter` / `dart`.

```bash
fvm flutter --version    # verify
fvm dart --version       # verify
```

### 3. iOS Toolchain

#### Xcode
- **Version**: Xcode 26.5 (Build 17F42)
- **Location**: `/Applications/Xcode.app`
- **License**: accepted (`xcodebuild -license check` → ok)
- **First-launch tasks**: run (`xcodebuild -runFirstLaunch`)

#### iOS Simulator
- **Runtime**: iOS 26.5 (23F77) — downloaded via `xcodebuild -downloadPlatform iOS`
- **Device**: "iPhone Dev" — iPhone 17 Pro on iOS 26.5 runtime
- **UDID**: `87B1A768-21AC-4E16-AA8B-35DCE3BE08B2`
- **State**: boots successfully (currently booted)

```bash
xcrun simctl list devices | grep "iPhone Dev"    # verify (should show Booted)
xcrun simctl boot "iPhone Dev"                   # boot if needed
```

#### CocoaPods
- **Version**: 1.17.0 (was 1.11.3 — too old, replaced)
- **Location**: `/opt/homebrew/bin/pod` (Homebrew install)
- **Why replaced**: the old 1.11.3 was a root-owned system-Ruby gem at `/usr/local/bin/pod`. It was uninstalled via `sudo gem uninstall -aIx cocoapods ...` and reinstalled cleanly via Homebrew so it lives in `/opt/homebrew/bin` and is managed by brew.

```bash
which pod && pod --version    # verify → /opt/homebrew/bin/pod, 1.17.0
```

### 4. Android Toolchain (command-line only, no Android Studio)

#### SDK Location
- **`ANDROID_HOME`**: `~/Library/Android/sdk`
- **cmdline-tools**: symlinked from Homebrew cask into SDK root (`~/Library/Android/sdk/cmdline-tools/latest` → `/opt/homebrew/share/android-commandlinetools/cmdline-tools/latest`)

#### Installed SDK Packages
| Package | Version |
|---|---|
| `platform-tools` | 37.0.1 |
| `platforms;android-36` | 2 |
| `build-tools;36.0.0` | 36.0.0 |
| `emulator` | 37.1.11 |
| `system-images;android-36;google_apis;arm64-v8a` | 7 |

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
sdkmanager --sdk_root="$ANDROID_HOME" --list_installed    # verify
```

#### AVD (Android Virtual Device)
- **Name**: `deeplogger_pixel`
- **Profile**: Pixel 7 (manual config)
- **Image**: `system-images;android-36;google_apis;arm64-v8a`

> **Known workaround**: the deprecated `avdmanager` (bundled in cmdline-tools) cannot enumerate system images in the new SDK 36 layout — it returns `Error: Package path is not valid. Valid system image paths are: null` even though the image is installed. The AVD was created by hand-writing the config files:
> - `~/.android/avd/deeplogger_pixel.ini` (path + target)
> - `~/.android/avd/deeplogger_pixel.avd/config.ini` (image.sysdir.1, abi.type, tag.id, hw.* fields)
>
> The `emulator` binary reads these hand-crafted configs fine. This is recorded as a filament lesson (`fl lesson show sjasm7fh`).

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
"$ANDROID_HOME/emulator/emulator" -list-avds    # verify → deeplogger_pixel
"$ANDROID_HOME/emulator/emulator" -avd deeplogger_pixel    # boot
```

### 5. Java (for Android Gradle)

- **Version**: OpenJDK 21.0.9 LTS (Amazon Corretto)
- **Source**: sdkman (`/Users/admin/.sdkman/candidates/java/current`)
- **Note**: JAVA_HOME must be set when building Android. In interactive shells sdkman handles this; in agent/CI shells, export it explicitly.

### 6. MCP Servers (project-local)

Configured in `opencode.json` (committed):

- **`dart`** — official Dart/Flutter MCP server. Runs via `fvm dart mcp-server --force-roots-fallback`. Provides: analysis-error fixing, symbol resolution, pub.dev search, pubspec management, test running, and driving the running app (screenshots/taps/hot reload).
- **`mobile-mcp`** — simulator/emulator control. Runs via `npx -y @mobilenext/mobile-mcp@latest`. Provides: launch apps, screenshots, accessibility-tree interaction, crash logs. Telemetry disabled.

## Full Verification

The single gate command that confirms everything works:

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
export JAVA_HOME="/Users/admin/.sdkman/candidates/java/current"
fvm flutter doctor
```

Expected output (all green, no issues):
```
[✓] Flutter (Channel stable, 3.44.9, on macOS 26.5.2 darwin-arm64)
[✓] Android toolchain - develop for Android devices (Android SDK version 36.0.0)
[✓] Xcode - develop for iOS and macOS (Xcode 26.5)
[✓] Chrome - develop for the web
[✓] Connected device (3 available)
[✓] Network resources
• No issues found!
```

The "Android Studio not installed" warning is **expected and acceptable** — command-line tools suffice for all builds.

## Environment Variables (per-session)

Set these in every shell that builds the app (or in CI):

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"          # some tools check this
export JAVA_HOME="/Users/admin/.sdkman/candidates/java/current"
```

Flutter remembers the Android SDK path via `fvm flutter config --android-sdk` (stored in its own config, no shell-profile edits needed).

## What's NOT Installed (Out of Scope for MVP)

- **Firebase App Distribution** — needs Firebase CLI + a Google/Firebase project + Apple Developer account. Tracked as a follow-up after MVP runs on simulators.
- **Real-device testing** — needs Apple Developer account (iOS) or a USB debugging device (Android).

## Session Handoff

This setup is complete. The next stage is Plan 01 (app development), starting with M1 (project scaffold). To pick up:

```bash
fl task ready    # → M1 Project scaffold
```
