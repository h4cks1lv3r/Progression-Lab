# Changelog

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
- Production signing, backup/export/import, target-load automation, substitutions, and diagnostics remain future work.
