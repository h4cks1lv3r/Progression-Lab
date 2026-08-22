import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/share_card.dart';

void main() {
  test('formats workout durations without dropping hour remainders', () {
    expect(formatShareDuration(Duration.zero), '<1 MIN');
    expect(formatShareDuration(const Duration(minutes: 42)), '42 MIN');
    expect(formatShareDuration(const Duration(hours: 1)), '1 HR');
    expect(
      formatShareDuration(const Duration(hours: 2, minutes: 7)),
      '2 HR 7 MIN',
    );
  });

  test('creates stable timestamped share file names', () {
    expect(
      shareFileName(DateTime(2026, 8, 22, 9, 5)),
      'progression-lab-20260822-0905.png',
    );
  });
}
