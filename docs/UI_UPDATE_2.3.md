# Progression Lab 2.3 preview

Based on main `d45546bd9f7ee88521070935868a9e2536766196` (2.2.0, build 16).
Version 2.3.0, build 17. Storage schema 17 is additive; older backups remain readable.

## Where to find things

| Area | Features |
| --- | --- |
| Home | Next Strength or Athletic session, resume, quick daily inputs, calendar-week completion totals |
| Programs | Training plans, cadence, schedule, starting position, exercise library |
| Track | Date selector; supplements, meals, hydration, sleep, recovery; edit past days |
| Progress | Exercise-specific charts, workout history, Athletic field assessments, Lab evidence, experiments, seven-day review |
| More | Units, share defaults, connections, backup/data, cloud folder, tour, feature tips |

## Behavior changes

- Shares use numeric session snapshots. All three templates apply privacy before rendering, including weight-sensitive highlights and volume. Preview exposes format and privacy settings. Athletic shares retain actual drill count and effort. Android image sharing respects caption preferences.
- Charts select meaningful metrics for each tracking type, normalize distances, and use the logger's personal-record policy. Strength estimates exclude unsupported tracking types. Weekly review uses real completion and record counts.
- Both training tracks persist session drafts. Strength elapsed and rest times use stored timestamps. Athletic checkmarks survive navigation and process restart.
- Logging disables duplicate taps, rolls back failed writes, offers Retry, and provides Undo. Draft save status is visible. Finishing is idempotent by session ID.
- Strength exercises can be selected directly. Saved sets are expanded. The editable load starts from the last comparable saved movement, with progression guidance and a plate calculator beside the inputs.
- Early finishes are partial; sessions with no work are skipped. Only complete sessions count toward full completion. The saved confirmation makes Done primary; sharing and post-workout response are optional.
- Health connections can export a selected timed session using a stable external ID. Historical sessions without reliable timing are excluded from export.
- Inline feature tips, larger small labels, darker primary buttons, flexible actions, and text-size-aware navigation improve readability and touch access.

## Build and test

```sh
flutter pub get
flutter analyze --no-fatal-infos
flutter test
ORG_GRADLE_PROJECT_previewBuild=true flutter build apk --release
```

The preview installs as **Progression Lab Preview**, package
`com.h4cks1lv3.iron_cadence.preview`, on Android 12 or newer. It keeps separate
app data and can coexist with the regular app. Export a full backup from the
regular app and import it into Preview to test with existing history.

The repository currently uses the Android debug signing configuration for release
test artifacts. The preview flag changes only application ID and label; a build
without that flag retains the regular package identity.

Validation includes the existing test suite, regression tests for privacy, typed
metrics, save failures, duplicate taps, Undo, draft recovery, partial completion,
past-day edits, and plate arithmetic. Screens were inspected at 360 and 412
logical pixels with 100%, 150%, and 200% text sizing. Device-specific health
permissions, wearable accounts, and Gemini Nano availability still require
testing on the target phone with those services configured.
