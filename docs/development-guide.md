# DeepLogger — Development Guide

This document covers the architecture, code conventions, testing strategy, and key business logic of DeepLogger. Read this before making changes to the codebase.

## Architecture overview

DeepLogger is an offline-first mobile app built with Flutter. All data is stored locally in SQLite — no cloud, no accounts, no network calls.

### Layered structure

```
lib/
├── main.dart                  # App entry point, ProviderScope, flutter_driver gate
├── models/                    # Immutable data classes (toMap/fromMap)
│   ├── dive_log.dart          #   Primary dive log entity (PRD §5.1)
│   ├── dive_photo.dart        #   Photo attached to a dive
│   ├── sighting.dart          #   Marine life sighting (links to a dive photo)
│   ├── certification.dart     #   Scuba certification card
│   └── gear_item.dart         #   Master equipment list item
├── database/
│   └── database_helper.dart   # Singleton SQLite wrapper, versioned schema, CRUD
├── providers/
│   └── dive_providers.dart    # Riverpod 3.x providers (FutureProvider, family, etc.)
├── services/                  # Pure business logic (no UI)
│   ├── sac_calculator.dart    #   SAC/RMV rate computation (PRD §5.2)
│   ├── dive_grouper.dart      #   Photo-to-dive clustering algorithm (PRD §5.3)
│   ├── gallery_scanner.dart   #   photo_manager + EXIF timestamp extraction
│   ├── image_store.dart       #   Copy/compress photos to app private dir
│   └── share_card.dart        #   Instagram export card widget + PNG capture
├── screens/                   # Full-page UI views
│   ├── dive_list_screen.dart  #   Home: dive list sorted by date desc
│   ├── dive_detail_screen.dart#   Detail: stats, SAC, expandable sections, sightings
│   ├── dive_form_screen.dart  #   Create/edit: all PRD §5.1 fields, gear multi-select
│   ├── scan_gallery_screen.dart#  Photo auto-log: scan → drafts → review
│   ├── gear_list_screen.dart  #   Master gear CRUD
│   └── certifications_screen.dart # Certifications grouped by org
└── widgets/                   # Reusable UI components (currently empty — add as needed)
```

### Data flow

```
UI (screens) → Riverpod providers → DatabaseHelper → SQLite
                   ↓
              Services (SAC, grouper, scanner) — pure logic, no DB
```

- **Screens** are `ConsumerWidget` or `ConsumerStatefulWidget`. They call `ref.watch(provider)` to read state and `ref.read(provider)` to trigger actions. No `BuildContext` lookups for state.
- **Providers** wrap `DatabaseHelper` calls and expose them as `FutureProvider` (for reads) or plain `Provider` (for computed values like SAC).
- **Services** contain pure business logic — no Flutter imports, no DB access. They are unit-tested in isolation.
- **Models** are immutable classes with `copyWith`, `toMap`, and `fromMap`. They do not contain logic.

## State management: Riverpod 3.x

We use `flutter_riverpod` 3.4.2 in classic (non-code-gen) style. No `@riverpod` annotations, no `build_runner`.

### Provider types used

| Provider type | When to use | Example |
|---|---|---|
| `FutureProvider` | One-shot async reads (DB queries) | `diveListProvider` — fetches all dives |
| `FutureProvider.family` | Parameterized async reads | `diveDetailProvider(id)` — fetch one dive |
| `Provider` | Sync computed values | `sacProvider(log)` — SAC from a DiveLog |
| `Provider` | Singleton access | `databaseProvider` — DatabaseHelper.instance |

### Key conventions

- **Watch for data, read for actions**: `ref.watch(provider)` in `build()` to rebuild when data changes; `ref.read(provider)` in callbacks to perform a one-shot action.
- **Invalidate after mutations**: after `insertDiveLog`/`updateDiveLog`/`deleteDiveLog`, call `ref.invalidate(diveListProvider)` to re-fetch.
- **`AsyncValue.when`**: use `.when(data:, loading:, error:)` to handle async states in the UI. This replaces hand-rolled loading/error enums.

### What we do NOT use

- `StateNotifierProvider` / `StateNotifier` — moved to `legacy/` in Riverpod 3.x. Use `NotifierProvider`+`Notifier` instead (not yet needed in this app — mutations go directly through `DatabaseHelper`).
- `ChangeNotifier` / `provider` package — considered and rejected in favor of Riverpod's compile-time safety and `AsyncValue` ergonomics.
- Code generation (`@riverpod` annotations) — avoided to keep the toolchain simple for an MVP.

## Database schema

Six tables in a single SQLite file (`deeplogger.db`), versioned at `version: 1`:

| Table | Purpose | Key columns |
|---|---|---|
| `dive_logs` | Dive entries (drafts + saved) | `start_time`, `end_time`, `location`, `max_depth_m`, `avg_depth_m`, `duration_min`, `gas_type`, `tank_size`, `start_pressure_bar`, `end_pressure_bar`, `is_draft` |
| `dive_photos` | Photos attached to dives | `dive_log_id` (FK CASCADE), `local_path`, `taken_at` |
| `sightings` | Marine life per dive | `dive_log_id` (FK CASCADE), `dive_photo_id` (FK SET NULL), `common_name` |
| `certifications` | Cert cards | `org`, `level`, `issue_date`, `photo_path` |
| `gear_items` | Master equipment list | `name`, `type_notes` |
| `dive_log_gear` | M2M: gear per dive | composite PK `(dive_log_id, gear_item_id)` |

Foreign keys are enforced via `PRAGMA foreign_keys = ON` in `onConfigure`. Cascade deletes work: deleting a dive log removes its photos and sightings automatically.

### Migrations

`DatabaseHelper.onUpgrade(db, oldVersion, newVersion)` is currently empty (we're at v1). When the schema changes:
1. Bump `_version` in `DatabaseHelper`.
2. Add migration code in `onUpgrade` (never modify `onCreate` for existing users).
3. Test the migration path: create a DB at the old version, open at the new version, verify data survives.

## Key business logic

### SAC rate (PRD §5.2)

File: `lib/services/sac_calculator.dart`

SAC (Surface Air Consumption) is computed dynamically from pressure/depth/duration/tank-size — it is **never stored** in the database.

Formula (industry-standard RMV):
```
P_rate = (Start_Bar - End_Bar) / (Duration_min × ((Avg_Depth_m / 10) + 1))   → bar/min
SAC    = P_rate × Tank_Volume_L                                              → L/min
```

Tank size parsing from free text:
- `"12L"` → 12.0 L (metric)
- `"80 cu ft"` → 80 × 28.3168 / 207 ≈ 10.9 L (imperial, assumes 207 bar service pressure)

Guard rails (return `null` — no SAC displayed):
- `Duration ≤ 0`
- `End_Pressure ≥ Start_Pressure`

Fallback: if tank volume is unparseable, returns `SacResult` with `barPerMin` only (no `litersPerMin`). The detail screen shows "Tank volume unknown — showing bar/min only".

### Photo grouping (PRD §5.3)

File: `lib/services/dive_grouper.dart`

Constants:
- `kMaxIntraDiveGap = 90 min` — max gap between consecutive photos in one dive
- `kMinInterDiveGap = 60 min` — gap that starts a new dive

Algorithm:
1. Sort timestamps ascending.
2. First photo starts a cluster.
3. Extend the cluster while gap-to-previous ≤ 60 min.
4. Any gap > 60 min starts a new cluster (so > 90 always does too).

This is a pure function over `List<DateTime>` — no I/O, no Flutter imports. Fully unit-tested.

### Image handling

Files: `lib/services/gallery_scanner.dart`, `lib/services/image_store.dart`

- Photos are **copied** into `getApplicationDocumentsDirectory()/dive_photos/` — never referenced from the gallery path. This prevents broken links when the user deletes the original.
- Thumbnails are generated via the `image` package (resize to 256px, JPEG quality 85).
- EXIF timestamp extraction priority: native `AssetEntity.createDateTime` (fast) → EXIF `DateTimeOriginal` → `DateTimeDigitized` → null.

## Testing strategy

### Test pyramid

```
Widget tests (UI with mocked providers)   ← test/widget_test.dart, test/services/share_card_test.dart
Unit tests (DB with in-memory SQLite)      ← test/database/database_helper_test.dart
Unit tests (pure logic)                    ← test/services/sac_calculator_test.dart, test/services/dive_grouper_test.dart
```

48 tests total. Run all: `fvm flutter test`.

### Database tests

File: `test/database/database_helper_test.dart`

Uses `sqflite_common_ffi` to run SQLite in-memory on the host machine (no simulator needed). Pattern:

```dart
setUpAll(() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;  // ← both lines required
});

setUp(() async {
  final db = DatabaseHelper.instance;
  final ffiDb = await openDatabase(
    inMemoryDatabasePath,
    version: 1,
    onConfigure: db.onConfigure,  // enables PRAGMA foreign_keys
    onCreate: db.onCreate,        // reuses the real schema
  );
  await db.useDatabaseForTesting(ffiDb);  // injects the in-memory DB
});
```

### Widget tests

File: `test/widget_test.dart`

Uses **provider overrides** instead of the real database. This avoids fake-async + Riverpod vsync scheduler conflicts (a gotcha — see filament lesson `gf9atdu6`).

Pattern:

```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      diveListProvider.overrideWith((ref) async => fakeDiveLogs),
    ],
    child: const DeepLoggerApp(),
  ),
);
await tester.pumpAndSettle();
```

The `Override` type is not exported from `flutter_riverpod` 3.x — inline overrides directly in `ProviderScope(overrides: [...])`.

### SAC / grouper tests

Pure unit tests — no Flutter, no DB, no mocking. Just call the function and assert the result. These are the fastest tests and should be the first line of defense when changing business logic.

## Development workflow

### Before you start coding

1. Check filament for context: `fl task ready` (next unblocked task), `fl lesson list` (gotchas from previous sessions).
2. Read the relevant PRD section and the corresponding skill in `.agents/skills/` if applicable.

### The gate (run after every change)

In this order — format before checks:

```bash
fvm dart format .
fvm flutter analyze
fvm flutter test
```

All three must pass before considering work done. This is non-negotiable.

### Adding a new feature

1. **Models**: if the feature needs new data, add/modify a model in `lib/models/`. Include `copyWith`, `toMap`, `fromMap`.
2. **Database**: if the model needs persistence, add a table to `onCreate` and CRUD methods to `DatabaseHelper`. Bump `_version` and add migration in `onUpgrade` if the table is new. Write DB tests.
3. **Services**: if the feature has business logic, put it in a pure function in `lib/services/`. Write unit tests first (TDD).
4. **Providers**: add Riverpod providers in `lib/providers/dive_providers.dart` to expose the new data/logic.
5. **Screens**: build the UI in `lib/screens/`. Use `ConsumerWidget`, `ref.watch` for data, `ref.read` for actions. Invalidate providers after mutations.
6. **Widget tests**: test the UI with provider overrides.

### Adding a new test

Tests mirror the `lib/` structure in `test/`:
- `lib/services/sac_calculator.dart` → `test/services/sac_calculator_test.dart`
- `lib/database/database_helper.dart` → `test/database/database_helper_test.dart`

Use `group()` for organization, `setUp()` for shared state, `test()` for individual cases.

### Commit conventions

Messages follow conventional commits:
- `feat:` new feature
- `fix:` bug fix
- `chore:` tooling, deps, config
- `docs:` documentation
- `test:` test-only changes

## File permission rules (platform)

### iOS (`ios/Runner/Info.plist`)

- `NSPhotoLibraryUsageDescription`: "DeepLogger groups your dive photos into draft log entries and stores copies inside the app."
- Deployment target: iOS 14.0

### Android (`android/app/src/main/AndroidManifest.xml`)

- `READ_MEDIA_IMAGES` (API 33+)
- `READ_EXTERNAL_STORAGE` with `maxSdkVersion="32"` (older Android)
- `minSdk = 23`

## Dependencies

| Package | Version | Purpose |
|---|---|---|
| `flutter_riverpod` | ^3.4.2 | State management (Riverpod 3.x) |
| `sqflite` | ^2.4.3 | Local SQLite database |
| `path` | ^1.9.1 | Path manipulation |
| `path_provider` | ^2.1.6 | App documents directory |
| `photo_manager` | ^3.12.0 | Gallery access + EXIF |
| `exif` | ^3.3.0 | EXIF tag parsing |
| `share_plus` | ^13.3.0 | Share sheet for Instagram export |
| `image` | ^4.9.1 | Image compression/thumbnails |
| `intl` | ^0.20.3 | Date formatting |

Dev dependencies: `flutter_lints`, `integration_test`, `flutter_driver`, `sqflite_common_ffi` (host-side DB tests).

## Key lessons (from filament)

1. **Riverpod 3.x widget tests use provider overrides, not real async deps** — the vsync-based ProviderScheduler doesn't flush in fake-async test environments. Override FutureProviders with `overrideWith((ref) async => testData)`.
2. **sqflite_common_ffi requires two setup lines** — `sqfliteFfiInit()` + `databaseFactory = databaseFactoryFfi`. One without the other fails silently.
3. **SQLite cascade deletes need `PRAGMA foreign_keys = ON`** — sqflite doesn't enable it by default. It's in `DatabaseHelper.onConfigure`.
4. **`DropdownButtonFormField.value` is deprecated** — use `initialValue` instead (Flutter 3.44+).
5. **`Override` type is not exported from flutter_riverpod 3.x** — inline overrides in `ProviderScope(overrides: [...])` directly.

Run `fl lesson list` to see all recorded lessons before starting a session.

## What's not done yet

- **Firebase App Distribution** — needs firebase CLI + a Google/Firebase project + Apple Developer account. Tracked as deferred in Plan 01.
- **Real-device testing** — needs an Apple Developer account (USB) or Android device with USB debugging.
- **Localization** — `intl` is included as a dependency but no `.arb` files or `gen-l10n` config yet. Strings are currently hardcoded in English.
- **Widget tests for detail/form/gear/cert screens** — only the list screen and share card have widget tests so far. The form and detail screens are verified via the M7 on-device smoke test but lack automated widget test coverage.
