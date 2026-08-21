import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'brand.dart';

enum ContextualTipId {
  strengthNavigator,
  strengthWorkout,
  athleticProgram,
  athleticAssessment,
  progressDashboard,
  exerciseLibrary,
  dailyInputs,
  labEvidence,
  dataConnections,
  shareStudio,
}

class ContextualTipDefinition {
  const ContextualTipDefinition({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;
}

abstract final class ContextualTips {
  static const definitions = <ContextualTipId, ContextualTipDefinition>{
    ContextualTipId.strengthNavigator: ContextualTipDefinition(
      title: 'Your program position',
      message:
          'Browse any phase without moving your current marker. Use Change Starting Point only when you intend to continue from another cycle.',
      icon: Icons.map_outlined,
    ),
    ContextualTipId.strengthWorkout: ContextualTipDefinition(
      title: 'Log the working set',
      message:
          'Enter the prescribed result, save the set, then let the rest timer handle the gap. Warm-ups stay separate from working-set progress.',
      icon: Icons.fitness_center_rounded,
    ),
    ContextualTipId.athleticProgram: ContextualTipDefinition(
      title: 'Move quality first',
      message:
          'Complete each drill with clean positions. Regressions and progressions are available inside the drill details.',
      icon: Icons.directions_run_rounded,
    ),
    ContextualTipId.athleticAssessment: ContextualTipDefinition(
      title: 'Repeat the same test',
      message:
          'Use the same setup, footwear, surface, and warm-up when possible. Consistent testing gives the Lab a cleaner signal.',
      icon: Icons.speed_rounded,
    ),
    ContextualTipId.progressDashboard: ContextualTipDefinition(
      title: 'Inspect the trend',
      message:
          'Choose one exercise and time range. Progression Lab keeps unrelated movements out of the same strength line.',
      icon: Icons.show_chart_rounded,
    ),
    ContextualTipId.exerciseLibrary: ContextualTipDefinition(
      title: 'Search by the way you train',
      message:
          'Use names, aliases, muscles, equipment, or tracking type. Bodyweight and assisted movements keep their own progress rules.',
      icon: Icons.search_rounded,
    ),
    ContextualTipId.dailyInputs: ContextualTipDefinition(
      title: 'Log only what matters',
      message:
          'A few consistent inputs beat a perfect week followed by silence. Start with the variables you actually want to test.',
      icon: Icons.local_drink_outlined,
    ),
    ContextualTipId.labEvidence: ContextualTipDefinition(
      title: 'Evidence before narration',
      message:
          'Lab Core calculates the comparison first. AI Analysis can explain it, but sample size and confounders stay visible.',
      icon: Icons.science_outlined,
    ),
    ContextualTipId.dataConnections: ContextualTipDefinition(
      title: 'Connect only what helps',
      message:
          'Health, cloud backup, and account imports are optional. Your detailed Progression Lab history remains local and exportable.',
      icon: Icons.hub_outlined,
    ),
    ContextualTipId.shareStudio: ContextualTipDefinition(
      title: 'Share the signal',
      message:
          'Choose a format and privacy defaults. The generated image can hide weights, duration, and body metrics without changing your workout log.',
      icon: Icons.ios_share_rounded,
    ),
  };
}

class ContextualTipController {
  static const _enabledKey = 'progression_lab_contextual_tips_enabled';
  static const _seenPrefix = 'progression_lab_tip_seen_';

  Future<bool> enabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_enabledKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, value);
  }

  Future<bool> shouldShow(ContextualTipId id) async {
    final preferences = await SharedPreferences.getInstance();
    if (!(preferences.getBool(_enabledKey) ?? true)) return false;
    return !(preferences.getBool('$_seenPrefix${id.name}') ?? false);
  }

  Future<void> markSeen(ContextualTipId id) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('$_seenPrefix${id.name}', true);
  }

  Future<void> resetAll() async {
    final preferences = await SharedPreferences.getInstance();
    for (final id in ContextualTipId.values) {
      await preferences.remove('$_seenPrefix${id.name}');
    }
    await preferences.setBool(_enabledKey, true);
  }

  Future<void> disableAll() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, false);
  }
}

class ContextualTipGate extends StatefulWidget {
  const ContextualTipGate({
    super.key,
    required this.tip,
    required this.child,
    this.delay = const Duration(milliseconds: 550),
  });

  final ContextualTipId tip;
  final Widget child;
  final Duration delay;

  @override
  State<ContextualTipGate> createState() => _ContextualTipGateState();
}

class _ContextualTipGateState extends State<ContextualTipGate> {
  var _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_show());
    });
  }

  Future<void> _show() async {
    await Future<void>.delayed(widget.delay);
    if (!mounted) return;
    final controller = ContextualTipController();
    if (!await controller.shouldShow(widget.tip) || !mounted) return;
    final definition = ContextualTips.definitions[widget.tip];
    if (definition == null) return;
    await controller.markSeen(widget.tip);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ContextualTipSheet(
        definition: definition,
        onDisable: () async {
          await controller.disableAll();
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ContextualTipSheet extends StatelessWidget {
  const _ContextualTipSheet({
    required this.definition,
    required this.onDisable,
  });

  final ContextualTipDefinition definition;
  final Future<void> Function() onDisable;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF101722),
    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [BrandColors.violet, BrandColors.cyan],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(definition.icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      definition.message,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              TextButton(
                onPressed: onDisable,
                child: const Text('DO NOT SHOW TIPS'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('GOT IT'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
