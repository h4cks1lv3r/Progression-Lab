import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand.dart';
import 'daily_inputs.dart';
import 'gemini_nano.dart';
import 'lab_analysis.dart';
import 'store.dart';

class LabScreen extends StatefulWidget {
  const LabScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  static const _systemInstruction =
      'You are the Progression Lab on-device analysis narrator. '
      'Use only the deterministic evidence in the supplied JSON. '
      'Never invent numbers, diagnose illness, prescribe supplements, or claim causation. '
      'State sample size, confidence, and major confounders. '
      'When evidence is insufficient, say so directly. Keep the response concise, practical, and plainspoken.';

  final _service = const GeminiNanoService();
  final _question = TextEditingController();
  GeminiNanoStatus? _status;
  bool _checking = false;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    if (widget.store.aiAnalysisEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshStatus());
    }
  }

  @override
  void dispose() {
    unawaited(_service.cancel());
    _question.dispose();
    super.dispose();
  }

  LabReport get _report => const LabAnalysisEngine().build(widget.store);

  Future<void> _refreshStatus() async {
    if (_checking || !mounted) return;
    setState(() => _checking = true);
    final status = await _service.status();
    if (!mounted) return;
    setState(() {
      _status = status;
      _checking = false;
    });
  }

  Future<void> _downloadModel() async {
    if (_checking || !mounted) return;
    setState(() => _checking = true);
    final status = await _service.download();
    if (!mounted) return;
    setState(() {
      _status = status;
      _checking = false;
    });
  }

  Future<void> _toggleAi(bool value) async {
    try {
      await widget.store.setAiAnalysisEnabled(value);
    } on Object {
      if (mounted) _snack('The AI setting could not be saved.');
      return;
    }
    if (!mounted) return;
    if (!value) {
      await _service.cancel();
      setState(() {
        _status = null;
        _generating = false;
      });
    } else {
      await _refreshStatus();
    }
  }

  Future<void> _generate({String? question}) async {
    if (_generating || !widget.store.aiAnalysisEnabled) return;
    final status = _status ?? await _service.status();
    if (!mounted) return;
    setState(() => _status = status);
    if (!status.canGenerate) {
      _snack(
        'Gemini Nano is not ready on this device. Lab Core remains available.',
      );
      return;
    }
    final report = _report;
    final prompt = report.toPromptPacket(question: question);
    final now = DateTime.now();
    if (question != null && question.trim().isNotEmpty) {
      await widget.store.addLabMessage(
        LabMessage(
          id: createRecordId('lab-user'),
          role: 'user',
          text: question.trim(),
          createdAt: now,
        ),
      );
    }
    if (!mounted) return;
    setState(() => _generating = true);
    try {
      final result = await _service.generate(
        systemInstruction: _systemInstruction,
        prompt: prompt,
      );
      if (result.text.isEmpty)
        throw StateError('Gemini returned an empty answer.');
      await widget.store.addLabMessage(
        LabMessage(
          id: createRecordId('lab-assistant'),
          role: 'assistant',
          text: result.text,
          createdAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      _question.clear();
      setState(
        () => _status = GeminiNanoStatus(
          availability: GeminiNanoAvailability.available,
          modelName: result.modelName ?? status.modelName,
        ),
      );
    } on PlatformException catch (error) {
      if (mounted) _snack(_friendlyAiError(error));
    } on Object catch (error) {
      if (mounted) _snack('The Lab could not complete that analysis: $error');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final report = _report;
      return Scaffold(
        body: BrandBackdrop(
          child: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  title: const Text('THE LAB'),
                  backgroundColor: BrandColors.ink.withValues(alpha: .94),
                  actions: [
                    IconButton(
                      tooltip: 'View analysis data packet',
                      onPressed: () => _showDataPacket(context, report),
                      icon: const Icon(Icons.data_object_rounded),
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
                  sliver: SliverList.list(
                    children: [
                      const _LabHero(),
                      const SizedBox(height: 18),
                      _AiControlPanel(
                        enabled: widget.store.aiAnalysisEnabled,
                        status: _status,
                        checking: _checking,
                        onChanged: _toggleAi,
                        onRefresh: _refreshStatus,
                        onDownload: _downloadModel,
                      ),
                      const SizedBox(height: 18),
                      _DataDomainPanel(store: widget.store),
                      const SizedBox(height: 22),
                      BrandSectionLabel(
                        'Lab Core evidence',
                        trailing: Text(
                          '${report.evidence.length} SIGNALS',
                          style: const TextStyle(
                            color: BrandColors.muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final evidence in report.evidence) ...[
                        LabEvidenceCard(evidence: evidence),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 12),
                      if (widget.store.aiAnalysisEnabled) ...[
                        GradientAction(
                          label: _generating
                              ? 'ANALYZING ON DEVICE'
                              : 'EXPLAIN THESE RESULTS WITH GEMINI',
                          icon: Icons.auto_awesome_rounded,
                          onPressed: _generating || _status?.canGenerate != true
                              ? null
                              : () => _generate(),
                        ),
                        const SizedBox(height: 22),
                        const BrandSectionLabel('Ask the Lab'),
                        const SizedBox(height: 10),
                        LabPanel(
                          accent: BrandColors.violet,
                          child: Column(
                            children: [
                              TextField(
                                controller: _question,
                                enabled: !_generating,
                                minLines: 2,
                                maxLines: 5,
                                decoration: const InputDecoration(
                                  hintText:
                                      'Example: Does caffeine appear to help my matched strength sessions?',
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed:
                                      _generating ||
                                          _status?.canGenerate != true
                                      ? null
                                      : () {
                                          final text = _question.text.trim();
                                          if (text.isEmpty) {
                                            _snack('Enter a question first.');
                                            return;
                                          }
                                          _generate(question: text);
                                        },
                                  icon: const Icon(Icons.send_rounded),
                                  label: const Text('ASK ON DEVICE'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        BrandSectionLabel(
                          'Saved Lab notes',
                          trailing: widget.store.labMessages.isEmpty
                              ? null
                              : TextButton(
                                  onPressed: () => _clearHistory(context),
                                  child: const Text('CLEAR'),
                                ),
                        ),
                        const SizedBox(height: 10),
                        _LabConversation(messages: widget.store.labMessages),
                      ],
                      const SizedBox(height: 20),
                      const Text(
                        'The Lab summarizes verified in-app calculations. It does not provide medical advice, prove causation, or recommend supplement doses.',
                        style: TextStyle(
                          color: BrandColors.muted,
                          fontSize: 11,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Future<void> _clearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Lab notes?'),
        content: const Text(
          'This deletes saved AI summaries and questions. Workout and input data stay intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CLEAR'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.store.clearLabMessages();
    } on Object {
      if (mounted) _snack('The saved Lab notes could not be cleared.');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class InputsPerformanceScreen extends StatelessWidget {
  const InputsPerformanceScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final report = const LabAnalysisEngine().build(store);
      return Scaffold(
        body: BrandBackdrop(
          child: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  title: const Text('INPUTS & PERFORMANCE'),
                  backgroundColor: BrandColors.ink.withValues(alpha: .94),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
                  sliver: SliverList.list(
                    children: [
                      const Text(
                        'Deterministic comparisons connect logged supplements, meals, and recovery with similar workouts. No AI is required.',
                        style: TextStyle(
                          color: BrandColors.muted,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (final evidence in report.evidence) ...[
                        LabEvidenceCard(evidence: evidence),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class LabEvidenceCard extends StatelessWidget {
  const LabEvidenceCard({super.key, required this.evidence});

  final LabEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final color = switch (evidence.confidence) {
      LabConfidence.insufficient => BrandColors.muted,
      LabConfidence.preliminary => BrandColors.cyan,
      LabConfidence.developing => BrandColors.violet,
      LabConfidence.stronger => BrandColors.magenta,
    };
    return LabPanel(
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                evidence.hasEnoughData
                    ? evidence.positive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded
                    : Icons.hourglass_top_rounded,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  evidence.title.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
              ),
              _ConfidenceChip(confidence: evidence.confidence),
            ],
          ),
          const SizedBox(height: 12),
          Text(evidence.finding, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 11),
          Text(
            evidence.comparison,
            style: const TextStyle(
              color: BrandColors.cyan,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${evidence.sampleLabel} · ${evidence.metric}',
            style: const TextStyle(color: BrandColors.muted, fontSize: 11),
          ),
          if (evidence.effectPercent case final double effect) ...[
            const SizedBox(height: 9),
            Text(
              '${effect >= 0 ? '+' : ''}${effect.toStringAsFixed(1)}%',
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          if (evidence.confounders.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              'Consider: ${evidence.confounders.join(', ')}',
              style: const TextStyle(
                color: BrandColors.muted,
                fontSize: 10,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LabHero extends StatelessWidget {
  const _LabHero();

  @override
  Widget build(BuildContext context) => LabPanel(
    accent: BrandColors.violet,
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabMark(size: 56),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WHAT IS MOVING THE NEEDLE?',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Lab Core calculates the evidence. Optional Gemini Nano explains it in plain language on supported Android devices.',
                style: TextStyle(color: BrandColors.muted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AiControlPanel extends StatelessWidget {
  const _AiControlPanel({
    required this.enabled,
    required this.status,
    required this.checking,
    required this.onChanged,
    required this.onRefresh,
    required this.onDownload,
  });

  final bool enabled;
  final GeminiNanoStatus? status;
  final bool checking;
  final ValueChanged<bool> onChanged;
  final VoidCallback onRefresh;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final description = !enabled
        ? 'Off. No model calls are made. Lab Core still works.'
        : checking
        ? 'Checking on-device Gemini Nano availability…'
        : _statusText(status);
    return LabPanel(
      accent: enabled ? BrandColors.cyan : BrandColors.line,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: enabled,
            onChanged: onChanged,
            secondary: const Icon(Icons.auto_awesome_rounded),
            title: const Text(
              'Use AI Analysis',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text(
              'Optional · off by default · no cloud fallback',
            ),
          ),
          const Divider(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (checking)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  _statusIcon(status),
                  color: _statusColor(status),
                  size: 20,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  description,
                  style: const TextStyle(color: BrandColors.muted, height: 1.4),
                ),
              ),
            ],
          ),
          if (enabled && !checking) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('CHECK STATUS'),
                  ),
                ),
                if (status?.canDownload == true) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onDownload,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('PREPARE MODEL'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DataDomainPanel extends StatelessWidget {
  const _DataDomainPanel({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) => LabPanel(
    accent: BrandColors.purple,
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      leading: const Icon(Icons.tune_rounded, color: BrandColors.violet),
      title: const Text(
        'DATA INCLUDED IN THE LAB',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        '${store.labDataDomains.length}/${LabDataDomain.values.length} categories enabled',
      ),
      children: [
        for (final domain in LabDataDomain.values)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: store.labDataDomains.contains(domain),
            title: Text(_domainLabel(domain)),
            onChanged: (value) {
              unawaited(
                store.setLabDataDomain(domain, value).catchError((Object _) {}),
              );
            },
          ),
      ],
    ),
  );
}

class _ConfidenceChip extends StatelessWidget {
  const _ConfidenceChip({required this.confidence});

  final LabConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final text = switch (confidence) {
      LabConfidence.insufficient => 'NEED DATA',
      LabConfidence.preliminary => 'PRELIMINARY',
      LabConfidence.developing => 'DEVELOPING',
      LabConfidence.stronger => 'STRONGER',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: BrandColors.muted,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: .6,
        ),
      ),
    );
  }
}

class _LabConversation extends StatelessWidget {
  const _LabConversation({required this.messages});

  final List<LabMessage> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const LabPanel(
        accent: BrandColors.line,
        child: Text(
          'No Gemini summaries have been saved yet.',
          style: TextStyle(color: BrandColors.muted),
        ),
      );
    }
    return Column(
      children: [
        for (final message in messages.reversed.take(10).toList().reversed) ...[
          Align(
            alignment: message.role == 'user'
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 640),
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: message.role == 'user'
                    ? BrandColors.purple.withValues(alpha: .22)
                    : BrandColors.panel,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: message.role == 'user'
                      ? BrandColors.violet.withValues(alpha: .24)
                      : BrandColors.line,
                ),
              ),
              child: Text(message.text, style: const TextStyle(height: 1.42)),
            ),
          ),
        ],
      ],
    );
  }
}

Future<void> _showDataPacket(BuildContext context, LabReport report) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .82,
        minChildSize: .5,
        maxChildSize: .95,
        builder: (context, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DATA USED FOR THIS ANALYSIS',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'This is the structured packet sent to Gemini Nano when AI analysis is enabled.',
                style: TextStyle(color: BrandColors.muted),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: SelectableText(
                    report.toPromptPacket(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _statusText(GeminiNanoStatus? status) {
  if (status == null) return 'Status has not been checked.';
  return switch (status.availability) {
    GeminiNanoAvailability.available =>
      'Ready on device${status.modelName == null ? '' : ' · ${status.modelName}'}.',
    GeminiNanoAvailability.downloadable =>
      'Supported. The on-device model needs to be prepared before use.',
    GeminiNanoAvailability.downloading =>
      'The on-device model is currently downloading.',
    GeminiNanoAvailability.unavailable =>
      status.message ?? 'Gemini Nano is unavailable on this device.',
    GeminiNanoAvailability.unsupported =>
      status.message ?? 'This device does not support Gemini Nano Prompt API.',
    GeminiNanoAvailability.error =>
      status.message ?? 'Gemini Nano status could not be determined.',
  };
}

IconData _statusIcon(GeminiNanoStatus? status) =>
    switch (status?.availability) {
      GeminiNanoAvailability.available => Icons.check_circle_rounded,
      GeminiNanoAvailability.downloadable => Icons.download_rounded,
      GeminiNanoAvailability.downloading => Icons.downloading_rounded,
      GeminiNanoAvailability.unavailable ||
      GeminiNanoAvailability.unsupported => Icons.phone_android_rounded,
      _ => Icons.info_outline_rounded,
    };

Color _statusColor(GeminiNanoStatus? status) => switch (status?.availability) {
  GeminiNanoAvailability.available => BrandColors.cyan,
  GeminiNanoAvailability.downloadable ||
  GeminiNanoAvailability.downloading => BrandColors.violet,
  GeminiNanoAvailability.unavailable ||
  GeminiNanoAvailability.unsupported => BrandColors.muted,
  _ => BrandColors.magenta,
};

String _domainLabel(LabDataDomain domain) => switch (domain) {
  LabDataDomain.workouts => 'Strength workouts and progress',
  LabDataDomain.supplements => 'Supplements and caffeine',
  LabDataDomain.meals => 'Meals and macros',
  LabDataDomain.hydration => 'Hydration and electrolytes',
  LabDataDomain.recovery => 'Sleep, stress, soreness, and workout response',
  LabDataDomain.bodyMetrics => 'Bodyweight and measurements',
  LabDataDomain.athletic => 'Athletic sessions and assessments',
};

String _friendlyAiError(PlatformException error) {
  final code = error.code.toLowerCase();
  if (code.contains('busy')) {
    return 'Gemini Nano is busy. Wait briefly and try again.';
  }
  if (code.contains('battery') || code.contains('quota')) {
    return 'The device has reached its current on-device AI usage limit. Try later.';
  }
  if (code.contains('background')) {
    return 'Keep the Lab open while Gemini Nano is analyzing.';
  }
  if (code.contains('cancel')) return 'The analysis was cancelled.';
  if (code.contains('unsupported') || code.contains('not_available')) {
    return 'Gemini Nano narration is not supported on this device. Lab Core still works.';
  }
  return error.message ?? 'Gemini Nano could not complete the analysis.';
}
