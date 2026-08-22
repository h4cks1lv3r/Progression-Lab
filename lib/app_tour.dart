import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'brand.dart';

class AppTourStep {
  const AppTourStep({
    required this.targetKey,
    required this.title,
    required this.body,
  });

  final GlobalKey targetKey;
  final String title;
  final String body;
}

class AppTourOverlay extends StatefulWidget {
  const AppTourOverlay({
    super.key,
    required this.steps,
    required this.stepIndex,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  final List<AppTourStep> steps;
  final int stepIndex;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback onSkip;

  @override
  State<AppTourOverlay> createState() => _AppTourOverlayState();
}

class _AppTourOverlayState extends State<AppTourOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Rect _fromRect = Rect.zero;
  Rect _targetRect = Rect.zero;
  int _transition = 0;

  AppTourStep get _step => widget.steps[widget.stepIndex];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _scheduleTargetRefresh();
  }

  @override
  void didUpdateWidget(covariant AppTourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stepIndex != widget.stepIndex ||
        oldWidget.steps != widget.steps) {
      _pulse.forward(from: 0);
      _scheduleTargetRefresh();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleTargetRefresh();
  }

  void _scheduleTargetRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshTarget());
  }

  void _refreshTarget() {
    if (!mounted) return;
    final overlayBox = context.findRenderObject();
    final targetBox = _step.targetKey.currentContext?.findRenderObject();
    if (overlayBox is! RenderBox ||
        targetBox is! RenderBox ||
        !overlayBox.hasSize ||
        !targetBox.hasSize) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshTarget());
      return;
    }
    final topLeft = overlayBox.globalToLocal(
      targetBox.localToGlobal(Offset.zero),
    );
    final raw = topLeft & targetBox.size;
    final expanded = raw.inflate(10);
    if (_targetRect == expanded) return;
    setState(() {
      _fromRect = _targetRect == Rect.zero ? expanded : _targetRect;
      _targetRect = expanded;
      _transition++;
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 560);
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          key: ValueKey(_transition),
          tween: Tween(begin: 0, end: 1),
          duration: duration,
          curve: Curves.easeInOutCubic,
          builder: (context, progress, _) {
            final rect =
                Rect.lerp(_fromRect, _targetRect, progress) ?? Rect.zero;
            return AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final card = _cardRect(size, rect);
                  final guide = _guidePosition(size, rect);
                  return Stack(
                    children: [
                      const ModalBarrier(
                        dismissible: false,
                        color: Colors.transparent,
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _TourScrimPainter(
                              target: rect,
                              pulse: _pulse.value,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: guide.dx,
                        top: guide.dy,
                        child: const _LabGuideCursor(),
                      ),
                      Positioned(
                        left: card.left,
                        top: card.top,
                        width: card.width,
                        height: card.height,
                        child: _TourFactCard(
                          step: _step,
                          index: widget.stepIndex,
                          count: widget.steps.length,
                          onBack: widget.onBack,
                          onNext: widget.onNext,
                          onSkip: widget.onSkip,
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Rect _cardRect(Size size, Rect target) {
    const horizontalMargin = 16.0;
    const cardHeight = 260.0;
    final width = math.min(382.0, size.width - horizontalMargin * 2);
    final left = ((target.center.dx - width / 2).clamp(
      horizontalMargin,
      size.width - width - horizontalMargin,
    )).toDouble();
    final safeTop = MediaQuery.paddingOf(context).top + 12;
    final safeBottom = MediaQuery.paddingOf(context).bottom + 12;
    final below = target.bottom + 20;
    final above = target.top - cardHeight - 20;
    final top = below + cardHeight < size.height - safeBottom
        ? below
        : math.max(safeTop, above);
    return Rect.fromLTWH(left, top, width, cardHeight);
  }

  Offset _guidePosition(Size size, Rect target) {
    const cursorSize = 38.0;
    final x = (target.right - cursorSize * .25)
        .clamp(8.0, size.width - cursorSize - 8)
        .toDouble();
    final y = (target.top - cursorSize * .55)
        .clamp(8.0, size.height - cursorSize - 8)
        .toDouble();
    return Offset(x, y);
  }
}

class _LabGuideCursor extends StatelessWidget {
  const _LabGuideCursor();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [BrandColors.cyan, BrandColors.violet],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .75)),
        boxShadow: [
          BoxShadow(
            color: BrandColors.cyan.withValues(alpha: .42),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.science_rounded, size: 20, color: Colors.white),
    ),
  );
}

class _TourFactCard extends StatelessWidget {
  const _TourFactCard({
    required this.step,
    required this.index,
    required this.count,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
  });

  final AppTourStep step;
  final int index;
  final int count;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: '${step.title}. ${step.body}',
    child: Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: BrandColors.panelHigh,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BrandColors.violet.withValues(alpha: .5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .5),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${index + 1} OF $count',
                style: const TextStyle(
                  color: BrandColors.cyan,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              TextButton(onPressed: onSkip, child: const Text('SKIP TOUR')),
            ],
          ),
          Text(
            step.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                step.body,
                style: const TextStyle(color: BrandColors.muted, height: 1.42),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (onBack != null)
                TextButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('BACK'),
                )
              else
                const SizedBox.shrink(),
              const Spacer(),
              FilledButton.icon(
                onPressed: onNext,
                icon: Icon(
                  index == count - 1
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                  size: 18,
                ),
                label: Text(index == count - 1 ? 'FINISH TOUR' : 'NEXT'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _TourScrimPainter extends CustomPainter {
  const _TourScrimPainter({required this.target, required this.pulse});

  final Rect target;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final fullPath = Path()..addRect(Offset.zero & size);
    if (target == Rect.zero) {
      canvas.drawPath(
        fullPath,
        Paint()..color = Colors.black.withValues(alpha: .78),
      );
      return;
    }
    final radius = 20.0 + pulse * 2;
    final targetPath = Path()
      ..addRRect(RRect.fromRectAndRadius(target, Radius.circular(radius)));
    final scrim = Path.combine(PathOperation.difference, fullPath, targetPath);
    canvas.drawPath(
      scrim,
      Paint()..color = Colors.black.withValues(alpha: .78),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(target, Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 + pulse * 1.8
        ..color = Color.lerp(BrandColors.cyan, BrandColors.violet, pulse)!
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 + pulse * 4),
    );
  }

  @override
  bool shouldRepaint(covariant _TourScrimPainter oldDelegate) =>
      oldDelegate.target != target || oldDelegate.pulse != pulse;
}
