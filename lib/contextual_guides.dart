import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum ContextualGuideId {
  strengthWorkout,
  strengthWeekNavigator,
  athleticSession,
  athleticAssessment,
  progressCharts,
  exerciseSubstitution,
  dailyInputs,
  labEvidence,
  workoutSharing,
  dataBackup,
}

class ContextualGuideStep {
  const ContextualGuideStep({
    required this.title,
    required this.message,
    required this.targetKey,
    this.preferredAlignment = Alignment.bottomCenter,
  });

  final String title;
  final String message;
  final GlobalKey targetKey;
  final Alignment preferredAlignment;
}

class ContextualGuideState extends ChangeNotifier {
  ContextualGuideState({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('progression_lab/guide_state');

  final MethodChannel _channel;
  final Set<ContextualGuideId> _seen = <ContextualGuideId>{};
  bool _tipsEnabled = true;
  bool _loaded = false;

  bool get tipsEnabled => _tipsEnabled;
  bool get loaded => _loaded;
  Set<ContextualGuideId> get seen => Set.unmodifiable(_seen);

  Future<void> load() async {
    try {
      final data = await _channel.invokeMapMethod<Object?, Object?>('read');
      _tipsEnabled = data?['tipsEnabled'] != false;
      final rawSeen = data?['seen'];
      if (rawSeen is List) {
        _seen
          ..clear()
          ..addAll(
            rawSeen
                .map((value) => ContextualGuideId.values
                    .where((item) => item.name == '$value')
                    .firstOrNull)
                .whereType<ContextualGuideId>(),
          );
      }
    } on PlatformException {
      // Guidance remains available in memory when platform persistence is not.
    }
    _loaded = true;
    notifyListeners();
  }

  bool shouldShow(ContextualGuideId id) =>
      _tipsEnabled && !_seen.contains(id);

  Future<void> markSeen(ContextualGuideId id) async {
    if (!_seen.add(id)) return;
    await _save();
    notifyListeners();
  }

  Future<void> setTipsEnabled(bool enabled) async {
    _tipsEnabled = enabled;
    await _save();
    notifyListeners();
  }

  Future<void> resetAllTips() async {
    _seen.clear();
    _tipsEnabled = true;
    await _save();
    notifyListeners();
  }

  Future<void> resetGuide(ContextualGuideId id) async {
    _seen.remove(id);
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      await _channel.invokeMethod<void>(
        'write',
        <String, Object>{
          'tipsEnabled': _tipsEnabled,
          'seen': _seen.map((item) => item.name).toList(),
        },
      );
    } on PlatformException {
      // Do not block app use when lightweight tip persistence fails.
    }
  }
}

/// A restrained branded coach-mark sequence. It uses measured widget bounds,
/// never hard-coded device coordinates, and respects reduced-motion settings.
class ContextualGuideOverlay extends StatefulWidget {
  const ContextualGuideOverlay({
    super.key,
    required this.guideId,
    required this.steps,
    required this.state,
    required this.child,
  });

  final ContextualGuideId guideId;
  final List<ContextualGuideStep> steps;
  final ContextualGuideState state;
  final Widget child;

  @override
  State<ContextualGuideOverlay> createState() => _ContextualGuideOverlayState();
}

class _ContextualGuideOverlayState extends State<ContextualGuideOverlay> {
  OverlayEntry? _entry;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  @override
  void didUpdateWidget(covariant ContextualGuideOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.guideId != widget.guideId || oldWidget.steps != widget.steps) {
      _dismiss(markSeen: false);
      _index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
    }
  }

  Future<void> _maybeShow() async {
    if (!mounted || widget.steps.isEmpty || !widget.state.shouldShow(widget.guideId)) {
      return;
    }
    final targetContext = widget.steps[_index].targetKey.currentContext;
    if (targetContext == null) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (mounted) _maybeShow();
      return;
    }
    _entry ??= OverlayEntry(builder: _buildOverlay);
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final step = widget.steps[_index];
    final targetContext = step.targetKey.currentContext;
    final box = targetContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return const SizedBox.shrink();
    final target = box.localToGlobal(Offset.zero) & box.size;
    final media = MediaQuery.of(overlayContext);
    final reduceMotion = media.disableAnimations ||
        media.accessibleNavigation ||
        MediaQuery.maybeOf(context)?.disableAnimations == true;
    final screen = media.size;
    final cardWidth = mathMin(360, screen.width - 32);
    final placeBelow = target.bottom + 190 < screen.height - media.padding.bottom;
    final cardTop = placeBelow
        ? target.bottom + 16
        : mathMax(media.padding.top + 16, target.top - 174);
    final cardLeft = (target.center.dx - cardWidth / 2)
        .clamp(16.0, screen.width - cardWidth - 16.0);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: CustomPaint(
                painter: _CoachMaskPainter(target.inflate(8)),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: target.inflate(8),
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: .3, end: 1),
                duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 520),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xffa855f7).withValues(alpha: value),
                      width: 2.5,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xff7c3aed).withValues(alpha: .35 * value),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: cardLeft,
            top: cardTop,
            width: cardWidth,
            child: _CoachCard(
              step: step,
              index: _index,
              count: widget.steps.length,
              onBack: _index == 0 ? null : _back,
              onNext: _next,
              onSkip: () => _dismiss(markSeen: true),
            ),
          ),
        ],
      ),
    );
  }

  void _back() {
    if (_index == 0) return;
    setState(() => _index--);
    _entry?.markNeedsBuild();
  }

  Future<void> _next() async {
    if (_index + 1 < widget.steps.length) {
      setState(() => _index++);
      _entry?.markNeedsBuild();
      return;
    }
    await _dismiss(markSeen: true);
  }

  Future<void> _dismiss({required bool markSeen}) async {
    _entry?.remove();
    _entry = null;
    if (markSeen) await widget.state.markSeen(widget.guideId);
  }

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.step,
    required this.index,
    required this.count,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
  });

  final ContextualGuideStep step;
  final int index;
  final int count;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xff11131c),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xffa855f7).withValues(alpha: .55)),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 14)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xff22d3ee), Color(0xffa855f7)],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(0xff7c3aed).withValues(alpha: .45),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.science_rounded, size: 19, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${index + 1} / $count',
                    style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                step.message,
                style: const TextStyle(color: Colors.white70, height: 1.45),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  TextButton(onPressed: onSkip, child: const Text('SKIP')),
                  const Spacer(),
                  if (onBack != null)
                    TextButton(onPressed: onBack, child: const Text('BACK')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onNext,
                    child: Text(index + 1 == count ? 'GOT IT' : 'NEXT'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _CoachMaskPainter extends CustomPainter {
  const _CoachMaskPainter(this.target);

  final Rect target;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(target, const Radius.circular(18)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: .72));
  }

  @override
  bool shouldRepaint(covariant _CoachMaskPainter oldDelegate) =>
      oldDelegate.target != target;
}

double mathMin(num a, num b) => a < b ? a.toDouble() : b.toDouble();
double mathMax(num a, num b) => a > b ? a.toDouble() : b.toDouble();

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
