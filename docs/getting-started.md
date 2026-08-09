# DiveLogger — Getting Started

How to run the app on your computer. This assumes the environment setup (Plan 00) is already complete — if not, see `docs/environment-setup.md` first.

## Prerequisites

- macOS (arm64) with Xcode 26.5+ and Android SDK installed
- `fvm` installed (`brew install fvm`) — this is the only global binary
- The Flutter SDK is pinned in `.fvmrc` (Flutter 3.44.9); fvm manages it automatically

## Install dependencies

From the project root:

```bash
fvm flutter pub get
```

This reads `pubspec.yaml` and downloads all packages. Run this after every `git pull` or when dependencies change.

## Running on iOS Simulator

### One-time: boot the simulator

```bash
xcrun simctl boot "iPhone Dev"
open -a Simulator   # opens the Simulator app window
```

If you don't have an "iPhone Dev" simulator, create one:

```bash
xcrun simctl list devicetypes    # find a device type, e.g. "iPhone 17 Pro"
xcrun simctl create "iPhone Dev" "iPhone 17 Pro" "iOS26.5"
```

### Build and run

```bash
fvm flutter run -d "iPhone Dev"
```

This compiles the app, installs it on the simulator, and launches it with hot reload enabled. Keep this terminal open while developing.

### Hot reload

While the app is running, press `r` in the terminal to hot reload (applies code changes without losing state). Press `R` for hot restart (resets state). Press `q` to quit.

### For MCP/driver automation

If you want the Dart MCP server or `flutter_driver` to control the app (for automated taps, screenshots, widget inspection), add the dart-define flag:

```bash
fvm flutter run -d "iPhone Dev" --dart-define=ENABLE_FLUTTER_DRIVER=true
```

This enables the `flutter_driver` extension in `lib/main.dart`. Without the flag, the driver extension is disabled (production-safe).

## Running on Android Emulator

### One-time: create the AVD

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
avdmanager create avd -n divelogger_pixel -k "system-images;android-36;google_apis;arm64-v8a" -d pixel_7
```

### Boot and run

```bash
$ANDROID_HOME/emulator/emulator -avd divelogger_pixel &
fvm flutter run -d divelogger_pixel
```

## Building release APK / IPA

### Android (debug APK, no signing needed)

```bash
fvm flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

### iOS (no codesign — for simulator or manual signing)

```bash
fvm flutter build ios --no-codesign
# Output: build/ios/iphoneos/Runner.app
```

### iOS simulator build

```bash
fvm flutter build ios --simulator
# Output: build/ios/iphonesimulator/Runner.app
# Install: xcrun simctl install booted build/ios/iphonesimulator/Runner.app
```

## Closing the app

### On the simulator

- Press the Home button in the Simulator app (Cmd+Shift+H), or
- From the terminal: `xcrun simctl terminate booted com.divelogger.divelogger`
- From opencode/mobile-mcp: the `mobile_terminate_app` tool

### Shutting down the simulator entirely

```bash
xcrun simctl shutdown "iPhone Dev"
```

### Quitting the Simulator app

Cmd+Q in the Simulator app window, or:

```bash
osascript -e 'quit app "Simulator"'
```

## Common issues

**"NDK did not have a source.properties file"** — the NDK download was corrupted. Delete `~/Library/Android/sdk/ndk/<version>/` and rebuild; Gradle will re-download it.

**"CocoaPods too old"** — if `pod install` fails, reinstall: `brew install cocoapods` (the system gem at `/usr/local/bin/pod` is too old).

**"databaseFactory not initialized"** (in tests only) — you need both `sqfliteFfiInit()` and `databaseFactory = databaseFactoryFfi` in your test's `setUpAll`. See `test/database/database_helper_test.dart` for the pattern.

**Permission denied for photos** — the first time you tap "Scan Gallery", iOS will show a permission dialog. If you deny it, the app will show an error message. Grant access in Settings > Privacy > Photos > DiveLogger.
