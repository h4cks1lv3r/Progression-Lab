# Progression Lab

Progression Lab is an original, offline-first Android strength-training tracker built around a focused 48-week, three-phase progression.

Version: **1.1.1+3**

The Android application ID and local-storage keys intentionally retain their original `iron_cadence` identifiers. This allows an installed earlier build to upgrade without losing workout history.

## What changed in 1.1

- Safe 3-, 4-, and 5-day cadence switching at any point in the program.
- Phase and microcycle remain unchanged during a cadence switch.
- The user selects the exact next workout before the change is saved.
- A modern Phase 1–3 navigator with 16 microcycles per phase.
- Expandable workout and prescription details.
- Interactive exercise-specific progress dashboard.
- Estimated 1RM, working-weight, and set-volume graphs.
- 30-day, 90-day, one-year, and all-time filters.
- Animated neon graph, touch scrubbing, nearest-set details, and haptics.
- Responsive bottom navigation/NavigationRail layouts.
- Corrected volume-deload repetitions.
- Real lb/kg conversion for stored history.
- Input validation, explicit early-finish confirmation, and safer persistence rollback.

## Program behavior

The verified reference set supports three 16-microcycle phases, for 48 program weeks. The app no longer invents weeks 49–52 by silently restarting Phase 1.

Cadence changes do not reset the program. The default next workout is selected by exercise overlap, anchor lift, and weekly position. The confirmation sheet always lets the user override that choice.

## Build

The repository includes `.github/workflows/android-apk.yml`. Every pull request and push to `main` runs Flutter analysis, the test suite, and a release APK build. Because this account's GitHub Actions artifact quota is exhausted, the first successful pull-request build publishes the APK at `apk/Progression-Lab-1.1.1.apk` on the source branch instead of using temporary artifact storage.

Use a Flutter release compatible with Dart `^3.12.2` and Java 17:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The included APK is release-optimized but debug-signed, so it is installable for direct testing. Configure a private production signing key before Play Store distribution or public release.

## Current limits

This release is still based on the recovered SharedPreferences prototype. It does not yet have durable active-session recovery, a transactional database, export/import, exercise substitutions, target-load automation, or production release signing.

The Phase 1 five-day source pages were not present in the private reference set. That routine remains inherited from the prototype and is not claimed as verified Mike Matthews content.

Progression Lab is an independent implementation. It does not use Stacked or Legion branding, source code, artwork, or interface assets.
