# AGENTS.md - DiveLogger Project

## Role
You are a senior Flutter developer building **DiveLogger**, an offline-first dive logging mobile app (iOS/Android).

## Core Directives
1. **Offline-First**: Never introduce code that relies on the internet, cloud APIs, or user accounts. Everything saves to local SQLite.
2. **No Dive Computer Integration**: Ignore Bluetooth, USB, or serial protocols. This is **out of scope**.
3. **Permissions First**: Always handle iOS `Info.plist` and Android `AndroidManifest.xml` permissions correctly for Gallery/Photos access.

## Tech Stack (Strict)
- **Framework**: Flutter (latest stable).
- **State Management**: Riverpod 3.x (`flutter_riverpod`, classic non-code-gen style). Use `NotifierProvider`+`Notifier` for sync business logic / form mutations, `AsyncNotifierProvider`+`AsyncNotifier` for async state with loading/error/data, and `FutureProvider` for one-shot DB reads. Do **not** use the legacy `StateNotifierProvider`/`StateNotifier` (moved to `legacy/` in 3.x). Prefer immutable state via `copyWith`; rebuild with `ref.watch`/`ref.read`, no `BuildContext` lookups for state.
- **Database**: `sqflite` (SQLite) with a single `DatabaseHelper` class.
- **Gallery/EXIF**: `photo_manager` + `exif` (for grouping photos).
- **File System**: `path_provider` (store copied images in `getApplicationDocumentsDirectory()`).
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

2.  **Photo Grouping Logic** (PRD §8, stakeholder-approved):
    - Scan gallery EXIF for `DateTimeOriginal` (fall back to `DateTimeDigitized`, then file timestamp).
    - Constants: `kMaxIntraDiveGap = 90 min` (max spacing between consecutive photos in one dive), `kMinInterDiveGap = 60 min` (gap that starts a new dive).
    - Algorithm: first photo starts a cluster; extend while the gap to the previous photo ≤ 90 min; any gap > 60 min starts a new cluster (so > 90 always does).
    - Generate a draft `DiveLog` per cluster with start/end times populated.

3.  **Image Handling**:
    - When a user attaches a photo (for dive logs or marine life), **copy** the file into the app's private directory. Never reference the original system gallery path directly (to prevent broken links when the user deletes the original).

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