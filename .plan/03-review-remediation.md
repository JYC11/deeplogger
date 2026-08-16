# Plan 03 — Review Remediation

> Source: full-codebase review (code quality / security / performance / dead code / spec conformance).
> Status: approved by user — scope = **all findings**. Build in progress.

## Locked Decisions
- Fix the ad-hoc gear chip duplicate bug (only broken gesture in the app).
- Delete the dead pre-refactor provider/DB layer (keep the paginated notifiers).
- Match PRD §8.2 exactly: imperial SAC (psi/min, cu ft/min) and bar/min live in the
  expandable **Details** tile, L/min stays the primary SAC stat.
- Wire the D-THUMB thumbnail system into the detail photo grid; retire `createThumbnail`.
- Wrap gear writes in a transaction (atomic).
- Add single-row fetches for edit-form notifiers (kill whole-table scans).
- Every change gated on `fvm flutter analyze` + full `fvm flutter test` passing.

## Task List

### T1. Fix ad-hoc gear chip duplicate bug
- **Files:** `lib/screens/dive_form_screen.dart`, `lib/providers/dive_form_provider.dart`, widget test.
- Ad-hoc `FilterChip` is hardcoded `selected: true` with `onSelected: (_) => onAddAdHoc(text)` →
  every tap duplicates the entry. Thread a remove callback; deselect → remove, select → add.
- New widget test: tapping an ad-hoc chip removes it (does not duplicate).

### T2. Delete dead providers
- **Files:** `lib/providers/dive_providers.dart`, `test/providers/dive_providers_test.dart`.
- Remove `diveListProvider`, `diveDetailFullProvider`, `diveGearProvider`,
  `certificationListProvider`. Keep `gearListProvider`, `divePhotosProvider`,
  `sightingsProvider`, `diveDetailProvider`, `sacProvider`, `databaseProvider`.

### T3. Delete dead DB methods
- **Files:** `lib/database/database_helper.dart`, `test/database/database_helper_test.dart`.
- Remove `getAllDiveLogs`, `getAllCertifications`, `getGearForDive`, `setGearForDive`,
  `deleteDivePhoto` + their tests. Keep `getAllGearItems` (live via `gearListProvider`).

### T4. Delete dead service/model functions
- **Files:** `lib/services/dive_grouper.dart`, `lib/services/gallery_scanner.dart`,
  `lib/services/image_store.dart`, `lib/providers/dive_form_provider.dart`, tests.
- Remove `createDraftDiveLogs` (legacy), `copyAssetToAppDir`, `createThumbnail`,
  `promoteAdHocGear` (+ their tests). Keep `ensureThumbnail`/`thumbnailPathFor` (wired in T7).

### T5. DRY — unify D-GROUP clustering
- **Files:** `lib/services/dive_grouper.dart`.
- Extract generic `_groupClusters<T>(List<T>, DateTime Function(T))`; `groupPhotosByDive`
  and `groupScannedPhotos` delegate. Behavior identical — existing tests prove equivalence.

### T6. Single-row edit-form fetches
- **Files:** `lib/database/database_helper.dart`, `lib/providers/gear_form_provider.dart`,
  `lib/providers/certification_form_provider.dart`, DB tests.
- Add `getGearItem(int id)` / `getCertification(int id)`; use instead of
  `getGearItems(limit: 100000)`/`getCertifications(limit: 100000)` + `firstWhere`.

### T7. Wire thumbnails into detail photo grid
- **Files:** `lib/screens/dive_detail_screen.dart`.
- `_PhotosSection` renders each photo via `ensureThumbnail(photo.id!, photo.localPath)` in a
  small stateful widget; fallback to full-file + `cacheWidth` + broken-image on error.
  Makes the D-THUMB docs claims true.

### T8. Atomic gear writes
- **Files:** `lib/database/database_helper.dart`.
- Wrap `setGearEntriesForDive` delete+inserts in `db.transaction`.

### T9. Spec alignment — imperial SAC in expanded details
- **Files:** `lib/screens/dive_detail_screen.dart`, widget test.
- Keep L/min as the primary SAC block; move bar/min, psi/min, cu ft/min and the
  "tank volume unknown" note into the `Details` ExpansionTile (PRD §8.2).

### T10. Search debounce
- **Files:** `lib/screens/dive_list_screen.dart`.
- 300 ms `Timer` debounce on search `onChanged` (stop a DB query per keystroke).

### T11. Docs sync
- **Files:** `AGENTS.md`, `docs/security-performance-analysis.md`, `MEMORY.md`.
- D-THUMB claims now accurate; drop "will be removed once call sites migrate" wording;
  note atomic gear writes; update session state on completion.

### T12. Verification
- `fvm dart format .` → `fvm flutter analyze` → `fvm flutter test` (all green).

## Dependencies
```
T1, T5, T8, T9, T10  (standalone)
T2 ─▶ T3 ─▶ T4        (cascade — each touches tests)
T4 ─▶ T7              (thumbnail wiring after createThumbnail removal)
T6  (needs DB methods, standalone otherwise)
T11 ─▶ T12
```
`fl task ready` respects these via `depends_on`.

## Out of scope / deferred
- SQLCipher DB encryption (deferred in security analysis — do not implement).
- Real app icon asset (placeholder ships until designer swap).
- Android emulator QA (MEMORY.md follow-up; only iOS sim verified).
- NFR-2 perf gate (1,000 photos < 3 s) needs on-device verification, not code.
