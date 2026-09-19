# Actor-inspired plans — version 2.6

Open **Programs → Actor-inspired programs**, choose a plan, and review its five
training days, evidence notes, and sources. Start the next day or resume an
unfinished session. Finish five days to begin another week of that plan; each
plan keeps its own position alongside the existing Strength and Athletic
programs. These are repeatable five-day schedules, not claims of a prescribed
celebrity transformation timeline.

## Included plans

| Inspiration | Role or training context |
| --- | --- |
| Charlie Hunnam | King Arthur |
| Henry Cavill | Superman |
| Ryan Reynolds | Deadpool |
| Hugh Jackman | Wolverine |
| Chris Hemsworth | Thor |
| Chris Evans | Captain America |
| Christian Bale | Batman |
| Tom Hardy | Bane |
| Brad Pitt | Troy |
| Jason Momoa | Aquaman |
| Bruce Lee | Martial arts and screen training |
| Jason Statham | Action-film conditioning |

The catalog draws on the three research documents supplied for this update:
*Eight Hollywood Transformations*, *Brad Pitt (Troy) and Jason Momoa (Aquaman)*,
and *Bruce Lee and Jason Statham*. Most five-day schedules are reconstructions
or app adaptations of reported training principles. Each plan states that
distinction, describes modifications, and includes the sources available in the
research. Document attribution is retained when the supplied research lacks a
direct source URL. An actor's name identifies the inspiration; it does not imply
endorsement or promise an identical physique.

## Logging and resuming

- Log performed reps for bodyweight work, load and reps for loaded lifts,
  seconds for timed work, or distance for distance-based work. Prescriptions
  remain targets; they are not automatically counted as completed sets.
- Grouped movements alternate by round. Rest appears between rounds or ordinary
  sets, with a countdown that can finish while the app is in the background.
- Inputs and the current step are saved. Leaving a session keeps it available
  to resume; its saved exercise prescriptions remain stable across catalog
  updates.
- A completed day advances only that plan. Ending early requires explicit
  partial completion; history distinguishes partial and completed sessions and
  records actual logged sets against the planned total.
- Logged sets use the same local history as other training and can be edited.
  No placeholder sets are added for exercises that were not performed.

## Data and compatibility

App state schema 19 adds curated progress, drafts, and session history. Existing
Strength progress, Athletic progress, imported workouts, and exercise IDs remain
in place. The version 2.5 arbitrary Strength starting point and imported-history
matching feature remains available; see [its guide](strength-history-2.5.md).

An exact `.plab` backup retains all curated state, including unfinished inputs
and the session's exercise snapshot. It also includes a readable
`curated_training.json`. Portable exports include actual sets in `sets.csv`,
finished sessions in `workouts.csv`, and `curated_progress.csv` and
`curated_history.csv` in the comprehensive export. History exports identify
partial sessions and contain both logged and planned set counts. CSV exports
are for portable records; use `.plab` for an exact in-app restore.

## Logging fixes

The set-completion message dismisses after four seconds, retains Undo, and
offers a close control. New messages replace older queued feedback.

Dip, Bench Dip, Triceps Dip, Dead Bug, Hamstring Walkout, and Walking Lunge are
classified as bodyweight movements. They can be logged without a weight entry.
Weighted-bodyweight movements accept a blank added weight as zero; loaded lifts
and assisted movements retain their own validation. Existing exercise IDs and
recorded weights are preserved.
