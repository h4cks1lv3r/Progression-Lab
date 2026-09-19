# Continue strength training from imported history

Version 2.5 builds on main at `890955e` and retains the 2.4 body progress features.

1. Import your previous app's workout file through More → Backup & data. Check
   the import preview and exercise mappings first.
2. In Programs → Strength, choose Change starting point. Select phase 1–3,
   microcycle 1–16, a 3/4/5-day cadence, the next workout, and its date.
3. Move the current run or start a new run. A recorded target requires a new run.
4. Enable Fill earlier workouts from imported history and review the matches.
5. Tap any unfilled or matched workout to choose an imported session or clear
   its assignment. Use the matches, then save the starting point.

The preview covers all slots before the selected next workout, including earlier
workouts within its microcycle. Each slot shows its phase and microcycle. Existing
workouts and drafts are protected. Missing sessions remain unfilled.

Suggestions use canonical exercise names and aliases, require at least two shared
exercises and 50% of the plan's exercises, and require dates within three calendar
days of the selected schedule. Sequence alignment preserves chronological order
and never reuses a session. Duplicate import signatures are considered once.
Names alone and warmup-only sessions cannot produce suggestions. An older session
outside that date window can be assigned manually if it has a matching exercise;
all selected sessions must precede the selected next-workout date and remain in
date order. This permits resuming after a training break without changing the
original performance dates. Automatic matching does not infer missing sessions
or claim that imported training followed the program's load, rep, or deload targets.

A link references the original imported session and its set records. It does not
copy sets, change source dates, weights, units, reps, or notes. Sessions with fewer
working sets than the target plan are marked partial. Other linked sessions show
an Imported label with their completion status. Existing performance totals and
personal records retain their original set data. Portable workout CSV export
emits the original imported workout once. Exact `.plab` backups retain the links.

To correct a link, open View logged workout → Unlink from program. Imported
history and sets remain available for another assignment. Undo last import also
removes that batch's program links. Both operations preserve the chosen current
position. A failed save restores the prior in-memory state. A changed import,
logged set, draft, or starting point requires a fresh review before applying.

Tests cover all program phases and cadences, gaps, exact source preservation,
partial coverage, duplicate protection, stale reviews, persistence, failed writes,
unlink, undo import, and the review flow on a phone-sized surface.
