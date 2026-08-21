# Progression Lab External Integrations

Progression Lab remains local-first. External connections are optional, reversible, and separate from the detailed set-by-set database.

## Health Connect and Apple Health

The Data & Connections screen can request system-controlled access to:

- read workout summaries
- read bodyweight
- read heart rate and active energy where available
- write completed Progression Lab workout summaries

Android uses Health Connect through the Flutter `health` plugin. iOS uses HealthKit. The user can change or revoke permissions in the operating system at any time.

Progression Lab remains authoritative for detailed exercises, sets, repetitions, substitutions, notes, program runs, Daily Inputs, and Lab evidence. Health platforms receive or provide session summaries and measurements rather than replacing the Progression Lab database.

## FIT, TCX, and GPX

The activity importer supports:

- FIT activity files
- TCX activity files
- GPX route files
- ZIP archives containing supported files
- Strava bulk exports, including `activities.csv`
- Garmin exports containing original FIT, TCX, or GPX activities

Imported summaries can include time, duration, distance, calories, heart rate, cadence, and power when those fields exist. Duplicate fingerprints prevent repeated imports from multiplying the same activity.

## Strava and Garmin accounts

Direct account connection is credential-gated.

Provider client secrets must not be embedded in a mobile application. Progression Lab therefore connects through an approved HTTPS OAuth relay operated by the build owner.

The relay must:

1. initiate provider authorization
2. return a one-time code to `progressionlab://oauth/<provider>`
3. exchange that code through the relay's `/token` endpoint
4. expose normalized recent activities through an authenticated `/activities` endpoint

Access tokens are stored through Android Keystore or iOS Keychain using `flutter_secure_storage`. Disconnecting removes the token without deleting already imported data.

Manual Strava and Garmin file import remains available when no relay or provider approval exists.

## Cross-platform WebDAV backup

Users can configure an HTTPS WebDAV location, including compatible Nextcloud or ownCloud storage.

Progression Lab can:

- upload a validated `.plab` backup
- restore a validated cloud backup
- create a local safety backup before restore
- use ETags to reject blind overwrite after another device changes the cloud copy
- perform best-effort automatic upload while the application is active

Passwords or app passwords are stored through Android Keystore or iOS Keychain. They are never written into `.plab` or CSV exports.

## Exact backup coverage

A current `.plab` backup includes:

- Strength and Athletic program runs
- workouts, sets, drafts, substitutions, and assessments
- custom exercises and exercise metadata
- Daily Inputs and recovery records
- Lab preferences and saved in-app analysis data
- imported external activity summaries
- personal experiment definitions
- non-secret integration preferences

Portable CSV exports include the same non-secret domains where a tabular representation is useful. Private account tokens, WebDAV passwords, and private Lab conversation text are excluded by default.

## Personal experiments

Personal experiments use deterministic Progression Lab data. A definition includes:

- one input variable
- one outcome metric
- a collection window
- a minimum matched-workout count
- condition and control labels

The engine calculates sample counts, averages, percentage difference, confidence, and confounders. AI Analysis may explain the result but does not calculate or replace it.

## Credential and signing requirements

The source code can be built without committing private credentials. Operational distribution still requires:

- a permanent Android release key for reliable production updates
- Apple Developer signing and App Store Connect credentials for TestFlight
- approved Strava and Garmin credentials for direct account connections
- a build-owner OAuth relay for provider token exchange

These values belong in protected CI secrets or the relay environment, never in source control.
