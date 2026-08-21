import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum WorkoutShareTemplate { cleanPerformance, achievement, sessionRecap }

enum WorkoutShareAspect { story, portraitFeed, square }

class WorkoutSharePrivacy {
  const WorkoutSharePrivacy({
    this.showExactWeights = true,
    this.showDuration = true,
    this.showBodyweight = false,
    this.showVolume = true,
    this.showDate = true,
    this.completionOnly = false,
  });

  final bool showExactWeights;
  final bool showDuration;
  final bool showBodyweight;
  final bool showVolume;
  final bool showDate;
  final bool completionOnly;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'showExactWeights': showExactWeights,
        'showDuration': showDuration,
        'showBodyweight': showBodyweight,
        'showVolume': showVolume,
        'showDate': showDate,
        'completionOnly': completionOnly,
      };

  factory WorkoutSharePrivacy.fromJson(Map<String, dynamic> value) =>
      WorkoutSharePrivacy(
        showExactWeights: value['showExactWeights'] != false,
        showDuration: value['showDuration'] != false,
        showBodyweight: value['showBodyweight'] == true,
        showVolume: value['showVolume'] != false,
        showDate: value['showDate'] != false,
        completionOnly: value['completionOnly'] == true,
      );
}

class WorkoutSharePreferences {
  const WorkoutSharePreferences({
    this.template = WorkoutShareTemplate.cleanPerformance,
    this.aspect = WorkoutShareAspect.story,
    this.privacy = const WorkoutSharePrivacy(),
    this.includeCaption = true,
  });

  final WorkoutShareTemplate template;
  final WorkoutShareAspect aspect;
  final WorkoutSharePrivacy privacy;
  final bool includeCaption;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'template': template.name,
        'aspect': aspect.name,
        'privacy': privacy.toJson(),
        'includeCaption': includeCaption,
      };

  factory WorkoutSharePreferences.fromJson(Map<String, dynamic> value) {
    T enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) =>
        values.where((item) => item.name == '$raw').firstOrNull ?? fallback;
    return WorkoutSharePreferences(
      template: enumByName(
        WorkoutShareTemplate.values,
        value['template'],
        WorkoutShareTemplate.cleanPerformance,
      ),
      aspect: enumByName(
        WorkoutShareAspect.values,
        value['aspect'],
        WorkoutShareAspect.story,
      ),
      privacy: value['privacy'] is Map
          ? WorkoutSharePrivacy.fromJson(
              Map<String, dynamic>.from(value['privacy'] as Map),
            )
          : const WorkoutSharePrivacy(),
      includeCaption: value['includeCaption'] != false,
    );
  }
}

class ShareHighlight {
  const ShareHighlight(this.label, this.value, {this.sensitiveWeight = false});

  final String label;
  final String value;
  final bool sensitiveWeight;
}

class ShareWorkoutSnapshot {
  const ShareWorkoutSnapshot({
    required this.program,
    required this.workout,
    required this.completedAt,
    required this.duration,
    required this.sets,
    required this.exercises,
    this.volume,
    this.volumeUnit = 'lb',
    this.bodyweight,
    this.bodyweightUnit = 'lb',
    this.phaseLabel = '',
    this.achievement = '',
    this.highlights = const <ShareHighlight>[],
  });

  final String program;
  final String workout;
  final DateTime completedAt;
  final Duration duration;
  final int sets;
  final int exercises;
  final double? volume;
  final String volumeUnit;
  final double? bodyweight;
  final String bodyweightUnit;
  final String phaseLabel;
  final String achievement;
  final List<ShareHighlight> highlights;
}

abstract final class WorkoutShareCaptionBuilder {
  static String build(
    ShareWorkoutSnapshot snapshot,
    WorkoutSharePreferences preferences,
  ) {
    final privacy = preferences.privacy;
    final parts = <String>[
      '${snapshot.workout} complete.',
      if (!privacy.completionOnly && snapshot.sets > 0)
        '${snapshot.sets} working sets across ${snapshot.exercises} exercises.',
      if (!privacy.completionOnly && privacy.showDuration)
        '${snapshot.duration.inMinutes} minutes of work.',
      if (!privacy.completionOnly && snapshot.achievement.isNotEmpty)
        snapshot.achievement,
      'Built, not guessed. #ProgressionLab',
    ];
    return parts.join(' ');
  }
}

abstract final class AdvancedWorkoutShareCardGenerator {
  static Future<Uint8List> generate(
    ShareWorkoutSnapshot snapshot,
    WorkoutSharePreferences preferences,
  ) async {
    final size = switch (preferences.aspect) {
      WorkoutShareAspect.story => const Size(1080, 1920),
      WorkoutShareAspect.portraitFeed => const Size(1080, 1350),
      WorkoutShareAspect.square => const Size(1080, 1080),
    };
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _paintBackground(canvas, size, preferences.template);
    switch (preferences.template) {
      case WorkoutShareTemplate.cleanPerformance:
        _paintClean(canvas, size, snapshot, preferences.privacy);
      case WorkoutShareTemplate.achievement:
        _paintAchievement(canvas, size, snapshot, preferences.privacy);
      case WorkoutShareTemplate.sessionRecap:
        _paintRecap(canvas, size, snapshot, preferences.privacy);
    }
    _paintFooter(canvas, size);
    final image = await recorder.endRecording().toImage(
          size.width.round(),
          size.height.round(),
        );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('The workout image could not be encoded.');
    return data.buffer.asUint8List();
  }

  static void _paintBackground(
    Canvas canvas,
    Size size,
    WorkoutShareTemplate template,
  ) {
    const ink = Color(0xff06070c);
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = ink);
    final accent = switch (template) {
      WorkoutShareTemplate.cleanPerformance => const Color(0xff7c3aed),
      WorkoutShareTemplate.achievement => const Color(0xffa855f7),
      WorkoutShareTemplate.sessionRecap => const Color(0xff22d3ee),
    };
    canvas.drawCircle(
      Offset(size.width * .18, size.height * .08),
      size.width * .65,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * .18, size.height * .08),
          size.width * .65,
          <Color>[accent.withValues(alpha: .38), Colors.transparent],
        ),
    );
    canvas.drawCircle(
      Offset(size.width * .92, size.height * .82),
      size.width * .75,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * .92, size.height * .82),
          size.width * .75,
          <Color>[
            const Color(0xff0ea5e9).withValues(alpha: .2),
            Colors.transparent,
          ],
        ),
    );
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .025)
      ..strokeWidth = 1;
    const spacing = 72.0;
    for (var x = 0.0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  static void _paintClean(
    Canvas canvas,
    Size size,
    ShareWorkoutSnapshot snapshot,
    WorkoutSharePrivacy privacy,
  ) {
    final left = size.width * .085;
    var y = size.height * .105;
    _text(canvas, 'WORKOUT COMPLETE', Offset(left, y), 34,
        color: const Color(0xff22d3ee), weight: FontWeight.w800, letterSpacing: 4);
    y += 92;
    _textBlock(canvas, snapshot.workout, Offset(left, y), size.width * .82, 88,
        weight: FontWeight.w900, height: 1.02);
    y += size.height * .19;
    if (snapshot.phaseLabel.isNotEmpty) {
      _text(canvas, snapshot.phaseLabel, Offset(left, y), 34,
          color: Colors.white70, weight: FontWeight.w600);
      y += 74;
    }
    if (!privacy.completionOnly) {
      final metrics = _metrics(snapshot, privacy);
      _metricGrid(canvas, Offset(left, y), size.width * .83, metrics);
      y += metrics.length > 2 ? 310 : 170;
      _highlights(canvas, Offset(left, y), size.width * .83, snapshot, privacy);
    }
  }

  static void _paintAchievement(
    Canvas canvas,
    Size size,
    ShareWorkoutSnapshot snapshot,
    WorkoutSharePrivacy privacy,
  ) {
    final center = Offset(size.width / 2, size.height * .34);
    final radius = math.min(size.width * .33, size.height * .2);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          <Color>[
            const Color(0xffa855f7).withValues(alpha: .42),
            const Color(0xff7c3aed).withValues(alpha: .12),
          ],
        )
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xffa855f7).withValues(alpha: .8)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke,
    );
    _textCentered(canvas, snapshot.achievement.isNotEmpty ? 'NEW BEST' : 'LOCKED IN',
        Offset(size.width / 2, size.height * .135), 40,
        color: const Color(0xff22d3ee), weight: FontWeight.w900, letterSpacing: 5);
    final highlight = snapshot.highlights.firstOrNull;
    _textCentered(
      canvas,
      highlight?.label.toUpperCase() ?? snapshot.workout.toUpperCase(),
      Offset(size.width / 2, center.dy - 52),
      34,
      color: Colors.white70,
      weight: FontWeight.w700,
      maxWidth: size.width * .72,
    );
    final value = highlight == null
        ? snapshot.workout
        : (!privacy.showExactWeights && highlight.sensitiveWeight
            ? 'PERSONAL RECORD'
            : highlight.value);
    _textCentered(
      canvas,
      value,
      Offset(size.width / 2, center.dy + 24),
      value.length > 20 ? 54 : 74,
      weight: FontWeight.w900,
      maxWidth: size.width * .72,
    );
    var y = center.dy + radius + 115;
    _textCentered(canvas, snapshot.workout, Offset(size.width / 2, y), 48,
        weight: FontWeight.w800, maxWidth: size.width * .82);
    y += 96;
    if (!privacy.completionOnly) {
      _metricGrid(
        canvas,
        Offset(size.width * .1, y),
        size.width * .8,
        _metrics(snapshot, privacy).take(4).toList(),
      );
    }
  }

  static void _paintRecap(
    Canvas canvas,
    Size size,
    ShareWorkoutSnapshot snapshot,
    WorkoutSharePrivacy privacy,
  ) {
    final left = size.width * .075;
    var y = size.height * .085;
    _text(canvas, 'SESSION RECAP', Offset(left, y), 34,
        color: const Color(0xff22d3ee), weight: FontWeight.w900, letterSpacing: 4);
    y += 82;
    _textBlock(canvas, snapshot.workout, Offset(left, y), size.width * .84, 70,
        weight: FontWeight.w900, height: 1.02);
    y += size.height * .16;
    if (!privacy.completionOnly) {
      final metrics = _metrics(snapshot, privacy);
      _metricGrid(canvas, Offset(left, y), size.width * .85, metrics);
      y += metrics.length > 2 ? 300 : 170;
      final visible = snapshot.highlights
          .where((item) => privacy.showExactWeights || !item.sensitiveWeight)
          .take(3)
          .toList();
      for (final item in visible) {
        _recapRow(canvas, Offset(left, y), size.width * .85, item.label, item.value);
        y += 122;
      }
      if (visible.isEmpty) {
        _recapRow(canvas, Offset(left, y), size.width * .85, 'RESULT',
            'All prescribed work complete');
      }
    } else {
      _recapRow(canvas, Offset(left, y), size.width * .85, 'RESULT',
          'Workout complete');
    }
  }

  static List<ShareHighlight> _metrics(
    ShareWorkoutSnapshot snapshot,
    WorkoutSharePrivacy privacy,
  ) {
    if (privacy.completionOnly) return const <ShareHighlight>[];
    return <ShareHighlight>[
      if (privacy.showDuration)
        ShareHighlight('DURATION', '${snapshot.duration.inMinutes} MIN'),
      ShareHighlight('WORKING SETS', '${snapshot.sets}'),
      ShareHighlight('EXERCISES', '${snapshot.exercises}'),
      if (privacy.showVolume && snapshot.volume != null)
        ShareHighlight(
          'VOLUME',
          '${_compact(snapshot.volume!)} ${snapshot.volumeUnit.toUpperCase()}',
          sensitiveWeight: true,
        ),
      if (privacy.showBodyweight && snapshot.bodyweight != null)
        ShareHighlight(
          'BODYWEIGHT',
          '${_compact(snapshot.bodyweight!)} ${snapshot.bodyweightUnit.toUpperCase()}',
          sensitiveWeight: true,
        ),
    ];
  }

  static void _metricGrid(
    Canvas canvas,
    Offset origin,
    double width,
    List<ShareHighlight> metrics,
  ) {
    final columns = metrics.length <= 2 ? metrics.length : 2;
    if (columns == 0) return;
    final cellWidth = (width - 24) / columns;
    for (var index = 0; index < metrics.length; index++) {
      final column = index % columns;
      final row = index ~/ columns;
      final rect = Rect.fromLTWH(
        origin.dx + column * (cellWidth + 24),
        origin.dy + row * 144,
        cellWidth,
        120,
      );
      _panel(canvas, rect);
      _text(canvas, metrics[index].label, rect.topLeft + const Offset(24, 22), 22,
          color: Colors.white54, weight: FontWeight.w700, letterSpacing: 2);
      _text(canvas, metrics[index].value, rect.topLeft + const Offset(24, 58), 36,
          weight: FontWeight.w900, maxWidth: rect.width - 48);
    }
  }

  static void _highlights(
    Canvas canvas,
    Offset origin,
    double width,
    ShareWorkoutSnapshot snapshot,
    WorkoutSharePrivacy privacy,
  ) {
    final visible = snapshot.highlights
        .where((item) => privacy.showExactWeights || !item.sensitiveWeight)
        .take(2)
        .toList();
    var y = origin.dy;
    if (snapshot.achievement.isNotEmpty) {
      _recapRow(canvas, Offset(origin.dx, y), width, 'ACHIEVEMENT', snapshot.achievement);
      y += 130;
    }
    for (final item in visible) {
      _recapRow(canvas, Offset(origin.dx, y), width, item.label, item.value);
      y += 130;
    }
  }

  static void _recapRow(
    Canvas canvas,
    Offset origin,
    double width,
    String label,
    String value,
  ) {
    final rect = Rect.fromLTWH(origin.dx, origin.dy, width, 104);
    _panel(canvas, rect);
    _text(canvas, label.toUpperCase(), rect.topLeft + const Offset(24, 20), 20,
        color: const Color(0xff22d3ee), weight: FontWeight.w800, letterSpacing: 2);
    _text(canvas, value, rect.topLeft + const Offset(24, 51), 30,
        weight: FontWeight.w800, maxWidth: rect.width - 48);
  }

  static void _panel(Canvas canvas, Rect rect) {
    final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(24));
    canvas.drawRRect(
      rounded,
      Paint()..color = const Color(0xff11131c).withValues(alpha: .88),
    );
    canvas.drawRRect(
      rounded,
      Paint()
        ..color = Colors.white.withValues(alpha: .09)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  static void _paintFooter(Canvas canvas, Size size) {
    _drawLabMark(canvas, Offset(size.width * .085, size.height * .9), size.width * .075);
    _text(canvas, 'PROGRESSION LAB', Offset(size.width * .18, size.height * .895), 34,
        weight: FontWeight.w900, letterSpacing: 3);
    _text(canvas, 'TEST. TRAIN. TRANSFORM.',
        Offset(size.width * .18, size.height * .925), 18,
        color: Colors.white54, weight: FontWeight.w700, letterSpacing: 3);
  }

  static void _drawLabMark(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = const Color(0xffa855f7)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * .11;
    final path = Path()
      ..moveTo(center.dx - radius * .25, center.dy - radius * .65)
      ..lineTo(center.dx + radius * .25, center.dy - radius * .65)
      ..moveTo(center.dx - radius * .12, center.dy - radius * .62)
      ..lineTo(center.dx - radius * .12, center.dy - radius * .15)
      ..lineTo(center.dx - radius * .48, center.dy + radius * .52)
      ..quadraticBezierTo(
        center.dx - radius * .5,
        center.dy + radius * .7,
        center.dx - radius * .3,
        center.dy + radius * .7,
      )
      ..lineTo(center.dx + radius * .3, center.dy + radius * .7)
      ..quadraticBezierTo(
        center.dx + radius * .5,
        center.dy + radius * .7,
        center.dx + radius * .48,
        center.dy + radius * .52,
      )
      ..lineTo(center.dx + radius * .12, center.dy - radius * .15)
      ..lineTo(center.dx + radius * .12, center.dy - radius * .62);
    canvas.drawPath(path, paint);
    final bar = Paint()
      ..color = const Color(0xff22d3ee)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * .15;
    canvas.drawLine(
      Offset(center.dx - radius * .72, center.dy + radius * .25),
      Offset(center.dx + radius * .72, center.dy + radius * .25),
      bar,
    );
  }

  static void _text(
    Canvas canvas,
    String value,
    Offset offset,
    double size, {
    Color color = Colors.white,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0,
    double? maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: letterSpacing,
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth ?? double.infinity);
    painter.paint(canvas, offset);
  }

  static void _textBlock(
    Canvas canvas,
    String value,
    Offset offset,
    double width,
    double size, {
    FontWeight weight = FontWeight.w400,
    double height = 1.2,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: Colors.white,
          fontSize: size,
          fontWeight: weight,
          height: height,
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  static void _textCentered(
    Canvas canvas,
    String value,
    Offset center,
    double size, {
    Color color = Colors.white,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0,
    double maxWidth = double.infinity,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: letterSpacing,
          fontFamily: 'Roboto',
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  static String _compact(double value) {
    if (value.abs() >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value.abs() >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
