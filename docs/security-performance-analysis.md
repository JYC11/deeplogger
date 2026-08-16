# Security & Performance Analysis

> Plan 02 §G4. Addresses feedback.md:11. Status as of the Plan 02 remediation.

## Security

### SQL injection — clean
All database access goes through `sqflite` parameterized queries (`db.query`/`db.insert`/`db.update`/`db.rawQuery` with `?` placeholders and `whereArgs`). User input (search terms, gear names, notes) is never string-interpolated into SQL.

The one place raw SQL is assembled is `ORDER BY`, and it is protected by a **whitelisted enum** (`DiveLogSortField`/`CertificationSortField`/`GearSortField` in `lib/database/sort_fields.dart`) — column names are mapped from the enum, never taken from user input.

### File storage — app sandbox, OK
Photos and certification images are copied into the app's private documents directory (`getApplicationDocumentsDirectory()` / `dive_photos/` and `thumbnails/`). The app never references original gallery paths after copying (D-PHOTO), preventing broken links and avoiding exposure of the user's full gallery. Files live in the app sandbox; other apps cannot access them without explicit share.

### Hardcoded secrets — none
The app is offline-first. No API keys, cloud credentials, or hardcoded secrets exist in the codebase or configuration. No network calls are made.

### Database encryption — none
SQLite is stored unencrypted. Dive logs, gear, and certifications are not currently considered sensitive enough to warrant encryption for the MVP. **Recommendation:** if certification card photos (which contain PII — cert numbers, names, photos) are deemed sensitive, consider `sqflite_sqlcipher` before public release. This is a deferred, non-breaking change (same API surface, different open call).

### Input sanitization — parameterized
Parameterized queries handle injection. Form-layer validation (D3) constrains numeric ranges and required fields before persistence, preventing nonsensical values from reaching the DB.

### Permissions — least privilege
- **iOS photos:** `IosAccessLevel.readWrite` (PhotoKit offers no read-only level — `addOnly` is write-only). The app calls **no write APIs**; read access is read-only in practice.
- **Android photos:** `READ_MEDIA_IMAGES` (API 33+) scoped to images only.

## Performance

| Concern | Status | Resolution |
|---------|--------|------------|
| Unbounded queries | **Fixed (B1)** | `getDiveLogs`/`getCertifications`/`getGearItems` now paginate (`limit`/`offset`) with `hasMore`. |
| In-Dart draft filter | **Fixed (B1)** | `includeDrafts` moved into the SQL `WHERE` clause (was filtered in Dart after a full fetch). |
| Sequential EXIF reads | **Fixed (G1)** | Per-asset timestamp extraction is chunked with `Future.wait` (8 at a time) on the platform thread. `AssetEntity` can't cross isolates, so `compute()` is not used for the fetch; the pure-Dart EXIF parse could be offloaded but the dominant cost (sequential I/O) is addressed by chunking. Perf gate: 1,000 photos < 3 s (NFR-2) — verify on device. |
| UI-isolate image decode | **Fixed (E3)** | `ImageStore.copyToAppDir` compresses on copy (max 1600 px, JPEG q85) via `compute()`. Thumbnails generated via `compute()` too. |
| Thumbnail memory | **Fixed (E3 + F1)** | Thumbnails are filesystem-only (path derived from photo id, no DB column), lazy-generated via `ImageStore.ensureThumbnail`, and the dive-detail photo grid renders them (full file + `cacheWidth` fallback). |
| Full table scan on invalidate | **Fixed (C3)** | List screens use `DiveListNotifier.refresh()` (reloads page 0 keeping search/sort) instead of `ref.invalidate(diveListProvider)` (which lost state and re-fetched all). |
| N+1 detail queries | **Fixed (B2)** | `getDiveDetail` loads log + photos + sightings + gear in one round trip via `Future.wait` on a single handle. |
| Edit-gear data loss | **Fixed (C2)** | The form notifier preloads gear via `getGearEntriesForDive` (the old form never loaded it, so saving an edit wiped the selection). |
| Non-atomic gear writes | **Fixed** | `setGearEntriesForDive` (delete + batch insert) runs inside `db.transaction`, so a mid-write failure can't strip a dive of its gear. |

## Deferred
- SQLCipher encryption (see above).
- Real app icon asset (H1 ships a placeholder).
- Relative photo paths for iOS restore robustness (revisit before public release).
