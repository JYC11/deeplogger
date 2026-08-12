# Plan 02 — Feedback Remediation

> **STATUS: REVIEWED (round 1 applied)** — ready for task creation.
> Source: `docs/feedback.md` (2026-08-10 engineer notes, 2026-08-12 user field notes) + full codebase review.
> Prerequisite: Plan 01 (MVP) complete. All work gated by `fvm dart format . && fvm flutter analyze && fvm flutter test` after each phase.
>
> **Review round 1 outcomes (locked):** full Riverpod form refactor stays in scope; D-GROUP span-cap reading confirmed (AGENTS.md algorithm paragraph to be rewritten to match, I4); G3 (relative photo paths) + F4 (structure moves) deferred; gear categories are constant-only, no seed rows (A3 rewritten); SAC calculator ownership added to D1; ad-hoc gear read path added to D5/B2.

---

## Locked Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| D-GROUP | **Two-threshold grouping with 90-min cluster-span cap.** For each photo after the first: `gap > 90` → new cluster; `60 < gap ≤ 90` → extend iff `newSpan ≤ 90`, else new cluster; `gap ≤ 60` → always extend. | Honors both PRD constants; 90 is a hard span ceiling, 60 is a soft break for long sparse clusters. |
| D-PHOTO | **Draft photos copied at "Complete draft" time.** Gallery scan preserves photos as `ScannedPhoto` values (`{ DateTime takenAt; Future<File?> Function() resolveFile; }`) — a value-type seam wrapping `AssetEntity.originFile`, since `AssetEntity` has no public constructor and cannot be mocked or cross isolates. On Complete, copy cluster photos to app dir + insert `DivePhoto` rows. Discard copies nothing. | Avoids wasted I/O for discarded drafts; seam makes the pipeline unit-testable. |
| D-RIVER | **Refactor all forms to `Notifier`/`AsyncNotifier` providers** per AGENTS.md. Replace `ConsumerStatefulWidget` + manual controllers. | Aligns with project conventions; eliminates the edit-gear data-loss bug. |
| D-MIG | **Custom migration manager: `.sql` files in `assets/migrations/`, `schema_version` table, transactional, idempotent (`IF NOT EXISTS`), backward compatible.** | No new deps; full control; satisfies feedback.md:8-9. |
| D-ICON | **`flutter_launcher_icons` pipeline + placeholder asset now.** Swap real asset later by replacing one file. | Non-Flutter-default icon immediately; designer swaps later. |
| D-TANK | **Tank volume: two new DB columns `tank_volume_value REAL` + `tank_volume_unit TEXT` (`'L'|'cu_ft'`).** Legacy `tank_size` text kept for back-compat; SAC calc reads new columns, falls back to parsing `tank_size` for old rows. | Locked in clarification round. |
| D-UNITS | **Full per-field unit dropdowns on all unit-bearing inputs** (depth, pressure, temp, weight, visibility, tank volume). Storage stays **metric-canonical** for existing fields (convert on save, convert back on load using a per-field unit preference). Tank volume is the exception (stores value + unit per D-TANK). | Satisfies feedback.md:13-14; keeps DB clean; matches AGENTS.md "metric primary." |
| D-GEAR | **Both reusable `GearItem` creation AND free-text per-dive gear entry.** `dive_log_gear` gets a nullable `gear_text` column; a row has either `gear_item_id` (master list) or `gear_text` (ad-hoc). Free-text entries can be promoted to real `GearItem`s. | feedback.md:35; avoids polluting master list with throwaway rows. |
| D-THUMB | **Thumbnails are filesystem-only.** Path derived from photo id (`thumbnails/{photoId}.jpg`); no DB column. Lazy-generate on first display if file missing. | Avoids migration; simple cache invalidation by file existence. |

---

## Phase A — Data layer foundation (no UI; gates everything)

> **Active development — destructive migration OK.** The first migration is the complete schema with all new columns. No backward-compat v1→v2 logic needed now; the migration manager exists for future non-destructive migrations.

### A1. Migration manager + complete schema
**Files:** `lib/database/migration_runner.dart` (new), `lib/database/database_helper.dart` (refactor `:20,141-143`), `assets/migrations/001__init.sql` (new)

- Extract current `onCreate` DDL (`database_helper.dart:63-137`) into `001__init.sql` **with all new columns folded in directly** (no separate v2 file):
  ```sql
  CREATE TABLE IF NOT EXISTS dive_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    start_time INTEGER NOT NULL,     -- NOT NULL: D3 adds a required-start-time validator
    end_time INTEGER,
    location TEXT,
    altitude TEXT,                   -- defaults live in the form (D4); toMap() writes explicit
    max_depth_m REAL,                -- NULLs, so SQL DEFAULT clauses would never fire
    avg_depth_m REAL,
    duration_min REAL,               -- stays REAL (model is double?); no type change
    gas_type TEXT,
    gas_other TEXT,
    tank_size TEXT,                  -- legacy; kept for back-compat reads
    tank_volume_value REAL,          -- NEW (D-TANK)
    tank_volume_unit TEXT,           -- NEW ('L' | 'cu_ft')
    start_pressure_bar REAL,
    end_pressure_bar REAL,
    water_temp_c REAL,
    salinity TEXT,
    visibility_m REAL,
    weight_kg REAL,
    notes TEXT,
    is_draft INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  );

  CREATE TABLE IF NOT EXISTS dive_photos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    dive_log_id INTEGER NOT NULL,
    local_path TEXT NOT NULL,
    taken_at INTEGER,
    FOREIGN KEY (dive_log_id) REFERENCES dive_logs(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS sightings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    dive_log_id INTEGER NOT NULL,
    dive_photo_id INTEGER,
    common_name TEXT NOT NULL,
    FOREIGN KEY (dive_log_id) REFERENCES dive_logs(id) ON DELETE CASCADE,
    FOREIGN KEY (dive_photo_id) REFERENCES dive_photos(id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS certifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    org TEXT NOT NULL,
    level TEXT NOT NULL,
    cert_id TEXT,                    -- NEW (feedback.md:39)
    issue_date INTEGER,
    photo_path TEXT
  );

  CREATE TABLE IF NOT EXISTS gear_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    type_notes TEXT,
    category TEXT                    -- NEW (feedback.md:23-33)
  );

  CREATE TABLE IF NOT EXISTS dive_log_gear (
    id INTEGER PRIMARY KEY AUTOINCREMENT,   -- NEW surrogate PK (D-GEAR)
    dive_log_id INTEGER NOT NULL,
    gear_item_id INTEGER,           -- nullable for ad-hoc gear_text rows
    gear_text TEXT,                 -- NEW (D-GEAR) ad-hoc gear name
    FOREIGN KEY (dive_log_id) REFERENCES dive_logs(id) ON DELETE CASCADE,
    FOREIGN KEY (gear_item_id) REFERENCES gear_items(id) ON DELETE CASCADE
  );
  CREATE UNIQUE INDEX IF NOT EXISTS idx_log_gear_pair
    ON dive_log_gear(dive_log_id, gear_item_id) WHERE gear_item_id IS NOT NULL;

  -- Indexes (review §1.5)
  CREATE INDEX IF NOT EXISTS idx_photos_log ON dive_photos(dive_log_id);
  CREATE INDEX IF NOT EXISTS idx_sightings_log ON sightings(dive_log_id);
  CREATE INDEX IF NOT EXISTS idx_sightings_photo ON sightings(dive_photo_id);
  CREATE INDEX IF NOT EXISTS idx_logs_start ON dive_logs(start_time);
  CREATE INDEX IF NOT EXISTS idx_certs_org ON certifications(org, issue_date);
  ```
- Implement `MigrationRunner`:
  - Creates `schema_version(version INTEGER PRIMARY KEY, applied_at TEXT NOT NULL)` meta table on first open.
  - Reads all `.sql` files from `assets/migrations/`, sorts by numeric prefix.
  - `onCreate`: runs all files in order inside a single transaction.
  - `onUpgrade`: runs files `old+1..new` in order, each in its own transaction.
  - All DDL uses `IF NOT EXISTS` for idempotency.
  - Rejects downgrade (throws on `old > new`).
- `database_helper.dart` `_version` = `1` (the single init migration); `onUpgrade` delegates to `MigrationRunner` (empty for now; future migrations append `002__*.sql` etc.).
- Register `assets/migrations/` in `pubspec.yaml` `flutter.assets`.
- **`dive_log_gear` now has a surrogate `id` PK** (per D-GEAR) so multiple ad-hoc `gear_text` rows per dive are allowed (NULL `gear_item_id`). A partial unique index prevents duplicate `(log, gear_item_id)` pairs for real gear items only.

**Tests** (`test/database/migration_runner_test.dart`):
- Fresh DB reaches v1; `schema_version` has row [1].
- All tables + columns + indexes present after init.
- No-op rerun (open at v1, no changes).
- Downgrade rejection: set `PRAGMA user_version = 2`, open with `version: 1` → throws (sqflite's default `onDowngrade` already throws; the runner's `old > new` check is defense-in-depth). **Note:** "version 0 → open at 1" is an *upgrade* that re-runs `001` idempotently and succeeds — it is NOT a downgrade test.
- Idempotency: run `001__init.sql` twice, no error.

### A2. Model updates
**Files:** `lib/models/dive_log.dart`, `lib/models/gear_item.dart`, `lib/models/certification.dart`, `lib/models/dive_photo.dart`

- `DiveLog`: add `tankVolumeValue: double?`, `tankVolumeUnit: String?`. Update `copyWith`/`toMap`/`fromMap` (`:52-158`).
- `GearItem`: add `category: String?`. Update `copyWith`/`toMap`/`fromMap`.
- `Certification`: add `certId: String?`. Update `copyWith`/`toMap`/`fromMap`.
- `DivePhoto`: no DB column changes (thumbnails filesystem-only per D-THUMB).
- **Fix `copyWith` clear-to-null gotcha on ALL models:** current pattern `field ?? this.field` makes it impossible to explicitly set a field to `null`. Use the sentinel pattern:
  ```dart
  static const _unset = Object();
  DiveLog copyWith({..., Object? field = _unset, ...}) {
    return DiveLog(..., field: field == _unset ? this.field : field as X?, ...);
  }
  ```
  Apply to every nullable field on every model.

**Tests:** update existing model tests to cover new fields + clear-to-null.

### A3. Default gear categories (constant-only, no seeding)
**File:** `lib/models/gear_item.dart` (or `lib/services/gear_categories.dart`)

- Define `kDefaultGearCategories` constant list: `['BCD', 'Wetsuit', 'Fins', 'Dive Computer', 'Torch', 'Regulator', 'Regulator – First Stage', 'Regulator – Second Stage', 'Other']`.
- **No DB seeding.** Review round 1: feedback.md asks for default *categories* (a taxonomy), not default gear. Seed rows would appear as phantom gear the user doesn't own — selectable in every dive form, deletable (breaking the defaults), and mixed with real items. The constant alone drives the category dropdown in the add/edit gear dialog (D6).
- Regulator subcategories are **flattened** to three top-level categories (`Regulator`, `Regulator – First Stage`, `Regulator – Second Stage`) — locks the previously deferred modeling decision; no parent/child column.
- `seed_defaults.dart` and the `main.dart` startup hook are **dropped** from the plan.

**Tests:** none needed for a constant (covered indirectly by D6 gear-dialog widget tests).

---

## Phase B — DB query layer (pagination / search / sort / N+1)

### B1. Paginated query methods
**File:** `lib/database/database_helper.dart`

- `getDiveLogs({int limit = 20, int offset = 0, String? search, String sortField = 'start_time', bool sortDesc = true, bool includeDrafts = false})` → `(List<DiveLog>, bool hasMore)`
  - Replace `getAllDiveLogs` (`:162-170`).
  - `search` → `WHERE location LIKE ? OR notes LIKE ?`.
  - `includeDrafts` → `WHERE is_draft = 0` (or omit). Moves the in-Dart filter (`:166-168`) into SQL.
  - `sortField` validated against a whitelist enum `DiveLogSortField { startTime, location, maxDepthM, durationMin }` to prevent SQL injection in ORDER BY.
  - `hasMore` = `COUNT(*)` with same WHERE > `offset + limit`.
- `getCertifications({limit, offset, search, sortField, sortDesc})` — replace `getAllCertifications` (`:242-249`).
- `getGearItems({limit, offset, search, category, sortField, sortDesc})` — replace `getAllGearItems` (`:265-269`). Add `category` filter.
- `getDivePhotosForLog(diveLogId, {int limit = 200})` — add limit to `:193-202`.
- `getSightingsForLog(diveLogId, {int limit = 200})` — add limit to `:218-226`.

### B2. Detail-screen combined query
**File:** `lib/database/database_helper.dart`

- `getDiveDetail(int id)` → `DiveDetail?` (log + photos + sightings + gear in one round trip).
  - Query the log row, then photos, sightings, gear in parallel via `Future.wait` within the same DB handle (sqflite serializes internally, but this collapses 4 provider watches into 1).
  - Or: single `rawQuery` with JOINs returning a flat row set, then assemble in Dart. Prefer the parallel-queries approach for simplicity.
  - **Gear uses the mixed read path** (review round 1): `getGearEntriesForDive(diveLogId)` returns `List<GearRef>` where `GearRef` is a sealed type — `GearRef.item(GearItem)` for master-list rows, `GearRef.adHoc(String)` for `gear_text` rows. A plain `INNER JOIN gear_items` would silently drop ad-hoc rows (`gear_item_id IS NULL`). Keep `getGearForDive` for legacy call sites or migrate them.
- Collapses the 4 sequential provider watches in `dive_detail_screen.dart:22,96,302-303`.

**Tests:** update `database_helper_test.dart` — add pagination, search, sort, hasMore, combined detail.

---

## Phase C — State management refactor (per D-RIVER)

### C1. AutoDispose
**File:** `lib/providers/dive_providers.dart`

- Add `.autoDispose` to: `diveDetailProvider` (`:22-27`), `diveGearProvider` (`:35-40`), `divePhotosProvider` (`:43-48`), `sightingsProvider` (`:51-56`).
- If B2's `getDiveDetail` replaces these, fold them into a single `diveDetailProvider` (autoDispose) returning `DiveDetail`.

### C2. Form Notifiers
**Files:** `lib/providers/dive_form_provider.dart` (new), `lib/providers/gear_form_provider.dart` (new), `lib/providers/certification_form_provider.dart` (new), `lib/providers/sighting_form_provider.dart` (new)

- `DiveFormNotifier extends FamilyAsyncNotifier<DiveFormState, int?>` (param = existing log id or null for new):
  - `DiveFormState`: all field values + validation errors + `isSaving` + `unitPreferences` (per-field unit selection for D-UNITS).
  - `build(id)`: if `id != null`, load existing log + `getGearEntriesForDive` (B2's mixed read path) into state (**fixes the edit-gear data-loss bug** at `dive_form_screen.dart:36,321-323`).
  - `save()`: validate → insert/update + `setGearForDive` → wrap in try-catch → set error state on failure.
  - `setField(name, value)`, `setUnitPreference(field, unit)`, `addAdHocGear(text)`, `promoteAdHocGear(text)`, `toggleGear(itemId)`.
- `GearFormNotifier`, `CertificationFormNotifier`, `SightingFormNotifier`: same pattern, smaller state.
- Screens become thin: `ConsumerWidget` that watches the notifier and dispatches actions. No `TextEditingController` management in widgets.

### C3. List Notifiers (pagination state)
**Files:** `lib/providers/dive_list_provider.dart` (new), replaces `diveListProvider` in `dive_providers.dart:17-19`

- `DiveListNotifier extends AsyncNotifier<DiveListState>`:
  - `DiveListState`: `logs: List<DiveLog>`, `page: int`, `hasMore: bool`, `search: String?`, `sortField`, `sortDesc`, `isLoadingMore: bool`.
  - `build()`: initial load (page 0).
  - `loadMore()`: append next page.
  - `setSearch(query)`: reset to page 0 with new search.
  - `setSort(field, desc)`: reset to page 0 with new sort.
  - `refresh()`: invalidate and reload.
- Same pattern for `GearListNotifier`, `CertificationListNotifier`.

**Tests:** `test/providers/` — `sacProvider` (logic-heavy, currently untested per review §8.5), `diveListProvider` loadMore/search/sort, `diveFormProvider` save + validation + gear pre-load.

---

## Phase D — Forms & input UX

### D1. Tank volume split input
**File:** `dive_form_screen.dart:176-181` (via `DiveFormNotifier`)

- Number field (`TextFormField` keyboardType=number) + units dropdown (`DropdownButton` with `['L', 'cu ft']`).
- Persists to `tankVolumeValue` + `tankVolumeUnit` (per D-TANK).
- Drop the free-text `tankSize` field from new dives; keep `tankSize` column for back-compat (SAC calc falls back).
- **SAC calculator ownership (review round 1 — this was the plan's biggest gap):** without these changes, every new dive has `tankSize == null` and SAC shows "tank volume unknown" forever.
  - `sac_calculator.dart`: `computeSac` gains optional `tankVolumeValue`/`tankVolumeUnit` params; structured value wins when present (`cu_ft` → L via the existing `× 28.3168 / 207` assumption), else falls back to `parseTankVolumeLiters(tankSize)` for legacy rows.
  - `dive_providers.dart:66-80`: `sacProvider` passes the structured fields from `DiveLog`.
  - I2's `sacProvider` tests must cover the structured path, the legacy fallback, and structured-wins precedence.

### D2. Full per-field unit dropdowns (per D-UNITS)
**Files:** `dive_form_screen.dart` (via `DiveFormNotifier`), `lib/services/unit_converter.dart` (new)

- Fields with unit dropdowns: `maxDepthM`, `avgDepthM`, `startPressureBar`, `endPressureBar`, `waterTempC`, `weightKg`, `visibilityM`, `tankVolumeValue`.
- Each field gets a row: `[number input] [unit dropdown]`.
- **Storage is metric-canonical:** on save, convert entered value → metric → store in existing column. On load (edit), convert metric → selected unit for display.
- Unit options per field:
  - Depth: `m | ft` (1 m = 3.28084 ft)
  - Pressure: `bar | psi` (1 bar = 14.5038 psi)
  - Temp: `°C | °F` (C→F = C×9/5+32)
  - Weight: `kg | lbs` (1 kg = 2.20462 lbs)
  - Visibility: `m | ft`
  - Tank volume: `L | cu ft` (per D-TANK, stored as entered — exception)
- `UnitConverter` service: `toMetric(field, value, unit)` and `fromMetric(field, metricValue, unit)`.
- Per-field unit preference saved in `SharedPreferences` (lightweight, not per-dive); defaults to metric. **New dependency:** add `flutter pub add shared_preferences` as the first step of this task (not currently in `pubspec.yaml`).
- **Rounding:** display converted values to field-appropriate precision (depth 1 decimal, temp 1 decimal, etc.) to minimize float-rounding artifacts on edit round-trip.

### D3. Input validation
**File:** `dive_form_screen.dart` (via `DiveFormNotifier`)

- Add validators with **visible error messages** (currently only `location` and `gasOther` have validators per review §5.2):
  - `startTime`: **required** (review round 1 — A1 makes the column `NOT NULL`; without this validator, save-without-start-time is a SQLite constraint crash).
  - `location`: required (exists).
  - `maxDepthM`: > 0, ≤ 300.
  - `avgDepthM`: > 0, ≤ `maxDepthM`.
  - `durationMin`: > 0, ≤ 600.
  - `startPressureBar`: > 0, ≤ 400.
  - `endPressureBar`: ≥ 0, < `startPressureBar`.
  - `waterTempC`: −5 to 40.
  - `weightKg`: ≥ 0, ≤ 50.
  - `visibilityM`: ≥ 0, ≤ 100.
  - `tankVolumeValue`: > 0 (if provided).
- `try-catch` around `_save` (`:288-326`); show error via `SnackBar`; clear `isSaving` on failure.
- Sighting add dialog (`dive_detail_screen.dart:412-413`): replace silent `return` on empty name with visible error.
- Cert form: `org` + `level` required (exists); `certId` optional.

### D4. Default values
**File:** `dive_form_screen.dart:47,75` (via `DiveFormNotifier`)

- Altitude: init `"Sea Level (0m)"` for new dives (feedback.md:21).
- Gas type: init `'Air'` for new dives (feedback.md:22). Dropdown shows default selection.

### D5. Ad-hoc gear on a dive log (per D-GEAR)
**Files:** `dive_form_screen.dart:224-233,348-380` (via `DiveFormNotifier`), `database_helper.dart`

- `_GearSelector` gets:
  1. Existing multi-select from master gear list (FilterChips).
  2. "+ Add ad-hoc gear" button → free-text name input → inserts a `dive_log_gear` row with `gear_text`, `gear_item_id = NULL`.
  3. "Promote to gear list" action on ad-hoc entries → creates a `GearItem` + updates the `dive_log_gear` row to reference it.
- `setGearForDive` must handle both `gear_item_id` rows and `gear_text` rows: delete all existing, insert new mixed set.
- **Read path (review round 1):** the form preloads via `getGearEntriesForDive` (B2's `GearRef` sealed type) — not `getGearForDive`, whose `INNER JOIN` drops ad-hoc rows. The detail screen renders both variants (ad-hoc shown distinctly, e.g. italic).
- Display ad-hoc gear distinctly in the selector (e.g., italic or chip color).

### D6. Gear list screen
**File:** `gear_list_screen.dart`

- Add `category` field to add dialog — dropdown options from `kDefaultGearCategories` (A3, constant-only); add category filter dropdown; add sort by name/category.
- Add **edit** (PRD §5.6 CRUD; currently only add+delete per review §5.5).
- Show category badge on each gear tile.
- Use `GearListNotifier` + `GearFormNotifier` from Phase C.

### D7. Certifications screen
**File:** `certifications_screen.dart:81-135`

- Add `certId` (ID#) field to form (feedback.md:39).
- Add **photo picker** — `Certification.photoPath` exists in model/DB but UI never exposes it (review §5.6). Copy cert image to app dir via `ImageStore`.
- Add **issue date picker** — `issueDate` is always null in UI (review §5.6).
- Add **edit** (currently only add+delete).
- Display cert photo thumbnail in the list.
- Pagination/search/sort via `CertificationListNotifier`.

### D8. Sighting add/edit
**File:** `dive_detail_screen.dart:368-433`

- Visible empty-name error (replace `:412-413` silent return).
- Add **edit** (PRD §5.4 CRUD; currently add+delete only per review §5.3).
- Use `SightingFormNotifier` from Phase C.

---

## Phase E — Photo pipeline fixes

### E1. Grouping algorithm (per D-GROUP)
**Files:** `lib/services/dive_grouper.dart:28-35`, `test/services/dive_grouper_test.dart:29-38`

- Implement:
  ```
  for each photo after first:
    gap = p.time - prev.time
    newSpan = p.time - cluster.first.time
    if gap > 90:          new cluster
    elif 60 < gap <= 90:  if newSpan <= 90: extend else new cluster
    else (gap <= 60):     extend
  ```
- Use `kMaxIntraDiveGap` (currently dead code at `:4`).
- Update tests: 75-min gap with span ≤ 90 → 1 cluster; 75-min gap with span > 90 → 2 clusters. Add span-cap edge cases (e.g., cluster spanning 85 min, then 70-min gap → newSpan = 155 > 90 → break).

### E2. Draft photo attachment (per D-PHOTO)
**Files:** `lib/services/gallery_scanner.dart:51-78`, `lib/screens/scan_gallery_screen.dart:153-165`

- `scanGalleryTimestamps` returns `List<ScanResult>` where `ScanResult` = `ScannedPhoto { DateTime takenAt; Future<File?> Function() resolveFile; }` (per D-PHOTO). Currently returns `List<DateTime>` and discards the asset. **Do not hold `AssetEntity` in `ScanResult`** — it has no public constructor (unmockable in E5 tests) and can't cross isolates.
- `DiveGrouper.groupAndCreateDrafts` operates on `List<ScannedPhoto>`; `DraftDive` carries `List<ScannedPhoto>` per cluster.
- On "Complete draft": copy all cluster photos to app dir via `ImageStore.copyToAppDir`, insert `DivePhoto` rows for the new dive. On "Discard": nothing copied.
- **Partial-failure policy (review round 1):** a deleted/unreadable source photo must not abort the whole Complete. Skip-and-count: copy what's readable, insert rows for successes only, show a `SnackBar` ("3 of 5 photos attached") if any were skipped. All-or-nothing is overkill for a draft flow.
- `scan_gallery_screen.dart` `_drafts` holds `DraftDive` (with `ScannedPhoto`s); `_completeDraft` does the copy + insert.

**Tests:** `test/services/gallery_scanner_test.dart` (new) — construct fake `ScannedPhoto`s directly (the value-type seam makes this trivial; no `AssetEntity` mocking needed); complete-draft copies N photos + creates N `DivePhoto` rows; discard copies 0; partial failure (one `resolveFile` returns null) → N−1 rows + skip reported.

### E3. Compression + thumbnails (per D-THUMB)
**Files:** `lib/services/image_store.dart:19-49,55-86`

- `copyToAppDir`: compress on copy — max dimension ~1600px, JPEG quality ~85, via `compute()` (off UI isolate). Currently copies full-resolution (review §4.4).
- `createThumbnail`: fix width-only resize bug (`:66` `width: maxSize` should constrain both dimensions); run via `compute()`. Generate lazily: path = `thumbnails/{photoId}.jpg`; if file doesn't exist on display, generate it.
- No `thumbnail_path` DB column (per D-THUMB). Display sites check file existence and fall back to full image if missing.
- Fix error wrapping (`:46-48,83-85`): preserve stack traces via `Error.throwWithStackTrace`.

**Tests:** `test/services/image_store_test.dart` (new) — copy+compress (check output file size < source), thumbnail dimensions, dedup guard, missing-source error, stack trace preservation.

### E4. iOS permission downgrade
**File:** `lib/services/gallery_scanner.dart:17`

- Change `IosAccessLevel.readWrite` → `IosAccessLevel.readOnly` (review §4.3, §9.3).
- Verify `photo_manager` readOnly flow works for scanning (no write APIs called anywhere).

### E5. Photo upload tests
**File:** `test/services/` (new files)

- `image_store_test.dart`: copy, dedup, missing source, compression, thumbnail generation + dimensions, stack trace.
- `gallery_scanner_test.dart`: timestamp extraction (fake `ScannedPhoto`s with scripted `resolveFile`), `scanGalleryTimestamps` returns `ScannedPhoto` values with working file resolvers.
- Complete-draft flow test: N photos copied + N `DivePhoto` rows created; partial-failure case (E2): unreadable source skipped, count surfaced.

---

## Phase F — UI completeness

### F1. Dive detail Photos section
**File:** `lib/screens/dive_detail_screen.dart`

- Currently photos only show as sighting avatars (`:343-348`); no "Photos" section exists (review §5.3).
- Add a photo grid section showing the dive's attached photos.
- Use thumbnails (E3) with `cacheWidth`/`cacheHeight` hints.
- `errorBuilder` on all `Image.file` for deleted-file resilience.

### F2. List pagination/search/sort UI
**Files:** `lib/screens/dive_list_screen.dart`, `lib/screens/gear_list_screen.dart`, `lib/screens/certifications_screen.dart`

- Infinite scroll: `ScrollController` detects near-bottom → `listNotifier.loadMore()`.
- AppBar search field → `listNotifier.setSearch()`.
- Sort toggle button (asc/desc icon) + sort-field dropdown → `listNotifier.setSort()`.
- Replace `ref.invalidate(diveListProvider)` on navigation return (`dive_list_screen.dart:32,76,139`) with `listNotifier.refresh()` (keeps search/sort state).

### F3. Verify `Icons.scuba_diving`
**File:** `lib/screens/dive_list_screen.dart:126`

- Run `fvm flutter run` and check if `Icons.scuba_diving` renders or throws. If invalid, replace with `Icons.pool` or `Icons.water`.

(Former F4 "Structure & shared helpers" deferred — see Out of scope. The `formatSac` dedup and gas/salinity label helpers are folded into the phases that touch those files: D-phase form work extracts labels; F1 touches `share_card.dart`'s display counterpart.)

---

## Phase G — Performance & security

### G1. Parallelize EXIF reads
**File:** `lib/services/gallery_scanner.dart:69-74`

- Current: sequential `for` loop with `await` per asset. Parallelize correctly (review round 1): `AssetEntity` is a platform-channel handle and **cannot cross isolates** — so `originFile` fetches are parallelized with chunked `Future.wait` (e.g. 8–16 at a time) on the platform thread; `compute()` is used only for the pure-Dart EXIF parse on already-fetched bytes.
- Perf gate: 1,000 photos < 3 s (NFR-2). Write a benchmark test or manual stopwatch verification.

### G2. Temp file cleanup
**File:** `lib/services/share_card.dart:311-314`

- Delete the shared PNG from `getTemporaryDirectory()` after `SharePlus.instance.share` completes (in `finally` block).

### G3. Error-handling audit
**Files:** `dive_form_screen.dart:288-326`, `dive_detail_screen.dart:33-53` (share), `dive_detail_screen.dart:412-425` (sighting add), `image_store.dart:46-48,83-85`

- `try-catch` on all DB/File I/O with user-visible error feedback.
- `image_store.dart`: replace generic `Exception('Failed to: $e')` with `Error.throwWithStackTrace` to preserve stack traces.
- Share button (`dive_detail_screen.dart:33-53`): wrap in try-catch; show SnackBar on failure.

### G4. Security & performance analysis document
**File:** `docs/security-performance-analysis.md` (new, per feedback.md:11)

- **Security:** SQL injection (clean — parameterized), file storage (app sandbox, OK), hardcoded secrets (none), DB encryption (none; note SQLCipher recommendation if certs deemed sensitive), input sanitization (parameterized queries handle it).
- **Performance:** unbounded queries (addressed by B1), in-Dart draft filter (moved to SQL in B1), sequential EXIF (addressed by G1), UI-isolate image decode (addressed by E3 `compute()`), thumbnail memory (addressed by E3 + `cacheWidth`), full table scan on invalidate (addressed by C3 `refresh`).

---

## Phase H — App icon & branding (per D-ICON)

### H1. flutter_launcher_icons pipeline
**Files:** `pubspec.yaml`, `flutter_launcher_icons.yaml` (new), `assets/icon_placeholder.png` (new)

- Add `flutter_launcher_icons` to `dev_dependencies`.
- Create `flutter_launcher_icons.yaml`:
  ```yaml
  flutter_launcher_icons:
    android: true
    ios: true
    image_path: "assets/icon_placeholder.png"
    adaptive_icon_background: "#00838F"
    adaptive_icon_foreground: "assets/icon_placeholder.png"
    min_sdk_android: 23
  ```
- Generate a simple placeholder PNG (1024×1024, teal background, "DL" monogram or dive-themed silhouette) — any non-Flutter-default image.
- Run `fvm dart run flutter_launcher_icons`.
- Replaces default Flutter logo on both platforms (review §12). Adaptive icon for Android 8+.
- When a designer delivers: replace `assets/icon_placeholder.png`, rerun the generator. One-file swap.

---

## Phase I — Tests & analysis config

### I1. Lint rules
**File:** `analysis_options.yaml`

- Enable: `require_trailing_commas`, `avoid_print`, `unawaited_futures`, `prefer_single_quotes`.
- Run `fvm dart fix --apply` after enabling.

### I2. Provider tests
**File:** `test/providers/dive_providers_test.dart` (expand from 37 lines)

- `sacProvider` — the most logic-heavy provider, currently untested (review §8.5). Test all `computeSac` paths via the provider.
- `diveDetailProvider` — loads combined detail.
- `diveListProvider` (or `DiveListNotifier`) — `loadMore`, `setSearch`, `setSort`, `refresh` keeping search/sort state.

### I3. Widget tests
**File:** `test/widget_test.dart` (expand from 97 lines)

- List → detail navigation.
- Form submission flow (fill fields → save → detail shows data).
- Validation error display (empty required field → visible error).
- Gear/cert navigation from popup menu.
- Scan-gallery navigation.

### I4. AGENTS.md update (review round 1 — required)

- Rewrite the **Photo Grouping Logic** paragraph to state D-GROUP's two-threshold span-cap semantics precisely (replaces the self-contradictory "extend ≤ 90 / > 60 breaks" text).
- Document: `assets/migrations/` + MigrationRunner conventions (how to add `002__*.sql`), the form-notifier pattern (C2 replaces `ConsumerStatefulWidget` forms), `kDefaultGearCategories` (constant-only, no seeding), `ScannedPhoto` seam, `GearRef` sealed type, `UnitConverter` + metric-canonical storage rule.
- Add `shared_preferences` and `flutter_launcher_icons` to the tech-stack list.

---

## Dependency Graph

```
A1 (migrations+schema) ──→ A2 (models)        (A3 is a constant — no deps)
       │
       └─→ B1 (queries) ──→ B2 (detail query + GearRef read path)
                            │
C1 (autoDispose) ──────────┤
C2 (form notifiers) ───────┴─→ D1-D8 (forms UX; D1 includes SAC calc update)
C3 (list notifiers) ────────→ F2 (list UI)

E1 (grouping) ←─ independent
E2 (draft photos) ←─ depends on E3 (compression)
E3 (compression) ←─ independent
E4 (iOS perm) ←─ independent
E5 (photo tests) ←─ depends on E2, E3

F1 (photos section) ←─ depends on E3 (thumbnails)
F3 (icon check) ←─ independent

G1-G4 ←─ depends on B1, E3, C3
H1 (app icon) ←─ independent
I1-I4 ←─ ongoing (I4 last — documents final state)
```

**Critical path:** A1 → A2 → B1 → C2 → D1-D8.
**Parallel tracks:** E1/E3/E4 (photo pipeline), F3 (icon check), H1 (icon), I1 (lints) can proceed independently.

---

## Out of scope / deferred
- **DB encryption (SQLCipher):** noted in G4 analysis doc; not implemented.
- **Real app icon asset:** placeholder until designer delivers (H1).
- **Camera capture, location, dive-computer integration:** out per AGENTS.md.
- **l10n beyond `intl` plumbing:** deferred from Plan 01.
- **Firebase App Distribution:** deferred from Plan 01.
- **Relative photo paths (was G3):** deferred in review round 1 — its migration rationale ("convert existing absolute paths") contradicts the destructive-dev stance (no existing installs). Revisit before public release for iOS restore robustness.
- **Structure & shared-helper moves (was F4):** deferred in review round 1 — cosmetic file moves (`share_card.dart` → `widgets/`, generic form-dialog extraction) add rebase churn mid-refactor for no behavior gain. Small dedups (formatSac, gas/salinity labels) are folded into the phases touching those files.
