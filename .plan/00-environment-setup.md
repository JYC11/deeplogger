# Plan 00 — Environment Setup (run before any app code)

**Goal**: isolated Flutter/Dart toolchain (no global installs) + Android/iOS toolchains + MCP servers, ending in a green `flutter doctor`.
**Context**: macOS 26.5.2 (arm64). Already present: Homebrew, git, Node 24 (nvm), Java 21 (sdkman), Xcode 26.5, CocoaPods 1.11.3 (**too old — upgraded below**). No iOS simulator runtimes yet. No Android SDK yet.
**Repo root**: `/Users/admin/Desktop/code/deeplogger` (directory name stays as-is; the Flutter project name is `divelogger`).

> Run tasks in order. Each task lists its dependencies. Do NOT skip the verification gates.

---

## Task 1 — Install fvm (the only global binary)
```bash
brew tap leoafarias/fvm
brew install fvm
fvm --version   # gate: prints version
```
Nothing named `flutter` or `dart` is put on the global PATH; SDKs live in `~/fvm/versions/`.

## Task 2 — Pin Flutter for this project
Depends on: Task 1.
```bash
cd /Users/admin/Desktop/code/deeplogger
fvm releases            # pick latest stable (3.44.x at time of writing)
fvm install <VERSION>   # e.g. fvm install 3.44.7
fvm use <VERSION>       # creates .fvmrc (pin, committed) + .fvm/ (sdk symlink, gitignored)
fvm flutter --version && fvm dart --version   # gate
```
**Rule for every later step**: always `fvm flutter …` / `fvm dart …`, never bare commands.

## Task 3 — iOS toolchain
Depends on: Task 2.
```bash
sudo xcodebuild -license accept || true
xcodebuild -runFirstLaunch
xcodebuild -downloadPlatform iOS        # installs the missing simulator runtime (large download)
xcrun simctl list devicetypes           # pick latest iPhone type
xcrun simctl create "iPhone Dev" <DEVICETYPE> <RUNTIME>
xcrun simctl boot "iPhone Dev"          # gate: boots without error
brew install cocoapods                  # upgrades 1.11.3 → current; lands in /opt/homebrew/bin
hash -r; which pod && pod --version     # gate: /opt/homebrew/bin/pod, ≥ 1.15
```

## Task 4 — Android toolchain (command-line only, no Android Studio)
Depends on: Task 2.
```bash
brew install --cask android-commandlinetools
export ANDROID_HOME="$HOME/Library/Android/sdk"
yes | sdkmanager --sdk_root="$ANDROID_HOME" --licenses
sdkmanager --sdk_root="$ANDROID_HOME" \
  "platform-tools" "platforms;android-36" "build-tools;36.0.0" \
  "emulator" "system-images;android-36;google_apis;arm64-v8a"
fvm flutter config --android-sdk "$ANDROID_HOME"   # stored in Flutter's own config; no shell-profile edits
avdmanager create avd -n divelogger_pixel \
  -k "system-images;android-36;google_apis;arm64-v8a" -d pixel_7
```
Notes:
- Java 21 from sdkman satisfies the Android Gradle Plugin — no Java changes needed. Ensure `JAVA_HOME` is set when building (sdkman does this in interactive shells; the agent shell inherits it — verify with `echo $JAVA_HOME`).
- Platform/build-tools versions are "latest at execution time"; adjust if sdkmanager lists newer.

## Task 5 — Full doctor gate
Depends on: Tasks 2–4.
```bash
fvm flutter doctor -v
```
Gate: **Flutter, Android toolchain, Xcode, CocoaPods all green.** Android Studio "not installed" warning is expected and acceptable (cmdline tools suffice). Do not proceed to plan 01 until this passes.

## Task 6 — MCP servers (project-local opencode.json)
Depends on: Task 2 (dart MCP), Task 3+4 (useful mobile-mcp output).
Create `/Users/admin/Desktop/code/deeplogger/opencode.json`:
```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "dart": {
      "type": "local",
      "command": ["fvm", "dart", "mcp-server", "--force-roots-fallback"],
      "enabled": true
    },
    "mobile-mcp": {
      "type": "local",
      "command": ["npx", "-y", "@mobilenext/mobile-mcp@latest"],
      "enabled": true,
      "environment": { "MOBILEMCP_DISABLE_TELEMETRY": "1" }
    }
  }
}
```
- `dart` = official Dart & Flutter MCP (experimental; needs Dart ≥ 3.9 — satisfied by the pinned SDK). Gives the agent: analysis-error fixing, symbol resolution, pub.dev search, pubspec management, test running, and driving the running app (screenshots/taps/hot reload via DTD + flutter_driver).
- `mobile-mcp` = simulator/emulator control (launch apps, screenshots, accessibility-tree interaction, crash logs).
- Gotcha: if opencode can't spawn `npx` (nvm-managed Node), replace with the absolute path from `which npx`.
- Gate: restart opencode in this repo; both servers appear as connected; `mobile_list_available_devices` returns the booted iOS sim and/or Android emulator.

## Task 7 — Commit checkpoint
Depends on: all above.
```bash
git add -A && git commit -m "chore: pin Flutter via fvm, configure MCP servers"
```
(Only if the user has approved git commits in that session.)

---

## Deferred (NOT part of this plan)
- **Firebase App Distribution** (needs firebase CLI + a Google/Firebase project + Apple Developer account for iOS builds). Track as a follow-up after MVP runs on simulators.
- **Real-device testing** (needs Apple Developer account / USB debugging device).
