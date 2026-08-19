# Plan 05 — Further Feedback (2026-08-19) — PLAN ONLY, implement next session

Source: `docs/feedback.md` → "further feedback" (7 items). Plan 04 prior items
(B1 gear-in-form, B2 stale forms) were fixed + verified on the iOS simulator.

## Feedbacks → Changes

### F1 — Dive log delete
Currently no delete anywhere (`dive_list_screen.dart` tile has tap-only;
detail AppBar has Share/Edit only). `DatabaseHelper.deleteDiveLog(id)` exists;
FK cascade (PRAGMA foreign_keys = ON) removes `dive_photos`/`sightings`/
`dive_log_gear` rows, but **photo files + thumbnails on disk would orphan**.

- [ ] UI: delete affordance in `DiveDetailScreen` AppBar (trash icon) with a
      confirmation dialog; optionally also swipe-to-dismiss on `DiveListTile`.
- [ ] Before `db.deleteDiveLog(id)`: read `getDivePhotosForLog(id)`, delete each
      file copy + `thumbnails/{photoId}.jpg` via `ImageStore`, then delete row.
- [ ] After delete: pop detail, `diveListNotifierProvider.refresh()`; invalidate
      detail-scoped providers (defensive — they are autoDispose).
- [ ] Files: `lib/screens/dive_detail_screen.dart`, `lib/screens/dive_list_screen.dart`
      (if swipe chosen), `lib/database/database_helper.dart` (no change),
      `lib/services/image_store.dart` (add `deleteForLog`/`deletePhotoFiles` helper).
- [ ] Tests: DB cascade test (rows gone), ImageStore file cleanup test,
      widget test for confirm dialog.

### F2/F3 — Sightings independent of photos (full CRUD anywhere)
`_SightingsSection.trailing` gates the add `IconButton` on
`photos.isEmpty` (`dive_detail_screen.dart` ~line 442). `_SightingDialog`
already allows `divePhotoId == null`. Editing exists (chip `onPressed`),
delete exists (chip `onDeleted`). So "full CRUD" = ungate the add button.

- [ ] Remove the `photos.isEmpty` gate → always show the + button.
- [ ] Photo picker inside the dialog stays optional (name-only sightings valid).
- [ ] Verify edit dialog preloads + saves when no photos on the dive.
- [ ] Tests: `_SightingsSection` widget test — add button visible with zero
      photos; sighting form save without photo persists with `divePhotoId = null`.

### F4 — Gear selector overflow at scale
`_GearSelector` (`dive_form_screen.dart` lines 392–487) is an unbounded
`Wrap` of FilterChips inside the form ListView — fine at 10 items, poor at 100+.

- [ ] Replace with a compact selector: a "Select gear (n)" button showing a
      summary of chosen chips + opens a modal dialog with: search field,
      checkbox list of all gear (scrollable), ad-hoc entry at the bottom.
      Selection writes back to `DiveFormNotifier.selectedGearIds`/`adHocGear`.
- [ ] Alternative (if we want minimal change): cap the Wrap in a
      `SizedBox(height: 160)` + `SingleChildScrollView`. Cheaper, worse UX.
      **Recommendation: dialog approach.**
- [ ] Tests: widget test with 50 gear items — no overflow exceptions, search
      filters list, toggles commit on dialog confirm.

### F5 — Share card numbers render vertically
The `ShareCard` canvas is `width: 1080` but is displayed inside a ~340px
`AlertDialog`; `_StatChip` uses `Expanded` in a `Row`, so each chip gets ~95px
and "30.0m" wraps char-by-char (screenshot evidence in session). The PNG
capture renders the same squished widget.

- [ ] Give stat chips a fixed width (e.g., `SizedBox(width: 300)`), sized to
      the 1080 canvas — no `Expanded`. Layout becomes display-independent.
- [ ] Preview dialog: wrap card in horizontal `SingleChildScrollView` or
      `FittedBox` so the 1080 canvas displays sanely; capture stays 1080-wide.
- [ ] Files: `lib/services/share_card.dart`.
- [ ] Tests: widget test pumping `ShareCard` at narrow constraints asserting
      chip texts occupy one line (no `\n`-style wrap — e.g., compare
      `Text`'s rendered height, or find a Row with fixed-width SizedBoxes).

### F6 — Stale validation errors on numeric fields (found during QA)
`DiveFormNotifier._clearError` is only called from `setStartTime`/`setLocation`
(lesson `57ttwjr2` fixed those two). Numeric setters (`setDuration`,
`setMaxDepth`, `setAvgDepth`, `setStartPressure`, `setEndPressure`,
`setWaterTemp`, `setWeight`, `setVisibility`, `setTankVolumeValue`) leave a
failed-save error displayed even after the user corrects the value (observed
live: duration 4524 error stayed after fixing to 45).

- [ ] Add `_clearError('<field>')` to every numeric setter (error keys match
      `_validate`'s keys: `maxDepthM`, `avgDepthM`, `durationMin`,
      `startPressureBar`, `endPressureBar`, `waterTempC`, `weightKg`,
      `visibilityM`, `tankVolumeValue`).
- [ ] Tests: seed a validation error via failed `save()`, call the setter,
      assert the key is gone from `validationErrors` (mirror existing
      startTime test pattern in `dive_form_provider_test.dart`).

### F7 — Manual backup / import (feature — brainstorm, needs user decision)
Offline-only, no cloud/sign-in (AGENTS.md directive). All data: single SQLite
file (5 tables, migration 001) + copied images + SharedPreferences units.

- [ ] **Export format (decide)**: 
      (a) **zip** `deeplogger_backup.zip { deeplogger.db, images/, manifest.json }`,
      (b) db-only export (loses photos), (c) share the app-documents folder.
      **Recommendation: (a) zip with manifest** `{format: 1, schemaVersion,
      exportedAt}`; thumbnails can be excluded (regenerable via
      `ensureThumbnail`) — include or exclude is a decision point.
- [ ] **Export flow**: (menu → "Backup & Restore") → zip build in temp
      (`archive` package or manual `IOStream` zip; check `archive` works offline)
      → `share_plus` Save-to-Files. New dep: `archive` (pure Dart, offline OK).
- [ ] **Import flow**: `file_picker` (new dep, native picker, offline OK) →
      validate zip contains db + manifest `format`/`schemaVersion ≤ current` →
      confirm destructive replace dialog → `DatabaseHelper.close()` → replace
      db file + images dir → reopen → reset all providers (app-level refresh or
      full restart loop).
- [ ] **Semantics**: replace-only in v1 (no merge). Draft rows included as-is.
- [ ] **Open questions for user**: zip vs db-only; include certifications'
      photo files (yes — same images dir? cert photos use `ImageStore` too);
      include unit prefs (SharedPreferences) or not; where the entry point
      lives (dive-list overflow menu).
- [ ] Tests: round-trip export→import on ffi db; corrupt zip rejected;
      newer-version manifest rejected with clear error; providers refresh post
      import.

### Behavioral (no code)
- [x] When stuck in a manual-testing loop, pause and ask for clarification
      → captured as filament lesson.

## Leftover QA from session (next session)
- Finish iOS simulator QA: certifications add/edit/delete + photo upload,
  gallery scan (allow photo permission — 6 photos on sim), draft
  complete/discard, sightings CRUD after F2/F3, unit dropdown round-trips,
  gear category filter, list search/sort/pagination, share card after F5.
- Android emulator QA (never done).

## Verification gates (for implementation session)
1. `fvm flutter test` green (new + existing; adapt harness only via
   subscription holds, never weaken assertions).
2. `fvm dart format` + `fvm flutter analyze` clean.
3. Re-run iOS simulator QA checklist above.
