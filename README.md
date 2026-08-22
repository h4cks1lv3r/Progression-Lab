# Progression Lab

Progression Lab is an original, local-first strength, bodybuilding, and athletic-training application for Android and iOS.

Current version: **2.1.0+14**

The product combines a 48-week Strength program, a 12-week Athletic Functional Training program, a structured exercise library, Daily Inputs and recovery tracking, deterministic performance analysis, optional on-device Gemini narration, data portability, and branded workout sharing.

## Core training systems

### Strength Program

- Three phases and 48 authored cycles
- 3-, 4-, and 5-day cadences
- Safe cadence switching without losing the active cycle
- User-selected phase, cycle, next workout, and schedule anchor
- Separate numbered program runs
- Exercise substitutions, notes, rest timer, set editing, and history
- Automatic compound-lift warm-ups using the configured ramp

### Athletic Functional Training

- Twelve weeks across three progressive cycles
- Four coached sessions per week
- Locomotion, unilateral strength, rotation, elastic strength, landing, deceleration, acceleration, and change-of-direction work
- Independent program runs, session history, effort, notes, and field assessments

## Exercise Library 2.0

- More than 500 built-in movements
- Full Abs/Core coverage, including Captain’s Chair Leg Lift and common aliases
- Stable exercise IDs, aliases, primary and secondary muscles, equipment, movement patterns, and tracking types
- Bodyweight, weighted-bodyweight, assisted-bodyweight, repetitions, duration, distance, and load-based logging
- Custom exercise creation, editing, duplication, favorites, archiving, and restoration
- Search, muscle/equipment/type filters, recent items, and ranked substitutions
- History-safe exercise metadata and imports

Standard bodyweight movements such as push-ups, pull-ups, chin-ups, bodyweight squats, hanging leg raises, and planks do not require a weight entry. Weighted and assisted variants use explicit **Added Weight** and **Assistance** semantics.

## Daily Inputs and The Lab

Daily Inputs can record:

- supplements and custom presets
- embedded caffeine in coffee or pre-workout products
- meals and optional macros
- hydration and electrolytes
- sleep, stress, soreness, illness, and bodyweight
- post-workout energy, focus, pump, effort, discomfort, and notes

Lab Core calculates deterministic evidence before any generative model is involved. It reports associations, sample sizes, date ranges, confidence, and likely confounders. Optional Gemini Nano narration is off by default, uses only enabled data domains, and has no automatic cloud fallback. Unsupported devices retain the complete deterministic Lab experience.

## Data ownership

Progression Lab supports:

- versioned `.plab` backup and restore
- automatic rolling backups
- safety backups before import and restore
- comprehensive portable CSV export
- Strong-compatible CSV export
- Strong, Hevy, FitNotes, portable ZIP, and generic CSV import
- import preview, exercise mapping, duplicate detection, and undo

Exact backups retain the full application state, including program runs, custom exercises, Daily Inputs, recovery records, Lab settings, and history. Portable CSV exports intentionally exclude private Lab conversation text.

## Navigation and onboarding

The primary navigation is:

- Home
- Programs
- Progress
- More

A skippable first-launch tour uses a branded guide to highlight the live interface. It can be replayed from **More → Help & Guides → App Tour**.

Shared safe-layout components keep primary actions above Android gesture or three-button navigation, the iOS home indicator, display cutouts, and the software keyboard.

## Social sharing

Completed Strength and Athletic sessions can generate an offline, branded 1080 × 1920 workout story image for saving or sharing through the platform share sheet.

## Build and validation

Use Flutter stable with Java 17:

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --release
```

The repository contains direct-source GitHub Actions workflows for Android and iOS validation. The Android workflow analyzes, tests, builds a release APK, and publishes its SHA-256 checksum. The iOS workflow analyzes, tests, builds an iOS Simulator app and unsigned iPhone package, and packages the Xcode project.

## Application identity and upgrades

The Android application ID and storage channels intentionally retain their original `iron_cadence` identifiers to preserve the existing local data namespace.

Android also requires the same signing certificate for an in-place update. Test APKs may use different temporary debug certificates. Do not uninstall an existing build if it contains data that has not been backed up.

## Current distribution limits

- Public Android distribution still needs a permanent private release key.
- Physical-iPhone distribution needs Apple signing and TestFlight or App Store Connect configuration.
- Gemini Nano availability depends on the device, AICore, and current ML Kit support.
- Health Connect, Apple Health, direct Strava/Garmin account connections, and FIT/TCX/GPX import remain separate future integrations.

Progression Lab is independent software. It does not copy competitor source code, artwork, exercise media, or proprietary coaching content.
