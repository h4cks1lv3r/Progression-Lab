import 'package:flutter/material.dart';

import 'brand.dart';
import 'safe_layout.dart';

/// A single, persistent place to save the current entry and finish a workout.
/// The caller owns validation, storage, partial-workout warnings and navigation.
class WorkoutActionBar extends StatelessWidget {
  const WorkoutActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryKey,
    this.primaryIcon = Icons.add_task_rounded,
    this.onFinish,
    this.finishKey,
    this.hint,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final Key? primaryKey;
  final IconData primaryIcon;
  final VoidCallback? onFinish;
  final Key? finishKey;
  final String? hint;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: LabSafeBottomAction(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hint != null) ...[
            Text(hint!, style: const TextStyle(color: BrandColors.muted)),
            const SizedBox(height: 8),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: FilledButton.icon(
              key: primaryKey,
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: BrandColors.purple,
                foregroundColor: Colors.white,
              ),
              icon: Icon(primaryIcon),
              label: Text(
                primaryLabel,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          if (finishKey != null || onFinish != null)
            TextButton.icon(
              key: finishKey,
              onPressed: onFinish,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Finish workout'),
            ),
        ],
      ),
    ),
  );
}

/// Shared progress language with an optional total. Open workouts do not have a
/// prescribed set count; functional workouts count completed drills, not sets.
class WorkoutSaveProgress extends StatelessWidget {
  const WorkoutSaveProgress({
    super.key,
    required this.countLabel,
    this.countKey,
    this.progress,
    this.saving = false,
    this.failed = false,
    this.onRetry,
  });

  final String countLabel;
  final Key? countKey;
  final double? progress;
  final bool saving;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (progress != null) ...[
        LinearProgressIndicator(
          value: progress!.clamp(0, 1),
          minHeight: 6,
          color: BrandColors.violet,
          backgroundColor: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 8),
      ],
      Text(countLabel, key: countKey),
      Row(
        children: [
          Expanded(
            child: Text(
              failed
                  ? 'Could not save progress. Retry before closing.'
                  : saving
                  ? 'Saving progress…'
                  : 'Progress saved on this device. Come back anytime.',
              style: TextStyle(
                color: failed ? BrandColors.error : BrandColors.muted,
                fontSize: 13,
              ),
            ),
          ),
          if (failed && onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ],
  );
}
