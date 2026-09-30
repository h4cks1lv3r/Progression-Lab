# Progression Lab 2.8.1 audit fixes

Starting point: `5e01e63cd489751f36026c58a14846820fb9b801` (2.8.0+24).

The independent September 30 audit reproduced defects through real Flutter widgets and state transitions. The same scenarios now require corrected outcomes. Storage, cloud, and native service calls are mocked in those tests.

| Finding | Result | Regression evidence |
| --- | --- | --- |
| F01 Functional draft replacement | Drafts are scoped to run, week, and session; switching days retains checks. | Functional A → B → A widget flow |
| F02 Split imported exercise histories / false records | Stable reviewed identities and conservative legacy name resolution share history and record comparisons. | Imported 200 lb record remains above live 100/150 lb; one exercise history |
| F03 Incorrect imported tracking controls | Imported time, distance, bodyweight, assistance, and added load retain appropriate tracking rules. | Imported Front Plank exposes Duration |
| F04 Missing Body weights in Lab/export | Current daily Body readings are authoritative; converted legacy readings fill missing days without duplication. | Three Body measurements appear in Lab and CSV |
| F05 Misleading backup direction/status | Explicit backup selection and restore preview; content comparison; verified safety copy; last successful upload, pending changes, error, and retry. | Empty phone offers restore; null/corrupt safety copies and stale previews block replacement |
| F06 Missing correction routes | Persistent set deletion with Undo, Open Workout discard, and confirmed exercise removal. | Actual Delete/Discard controls and state/count restoration |
| F07 Fixed Iconic exercise order | Choose a movement or do it later; discard or honestly skip an empty day. | Reordered logging, zero-set escape, completed/partial/skipped status |
| F08 Invented recovery ratings / dismissal failure | Optional ratings stay unanswered; sheets own controller lifetimes through dismissal. | Sleep-only save leaves ratings null and throws no dismissal exception |
| F09 Past workouts assigned today's date | Past Strength logging requires performed date/time, while entry and scheduled dates stay separate. | Performed date persists in sets, history, Lab joins, and portable export |
| F10 Incomplete Home resume discovery | Valid unfinished Strength, Functional, Open, and Iconic sessions appear before plan discovery. | Open Resume prominence and invalid legacy-scope guards |
| F11 Lost typed Strength inputs | Pending entries are preserved by exercise/substitution slot and restored on return. | 123 lb / 9 reps / note survive A → B → A |
| F12 Absence counted as training time | Active elapsed time is checkpointed and paused on leaving/backgrounding. Legacy drafts avoid reconstructing a full-day duration. | Overnight legacy resume and saved elapsed-time tests |
| F13 Missing workout modes in Lab | A shared completed-session adapter includes comparable Strength, Open, Iconic, and standalone imports; linked imports are deduplicated. | Cross-mode, import, cohort, and habit-window tests |
| F14 Incorrect chart point selection | Painting and hit testing share coordinates; a recent-set list provides a second selection route. | Different values at identical timestamps select the point tapped |
| F15 Ineffective data exclusions | Domains are excluded before derived comparisons, summaries, experiments, and AI prompt packets. | Workouts off removes comparisons, counts, and imported records |

The update also adds visible plan back/start actions, a primary Finish action after Strength completion, grouped exercise filters, direct Body navigation, readable labels, shorter targeted tour steps, confirmation for destructive actions, and unsaved custom-copy editing.

Restore review additionally exposed settings rollback and concurrent-write defects. Replacement state is now validated separately, written through the save queue, and applied only after a successful unchanged-state check. Conflicting changes preserve current memory and repair the disk before rejecting the restore.

## Repeatable validation

Use Flutter **3.44.9** / Dart **3.12.2**, resolve dependencies, then run:

```sh
flutter test --no-pub test/strength_workout_switch_test.dart test/strength_cycle_picker_test.dart test/strength_cycle_order_test.dart --reporter expanded
flutter test --no-pub test/open_workout_widget_test.dart test/navigation_widget_test.dart test/training_layout_test.dart test/app_tour_accessibility_test.dart --reporter expanded
flutter test --no-pub test/audit_functional_draft_probe_test.dart test/audit_data_probe_test.dart test/audit_render_probe_test.dart test/audit_data_controls_probe_test.dart --reporter expanded
flutter test --no-pub --reporter expanded
flutter analyze --no-fatal-infos
```

The first two commands retain the original 46 scenarios. Two cycle-picker setup steps now require the current cycle to start expanded instead of toggling it open; their logging, duplicate-open, failure, and retry assertions are retained. The audit commands retain 14 scenarios, with assertions changed from reproducing defects to requiring correct behavior.

The render harness writes six 412 × 915 PNGs to `build/audit-evidence/` using SDK Roboto and Material Icons. These are headless widget renders. They do not measure human frustration or verify handset gestures, TalkBack, real cloud permissions, or native health service behavior. Existing Android/iOS CI supplies platform build and native checks before merging.
