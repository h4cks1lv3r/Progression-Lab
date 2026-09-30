# Progression Lab 2.8.2 UI follow-up

Base: `8814cd22a18159ad0023c80e28f67ea139c2b05f` (2.8.1+25). The first audit tests did not cover all of the technical review's presentation and wording gaps. This change addresses the supplied follow-up list directly.

| Reported gap | Implemented behavior | Evidence |
| --- | --- | --- |
| Raw errors in Body and workout sharing | Fixed messages and retry; no exception text, provider reply, or private path appears in the share UI. Late image actions stop when their screen/store is retired. | `share_error_feedback_test`, `user_feedback_test` |
| Technical backup errors | Typed validation reasons map to clear instructions; checksum and file internals remain diagnostics. Restore safety and stale-preview rejection remain. | `cloud_error_feedback_test`, existing backup controls/safety cases |
| Check-in names clash | Daily check-in, Body entry, Workout rating, and Functional Performance test have distinct names. | Body, Daily, and four-mode widget cases |
| Microcycle / MC labels | User-facing labels use Cycle, including picker, starting point, history matching, and summary. Internal serialized fields remain stable. | language, cycle picker, history backfill cases |
| Multiple date formats | Shared `formatAppDate` / `formatAppDateTime` produce dates such as Sep 30, 2026; storage and export keys retain their original formats. | `display_language_regression_test`, history/widget cases |
| Unexplained AMRAP and e1RM | Plan and active Strength screens explain AMRAP and the second four-rep set. Progress/Lab explain estimated one-rep maximum and its limitation. | language and logging widget cases |
| Different workout controls | Fixed, keyboard-aware save/finish controls and saved progress are shared. Strength, Open, and Iconic log sets; Functional explicitly keeps drill completion. Saving remains visible until all queued writes finish. | `followup_workout_logging_controls_test`, `workout_pending_save_status_test`, original mode regressions |
| Missing Delete all data | Backup & data requires an exact typed confirmation, lists the local scope, and explains that external copies remain. Pending work drains first; old stores, routes, credentials, mirrors, and share preferences cannot repopulate a reset. | `local_data_deletion_test`, reset lifecycle, mirror, cloud pause, provider race cases |
| All-caps labels | Section, workout, import, share, metric, and action labels use readable case. Proper acronyms and the brand wordmark remain. | source review and actual widget renders |
| Unlabeled close buttons | Exercise swap and connection notice have descriptive accessibility tooltips. Existing close labels remain. | logging/language cases and source review |
| LOCKED IN share headline | Share images use Workout complete or the actual partial-session/record state. | share render/feedback cases |
| Hidden photo-loss warning | Photo backup scope is visible on the Body overview, before photo entry, in Backup & data, and in encrypted backup review. | Body and deletion/widget cases |
| Creatine down arrow | Calendar icon and unsigned percentage show days logged; no performance effect is inferred. | `lab_condition_definitions_test` |
| Caffeine and sleep definitions differ | New comparisons and templates use shared dose/time boundaries and local-day sleep rules. Existing saved/custom experiments retain their criteria, displayed in full before use. | 22 boundary/preservation/adherence cases plus experiment preview review |
| Duplicate Year One title | One Year One app-bar title with a distinct explanatory page heading. | unique-title widget assertion |
| Faint performed/entered dates | The date line uses text with a measured contrast ratio of at least 4.5:1 against its panel. | actual widget color assertion |
| Lost EZ/trap/Smith plate tools | All supported plate-loaded bars expose the calculator. Nonstandard equipment requires its actual starting weight. | equipment and unknown-weight widget cases |
| Empty second Daily bar | Embedded Daily omits its own toolbar and retains supplement editing in visible content. | 412px, 320px, and 320px/2× text cases; fresh render |

## Repeated gate

Use Flutter 3.44.9 / Dart 3.12.2. Run the same 46 existing checks and 14 corrected audit cases, then the complete suite and analyzer:

```sh
flutter test --no-pub test/strength_workout_switch_test.dart test/strength_cycle_picker_test.dart test/strength_cycle_order_test.dart test/open_workout_widget_test.dart test/navigation_widget_test.dart test/training_layout_test.dart test/app_tour_accessibility_test.dart test/audit_functional_draft_probe_test.dart test/audit_data_probe_test.dart test/audit_render_probe_test.dart test/audit_data_controls_probe_test.dart --reporter expanded
flutter test --no-pub --reporter expanded
flutter analyze --no-fatal-infos
```

Original behavior assertions remain. Expected display text is updated for sentence case, common dates, and Notes (optional). The zero-set Finish assertion uses the shared ButtonStyleButton base after Finish moved to a secondary text button; its disabled-state assertion remains. The existing render scenario additionally captures Daily, Strength logging, and Functional logging.

## Limits and platform reset

Widget tests mock platform channels. Nine phone renders verify concrete layout and controls; they do not measure human confusion, physical gestures, or TalkBack/VoiceOver use. Android/iOS CI must pass before merge. The iOS gate also runs the native reset fixture test on a simulator.

Android reset delegates to the system Clear app data operation, stops the app, and requires reopening and granting permissions again. A positive API result confirms request acceptance. CI storage tests do not erase the running test application to claim complete reset verification. iOS stages private Application Support, temporary, and cache children, resets its app defaults and scoped credentials, and blocks normal startup if cleanup needs a retry. The native fixture covers picker originals, camera files, hidden caches, active staging exclusion, and preservation of external files reached through a symbolic link. External exports, cloud backups, gallery copies, and Health data remain outside the local reset scope.
