# DeepLogger Session State

**Last updated**: 2026-08-20
**Phase**: Pre-release — dependency upgrade + Android signing done; Firebase App Distribution wiring pending user-performed manual steps. iOS deferred.

## What's Done
- [x] Dependency upgrade: `image 4.9.2`, `sqflite_common_ffi 2.4.2+1` (+ transitive: dbus, sqlite3, synchronized, source_maps, vm_service). `dart analyze` clean, **188 tests pass**. Most of the "outdated" list was SDK-pinned transitive — not upgradable until Flutter releases a new SDK.
- [x] Flutter confirmed already on latest stable: `3.44.9` / Dart `3.12.2` (the "new version" banner in `fvm flutter --version` is stale/misleading — `fvm list` confirms 3.44.9 is the only and latest installed stable).
- [x] Firebase CLI installed via Homebrew: `firebase-cli 15.27.0`.
- [x] Android release keystore created: `android/app/keystore/upload-keystore.jks` (PKCS12, RSA 2048, 10000-day validity, DN `CN=DeepLogger Upload, O=DeepLogger, C=US`). Passwords in gitignored `android/key.properties`. Backup at `~/Backups/deeplogger/`.
- [x] `android/app/build.gradle.kts` wired with `release` signingConfig (debug-fallback guard if `key.properties` absent).
- [x] Local release APK builds + verifies: `app-release.apk` (~60 MB), release-signed (SHA-256 `b913e05d...`, SHA-1 `a5a5f627...`, MD5 `b894300362f6dfb23a6d987eb3bc32c6`).
- [x] Docs written: `docs/release-build.md` (signing/build/verify), `docs/firebase-app-distribution.md` (manual TODO checklist for user). Both referenced from AGENTS.md.

## Current State
### Tooling
| Tool | Version | Notes |
|---|---|---|
| Flutter (fvm) | 3.44.9 stable | latest as of session |
| firebase-cli | 15.27.0 | installed via brew; `firebase login` not yet completed |

### Signing
- **Android**: release keystore at `android/app/keystore/upload-keystore.jks`, secrets at `android/key.properties` (gitignored), backup at `~/Backups/deeplogger/`.
- **iOS**: deferred — would need paid Apple Developer Program ($99/yr) for App Distribution; free account suffices for local device sideload only (7-day expiry, 3 apps max).

## What's Next (next session — blocked on user)
1. **User**: complete `firebase login` (browser auth flow — paste auth code back so agent can run `firebase login <code>`).
2. **Agent**: `firebase projects:create deeplogger --name "DeepLogger"` (pick fallback ID if `deeplogger` taken).
3. **Agent**: `firebase apps:create android --project deeplogger --package com.deeplogger.deeplogger` → save returned Firebase App ID.
4. **Agent**: first upload — `firebase appdistribution:distribute --project deeplogger --app <APP_ID> --release-notes "Initial internal build" --testers <you> build/app/outputs/flutter-apk/app-release.apk`.
5. **Deferred from prior session**: iOS simulator QA of F1–F7 (see `.plan/05-further-feedback.md`); Android emulator QA (never done). These are independent of distribution — can interleave.

## Gotchas / Lessons
- **F7 round-trip test**: `BackupService.importFromZip` reopens the DB via `DatabaseHelper._open()` which calls `getDatabasesPath()` — that's a platform channel not mocked in host tests. Added `DatabaseHelper.databasesPathOverride` test seam; set it to a temp dir in `backup_service_test.dart` setUp or the post-import `database` getter throws `MissingPluginException`.
- **file_picker v12 API**: `FilePicker.platform.pickFiles` is gone — use `FilePicker.pickFile(...)` (returns `PlatformFile?`, not `FilePickerResult?`). Got bit by this during analyze.
- **ShareCard 1080px canvas**: any widget test pumping `ShareCard` bare in an 800px viewport overflows. Must wrap in `FittedBox(fit: BoxFit.contain)` — mirrors the production preview dialog path.
- **autoDispose + test holds**: form providers are autoDispose; bare `container.read` between awaits tears them down. Hold a `container.listen` subscription across setUp + test bodies (lesson `scfm7xih`).
- **Flutter "new version available" banner is stale**: `fvm flutter --version` shows a banner even on the latest stable. Trust `fvm list` / `fvm releases stable` instead.
- **PKCS12 keystore ignores `-keypass`**: keytool warns "Different store and key passwords not supported for PKCS12 KeyStores. Ignoring user-specified -keypass value." — store and key passwords are the same; `key.properties` must set both to the store password.
- **`photo_manager` applies KGP directly**: build warns it'll break in a future Flutter requiring Built-in Kotlin. Track upstream; non-blocking today.
- **Free Apple ID ≠ App Distribution**: free account allows personal sideload (7-day expiry, 3 apps) but cannot produce ad-hoc/development `.ipa` for App Distribution/TestFlight — those require paid $99/yr membership. iOS distribution deferred accordingly.
