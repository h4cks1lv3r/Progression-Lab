import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progression_lab/athletic_training.dart';
import 'package:progression_lab/brand.dart';
import 'package:progression_lab/data_management_screen.dart';
import 'package:progression_lab/data_portability.dart';
import 'package:progression_lab/data_portability_core.dart';
import 'package:progression_lab/store.dart';

void main() {
  Rect paintedMark(WidgetTester tester) {
    final painter = find.descendant(
      of: find.byType(LabMark),
      matching: find.byType(CustomPaint),
    );
    final box = tester.renderObject<RenderBox>(painter);
    return MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
  }

  Future<void> open(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: ProgressionBrand.theme(), home: page),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('import preview keeps the logo square as the list widens', (
    tester,
  ) async {
    final store = AppStore();
    addTearDown(store.dispose);
    final before = store.exportState();
    final bytes = Uint8List.fromList(
      utf8.encode(
        'Date,Workout Name,Exercise Name,Set Order,Weight,Weight Unit,Reps\n'
        '2026-09-01 18:00,Upper,Bench Press,1,100,lb,5\n',
      ),
    );
    final inspection = WorkoutCsvImporter.inspect(bytes);
    final plan = WorkoutCsvImporter.buildPlan(
      inspection: inspection,
      mapping: inspection.suggestedMapping!,
      fileName: 'FitNotes_Backup--2--converted.csv',
      fileBytes: bytes,
      targetUnit: store.unit,
      defaultSourceWeightUnit: 'lb',
      knownSignatures: store.knownImportSignatures,
      knownExercises: store.knownExerciseNames,
    );
    await open(
      tester,
      ImportPreviewScreen(
        controller: DataPortabilityController(store),
        plan: plan,
      ),
    );
    for (final width in [320.0, 430.0, 800.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pump();
      expect(paintedMark(tester).size, const Size(68, 68));
      expect(paintedMark(tester).left, 20);
      expect(find.text(plan.fileName), findsOneWidget);
      expect(find.text('IMPORT 1 WORKOUTS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    expect(store.exportState(), before);
  });

  testWidgets('performance check-in also keeps its list logo square', (
    tester,
  ) async {
    final store = AppStore();
    addTearDown(store.dispose);
    await open(tester, AthleticAssessmentScreen(store: store));
    expect(paintedMark(tester).size, const Size(58, 58));
    expect(tester.takeException(), isNull);
  });

  testWidgets('logo keeps its normal row size and scales down uniformly', (
    tester,
  ) async {
    for (final available in [const Size(68, 68), const Size(32, 20)]) {
      await open(
        tester,
        Scaffold(
          body: Row(
            children: [
              SizedBox.fromSize(
                size: available,
                child: const LabMark(size: 68),
              ),
              const Text('Progression Lab'),
            ],
          ),
        ),
      );
      final side = available.shortestSide;
      expect(paintedMark(tester).width, closeTo(side, .001));
      expect(paintedMark(tester).height, closeTo(side, .001));
      expect(tester.takeException(), isNull);
    }
  });
}
