# Verification report — Progression Lab 1.1.1+3

Date: 2026-08-11

## Completed checks

- Product branding is Progression Lab in the launcher label and visible app shell.
- The Android application ID and storage identifiers are unchanged, but an in-place upgrade still requires the earlier APK's signing certificate.
- All seven Dart files passed a Tree-sitter Dart syntax parse with no error or missing nodes.
- Program state is constrained to supported 3/4/5-day cadences and weeks 1–48.
- The cadence-switch engine keeps the current week and accepts an explicit next-workout index.
- The default switch mapping uses exercise overlap, anchor lift, and weekly position.
- Volume-deload targets are covered by tests.
- lb/kg conversion and failed-save rollback are covered by tests.
- Program boundary, corrupted-state recovery, completion, mapping, and PR behavior are covered by tests.
- Widget tests cover cadence confirmation, exact next-workout selection, progress empty state, exercise selection, and metric selection.
- Test source now defines 23 unit/widget test cases.
- The broken mixed-exercise chart is no longer referenced by the application shell.
- The old `ProgramPage`, `ProgressPage`, and `_Chart` implementations were removed from `main.dart`.
- GitHub Actions used Flutter 3.44.9, Dart 3.12.2, and Java 17.
- `flutter analyze` completed with no issues.
- All 23 unit and widget tests passed.
- `flutter build apk --release --build-name 1.1.1 --build-number 3` completed successfully.
- The resulting 49.8 MB APK is stored at `apk/Progression-Lab-1.1.1.apk`.

## Checks still required

- Install, upgrade, navigation, graph interaction, touch, and haptic tests on a Galaxy S24 Ultra.
- Process-death and low-memory recovery tests.
- Android accessibility and large-font layout tests.
- Production signing and Play Store release validation.

## Known engineering limits

- The active workout is still not durable across process death.
- SharedPreferences remains the history store; canonical-unit SQLite migration is still required.
- Phase 1's five-day routine is inherited from the old prototype because the private screenshots did not contain that source sequence.
- Primary/AMRAP classification still needs explicit per-slot program metadata.
- E1RM still uses the recovered Epley formula.
- The APK is release-optimized but debug-signed. Production release signing is not configured.
- A previously installed build signed with another key may produce an Android signature-conflict error instead of upgrading.

Use the APK for direct device testing only. Do not distribute it as a production release until production signing and device verification pass.
