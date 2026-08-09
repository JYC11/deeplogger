# Plan 01 — DiveLogger App Development (MVP)

**Prerequisite**: `.plan/00-environment-setup.md` complete (green `fvm flutter doctor -v`).
**Authority order**: `PRD.md` (v1.1, stakeholder-approved) > `AGENTS.md`. Key decisions already locked:
- Official name: **DiveLogger** (`--project-name divelogger`, display name "DiveLogger").
- SAC: industry-standard RMV (see PRD §5.2 — computed dynamically, never stored).
- Photo grouping: 90-min intra-dive cap / 60-min new-dive gap (PRD §8).
- Offline-first, no dive-computer integration, no accounts/cloud.

**Gate after EVERY milestone** (in this order — format before checks):
```bash
fvm dart format . && fvm flutter analyze && fvm flutter test
```
All three must pass before the milestone is considered done. Relevant skills in `.agents/skills/` (e.g. `flutter-apply-architecture-best-practices`, `dart-add-unit-test`, `flutter-add-widget-test`) should be loaded and followed.

---

## M1 — Project scaffold
1. `fvm flutter create --org com.divelogger --project-name divelogger --platforms ios,android .`
   (Resulting IDs: `com.divelogger.divelogger` — acceptable default; change `--org` only if the user requests.)
2. Dependencies (`fvm flutter pub add`): `flutter_riverpod sqflite path path_provider photo_manager exif share_plus image intl`
   Dev: `flutter_lints` (+ `integration_test`, `flutter_driver:{sdk: flutter}` — driver extension gated behind `--dart-define=ENABLE_FLUTTER_DRIVER=true` in `main.dart` so the dart MCP server can drive the app; keep it out of release builds).
3. Permissions:
   - iOS `ios/Runner/Info.plist`: `NSPhotoLibraryUsageDescription` ("DiveLogger groups your dive photos into draft log entries and stores copies inside the app."), deployment target iOS 14.
   - Android `android/app/src/main/AndroidManifest.xml`: `READ_MEDIA_IMAGES` (+ `READ_EXTERNAL_STORAGE` with `maxSdkVersion="32"`), `minSdkVersion 23`.
4. Folder layout per AGENTS.md: `lib/models|database|providers|screens|widgets|services`.
5. `git add -A && git commit -m "feat: flutter scaffold with dependencies and permissions"` (if approved).

## M2 — Data layer
Depends on: M1.
- `lib/models/`: `dive_log.dart`, `sighting.dart`, `certification.dart`, `gear_item.dart`, `dive_photo.dart` (plain immutable classes + `toMap`/`fromMap`; null-safe).
- `lib/database/database_helper.dart`: singleton `DatabaseHelper`, versioned `onCreate`/`onUpgrade` migrations.
  Tables:
  - `dive_logs(id PK, start_time, end_time, location, altitude, max_depth_m, avg_depth_m, duration_min, gas_type, gas_other, tank_size, start_pressure_bar, end_pressure_bar, water_temp_c, salinity, visibility_m, weight_kg, notes, is_draft, created_at, updated_at)`
  - `dive_photos(id PK, dive_log_id FK→dive_logs ON DELETE CASCADE, local_path, taken_at)`
  - `sightings(id PK, dive_log_id FK, dive_photo_id FK→dive_photos, common_name)` — photo must reference an attached dive photo (PRD §8.3).
  - `certifications(id PK, org, level, issue_date, photo_path)`
  - `gear_items(id PK, name, type_notes)`
  - `dive_log_gear(dive_log_id FK, gear_item_id FK, PK(dive_log_id, gear_item_id))` — M2M per-dive gear selection.
- `lib/services/sac_calculator.dart`: `SacResult? computeSac({startBar, endBar, durationMin, avgDepthM, tankSize})` implementing PRD §5.2 exactly (incl. tank-size parsing: `12L` → 12.0; `80 cu ft` → 80 × 28.3168 / 207; guards for duration ≤ 0 / end ≥ start / unknown volume → bar/min fallback or null).
- Tests (`test/`): SAC formula + tank parsing + all guard rails; DB CRUD for every table; migration path. Use `sqflite_common_ffi` for host-side DB tests.

## M3 — Core dive logbook UI
Depends on: M2.
- Riverpod per AGENTS.md: `StateNotifierProvider` (mutations), `FutureProvider` (DB reads). Pure `build()` methods.
- Screens: dive list (desc by date) → dive detail (depth/duration/SAC prominent; expandable secondary section with tank/salinity/altitude + imperial conversions) → dive form (all PRD §5.1 fields incl. gear multi-select from master list, gas dropdown Air/Nitrox/Other+free-text, salinity dropdown).
- Widget tests for list + detail + form validation (`.agents/skills/flutter-add-widget-test`).

## M4 — Photo auto-log ("killer feature", PRD §5.3)
Depends on: M3.
- `lib/services/gallery_scanner.dart`: `photo_manager` permission flow (iOS limited-access handling) + timestamp extraction (native `createDateTime` first for speed; EXIF `DateTimeOriginal` → `DateTimeDigitized` → file timestamp fallback).
- `lib/services/dive_grouper.dart`: pure function over sorted timestamps. Constants `kMaxIntraDiveGap = 90 min`, `kMinInterDiveGap = 60 min`. First photo starts a cluster; extend while gap-to-previous ≤ 90 min; any gap > 60 min starts a new cluster. Unit-test gaps of 30 / 75 / 120 min and single-photo edge cases.
- Draft flow: one draft `DiveLog` (`is_draft = true`) per cluster with start/end from first/last photo; review screen lets the user complete + save or discard.
- `lib/services/image_store.dart`: copy attached photos into `getApplicationDocumentsDirectory()` (never reference gallery paths); thumbnail-friendly compression.
- Perf gate: 1,000-photo scan < 3 s on a mid-range device (PRD NFR-2) — batch `photo_manager` queries; avoid per-asset full EXIF reads.

## M5 — Marine life, gear, certifications
Depends on: M3.
- Sightings CRUD inside dive detail; photo picker constrained to the dive's `dive_photos`; thumbnails in detail view.
- Gear master list screen (CRUD) + per-dive selection wired through `dive_log_gear`.
- Certifications screen grouped by org (PADI/SSI/BSAC/…, free-text allowed); fields org/level/optional issue date/card photo (photo copied to app dir).

## M6 — Instagram export (PRD §5.5)
Depends on: M4 (photos), M5 (sightings).
- `lib/services/share_card.dart`: render a card widget (site, date, duration, max depth, SAC, ≤4-photo grid, ≤5 species) → capture via `RepaintBoundary` → PNG bytes.
- Share via `share_plus`; camera-roll fallback.
- Widget test: card renders with 0–4 photos and 0–5 sightings without overflow (`.agents/skills/flutter-fix-layout-issues` if needed).

## M7 — On-device verification
Depends on: M4–M6.
- Run on iOS simulator AND Android emulator (`fvm flutter run -d …`).
- Drive via MCP: `dart` server for runtime errors/widget tree/hot reload; `mobile-mcp` for screenshots, taps, permission dialogs.
- Verify: photo-permission flows (incl. iOS limited access), zero crashes during gallery scan, SAC displayed correctly, share sheet opens.
- Final gate: format/analyze/test clean + `fvm flutter build apk --debug` and `--no-codesign` iOS build succeed.

---

## Out of scope / deferred
- Firebase App Distribution setup (needs firebase CLI + Google/Firebase project; Apple Developer account for iOS).
- Real-device testing, App Store / Play listings, l10n beyond `intl` plumbing.
