# Progression Lab

## Version 2.7 — your training, your way

Home leads with **Open Workout**, **Iconic Builds**, **Year One Strength**, and
**Functional Training**. The left menu groups workouts, the exercise library,
the Lab, progress, daily check-ins, and settings. It opens from the top-left
button on phones and stays visible on larger screens.

Open Workout lets you pick exercises, log sets with the right measurements,
resume an unfinished session, and review or edit saved sets. It has its own
history and does not move any guided program forward. Year One Strength keeps
the existing 48-week plan; Iconic Builds names the 12 actor-inspired plans.

The copy throughout uses clear, current language, with shorter actions and
help text. See [the product voice guide](docs/PRODUCT_VOICE.md).

## Version 2.6.1 — Android import picker fix

Import pickers now let you select readable files even when their provider uses
an unexpected file-type label. The app still checks supported formats and file
contents before showing an import preview. No extra storage permission is needed.

## Version 2.6 — actor-inspired training and logging fixes

Open **Home → Iconic Builds** for 12 curated five-day plans based on
the supplied actor-training research. Review each plan's adaptation notes and
sources, then log actual sets, timed work, and distance with saved progress.
Each plan has independent progress and resumable sessions. See
[the curated training guide](docs/curated-programs-2.6.md).

Set-completion feedback now dismisses automatically after four seconds while
retaining Undo. Dips and other corrected bodyweight movements accept reps
without a weight; weighted-bodyweight movements also allow zero added weight.

## Version 2.5 — continue from imported strength history

Open **Home → Year One Strength → Change starting point** to choose any phase,
microcycle, cadence, and next workout. Enable **Fill earlier workouts from
imported history**, review the matches, then save the starting point. The same
flow is available from **Settings → Backup & data → Continue your strength program**
after importing workouts. See [the history matching guide](docs/strength-history-2.5.md).

## Version 2.4 — body progress

Open **Progress → Body** for private progress photos, optional body measurements, weight trends, comparisons, and locally generated social images. Use **Body → settings** for Health Connect, optional device lock and reminders, and encrypted photo backup. Daily check-in’s weight entry uses the same history. See [the body progress guide](docs/body-progress-2.4.md) for workflows, privacy, backup, and testing details.


Progression Lab is an original, local-first strength, bodybuilding, and athletic-training application for Android and iOS.

Current version: **2.7.0+22**

The product combines Open Workout, the 48-week Year One Strength plan, the 12-week Functional Training plan, 12 Iconic Builds five-day plans, a structured exercise library, Daily Inputs and recovery tracking, deterministic performance analysis, optional on-device Gemini narration, data portability, health and wearable integrations, personal experiments, and branded workout sharing.

## Core training systems

### Year One Strength

- Three phases and 48 authored cycles
- 3-, 4-, and 5-day plans
- Safe cadence switching without losing the active cycle
- User-selected phase, cycle, next workout, and schedule anchor
- Separate numbered program runs
- Exercise substitutions, notes, rest timer, set editing, and history
- Automatic compound-lift warm-ups using the configured ramp

### Functional Training

- Twelve weeks across three progressive cycles
- Four coached sessions per week
- Locomotion, unilateral strength, rotation, elastic strength, landing, deceleration, acceleration, and change-of-direction work
- Independent program runs, session history, effort, notes, and field assessments

### Iconic Builds

- Twelve five-day plans with evidence labels, adaptation notes, and sources
- Actual reps, load, duration, and distance logging according to the movement
- Alternating rounds for grouped movements and a rest countdown
- Autosaved session inputs and independent progress for each plan
- Explicit partial-session completion and editable logged-set history
- Full backup support and portable progress, history, and set exports

## Exercise Library 2.0

- More than 500 built-in movements
- Full Abs/Core coverage, including Captain’s Chair Leg Lift and common aliases
- Stable exercise IDs, aliases, primary and secondary muscles, equipment, movement patterns, and tracking types
- Bodyweight, weighted-bodyweight, assisted-bodyweight, repetitions, duration, distance, and load-based logging
- Custom exercise creation, editing, duplication, favorites, archiving, and restoration
- Search, muscle/equipment/type filters, recent items, and ranked substitutions
- History-safe exercise metadata and imports

Standard bodyweight movements such as dips, push-ups, pull-ups, chin-ups, bodyweight squats, hanging leg raises, and planks do not require a weight entry. Weighted and assisted variants use explicit **Added Weight** and **Assistance** semantics. Blank added weight means zero for weighted-bodyweight movements.

## Daily Inputs and The Lab

Daily Inputs can record:

- supplements and custom presets
- embedded caffeine in coffee or pre-workout products
- meals and optional macros
- hydration and electrolytes
- sleep, stress, soreness, illness, and bodyweight
- post-workout energy, focus, pump, effort, discomfort, and notes

Lab Core calculates deterministic evidence before any generative model is involved. It reports associations, sample sizes, date ranges, confidence, and likely confounders. Optional Gemini Nano narration is off by default, uses only enabled data domains, and has no automatic cloud fallback. Unsupported devices retain the complete deterministic Lab experience.

## Connections and experiments

Open **Settings → Connections** to use the version 2.1 integration tools:

- Health Connect on Android and Apple Health on iOS for permission-controlled workout summaries, bodyweight, and body-fat data
- local FIT, TCX, and GPX activity import
- optional Strava and Garmin account sync through an operator-managed OAuth broker
- user-selected automatic backup locations through Android document providers or iOS Files/iCloud Drive
- deterministic personal experiments and user-triggered weekly evidence reviews
- contextual coach marks with replay and reset controls
- Performance, Achievement, and Session Recap share templates in Story, portrait-feed, and square formats

Direct Strava and Garmin connections are intentionally unavailable until a protected HTTPS broker is configured. Provider client secrets do not ship in the mobile app. Manual file import remains available without provider credentials.

See [External integrations](docs/EXTERNAL_INTEGRATIONS.md) for architecture, configuration, data-handling, and device-validation details.

## Data ownership

Progression Lab supports:

- versioned `.plab` backup and restore
- automatic rolling backups
- safety backups before import and restore
- comprehensive portable CSV export
- Strong-compatible CSV export
- Strong, Hevy, FitNotes, portable ZIP, and generic CSV import
- import preview, exercise mapping, duplicate detection, and undo

Exact backups retain the full application state, including program runs, Open Workout history and drafts, Iconic Builds progress and unfinished sessions, custom exercises, Daily Inputs, recovery records, Lab settings, imported external activities, health-derived integration state, personal experiments, share preferences, contextual-guide state, and history. Provider session tokens stay in native secure storage and are not written into `.plab` backups. Portable CSV exports intentionally exclude private Lab conversation text.

## Navigation and onboarding

The left menu groups:

- Home
- Workouts: all workouts, Open Workout, Iconic Builds, Year One Strength, Functional Training, exercise library
- Your Lab: Lab, Progress, Daily check-in
- Settings

An eight-step, skippable first-launch tour highlights the live interface and covers every core feature: the four workout modes, start-anywhere strength and imported history, workout tools, progress and body tracking, daily check-ins, the Lab, connections, sharing, and backups. Finishing returns to Home. It can be replayed from **Settings → Help & guides → App tour**. Integration-specific coach marks can be replayed or reset from **Connections & Experiments**.

Shared safe-layout components keep primary actions above Android gesture or three-button navigation, the iOS home indicator, display cutouts, and the software keyboard.

## Social sharing

Completed Strength and Athletic sessions can generate offline branded workout images in 9:16 Story, 4:5 portrait-feed, and 1:1 square formats. Privacy controls can hide exact weights or produce completion-only captions before saving or sharing through the platform share sheet.

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
- Direct Strava and Garmin account sync needs provider approval, server-side credentials, and configured HTTPS broker endpoints. Manual FIT, TCX, and GPX import does not.
- Health Connect and Apple Health features depend on platform availability, granted permissions, and device-level validation.
- Gemini Nano availability depends on the device, AICore, and current ML Kit support.
- Release QA still requires installation, upgrade, permission, import, backup, and restore checks on representative physical Android and iOS devices.

Progression Lab is independent software. It does not copy competitor source code, artwork, exercise media, or proprietary coaching content.
