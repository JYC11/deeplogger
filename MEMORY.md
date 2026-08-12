# DeepLogger Session State

**Last updated**: 2026-08-12
**Phase**: Plan 02 (Feedback Remediation) — IMPLEMENTATION COMPLETE
**Next**: QA / verification session — run app on simulators, verify features, check deferred items

## What's Done
- [x] Plan 02 all 33 tasks (A1-I4) — closed in filament under plan `97f93qgz`
- [x] Phase A: MigrationRunner + complete schema; sentinel copyWith models; gear categories constant
- [x] Phase B: paginated queries; `getDiveDetail` + `GearRef` sealed type
- [x] Phase C: autoDispose providers; 4 form notifiers; 3 list notifiers
- [x] Phase D: all forms (tank volume+SAC, unit dropdowns+UnitConverter, validation, defaults, ad-hoc gear, gear/cert/sighting screens)
- [x] Phase E: D-GROUP span-cap grouping; ScannedPhoto seam + DraftCompleter; compression+thumbnails; iOS perm; photo tests
- [x] Phase F: detail Photos section; list pagination/search/sort UI; icon verify
- [x] Phase G: parallelized EXIF; temp cleanup; error audit; security/perf doc
- [x] Phase H: flutter_launcher_icons + teal placeholder
- [x] Phase I: lint rules; provider tests; widget tests; AGENTS.md updated to final state
- [x] 4 commits pushed to `main` (latest `e839b48`)

## Current State
- **Tests**: 149 passing (was 62), `flutter analyze` clean
- **Git**: `main` synced with `origin/main`, working tree clean
- **New deps**: `shared_preferences`, `image_picker`, `flutter_launcher_icons` (dev)
- **Plan**: `.plan/02-feedback-remediation.md` (REVIEWED round 1, fully implemented)
- **Filament**: all 33 plan tasks closed; 12 lessons captured (run `fl lesson list`)

## What's Next (QA session)
1. **Run the app** on iOS sim + Android emulator (mobile-mcp / `fvm flutter run`) — app not yet run since the refactor; verify it launches with the new icon.
2. **Verify core flows end-to-end**: add dive (new defaults: altitude=Sea Level, gas=Air) → edit (gear preserved) → detail (Photos section, SAC, ad-hoc gear italic) → share (temp file cleanup).
3. **Verify unit dropdowns**: switch a field (e.g. depth m↔ft) — value re-renders; save round-trips to metric; edit reloads in selected unit.
4. **Verify gallery scan**: scan → drafts with photo counts → Complete copies photos + opens form → partial-failure SnackBar if a source is unreadable.
5. **Check deferred/out-of-scope** items (see below) — confirm none regressed.

## QA notes — intentional decisions to flag (not bugs)
- **iOS permission = `readWrite`** (not readOnly): PhotoKit has NO read-only level (`addOnly` is write-only). App calls no write APIs. See lesson `4wagigxa`.
- **Back-compat wrappers kept**: `getAllDiveLogs`/`getAllCertifications`/`getAllGearItems` still exist (delegate to paginated methods) — used by old `diveListProvider`/etc. and widget-test overrides. NOT dead code; safe to remove only after migrating all call sites (widget tests use `diveListProvider` override too — those now override `diveListNotifierProvider`).
- **`tankSize` field removed from new-dive form** but column + legacy fallback kept. SAC reads structured `tank_volume_value`/`tank_volume_unit` first, falls back to parsing `tank_size` for old rows.
- **`Icons.scuba_diving`** verified present in Flutter 3.44.9 SDK (F3).
- **Placeholder app icon** is a simple teal circle (1024×1024) — designer swaps `assets/icon_placeholder.png` + reruns `fvm dart run flutter_launcher_icons`.

## Deferred / out of scope (do NOT implement in QA without asking)
- DB encryption (SQLCipher) — noted in `docs/security-performance-analysis.md`; revisit if certs deemed sensitive.
- Relative photo paths (was G3) — deferred in review round 1; revisit before public release.
- Structure/shared-helper file moves (was F4) — deferred; cosmetic.
- Camera capture, location, dive-computer integration, l10n beyond intl plumbing, Firebase App Distribution — out per AGENTS.md.

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
