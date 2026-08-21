// ignore_for_file: use_child_property_last

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared Progression Lab visual language.
///
/// The palette mirrors the approved laboratory-strength identity: near-black
/// surfaces, electric violet primary actions, cyan data accents, and restrained
/// glow instead of saturated color on every surface.
abstract final class BrandColors {
  static const ink = Color(0xFF070811);
  static const inkRaised = Color(0xFF0C0E19);
  static const panel = Color(0xFF111421);
  static const panelHigh = Color(0xFF181C2D);
  static const panelSoft = Color(0xFF1F2335);
  static const purple = Color(0xFF7C3AED);
  static const violet = Color(0xFFA855F7);
  static const magenta = Color(0xFFC026D3);
  static const cyan = Color(0xFF22D3EE);
  static const blue = Color(0xFF0EA5E9);
  static const white = Color(0xFFE5E7EB);
  static const muted = Color(0xFF94A3B8);
  static const line = Color(0xFF282C3E);
  static const warning = Color(0xFFFFB454);
  static const error = Color(0xFFFF657A);
  static const success = Color(0xFF7EE7C6);
}

abstract final class ProgressionBrand {
  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: BrandColors.purple,
      brightness: Brightness.dark,
      primary: BrandColors.violet,
      secondary: BrandColors.cyan,
      tertiary: BrandColors.magenta,
      surface: BrandColors.panel,
      error: BrandColors.error,
    ).copyWith(
      onPrimary: Colors.white,
      onSecondary: BrandColors.ink,
      onTertiary: Colors.white,
      onSurface: BrandColors.white,
      outline: BrandColors.line,
      outlineVariant: BrandColors.line.withValues(alpha: .65),
      surfaceContainerLowest: BrandColors.ink,
      surfaceContainerLow: BrandColors.inkRaised,
      surfaceContainer: BrandColors.panel,
      surfaceContainerHigh: BrandColors.panelHigh,
      surfaceContainerHighest: BrandColors.panelSoft,
    );

    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: BrandColors.ink,
      colorScheme: scheme,
      fontFamily: 'Roboto',
      useMaterial3: true,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: BrandColors.ink,
        foregroundColor: BrandColors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: BrandColors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -.1,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: const Color(0xF40A0C14),
        surfaceTintColor: Colors.transparent,
        indicatorColor: BrandColors.purple.withValues(alpha: .25),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? BrandColors.white
                : BrandColors.muted,
            fontSize: 10.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? BrandColors.violet
                : BrandColors.muted,
            size: 23,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: const Color(0xFF0A0C14),
        indicatorColor: BrandColors.purple.withValues(alpha: .24),
        selectedIconTheme: const IconThemeData(color: BrandColors.violet),
        unselectedIconTheme: const IconThemeData(color: BrandColors.muted),
        selectedLabelTextStyle: const TextStyle(
          color: BrandColors.white,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: const TextStyle(color: BrandColors.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          backgroundColor: BrandColors.purple,
          foregroundColor: Colors.white,
          disabledBackgroundColor: BrandColors.panelSoft,
          disabledForegroundColor: BrandColors.muted,
          shape: rounded,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: .45,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 50),
          foregroundColor: BrandColors.white,
          side: BorderSide(color: BrandColors.violet.withValues(alpha: .55)),
          shape: rounded,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BrandColors.violet,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: BrandColors.violet,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: BrandColors.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: BrandColors.violet.withValues(alpha: .14)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: BrandColors.panelHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: BrandColors.panelHigh,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: BrandColors.panelHigh,
        showDragHandle: true,
        dragHandleColor: BrandColors.muted,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: .055),
        labelStyle: const TextStyle(color: BrandColors.muted),
        hintStyle: TextStyle(color: BrandColors.muted.withValues(alpha: .7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: BrandColors.line.withValues(alpha: .85),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: BrandColors.violet, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: BrandColors.panelHigh,
        selectedColor: BrandColors.purple.withValues(alpha: .35),
        disabledColor: BrandColors.panel,
        labelStyle: const TextStyle(color: BrandColors.white),
        secondaryLabelStyle: const TextStyle(color: BrandColors.white),
        side: BorderSide(color: BrandColors.line.withValues(alpha: .9)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: const DividerThemeData(color: BrandColors.line),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BrandColors.violet,
        linearTrackColor: BrandColors.panelSoft,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: BrandColors.violet,
        thumbColor: BrandColors.cyan,
        inactiveTrackColor: BrandColors.panelSoft,
        overlayColor: Color(0x227C3AED),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: BrandColors.panelHigh,
        contentTextStyle: const TextStyle(color: BrandColors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class BrandBackdrop extends StatelessWidget {
  const BrandBackdrop({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    textStyle: Theme.of(context).textTheme.bodyMedium,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: BrandColors.ink,
        gradient: RadialGradient(
          center: Alignment(-.85, -1.0),
          radius: 1.35,
          colors: [Color(0x332B0A57), BrandColors.ink],
          stops: [0, .76],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const IgnorePointer(child: CustomPaint(painter: _LabGridPainter())),
          ?child,
        ],
      ),
    ),
  );
}

class LabMark extends StatelessWidget {
  const LabMark({
    super.key,
    this.size = 46,
    this.glow = true,
    this.semanticLabel = 'Progression Lab',
  });

  final double size;
  final bool glow;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: semanticLabel,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .24),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: BrandColors.purple.withValues(alpha: .34),
                  blurRadius: size * .36,
                  spreadRadius: size * .02,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: const CustomPaint(painter: _LabMarkPainter()),
    ),
  );
}

class _LabMarkPainter extends CustomPainter {
  const _LabMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final radius = Radius.circular(size.width * .22);

    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, radius),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF11162B), Color(0xFF070811)],
        ).createShader(bounds),
    );

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .025
      ..shader = const LinearGradient(
        colors: [BrandColors.cyan, BrandColors.violet, BrandColors.magenta],
      ).createShader(bounds);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bounds.deflate(size.width * .018),
        Radius.circular(size.width * .205),
      ),
      border,
    );

    final flask = Path()
      ..moveTo(size.width * .39, size.height * .21)
      ..lineTo(size.width * .61, size.height * .21)
      ..moveTo(size.width * .42, size.height * .25)
      ..lineTo(size.width * .42, size.height * .42)
      ..lineTo(size.width * .29, size.height * .68)
      ..quadraticBezierTo(
        size.width * .265,
        size.height * .735,
        size.width * .34,
        size.height * .755,
      )
      ..lineTo(size.width * .66, size.height * .755)
      ..quadraticBezierTo(
        size.width * .735,
        size.height * .735,
        size.width * .71,
        size.height * .68,
      )
      ..lineTo(size.width * .58, size.height * .42)
      ..lineTo(size.width * .58, size.height * .25);

    final flaskPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size.width * .055
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [BrandColors.cyan, BrandColors.violet],
      ).createShader(bounds);
    canvas.drawPath(flask, flaskPaint);

    final liquid = Path()
      ..moveTo(size.width * .32, size.height * .65)
      ..quadraticBezierTo(
        size.width * .43,
        size.height * .58,
        size.width * .53,
        size.height * .65,
      )
      ..quadraticBezierTo(
        size.width * .62,
        size.height * .71,
        size.width * .69,
        size.height * .64,
      )
      ..lineTo(size.width * .69, size.height * .70)
      ..quadraticBezierTo(
        size.width * .69,
        size.height * .725,
        size.width * .65,
        size.height * .73,
      )
      ..lineTo(size.width * .35, size.height * .73)
      ..quadraticBezierTo(
        size.width * .31,
        size.height * .725,
        size.width * .31,
        size.height * .70,
      )
      ..close();
    canvas.drawPath(
      liquid,
      Paint()
        ..shader = const LinearGradient(
          colors: [BrandColors.purple, BrandColors.magenta],
        ).createShader(bounds),
    );

    final bar = Paint()
      ..color = BrandColors.violet
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * .052;
    canvas.drawLine(
      Offset(size.width * .16, size.height * .63),
      Offset(size.width * .84, size.height * .63),
      bar,
    );

    void plate(double left, double top, double width, double height) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * left,
            size.height * top,
            size.width * width,
            size.height * height,
          ),
          Radius.circular(size.width * .018),
        ),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [BrandColors.violet, BrandColors.purple],
          ).createShader(bounds),
      );
    }

    plate(.09, .52, .055, .22);
    plate(.145, .48, .05, .30);
    plate(.805, .48, .05, .30);
    plate(.855, .52, .055, .22);

    final bubble = Paint()..color = BrandColors.cyan;
    canvas.drawCircle(
      Offset(size.width * .49, size.height * .47),
      size.width * .025,
      bubble,
    );
    canvas.drawCircle(
      Offset(size.width * .54, size.height * .39),
      size.width * .019,
      bubble,
    );
    canvas.drawCircle(
      Offset(size.width * .47, size.height * .33),
      size.width * .014,
      bubble,
    );
  }

  @override
  bool shouldRepaint(covariant _LabMarkPainter oldDelegate) => false;
}

class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'PROGRESSION',
        style: TextStyle(
          color: BrandColors.white,
          fontSize: compact ? 15 : 19,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: compact ? 1.2 : 1.8,
        ),
      ),
      Text(
        'LAB',
        style: TextStyle(
          color: BrandColors.violet,
          fontSize: compact ? 17 : 22,
          height: 1.05,
          fontWeight: FontWeight.w900,
          letterSpacing: compact ? 3.4 : 4.5,
        ),
      ),
    ],
  );
}

class BrandSectionLabel extends StatelessWidget {
  const BrandSectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 4,
        height: 18,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [BrandColors.cyan, BrandColors.violet],
          ),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: BrandColors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.15,
            fontSize: 12,
          ),
        ),
      ),
      ?trailing,
    ],
  );
}

class LabPanel extends StatelessWidget {
  const LabPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.accent = BrandColors.purple,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final panel = Ink(
      padding: padding,
      decoration: BoxDecoration(
        color: BrandColors.panel.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: .18)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: onTap == null
          ? panel
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(22),
              child: panel,
            ),
    );
  }
}

class GradientAction extends StatelessWidget {
  const GradientAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onPressed == null ? .45 : 1,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [BrandColors.purple, BrandColors.violet],
        ),
        borderRadius: BorderRadius.circular(17),
        boxShadow: onPressed == null
            ? null
            : [
                BoxShadow(
                  color: BrandColors.purple.withValues(alpha: .28),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: TextButton.icon(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 19),
          label: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: .45,
            ),
          ),
        ),
      ),
    ),
  );
}

class _LabGridPainter extends CustomPainter {
  const _LabGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BrandColors.violet.withValues(alpha: .025)
      ..strokeWidth = 1;
    const step = 42.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          BrandColors.cyan.withValues(alpha: .07),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * .82, size.height * .12),
          radius: math.max(size.width, size.height) * .42,
        ),
      );
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(covariant _LabGridPainter oldDelegate) => false;
}
