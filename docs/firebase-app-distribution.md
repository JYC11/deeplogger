# Firebase App Distribution — Setup TODO

Manual steps you need to perform to wire Firebase App Distribution for DeepLogger. These require your Google account in a browser and cannot be automated by the agent.

The Firebase CLI (`firebase-cli 15.27.0`) is already installed via Homebrew. Android release signing is already configured (`docs/release-build.md`).

## 0. Prerequisites (already done)

- [x] Firebase CLI installed: `firebase --version` → `15.27.0`
- [x] Android release keystore created + signing config wired (`android/app/keystore/upload-keystore.jks`, `android/key.properties`, backup at `~/Backups/deeplogger/`)
- [x] Local release APK builds and verifies: `fvm flutter build apk --release` → `app-release.apk` (~60 MB), signed `CN=DeepLogger Upload`

## 1. Authenticate the Firebase CLI

```bash
firebase login
```

A browser opens with a session ID and code challenge. Approve access for your Google account. The CLI caches the refresh token in `~/.config/.firebase/` — re-login only when tokens expire.

**Verify:**

```bash
firebase projects:list
```

Should list your existing Firebase projects (or be empty if this is your first).

## 2. Create the Firebase project

Option A — CLI (fastest):

```bash
firebase projects:create deeplogger --name "DeepLogger"
```

- `deeplogger` is the **project ID** — globally unique across all Firebase projects, immutable.
- `--name` is the display name (mutable later).

Option B — Console: https://console.firebase.google.com → "Add project" → name it `DeepLogger`, accept defaults (no Google Analytics needed for App Distribution alone).

If `deeplogger` is taken, pick `deeplogger-app` / `deeplogger-<initials>` etc. and note the ID you chose — every later command uses it.

**Verify:**

```bash
firebase projects:list    # look for deeplogger in the list
```

## 3. Register the Android app in Firebase

```bash
firebase apps:create android \
  --project deeplogger \
  --package com.deeplogger.deeplogger
```

Returns the **Firebase App ID** in the format `1:<project-number>:android:<random>`. Save it — every `appdistribution:distribute` upload needs it.

(You do **not** need `google-services.json` or the `firebase_core` Flutter package for App Distribution alone — that's only required for in-app Firebase services like Crashlytics/Analytics. App Distribution is a CLI upload service.)

**Verify:**

```bash
firebase apps:list --project deeplogger
```

Should show one Android app with package `com.deeplogger.deeplogger`.

## 4. (Optional) Register the iOS app

iOS build/upload is deferred for now, but you can register the app so the bundle ID is reserved:

```bash
firebase apps:create ios \
  --project deeplogger \
  --bundle-id com.deeplogger.deeplogger
```

This does not require an Apple Developer account to register — only the upload does.

## 5. (Optional) Set up tester groups

Skipped per your earlier decision. If you want named groups later:

```bash
firebase appdistribution:group create \
  --project deeplogger \
  --name internal

firebase appdistribution:group create \
  --project deeplogger \
  --name beta
```

Add testers via the Console UI (App Distribution → Testers & Groups) or:

```bash
firebase appdistribution:testers add \
  --project deeplogger \
  --group internal \
  --emails tester1@example.com,tester2@example.com
```

## 6. First upload

Build the APK if you haven't recently:

```bash
fvm flutter build apk --release
```

Upload:

```bash
firebase appdistribution:distribute \
  --project deeplogger \
  --app <FIREBASE_APP_ID-from-step-3> \
  --release-notes "Initial internal build" \
  --testers you@example.com \
  build/app/outputs/flutter-apk/app-release.apk
```

Omit `--testers` to upload without notifying anyone; or use `--group internal` if you created a group in step 5.

**Verify:** open https://console.firebase.google.com/project/deeplogger/appdistribution — your release should appear with a build number, release notes, and a download link.

## 7. Inviting testers

Testers receive an email with an "Accept invite" link → installs the Firebase App Tester app (Android) or registers the device profile (iOS) → download the build.

First-time testers must be added by email (console or `firebase appdistribution:testers add`). Subsequent uploads to a tester who already accepted need no re-invite.

## 8. (Future) Automating the upload

Once the manual flow works, consider a GitHub Actions workflow on tag push:

```yaml
# .github/workflows/distribute.yml (sketch)
on:
  push:
    tags: ['v*']
jobs:
  distribute:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.44.9' }
      - run: flutter build apk --release
      - uses: w9jds/firebase-action@master
        with:
          creds: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          projectId: deeplogger
        # then run: firebase appdistribution:distribute ...
```

You'd store a Firebase service account JSON as a GitHub Actions secret. Not needed for the first manual release.

## Troubleshooting

| Symptom | Cause / Fix |
|---------|-------------|
| `Command not found: firebase` | `brew install firebase-cli` (already done on this machine) |
| `Failed to authenticate` | re-run `firebase login` — tokens expire |
| `Project ID deeplogger already taken` | pick another ID, use it consistently |
| Upload succeeds but testers don't get email | check spam; or use the console "Copy invite link" |
| `appdistribution:distribute: APK is not signed` | shouldn't happen — your APK is release-signed; verify with `apksigner verify` per `docs/release-build.md` |

## Reference

- App Distribution docs: https://firebase.google.com/docs/app-distribution
- CLI command reference: https://firebase.google.com/docs/cli#appdistribution_commands
- Signing requirements: https://firebase.google.com/docs/app-distribution/android/distribute-android-builds#signing
