# Body progress in Progression Lab 2.4

## Where to find it

- Progress → Training: existing Strength and Athletic history and charts.
- Progress → Body: Overview, Photos, Measurements, Add check-in, Compare / share.
- Track → Body weight: the same measurement history, with the selected Track date.
- Body → settings: optional metrics, units, source preferences, device lock, reminders, Health Connect, encrypted body backup.
- More → Data → Body photos and encrypted backup: shortcut to Body.

## What is included

Check-ins can contain photos, measurements, a photo-setup note, or a private note, in any combination. Front, left side, right side, back, and other views support relaxed, flexed, seated, or other poses. Multiple check-ins on one date are preserved. The camera supports a grid, timer, camera switching, and an optional previous-photo guide. Gallery imports use the platform picker. Drafts are saved privately and resumed after interruptions.

Measurements use canonical kg/cm values, preserving original units, dates, source IDs, revisions, and measurement methods. Weight, waist, height, hips, chest, left/right arm and thigh, and body-fat estimates are optional. Body-fat estimates remain separated by method. There is no photo-based body-fat estimate or body reshaping.

The weight overview uses one selected reading per calendar day, reports actual coverage, and requires three distinct days for a seven-day average. Missing days are not filled. Users choose a preferred source or explicitly select a reading for a day. Imported readings are not mirrored into new manual readings. BMI uses height effective on or before the weight date; adult category labels require an age-20-or-above setting. Waist-to-height uses height effective at the waist measurement date. Neither metric is a fitness score or diagnosis.

Photo comparisons match view and pose. Framing, rotation, and opaque privacy covers are nondestructive. Social images support comparison, milestone, recap, and photo-free layouts in 1080×1080, 1080×1350, and 1080×1920 sizes. Exact dates, weight, waist, and a training fact are opt-in. Measurements must belong to the selected dates; nearby dates are not substituted. Private notes, setup notes, BMI, and health-source metadata are excluded from images and captions. The final preview, Gallery save, and Sharesheet use the same PNG bytes. Posting is completed in the receiving app.

## Android privacy and persistence

Normalized, orientation-corrected JPEG masters (maximum long edge 2048 px) and thumbnails are stored under Android's private `noBackupFilesDir`. Re-encoding removes source EXIF metadata. The originals in the user's gallery are unaffected. An optional device-authentication gate protects body routes and applies `FLAG_SECURE` to hide screenshots and task snapshots while protected routes exist. Returning from the background relocks private routes. Reminders are optional and show generic text.

Ordinary app backups contain measurements and body display preferences, but exclude the private photo journal, photos, notes, and drafts. Users explicitly export a separate password-encrypted `.plabbody` archive. Uninstalling without that archive loses private photos and notes.

Archive envelope `PLABBODY2` uses PBKDF2-HMAC-SHA256 (210,000 iterations; random 128-bit salt; 256-bit key) and AES-GCM. Each bounded 64 KiB record authenticates its index and plaintext length, with a unique nonce per archive record. A final authenticated empty record rejects truncation. ZIP files are staged privately, bounded to 2 GiB expanded data and 20,001 entries, checked for allowed asset names, duplicate entries, and SHA-256 manifest matches. Restores merge saved IDs and retain existing photos when restoring an archive that excluded photos. Assets, app measurements, and the journal use a durable roll-forward transaction. Unreferenced assets are removed only after journal commitment. Shared cache files expire after 24 hours.

## Health Connect

Body sync requests read access only to the measurement types the user selects. Reads consume all pages and preserve platform record IDs and record-local dates. Per-type change tokens apply updates and deletions without re-exporting imported data. Checkpoints are saved with the resulting measurements. Initial sync and expired-token recovery reread the most recent 29 days; source changes outside that recovery window may be unavailable after an extended gap. Source deletions change the local imported copy; deleting a local entry does not delete the source record.

Reference: [Android Health Connect synchronization guidance](https://developer.android.com/health-and-fitness/health-connect/sync-data).

## Verification

Flutter regression tests cover canonical unit conversion, historical BMI, sparse daily trends, migration, stable Health Connect identities, selected permissions, sharing defaults, exact-date measurements, failed commits, private-journal exclusions, draft completion, device-lock lifecycle, small screens, large text, and exported PNG dimensions. Native tests reject wrong passwords, tampering, truncated/reordered records, trailing data, and oversize input, and round-trip archives exceeding 64 assets. Android instrumentation covers actual orientation correction, EXIF stripping, archive restoration, and FileProvider URI reads.

The GitHub Android workflow gates APK publication on analysis, Flutter tests, native tests, and Android emulator instrumentation. Camera hardware, biometric behavior, and each third-party social app should also be exercised on the test phone.
