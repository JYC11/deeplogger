# AGENTS.md - DeepLogger Project

## Role
We are building **DeepLogger**, an offline-first dive logging mobile app (iOS/Android).

## Core Directives
1. **Offline-First**: Never introduce code that relies on the internet, cloud APIs, or user accounts. Everything saves to local SQLite.
2. **No Dive Computer Integration**: Ignore Bluetooth, USB, or serial protocols. This is **out of scope**.
3. **Permissions First**: Always handle iOS `Info.plist` and Android `AndroidManifest.xml` permissions correctly for Gallery/Photos access.

## Tech Stack (Strict)
- **Framework**: Flutter (latest stable).
- **State Management**: Riverpod 3.x (`flutter_riverpod`, classic non-code-gen style). Use `NotifierProvider`+`Notifier` for sync business logic / form mutations, `AsyncNotifierProvider`+`AsyncNotifier` for async state with loading/error/data, and `FutureProvider` for one-shot DB reads. Do **not** use the legacy `StateNotifierProvider`/`StateNotifier` (moved to `legacy/` in 3.x). Prefer immutable state via `copyWith`; rebuild with `ref.watch`/`ref.read`, no `BuildContext` lookups for state.
  - **Family notifiers (3.x)**: family `AsyncNotifier`s extend plain `AsyncNotifier<State>` (there is NO `FamilyAsyncNotifier` base class). The family arg is passed via the **constructor** (`MyNotifier(this.arg)`), stored in a field, and `build()` takes **no arguments**. Provider: `AsyncNotifierProvider.family<MyNotifier, State, Arg>(MyNotifier.new)`.
  - **Form pattern**: `DiveFormNotifier`/`GearFormNotifier`/`CertificationFormNotifier`/`SightingFormNotifier` (in `lib/providers/*_form_provider.dart`) replace the old `ConsumerStatefulWidget`+`TextEditingController` forms. Screens are thin `ConsumerWidget`s that watch the notifier and dispatch actions; all field values, validation errors, and `isSaving` live in the notifier state. This fixed the edit-gear data-loss bug (the form now preloads gear via `getGearEntriesForDive`).
  - **List pattern**: `DiveListNotifier`/`GearListNotifier`/`CertificationListNotifier` (in `lib/providers/list_providers.dart`) hold paginated state (page, hasMore, search, sort). Screens call `refresh()` after navigation return (NOT `ref.invalidate` — that loses search/sort state).
- **Database**: `sqflite` (SQLite) with a single `DatabaseHelper` class + `MigrationRunner` (`lib/database/migration_runner.dart`).
  - **Migrations**: SQL files live in `assets/migrations/`, named `NNN__name.sql` (zero-padded int version), all DDL `IF NOT EXISTS` (idempotent). A `schema_version` meta table records applied versions. To add a migration: drop `002__*.sql`, add its path to `MigrationRunner.migrationAssets`, bump `DatabaseHelper._version`, rerun. `onDowngrade` rejects old>new. Tests inject a disk-based `MigrationRunner` via `DatabaseHelper.useMigrationRunnerForTesting`. The explicit `migrationAssets` list replaces `AssetManifest.json` discovery (Flutter 3.16+ generates binary `AssetManifest.bin` instead).
- **Gallery/EXIF**: `photo_manager` + `exif` (for grouping photos).
- **File System**: `path_provider` (store copied images in `getApplicationDocumentsDirectory()`).
- **Image picker**: `image_picker` (single cert-card photos; distinct from `photo_manager`'s gallery scan).
- **Unit prefs**: `shared_preferences` (per-field display-unit preferences, metric-canonical storage).
- **App icon**: `flutter_launcher_icons` (dev dep; config in `flutter_launcher_icons.yaml`, placeholder in `assets/icon_placeholder.png`, regenerate via `fvm dart run flutter_launcher_icons`).
- **Sharing**: `share_plus`.
- **Distribution**: Firebase App Distribution

## Project Structure (Standard)
Keep files organized in these folders:
- `/lib/models/` (Data classes: `dive_log.dart`, `sighting.dart`, `certification.dart`, `gear_item.dart`).
- `/lib/database/` (Migration scripts and `DatabaseHelper`).
- `/lib/providers/` (Riverpod state providers).
- `/lib/screens/` (UI views).
- `/lib/widgets/` (Reusable UI components).
- `/lib/services/` (Utility logic: EXIF parser, image compressor, share generator).

## Critical Business Logic (Memorize)
1.  **SAC Rate** (computed dynamically, never stored — industry-standard RMV):
    - `P_rate = (Start_Pressure − End_Pressure) / (Duration_min × ((Avg_Depth_m / 10) + 1))` → bar/min at surface.
    - Tank volume parsed from the free-text Tank Size: `"12L"` → 12 L; `"80 cu ft"` → `80 × 28.3168 / 207 ≈ 10.9 L` (assumes 207 bar service pressure). Unparseable/empty → unknown.
    - `SAC = P_rate × Tank_Volume_L` → display **L/min** (primary, metric). Expanded details: bar/min, psi/min, cu ft/min (L/min × 0.0353147).
    - Guards: `Duration_min ≤ 0` or `End ≥ Start` → no SAC. Unknown tank volume → show bar/min only.

2.  **Photo Grouping Logic** (PRD §8, stakeholder-approved — D-GROUP two-threshold span-cap):
    - Scan gallery EXIF for `DateTimeOriginal` (fall back to `DateTimeDigitized`, then file timestamp). `scanGalleryTimestamps` returns `List<ScannedPhoto>` values (`{ DateTime takenAt; Future<File?> Function() resolveFile; }`) — a value-type seam wrapping `AssetEntity.originFile`, since `AssetEntity` has no public constructor and cannot be mocked or cross isolates. On Complete, copy cluster photos to app dir + insert `DivePhoto` rows (`DraftCompleter`). Discard copies nothing. Partial-failure: skip-and-count unreadable sources, surface via SnackBar.
    - Constants: `kMaxIntraDiveGap = 90 min` (hard cluster-span ceiling), `kMinInterDiveGap = 60 min` (soft break for long sparse clusters).
    - Algorithm (for each photo after the first; `gap` = photo − previous, `newSpan` = photo − cluster.first): `gap > 90` → new cluster; `60 < gap ≤ 90` → extend iff `newSpan ≤ 90`, else new cluster; `gap ≤ 60` → always extend.
    - Generate a `DraftDive` per cluster (carrying its `ScannedPhoto`s); on Complete, a draft `DiveLog` is inserted with start/end times populated.

3.  **Image Handling**:
    - When a user attaches a photo (for dive logs or marine life), **copy** the file into the app's private directory. Never reference the original system gallery path directly (to prevent broken links when the user deletes the original). `ImageStore.copyToAppDir` compresses on copy (max 1600px, JPEG q85) via `compute()` (off UI isolate). Thumbnails are filesystem-only (`thumbnails/{photoId}.jpg`, no DB column), lazy-generated via `ImageStore.ensureThumbnail` and used by the dive-detail photo grid (`_PhotoThumb` falls back to the full file on failure).

4.  **Ad-hoc gear (D-GEAR)**: a dive's gear is read via `getGearEntriesForDive` → `List<GearRef>` (sealed type in `lib/models/gear_ref.dart`): `GearRef.item(GearItem)` for master-list rows, `GearRef.adHoc(String)` for free-text `gear_text` rows. It is the **only** gear read path (an `INNER JOIN` like the removed `getGearForDive` would silently drop ad-hoc rows). `dive_log_gear` has a surrogate `id` PK and a partial unique index on `(dive_log_id, gear_item_id) WHERE gear_item_id IS NOT NULL`. Writes go through `setGearEntriesForDive` (delete + batch insert inside a transaction). `kDefaultGearCategories` (constant-only, in `gear_item.dart`) drives the category dropdown — **no DB seeding**.

5.  **Units (D-UNITS)**: storage is metric-canonical — the DB always stores m/bar/°C/kg. `UnitConverter` (`lib/services/unit_converter.dart`) converts on the boundary: `toMetric` for entered values, `fromMetric` for display. Per-field display-unit preferences persist via `shared_preferences` (`UnitPreferencesService`). Tank volume is the exception (D-TANK): stored as `tank_volume_value` + `tank_volume_unit` (`'L'|'cu_ft'`) as entered; SAC reads structured value first (cu_ft → L via `× 28.3168 / 207`), falling back to parsing legacy `tank_size` text.

## Coding Conventions
- Use **Dart null safety** exclusively.
- Use `async/await` for all DB and File I/O (wrap in `try-catch` to prevent UI crashes).
- Keep widget build methods pure; move logic to providers or services.
- Use **relative imports** (avoid `package:` imports within the same lib folder unless necessary).

## SKILLS
- flutter and dart specific skills are in .agents/skills
.agents/skills
├── dart-add-unit-test
├── dart-build-cli-app
├── dart-collect-coverage
├── dart-fix-runtime-errors
├── dart-generate-test-mocks
├── dart-migrate-to-checks-package
├── dart-resolve-package-conflicts
├── dart-run-static-analysis
├── dart-setup-ffi-assets
├── dart-use-ffigen
├── dart-use-pattern-matching
├── dart-use-primary-constructors
├── effective-dart
├── flutter-add-integration-test
├── flutter-add-widget-preview
├── flutter-add-widget-test
├── flutter-apply-architecture-best-practices
├── flutter-build-responsive-layout
├── flutter-fix-layout-issues
├── flutter-implement-json-serialization
├── flutter-setup-declarative-routing
├── flutter-setup-localization
└── flutter-use-http-package

## Tooling
- Flutter/Dart are **not installed globally**. Use `fvm flutter ...` / `fvm dart ...` (version pinned in `.fvmrc`, SDKs live in `~/fvm/versions/`). If fvm is missing, run `.plan/00-environment-setup.md` first.
- MCP servers are configured in the project `opencode.json`: `dart` (official Dart/Flutter MCP via `fvm dart mcp-server`) and `mobile-mcp` (simulator/emulator control).
- Execution plans for the next agent live in `.plan/` — work them in order.
- Task tracking: filament (`fl` CLI, data in `.fl/` — gitignored). Plan steps are mirrored as filament epics grouped under two `plan` entities (`env-setup`, `app-development`); use `fl task ready` to find the next unblocked epic.

# General development cycle
- clarify requirements if unclear
- write tests for the requirements
- write code that satisfies the tests (TDD style)
- bugs introduced should have a test written for them and then fixed

## Resolved Defaults (PRD §8)
- **Units**: Metric primary; imperial conversions only in expanded detail sections.
- **Grouping thresholds**: 90/60 min constants (see Photo Grouping Logic above).
- **Marine life photos**: picked **from the dive's attached photos only**, never fresh from the gallery.

## Starting Prompt for New Sessions
If starting a fresh session, review the `PRD.md` file in the root directory first. 