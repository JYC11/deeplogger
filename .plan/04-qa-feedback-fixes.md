# Plan 04 — QA Feedback Fixes (2026-08-19) + Full Manual QA

Source: `docs/feedback.md` dated 2026-08-19 (manual QA result).

## Bugs

### B1 — Newly created gear does not show up in dive log creation
- **Root cause**: `_GearSelector` in `lib/screens/dive_form_screen.dart` watches
  `gearListProvider` (`lib/providers/dive_providers.dart`), a plain non-autoDispose
  `FutureProvider`. Once read, it caches `getAllGearItems()` forever. Gear created
  later (via the gear screen, which only refreshes the paginated
  `gearListNotifierProvider`) never appears in the form until app restart.
- **Fix**: make `gearListProvider` `FutureProvider.autoDispose` so it re-queries
  each time the dive form opens (its only watcher is the form's gear selector).

### B2 — Forms keep stale values when reopened (all forms)
- **Root cause**: all four form providers are non-autoDispose family providers
  (`diveFormProvider`, `gearFormProvider`, `certificationFormProvider`,
  `sightingFormProvider`). Family state is cached per key forever, so
  `diveFormProvider(null)` etc. retain the previously entered values after save/pop.
- **Fix**: pass `isAutoDispose: true` to all four
  `AsyncNotifierProvider.family(...)` declarations (Riverpod 3.x named param —
  verified in `riverpod/src/builder.dart`). Screens/dialogs watch the providers,
  so state lives exactly as long as the form is open.

## Tasks

1. [ ] Write regression tests (red): new file `test/providers/autodispose_regression_test.dart`
   - form reset after listener drop for all 4 form providers (null/new key)
   - `gearListProvider` re-queries after listener drop
   - ffi sqflite harness copied from `dive_form_provider_test.dart`
2. [ ] Apply fixes:
   - `lib/providers/dive_providers.dart`: `gearListProvider` → `FutureProvider.autoDispose`
   - `lib/providers/dive_form_provider.dart`: `isAutoDispose: true`
   - `lib/providers/gear_form_provider.dart`: `isAutoDispose: true`
   - `lib/providers/certification_form_provider.dart`: `isAutoDispose: true`
   - `lib/providers/sighting_form_provider.dart`: `isAutoDispose: true`
3. [ ] Run new tests → green; run FULL suite (`fvm flutter test`).
   - Risk: existing provider tests use bare `container.read` without holding a
     subscription; autoDispose may drop state between reads. If so, adapt the
     test harness with a held `container.listen` (assertions unchanged).
4. [ ] `fvm dart format` + `fvm flutter analyze` clean.
5. [ ] Full manual QA on iOS simulator (mobile-mcp): launch, dive CRUD + SAC,
   gear CRUD + gear-in-dive-form (B1), form-clear checks (B2), certs, photos,
   gallery scan, units dropdowns, list search/sort/pagination.
6. [ ] Update MEMORY.md + filament lessons; mark feedback items done.

## Notes / risks
- autoDispose form providers dispose on pop — desired. No other watchers exist
  (verified: screens + dialogs only).
- `dive_form_screen_test.dart` overrides `gearListProvider.overrideWith(...)` —
  still valid for autoDispose FutureProvider (same class in Riverpod 3.x).
