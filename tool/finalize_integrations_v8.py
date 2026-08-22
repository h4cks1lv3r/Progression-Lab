from __future__ import annotations

from pathlib import Path
import re

# Run the complete canonical PR #17/native bridge finalization first.
import finalize_integrations_v6  # noqa: F401


hub = Path("lib/integrations_hub.dart")
text = hub.read_text()

# Dart formatting can wrap the external-workout value across lines. Insert the
# new preference by its map key instead of depending on the surrounding layout.
if "'healthBodyMetrics': healthBodyMetrics" not in text:
    marker = "      'externalWorkouts':"
    index = text.find(marker)
    if index < 0:
        raise RuntimeError("The external workout preference key was not found")
    addition = """      'healthBodyMetrics': healthBodyMetrics
          .map((item) => item.toJson())
          .toList(),
"""
    text = text[:index] + addition + text[index:]
    hub.write_text(text)

# v7 exposes bodyweight and body-fat exchange through the visible hub. Its v6
# import is already cached, so the native finalization is not repeated.
import finalize_integrations_v7  # noqa: E402,F401


def repair_health_metric_chronology() -> None:
    path = Path("lib/integrations_hub.dart")
    text = path.read_text().replace(
        "metric.value.toStringAsFixed(metric.type == 'bodyWeight' ? 1 : 1)",
        "metric.value.toStringAsFixed(1)",
    )

    start = text.find("  Future<void> addHealthBodyMetrics(")
    end = text.find("\n  Future<void> addExternalWorkouts(", start)
    if start < 0 or end < 0:
        raise RuntimeError("The health body-metric import method was not bounded")
    section = text[start:end]
    section = section.replace(
        "      final now = DateTime.now();",
        "      final recordTime = value.recordedAt.toLocal();",
        1,
    )
    section = section.replace(
        "          createdAt: existing?.createdAt ?? now,",
        "          createdAt: existing?.createdAt ?? recordTime,",
        1,
    )
    section = section.replace(
        "          updatedAt: now,",
        "          updatedAt: existing?.updatedAt ?? recordTime,",
        1,
    )
    text = text[:start] + section + text[end:]
    text = re.sub(
        r"\.\.sort\(\(a, b\) => a\.updatedAt\.compareTo\(b\.updatedAt\)\);",
        "..sort((a, b) => a.localDate.compareTo(b.localDate));",
        text,
        count=1,
    )
    text = text.replace(
        "                  final entry = latestLocalWeight!;",
        "                  final entry = latestLocalWeight;",
        1,
    )
    path.write_text(text)


def repair_advanced_share_flow() -> None:
    path = Path("lib/share_card.dart")
    text = path.read_text()
    if "import 'brand.dart';" not in text:
        text = text.replace(
            "import 'package:flutter/services.dart';\n",
            "import 'package:flutter/services.dart';\n\nimport 'brand.dart';",
            1,
        )
    text = text.replace("Brand.accent", "BrandColors.violet")

    if "class WorkoutSharePreviewScreen extends StatefulWidget" not in text:
        text = text.rstrip() + """


class WorkoutSharePreviewScreen extends StatefulWidget {
  const WorkoutSharePreviewScreen({super.key, required this.data});

  final WorkoutShareData data;

  @override
  State<WorkoutSharePreviewScreen> createState() =>
      _WorkoutSharePreviewScreenState();
}

class _WorkoutSharePreviewScreenState
    extends State<WorkoutSharePreviewScreen> {
  late final Future<Uint8List> _image;
  bool _saving = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _image = WorkoutShareCardGenerator.generate(widget.data);
  }

  Future<void> _save(Uint8List bytes) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final location = await ShareImageBridge.savePng(
        bytes,
        shareFileName(widget.data.completedAt),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            location == null
                ? 'Saving images is unavailable on this platform.'
                : 'Share card saved.',
          ),
        ),
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not save the image.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share(Uint8List bytes) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await ShareImageBridge.sharePng(
        bytes,
        shareFileName(widget.data.completedAt),
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not share the image.')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Share workout')),
    body: BrandBackdrop(
      child: FutureBuilder<Uint8List>(
        future: _image,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not generate the share card.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final bytes = snapshot.data;
          if (bytes == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : () => _save(bytes),
                          icon: Icon(
                            _saving
                                ? Icons.hourglass_top_rounded
                                : Icons.download_rounded,
                          ),
                          label: Text(_saving ? 'SAVING' : 'SAVE IMAGE'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _sharing ? null : () => _share(bytes),
                          icon: Icon(
                            _sharing
                                ? Icons.hourglass_top_rounded
                                : Icons.share_rounded,
                          ),
                          label: Text(_sharing ? 'OPENING' : 'SHARE'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

Future<void> showWorkoutCompleteSheet(
  BuildContext context,
  WorkoutShareData data,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (sheetContext) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const LabMark(size: 68),
          const SizedBox(height: 16),
          const Text(
            'WORKOUT COMPLETE',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: BrandColors.muted, fontSize: 16),
          ),
          const SizedBox(height: 20),
          GradientAction(
            label: 'CREATE STORY CARD',
            icon: Icons.auto_awesome_rounded,
            onPressed: () => Navigator.push(
              sheetContext,
              MaterialPageRoute<void>(
                builder: (_) => WorkoutSharePreviewScreen(data: data),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: const Text('DONE'),
            ),
          ),
        ],
      ),
    ),
  ),
);

String formatShareDuration(Duration value) {
  final minutes = value.inMinutes;
  if (minutes < 1) return '<1 MIN';
  if (minutes < 60) return '$minutes MIN';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0 ? '$hours HR' : '$hours HR $remainder MIN';
}
""".lstrip("\n")
    path.write_text(text)


repair_health_metric_chronology()
repair_advanced_share_flow()
