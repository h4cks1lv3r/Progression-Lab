# Progression Lab 2.1 external integrations

Version 2.1 exposes health, wearable, provider, backup, sharing, guide, and experiment controls from **More → Connections & Experiments**. A single Flutter-facing native bridge on each platform keeps permission, secure-storage, document-picker, OAuth-callback, and health APIs outside the Dart business logic.

## Health platforms

### Android Health Connect

The Android host uses the native Health Connect client through the `progression_lab/integrations` Flutter method channel. The application manifest declares the required exercise, bodyweight, and body-fat permissions and provides the Android permission-rationale activities required by current Health Connect flows.

Available user actions include:

- request or review Health Connect permissions
- import recent workout summaries and body metrics
- write the latest local bodyweight reading
- add and write a body-fat reading

The app does not bypass platform permission controls. Availability can vary by Android version, Health Connect installation state, record type, and the permissions the user grants.

### Apple Health

The iOS host uses HealthKit through the same Flutter-facing integration contract. The Xcode project includes the HealthKit entitlement, Health usage descriptions, the native bridge in the Runner Sources phase, and the OAuth callback scheme.

HealthKit access remains subject to Apple platform availability, the user’s authorization choices, and signing on a physical device. Simulator compilation verifies the project wiring but does not prove live HealthKit behavior.

## FIT, TCX, and GPX import

Local file import does not require a provider account or network connection. The parser supports:

- FIT activity files
- TCX activity summaries and trackpoints
- GPX routes with common heart-rate and cadence extensions

Malformed or truncated files are rejected instead of being partially committed. Imported activities are normalized into Progression Lab external-workout records and saved in integration state.

## Strava and Garmin

Direct account sync is optional and uses a separately deployed OAuth broker. Client secrets and Garmin partner credentials must never be embedded in the APK, IPA, repository, or mobile configuration.

The mobile client uses:

- HTTPS-only broker URLs
- OAuth state validation
- PKCE with an S256 code challenge
- short-lived, device-scoped broker session tokens
- Android EncryptedSharedPreferences or the iOS Keychain for token storage

Build-time configuration keys are:

```text
STRAVA_SYNC_BROKER_URL
STRAVA_REDIRECT_URI
GARMIN_SYNC_BROKER_URL
GARMIN_REDIRECT_URI
```

The default callback URIs are `progressionlab://oauth/strava` and `progressionlab://oauth/garmin`. When no broker URL is supplied, direct connection controls report that the provider is unavailable and manual FIT, TCX, or GPX import remains usable.

The broker must perform provider-specific authorization-code exchange, token refresh, revocation, and activity retrieval. The mobile app receives only the broker contract and a device session token; it must not receive provider client secrets.

## User-selected cloud backup

Automatic cloud backup reuses the exact `.plab` backup format.

- Android uses a user-selected document-tree location through the Storage Access Framework and persists the granted URI permission.
- iOS uses a user-selected Files or iCloud Drive location through the native document picker and security-scoped file access.

Progression Lab does not ask for or store a cloud-provider password. If the operating system revokes access, the folder is moved, or the provider is offline, the app must report the failed backup rather than claiming success.

## Personal experiments and weekly review

Personal experiments are deterministic. They compare matched observations from the local app state and report sample size, confidence, missing data, and plausible confounders. The analyzer does not declare that an intervention works when the evidence is insufficient.

Weekly review is user-triggered. It summarizes available signals and explicitly reports data gaps. No cloud model is required for this analysis.

## Contextual guides

Integration coach marks are replayable and can be reset. Guide state is stored with the rest of the application’s integration preferences so it survives normal app restarts and exact backup/restore.

## Sharing and privacy

The share system can render Performance, Achievement, and Session Recap cards in:

- 9:16 Story
- 4:5 portrait feed
- 1:1 square

Rendering is local. Privacy options can hide exact weights or generate completion-only captions before the platform share sheet is opened.

## Backup and migration behavior

The 2.1 schema migration is additive. A schema-13 data set can load into the current schema without losing workout, recovery, bodyweight, or program state. Missing integration state is initialized safely.

Exact `.plab` backup includes integration preferences, normalized external workouts, imported body metrics, experiments, share settings, weekly-review preference, and guide state. Provider access and refresh material is excluded because it remains in native secure storage.

## Validation boundary

Repository CI verifies formatting, Flutter analysis, the complete automated test suite, Android release compilation, iOS Simulator compilation, and unsigned iPhone compilation. Automated tests cover schema migration, exact-backup retention, token exclusion, file parsing, experiment evidence thresholds, share-card formats, and privacy behavior.

Before a production release, perform physical-device checks for:

1. In-place upgrade without local-data loss.
2. Health Connect and HealthKit permission approval, denial, and revocation.
3. Bodyweight, body-fat, and workout read/write behavior.
4. Valid and malformed FIT, TCX, and GPX imports.
5. OAuth callback, cancellation, state mismatch, reconnect, and disconnect behavior with a real broker.
6. Automatic backup with the selected location available, moved, offline, and permission-revoked.
7. Share-card save and share actions for every aspect ratio and privacy mode.
8. `.plab` export, restore, and rollback on failure.

Passing CI is necessary, but it is not a substitute for those device checks.
