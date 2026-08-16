# DeepLogger Session State

**Last updated**: 2026-08-16
**Phase**: Review remediation (Plan 03) COMPLETE — landed, committed, pushed. Session closed.

## Review Remediation (Plan 03)

Full audit found no security-critical issues. Fixed/removed per plan `.plan/03-review-remediation.md`:
- **Bug**: ad-hoc gear chip duplicated its entry on every tap (FilterChip `onSelected` ignored the bool). Now remove-on-deselect; widget test added.
- **Dead code removed**: `diveListProvider`/`diveDetailFullProvider`/`diveGearProvider`/`certificationListProvider`; DB `getAllDiveLogs`/`getAllCertifications`/`getGearForDive`/`setGearForDive`/`deleteDivePhoto`; `createDraftDiveLogs`; `copyAssetToAppDir`; `createThumbnail`; `promoteAdHocGear`.
- **Perf**: edit-form notifiers now use single-row `getGearItem(id)`/`getCertification(id)` (was `limit: 100000` + `firstWhere`); search input debounced 300 ms.
- **Spec alignment**: imperial SAC (psi/min, cu ft/min) + bar/min moved into the expandable Details tile per PRD §8.2; L/min stays primary. Widget tests verify.
- **Thumbnails wired**: dive-detail grid renders via `ensureThumbnail` (was dead code; docs now accurate).
- **Atomicity**: `setGearEntriesForDive` wrapped in `db.transaction`.
- **DRY**: shared `_groupClusters<T>` for D-GROUP.

## Current State
- **Tests**: 149 passing, `flutter analyze` clean, `dart format` applied.
- **Git**: `main` synced with `origin/main` (Plan 03 commits `eff8f2c`, `dad7052`), working tree clean.
- **Filament**: tasks T1–T12 closed under plan `review-remediation` (closed); 19 lessons captured total.

## What's Next
1. **Android emulator QA**: run on Android emulator if available (only iOS sim tested).
2. Continue feature development per PRD roadmap.

## QA Session Results (prior session)

### Bugs Found & Fixed
1. **AssetManifest.json crash (CRITICAL)** — App crashed on launch. `MigrationRunner._defaultDiscoverer` loaded `AssetManifest.json` via `rootBundle.loadString`, but Flutter 3.16+ generates `AssetManifest.bin` (binary) instead. Tests masked this because they inject a custom disk-based discoverer. Fix: replaced with explicit `MigrationRunner.migrationAssets` constant list. Added test verifying list matches disk files. (lesson `5urqxrkk`)
2. **Stale validation error in dive form (MINOR)** — "Start time is required" persisted after user selected a time. `DiveFormNotifier` setters didn't clear `validationErrors` for the updated field. Fix: added `_clearError(key)` helper, called from `setStartTime` and `setLocation`. (lesson `57ttwjr2`)
3. **Gear edit crashes: no `updated_at` column (CRITICAL)** — `GearFormNotifier.save()` set `map['updated_at'] = null` before updating `gear_items`, but the table has no `updated_at` column. Fix: removed the line. (lesson `dirml1ly`)
4. **Stale gear/photos/sightings after dive edit (MAJOR)** — `DiveDetailScreen` only invalidated `diveDetailProvider` after edit, not `diveGearEntriesProvider`/`divePhotosProvider`/`sightingsProvider`. Master gear items added during edit didn't appear in detail until full restart. Fix: added `ref.invalidate()` for all four providers. (lesson `wjbhpeb5`)
5. **Stale validation error in gear + cert forms (MINOR)** — Same pattern as bug #2. `GearFormNotifier.setName` and `CertificationFormNotifier.setOrg`/`setLevel` didn't clear `validationErrors`. Fix: added `_clearError(key)` helper to both providers.

### QA Verified (all pass)
- [x] App launches on iOS sim (iPhone 17 Pro, iOS 26.5) with teal placeholder icon
- [x] Add dive: defaults (altitude=Sea Level, gas=Air) present, validation works, save navigates to list
- [x] Detail view: SAC computed correctly (11.4 L/min for 200→80 bar, 45min, 18m avg, 12L tank), expanded details (bar/min 0.95, psi/min 13.8, cu ft/min 0.40), Share card preview + iOS share sheet, temp file cleanup in `finally` block
- [x] Edit dive: all fields preloaded, ad-hoc gear preserved across edit + round-trip save, master gear item linked via FilterChip, both gear types (master + ad-hoc) show in detail after edit
- [x] Unit dropdowns: Max Depth m→ft (30.0→98.4) → m (30.0) round-trip verified, label + unit button update correctly
- [x] Gallery scan: found 5 drafts from 6 photos, permission dialog correct, Complete copies photo + inserts draft DiveLog + opens form with EXIF start time, Photos (1) visible in detail, draft banner shown
- [x] Gear: add (name validation), edit (preload all fields + category dropdown with kDefaultGearCategories), category filter, delete, link to dive via FilterChip
- [x] Certifications: add (org+level validation, ID, issue date picker), edit (all fields preloaded), delete, grouped by org in ExpansionTile
- [x] Deferred/out-of-scope items: no regression

## Gotchas / Lessons (for QA debugging)
- **Riverpod 3.x family notifiers**: extend `AsyncNotifier<State>`, arg via constructor, `build()` takes no args. No `FamilyAsyncNotifier` base. (lesson `z8uzw60n`)
- **Sentinel copyWith**: nullable double fields cast via `(value as num?)?.toDouble()` (not `as double?`) — int literals would crash otherwise. (lesson `bbcu1t2b`)
- **sqflite in-memory DB is per-connection** (not persistent across open/close); use a temp file for cross-open version tests. (lesson `963ixcwk`)
- **path_provider in tests**: `ImageStore` has a `@visibleForTesting appDirOverride` seam — inject a temp dir, don't mock the MethodChannel. (lesson `6aw72uui`)
- **SharedPreferences in tests**: call `SharedPreferences.setMockInitialValues({})` in setUpAll + `TestWidgetsFlutterBinding.ensureInitialized()` — form/list providers hit it.
- **Chip has no `onTap`/`onSelected`** in this Flutter; use `InputChip` (has `onPressed`+`onDeleted`) for tappable chips.
- **`DropdownButtonFormField.value` is deprecated** → use `initialValue:` (Flutter 3.33+).
- **App name is DeepLogger** (NOT DiveLogger) — stakeholder-corrected; repo dir name differs from app name. (lesson `phvcaghu`)
- **SAC formula is industry-standard RMV** — do not re-litigate or restore old formula. (lesson `9dbhk6s6`)
- **AssetManifest.json → AssetManifest.bin**: Flutter 3.16+ generates binary manifest. Don't load `AssetManifest.json` via `rootBundle`. Use explicit asset lists instead. (lesson `5urqxrkk`)
- **Form validation errors persist**: always clear the specific error key when a field is updated, not just on next save. Applies to ALL form providers (dive, gear, cert). (lesson `57ttwjr2`)
- **Gear items table has no `updated_at` column**: don't include it in update maps. Only `dive_logs` has timestamp columns. (lesson `dirml1ly`)
- **autoDispose providers stay cached while watched**: invalidate ALL affected providers after an edit, not just the main one. `diveDetailProvider` invalidation alone doesn't refresh `diveGearEntriesProvider`/`divePhotosProvider`/`sightingsProvider`. (lesson `wjbhpeb5`)
- **FilterChip `onSelected` fires with the inverse of current selection**: a `selected: true` chip passes `false` on tap — thread the bool to add/remove, don't ignore it. (lesson `i42z40wf`)
- **Public final fields are not promoted** after a null guard (only private final fields/locals are); use `id!`. (lesson `k9afbbl4`)
- **`ListView(children:)` mounts children lazily in widget tests**: off-screen fields aren't found by `find.text`; use `tester.dragUntilVisible(finder, find.byType(ListView), Offset(0,-300))` (multiple Scrollables make `scrollUntilVisible` ambiguous). (lesson `n6wyze2c`)

## QA notes — intentional decisions to flag (not bugs)
- **iOS permission = `readWrite`** (not readOnly): PhotoKit has NO read-only level (`addOnly` is write-only). App calls no write APIs. (lesson `4wagigxa`)
- **`tankSize` field removed from new-dive form** but column + legacy fallback kept for SAC.
- **Placeholder app icon** is a simple teal circle (1024×1024) — designer swaps `assets/icon_placeholder.png` + reruns `fvm dart run flutter_launcher_icons`.

## Deferred / out of scope (do NOT implement without asking)
- DB encryption (SQLCipher) — noted in `docs/security-performance-analysis.md`
- Relative photo paths (was G3) — deferred in review round 1
- Structure/shared-helper file moves (was F4) — deferred; cosmetic
- Camera capture, location, dive-computer integration, l10n beyond intl plumbing, Firebase App Distribution — out per AGENTS.md
