# DeepLogger Release Build & Signing

How to build a release-signed Android APK for DeepLogger and how the upload keystore is managed. Covers what was set up on this machine; forward-references Firebase App Distribution (covered separately once wired).

## Overview

- **Artifact**: `build/app/outputs/flutter-apk/app-release.apk` (~60 MB)
- **Signing identity**: `CN=DeepLogger Upload, O=DeepLogger, C=US`
- **Keystore type**: PKCS12, RSA 2048, validity 10000 days
- **Signing config**: applied automatically when `android/key.properties` is present; falls back to debug keys otherwise so `flutter run --release` still works without the keystore.

## Prerequisites (already satisfied on this machine)

| Tool | Version | Verify |
|------|---------|--------|
| Flutter (via fvm) | 3.44.9 stable | `fvm flutter --version` |
| Android SDK build-tools | 36.0.0 | `apksigner` on PATH below |
| `keytool` (JDK) | ships with Android Studio / JDK | `keytool -help` |

The keystore is **release-critical**: losing it means you can never push an update to the same app listing on Google Play. Treat `upload-keystore.jks` + `key.properties` like production secrets.

## Keystore layout

```
android/
├── key.properties                       # gitignored — store/key passwords + alias + path
└── app/
    └── keystore/
        └── upload-keystore.jks          # gitignored — the signing key itself
```

Both are listed in `android/.gitignore` (`key.properties`, `**/*.keystore`, `**/*.jks`), so they will never be committed.

### Offline backup

A copy lives outside the repo at:

```
~/Backups/deeplogger/
├── upload-keystore.jks
└── key.properties
```

Back this up to durable storage (encrypted cloud, USB, password manager attachment). If you lose the repo copy, restore from here.

## How the signing config is wired

`android/app/build.gradle.kts` reads `key.properties` at the project root and registers a `release` signing config:

```kotlin
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

signingConfigs {
    create("release") {
        if (keystorePropertiesFile.exists()) {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
}

buildTypes {
    release {
        signingConfig = if (keystorePropertiesFile.exists()) {
            signingConfigs.getByName("release")
        } else {
            signingConfigs.getByName("debug")
        }
    }
}
```

The `if (exists())` guard means CI machines and fresh clones that don't have `key.properties` will fall back to debug signing — `flutter run --release` keeps working. A real release build only happens where the keystore is present.

## Building a release APK

```bash
fvm flutter build apk --release
```

Output:

```
✓ Built build/app/outputs/flutter-apk/app-release.apk
```

If `key.properties` is present the APK is signed with the upload key; otherwise it's debug-signed (still installable, but not Play-store-ready).

## Verifying the signature

```bash
APKSIGNER=$(find ~/Library/Android/sdk/build-tools -name apksigner | sort -V | tail -1)
"$APKSIGNER" verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

Expected (the DN is the signing identity):

```
Signer #1 certificate DN: CN=DeepLogger Upload, O=DeepLogger, C=US
Signer #1 certificate SHA-256 digest: b913e05d...
```

Keep a note of the SHA-256 — Firebase App Distribution and Play Console both display it, so you can confirm you're shipping the same key across uploads.

## Regenerating the keystore (only if lost/compromised)

> ⚠️ Regenerating means a new signing identity. Existing installs cannot be upgraded — users must uninstall + reinstall. Do this only as a last resort.

```bash
STORE_PW=$(openssl rand -base64 24 | tr -d '/+=' | head -c 20)

mkdir -p android/app/keystore
keytool -genkey -v \
  -keystore android/app/keystore/upload-keystore.jks \
  -alias upload -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$STORE_PW" -keypass "$STORE_PW" \
  -dname "CN=DeepLogger Upload, O=DeepLogger, C=US"
```

Then write `android/key.properties` (same format as below) and re-back-up. For Play Store continuity, instead use Play App Signing: generate a new upload key, register it via the Play Console, and Google re-signs with your original app signing key. App Distribution does not require this since it does not go through Play.

## `key.properties` format

```
storePassword=<store password>
keyPassword=<key password>      # equals storePassword for PKCS12
keyAlias=upload
storeFile=keystore/upload-keystore.jks
```

The `storeFile` path is relative to `android/app/` (the module dir), so `keystore/upload-keystore.jks` resolves to `android/app/keystore/upload-keystore.jks`.

## Rotating passwords

PKCS12 keystores use one password for both store and key. To rotate:

```bash
keytool -storepasswd -keystore android/app/keystore/upload-keystore.jks \
  -storepass "<old>" -new "<new>"
```

Then update `storePassword` and `keyPassword` in `android/key.properties` and the backup copy at `~/Backups/deeplogger/key.properties`.

## Known warnings (non-blocking)

- `photo_manager` applies the Kotlin Gradle Plugin directly. A future Flutter will require plugin authors to migrate to Built-in Kotlin. Track upstream; not relevant to shipping today.
- `SDK XML version 4` warning from the build tools — harmless mismatch between Android Studio and command-line tools versions.

## Next: Firebase App Distribution

Once `firebase login` is complete:

```bash
firebase projects:create deeplogger                    # one-time
firebase apps:create android com.deeplogger.deeplogger  # register the Android app
firebase appdistribution:distribute \
  --app <FIREBASE_APP_ID> \
  build/app/outputs/flutter-apk/app-release.apk \
  --release-notes "Initial internal build"
```

`FIREBASE_APP_ID` is returned by `firebase apps:create` (format `1:xxxxxxxx:android:yyyyyyyy`), also visible in the Firebase Console → Project settings → Your apps.
