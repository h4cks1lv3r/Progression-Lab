import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/share_card.dart';

void main() {
  test('formats workout durations without dropping hour remainders', () {
    expect(formatShareDuration(Duration.zero), '<1 min');
    expect(formatShareDuration(const Duration(minutes: 42)), '42 min');
    expect(formatShareDuration(const Duration(hours: 1)), '1 hr');
    expect(
      formatShareDuration(const Duration(hours: 2, minutes: 7)),
      '2 hr 7 min',
    );
  });

  test('creates stable timestamped share file names', () {
    expect(
      shareFileName(DateTime(2026, 8, 22, 9, 5)),
      'progression-lab-20260822-0905.png',
    );
  });
}
