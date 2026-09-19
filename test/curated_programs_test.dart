import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/curated_programs.dart';

void main() {
  group('curated program catalog', () {
    test('includes all twelve supplied actor plans as five-session weeks', () {
      expect(CuratedPrograms.all, hasLength(12));
      expect(CuratedPrograms.all.map((program) => program.actor).toSet(), {
        'Charlie Hunnam',
        'Henry Cavill',
        'Ryan Reynolds',
        'Hugh Jackman',
        'Chris Hemsworth',
        'Chris Evans',
        'Christian Bale',
        'Tom Hardy',
        'Brad Pitt',
        'Jason Momoa',
        'Bruce Lee',
        'Jason Statham',
      });
      expect(
        CuratedPrograms.all.map((program) => program.id).toSet(),
        hasLength(12),
      );
      for (final program in CuratedPrograms.all) {
        expect(program.days, hasLength(5), reason: program.id);
        expect(program.days.map((day) => day.title).toSet(), hasLength(5));
        expect(CuratedPrograms.byId(program.id), same(program));
      }
      expect(CuratedPrograms.byId('no-such-program'), isNull);
    });

    test(
      'all session targets have valid values and match their logging metric',
      () {
        final numericReps = RegExp(r'^(\d+)(?:[–-](\d+))?$');
        final seenMetrics = <CuratedMetric>{};
        for (final program in CuratedPrograms.all) {
          for (final day in program.days) {
            expect(
              day.movements,
              isNotEmpty,
              reason: '${program.id}/${day.title}',
            );
            for (final movement in day.movements) {
              final context = '${program.id}/${day.title}/${movement.name}';
              expect(movement.name.trim(), isNotEmpty, reason: context);
              expect(movement.targets, isNotEmpty, reason: context);
              expect(
                movement.restSeconds,
                greaterThanOrEqualTo(0),
                reason: context,
              );
              seenMetrics.add(movement.metric);
              for (final target in movement.targets) {
                final values = [
                  target.reps,
                  target.seconds,
                  target.meters,
                ].where((value) => value != null);
                expect(values, hasLength(1), reason: context);
                switch (movement.metric) {
                  case CuratedMetric.reps:
                  case CuratedMetric.loadedReps:
                    final match = numericReps.firstMatch(target.reps ?? '');
                    expect(match, isNotNull, reason: context);
                    final minimum = int.parse(match!.group(1)!);
                    final maximum = int.parse(
                      match.group(2) ?? match.group(1)!,
                    );
                    expect(minimum, greaterThan(0), reason: context);
                    expect(
                      maximum,
                      greaterThanOrEqualTo(minimum),
                      reason: context,
                    );
                    expect(target.seconds, isNull, reason: context);
                    expect(target.meters, isNull, reason: context);
                  case CuratedMetric.duration:
                    expect(target.seconds, greaterThan(0), reason: context);
                    expect(target.reps, isNull, reason: context);
                    expect(target.meters, isNull, reason: context);
                  case CuratedMetric.distance:
                  case CuratedMetric.loadedDistance:
                    expect(target.meters, greaterThan(0), reason: context);
                    expect(target.meters!.isFinite, isTrue, reason: context);
                    expect(target.reps, isNull, reason: context);
                    expect(target.seconds, isNull, reason: context);
                }
              }
            }
          }
        }
        expect(seenMetrics, CuratedMetric.values.toSet());
      },
    );

    test('supersets and circuits form contiguous complete rounds', () {
      var groupedBlocks = 0;
      for (final program in CuratedPrograms.all) {
        for (final day in program.days) {
          final seen = <String>{};
          for (var index = 0; index < day.movements.length; index++) {
            final first = day.movements[index];
            final group = first.group;
            if (group == null) continue;
            final context = '${program.id}/${day.title}/$group';
            expect(seen.add(group), isTrue, reason: 'Noncontiguous $context');
            final members = <CuratedMovement>[first];
            while (index + 1 < day.movements.length &&
                day.movements[index + 1].group == group) {
              members.add(day.movements[++index]);
            }
            expect(members.length, greaterThan(1), reason: context);
            expect(
              members.map((movement) => movement.targets.length).toSet(),
              hasLength(1),
              reason:
                  'Every movement must have a target for every round: $context',
            );
            expect(members.last.restSeconds, greaterThan(0), reason: context);
            groupedBlocks++;
          }
        }
      }
      expect(groupedBlocks, greaterThan(10));
    });

    test('bodyweight pulling and pressing do not require a load', () {
      final bodyweightNames = RegExp(
        r'dip|pull-up|chin-up|push-up|inverted row',
        caseSensitive: false,
      );
      var checked = 0;
      for (final program in CuratedPrograms.all) {
        for (final day in program.days) {
          for (final movement in day.movements) {
            if (!bodyweightNames.hasMatch(movement.name)) continue;
            expect(
              movement.metric,
              CuratedMetric.reps,
              reason: '${program.id}/${movement.name}',
            );
            checked++;
          }
        }
      }
      expect(checked, greaterThan(25));
    });

    test('preserves variable-set ladders and separates units', () {
      final statham = CuratedPrograms.byId('statham_action')!;
      final ladder = statham.days[1].movements
          .where((movement) => movement.group == 'big_five')
          .toList();
      expect(ladder, hasLength(5));
      for (final movement in ladder) {
        expect(movement.targets.map((target) => target.reps).toList(), [
          '5',
          '4',
          '3',
          '2',
          '1',
        ]);
      }
      final intervals = statham.days[2].movements.firstWhere(
        (movement) => movement.metric == CuratedMetric.distance,
      );
      expect(intervals.targets, hasLength(6));
      expect(intervals.targets.every((target) => target.meters == 250), isTrue);
      expect(intervals.restSeconds, 180);
      expect(statham.days[2].movements.first.targets.single.seconds, 600);
    });

    test('labels adaptations and retains honest source attribution', () {
      for (final program in CuratedPrograms.all) {
        expect(program.evidence.toLowerCase(), contains('adapted'));
        expect(program.notes, contains('two recovery days'));
        expect(program.sources, isNotEmpty);
        expect(program.sources.first.title, startsWith('Supplied research:'));
        for (final source in program.sources) {
          expect(source.title.trim(), isNotEmpty);
          if (source.url.isEmpty) continue;
          final uri = Uri.parse(source.url);
          expect(uri.scheme, 'https');
          expect(uri.host, isNotEmpty);
        }
      }
      expect(CuratedPrograms.byId('momoa_aquaman')!.notes, contains('Conan'));
      expect(
        CuratedPrograms.byId('jackman_wolverine')!.evidence,
        contains('not his original percentage-based four-week wave'),
      );
      expect(
        CuratedPrograms.byId('statham_action')!.evidence,
        contains('single-week snapshot'),
      );
      expect(
        CuratedPrograms.byId('lee_dragon')!.evidence,
        contains('not a five-day'),
      );
    });

    test('catalog collections cannot be mutated during a workout', () {
      final first = CuratedPrograms.all.first;
      expect(() => CuratedPrograms.all.clear(), throwsUnsupportedError);
      expect(() => first.days.clear(), throwsUnsupportedError);
      expect(() => first.days.first.movements.clear(), throwsUnsupportedError);
      expect(
        () => first.days.first.movements.first.targets.clear(),
        throwsUnsupportedError,
      );
    });
  });
}
