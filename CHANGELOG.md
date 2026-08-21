# Changelog

## 2.0.0+13 — 2026-08-21

### Added

- Unified the previously separate training, Daily Inputs, Lab, and data-portability branches into normal committed Flutter source.
- Added versioned `.plab` backup and restore, automatic rolling backups, safety backups, validation, and rollback behavior.
- Added comprehensive CSV export, Strong-compatible export, and Strong, Hevy, FitNotes, portable ZIP, and generic CSV import with preview, mapping, duplicate detection, and undo.
- Added Exercise Library 2.0 with more than 500 built-in exercises, stable IDs, aliases, muscle/equipment metadata, tracking types, filters, favorites, history-safe custom exercises, and ranked substitutions.
- Added full Abs/Core coverage, including Captain’s Chair Leg Lift with Captain’s Chair Leg Raise and vertical-knee-raise aliases.
- Added bodyweight, weighted-bodyweight, assisted-bodyweight, repetitions-only, duration, distance, and combined tracking semantics.
- Added a branded structured custom-exercise creator with muscle, equipment, movement, unit, progression, and history-safety controls.
- Added app-wide safe-layout components for screens, sticky actions, bottom sheets, dialogs, and keyboard-aware forms.
- Added a source-controlled mature, direct, evidence-led product voice with restrained current cultural energy.
- Added comprehensive portable CSV files for supplements, meals, hydration, recovery, bodyweight, workout responses, Lab preferences, and full custom-exercise metadata.
- Added catalog, bodyweight, backup, export, system-inset, migration, and unified workflow regression tests.

### Changed

- Advanced local storage to the unified current schema while preserving older Strength and Athletic history as program run 1.
- Made the committed source tree authoritative; Android and iOS workflows now build it directly without layered source-materialization patches.
- Standard bodyweight exercises no longer require weight. Weighted and assisted variants use explicit Added Weight and Assistance fields.
- The exercise picker and substitution system now use canonical exercise identities rather than display names alone.
- Portable CSV exports exclude private Lab conversation text by default.
- Updated project documentation for version 2.0.0 and the current Android/iOS build process.

### Corrected

- Kept primary workout actions clear of Android gesture navigation, three-button navigation, the iOS home indicator, display cutouts, and the keyboard.
- Corrected Captain’s Chair Leg Lift to use bodyweight-repetition tracking and bodyweight equipment metadata.
- Repaired the consolidated AppStore scope and aligned legacy tests with the current schema and catalog.

## 1.9.0+12 — 2026-08-20

### Added

- Strength users can choose any authored phase, cycle, cadence, next workout, and schedule date as their current starting point.
- Expanded Strength cycle cards include a Start from this cycle action.
- Users can move the current Strength marker or begin a separate program run while preserving prior workout history and personal records.
- Athletic users can choose any cycle, week, next session, and schedule date, either within the current run or as a new run.
- Strength workout records and drafts now carry a program-run identifier so repeated runs do not mark old sessions complete in the active run.

### Changed

- Local storage schema advances to version 10 with additive migration of existing Strength history and drafts into run 1.
- Changing a starting point clears only the unfinished current-workout draft; logged sets and completed history remain intact.

## 1.8.0+11 — 2026-08-20

### Added

- Automatic ramp-up recommendations for primary compound lifts after a valid working weight and repetition target is available.
- Mike Matthews-style warm-up sets at approximately 50% for 6 reps and 70% for 4 reps, rounded to practical plate increments.
- Warm-up guidance appears before the first working set and stays hidden for isolation and secondary exercises.

### Corrected

- Bottom sheets now keep their controls above Android gesture and navigation areas, including How Progression Works, daily-input forms, and Lab evidence details.

## 1.7.0+10 — 2026-08-20

### Added

- Daily Inputs & Recovery tracking for supplements, caffeine, pre-workout, meals, hydration, sleep, stress, soreness, bodyweight, and workout-response check-ins.
- Custom supplement presets with embedded caffeine totals to prevent double entry.
- Deterministic Lab Core analysis with matched-session comparisons, sample sizes, confidence labels, date windows, and confounders.
- Optional on-device Gemini Nano narration and Ask the Lab on supported Android devices. AI is off by default and has no automatic cloud fallback.
- Per-domain Lab privacy controls and locally stored Lab notes that can be cleared without deleting workout data.
- Inputs & Performance access from Progress and the More screen.

### Changed

- Android minimum version is now API 31 because the ML Kit GenAI Prompt API requires Android 12 or later.
- Strength and Athletic workout completion can record an optional post-session response.
- Local storage schema advances to version 9 with additive migration from earlier builds.

## 1.5.1+8 — 2026-08-19

### Corrected

- Restores the intended Roboto/Material typography on standalone Strength Program and Athletic Functional Training routes.
- Removes Flutter's red monospace fallback text and yellow double-underlines by restoring a Material text-style boundary.
- Keeps standalone Strength, Athletic, and Progress screens clear of Android system bars.
- Adds regression coverage for directly routed program screens.

## 1.1.1+3 — 2026-08-11

### Changed

- Renamed the product from Iron Cadence to Progression Lab.
- Updated the launcher label, in-app title, Flutter package name, tests, and documentation.
- Retained the existing Android application ID, platform channel, and preferences key. In-place upgrades still require the same Android signing certificate.
- Added a GitHub Actions pipeline that analyzes, tests, builds, and retains the release APK.
- Changed APK delivery to a source-branch file because the account's Actions artifact-storage quota is exhausted.
- Verified the source with Flutter 3.44.9 and Dart 3.12.2: analysis passed, all 23 tests passed, and the 49.8 MB release APK compiled successfully.

## 1.1.0+2 — 2026-08-11

### Added

- Safe 3/4/5-day cadence-change confirmation flow.
- Explicit next-workout selection during a cadence change.
- Phase 1–3 navigation with animated 16-microcycle views.
- Week-type filters and expandable prescriptions.
- Exercise-specific interactive progress dashboard.
- E1RM, working-weight, and set-volume metrics.
- 30-day, 90-day, one-year, and all-time graph ranges.
- Neon animated chart, touch scrubbing, haptics, and nearest-point details.
- Responsive phone and large-screen navigation.
- Persistence rollback when a set, completion, cadence, or unit save fails.
- Input validation and early-finish confirmation.
- Expanded program, switching, persistence, and unit tests.

### Corrected

- Cadence changes no longer reset the current week.
- Program length now matches the verified 48-week, three-phase reference set.
- Volume-deload primary repetitions are 3/2/1 instead of 6/4/2.
- Weight-unit changes now convert stored values instead of relabeling them.
- AMRAP is no longer inserted as invalid numeric input.
- Progress graphs no longer mix unrelated exercises or ignore recent sets.

### Known limits

- Device-level validation on a Galaxy S24 Ultra is still required.
- Phase 1's five-day routine is inherited from the prototype because its source pages were not supplied.
- Active workouts are still memory-only; process-death recovery needs the planned database/session rebuild.
- The working history model still uses SharedPreferences rather than canonical-unit SQLite storage.
- The primary-lift classifier remains positional and needs normalized slot metadata.
- Production signing, target-load automation, direct health-platform sync, and diagnostics remain future work.
