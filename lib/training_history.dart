import 'package:flutter/material.dart';
import 'athletic_program.dart';
import 'brand.dart';
import 'daily_inputs_screen.dart';
import 'logged_sets.dart';
import 'store.dart';

class TrainingHistoryScreen extends StatelessWidget {
  const TrainingHistoryScreen({super.key, required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final entries = <(DateTime, String, String, String?, String, Widget?)>[
        for (final r in store.workoutHistory)
          (
            r.date,
            r.workout,
            'Strength · ${r.status.name} · Week ${r.week}',
            r.sessionId,
            'strength',
            LoggedWorkoutScreen(store: store, record: r),
          ),
        for (final r in store.athleticHistory)
          (
            r.completedAt,
            AthleticProgram.week(r.week).sessions[r.sessionIndex].name,
            'Athletic · ${r.status} · ${r.completedDrills?.length ?? AthleticProgram.week(r.week).sessions[r.sessionIndex].drills.length} drills${r.status == 'skipped' ? '' : ' · ${r.effort}/10 effort'}',
            r.sessionId,
            'athletic',
            null,
          ),
      ]..sort((a, b) => b.$1.compareTo(a.$1));
      return Scaffold(
        appBar: AppBar(title: const Text('Workout history')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Your saved sessions will appear here. Completed, partial, and skipped sessions stay distinct.',
                ),
              ),
            for (final e in entries)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        MaterialLocalizations.of(
                          context,
                        ).formatMediumDate(e.$1),
                        style: const TextStyle(color: BrandColors.muted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.$2,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(e.$3),
                      Wrap(
                        spacing: 12,
                        children: [
                          if (e.$6 != null)
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => e.$6!),
                              ),
                              child: const Text('View sets'),
                            ),
                          if (e.$4 != null && !e.$3.contains('skipped'))
                            TextButton(
                              onPressed: () => showWorkoutResponseSheet(
                                context,
                                store,
                                sessionId: e.$4!,
                                track: e.$5,
                              ),
                              child: const Text('How it felt'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
