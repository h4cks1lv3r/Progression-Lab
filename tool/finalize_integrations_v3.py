from __future__ import annotations

from pathlib import Path
import re
import shutil

# Importing v2 performs the baseline dependency, native-project, and menu work.
import finalize_integrations_v2  # noqa: F401


def balanced_end(text: str, open_index: int, opening: str = "{", closing: str = "}") -> int:
    depth = 0
    quote: str | None = None
    escaped = False
    for index in range(open_index, len(text)):
        char = text[index]
        if quote is not None:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            continue
        if char in "'\"":
            quote = char
        elif char == opening:
            depth += 1
        elif char == closing:
            depth -= 1
            if depth == 0:
                return index + 1
    raise RuntimeError("Unbalanced source block")


def fix_dart_sources() -> None:
    path = Path("lib/external_workout_formats.dart")
    text = path.read_text()
    text = text.replace(
        "final dataEnd = math.min(bytes.length, dataStart + dataSize);",
        "final dataEnd = math.min(bytes.length, dataStart + dataSize).toInt();",
    )
    text = text.replace(
        "math.max(0, endedAt.difference(startedAt).inMilliseconds / 1000),",
        "math.max(0, endedAt.difference(startedAt).inMilliseconds / 1000).toDouble(),",
    )
    # Traditional switch statements must not accidentally fall through.
    text = text.replace(
        """      case 0:
        _fileCreatedAt = _fitDate(values[4]);
      case 18:
""",
        """      case 0:
        _fileCreatedAt = _fitDate(values[4]);
        break;
      case 18:
""",
    )
    text = text.replace(
        """          if (values[20] != null) 'averagePower': values[20]!,
        });
      case 20:
""",
        """          if (values[20] != null) 'averagePower': values[20]!,
        });
        break;
      case 20:
""",
    )
    text = text.replace(
        """            powerWatts: values[7]?.toInt(),
          ),
        );
    }
""",
        """            powerWatts: values[7]?.toInt(),
          ),
        );
        break;
      default:
        break;
    }
""",
    )
    path.write_text(text)

    path = Path("lib/lab_experiments.dart")
    text = path.read_text().replace(
        "LabExperimentMetric.workoutCompletion => 1,",
        "LabExperimentMetric.workoutCompletion => 1.0,",
    )
    path.write_text(text)

    path = Path("lib/share_options.dart")
    text = path.read_text()
    text = text.replace(
        """      case WorkoutShareTemplate.cleanPerformance:
        _paintClean(canvas, size, snapshot, preferences.privacy);
      case WorkoutShareTemplate.achievement:
""",
        """      case WorkoutShareTemplate.cleanPerformance:
        _paintClean(canvas, size, snapshot, preferences.privacy);
        break;
      case WorkoutShareTemplate.achievement:
""",
    )
    text = text.replace(
        """      case WorkoutShareTemplate.achievement:
        _paintAchievement(canvas, size, snapshot, preferences.privacy);
      case WorkoutShareTemplate.sessionRecap:
""",
        """      case WorkoutShareTemplate.achievement:
        _paintAchievement(canvas, size, snapshot, preferences.privacy);
        break;
      case WorkoutShareTemplate.sessionRecap:
""",
    )
    text = text.replace(
        """      case WorkoutShareTemplate.sessionRecap:
        _paintRecap(canvas, size, snapshot, preferences.privacy);
    }
""",
        """      case WorkoutShareTemplate.sessionRecap:
        _paintRecap(canvas, size, snapshot, preferences.privacy);
        break;
    }
""",
    )
    if "static WorkoutSharePreferences currentPreferences" not in text:
        marker = "abstract final class AdvancedWorkoutShareCardGenerator {"
        text = text.replace(
            marker,
            marker
            + "\n  static WorkoutSharePreferences currentPreferences = const WorkoutSharePreferences();\n",
            1,
        )
    path.write_text(text)


def harden_native_source() -> None:
    hardened = Path("tool/IntegrationBridge.hardened.kt")
    if hardened.exists():
        shutil.copyfile(
            hardened,
            Path("android/app/src/main/kotlin/com/h4cks1lv3/iron_cadence/IntegrationBridge.kt"),
        )

    # MainActivity must forward legacy activity results used by FlutterActivity.
    path = Path("android/app/src/main/kotlin/com/h4cks1lv3/iron_cadence/MainActivity.kt")
    text = path.read_text()
    if "integrationBridge?.onActivityResult(requestCode, resultCode, data)" not in text:
        close = text.rfind("}")
        insertion = """
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (integrationBridge?.onActivityResult(requestCode, resultCode, data) == true) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

"""
        text = text[:close] + insertion + text[close:]
    path.write_text(text)

    # Accept ISO-8601 strings with or without fractional seconds on iOS.
    path = Path("ios/Runner/IntegrationBridge.swift")
    text = path.read_text()
    text = text.replace(
        """  private func isoDate(_ value: Any?) -> Date? {
    guard let value = value as? String else { return nil }
    return ISO8601DateFormatter.progressionLab.date(from: value)
  }
""",
        """  private func isoDate(_ value: Any?) -> Date? {
    guard let value = value as? String else { return nil }
    return ISO8601DateFormatter.progressionLab.date(from: value)
      ?? ISO8601DateFormatter.progressionLabWholeSeconds.date(from: value)
  }
""",
    )
    if "progressionLabWholeSeconds" not in text:
        text = text.replace(
            """private extension ISO8601DateFormatter {
  static let progressionLab: ISO8601DateFormatter = {
""",
            """private extension ISO8601DateFormatter {
  static let progressionLabWholeSeconds: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  static let progressionLab: ISO8601DateFormatter = {
""",
            1,
        )
    path.write_text(text)


def integrate_store_state() -> None:
    path = Path("lib/store.dart")
    text = path.read_text()
    if "Map<String, dynamic> integrationState" not in text:
        class_index = text.find("class AppStore extends ChangeNotifier {")
        if class_index < 0:
            raise RuntimeError("AppStore class not found")
        insert_at = text.find("\n", class_index) + 1
        text = (
            text[:insert_at]
            + "  Map<String, dynamic> integrationState = <String, dynamic>{};\n"
            + text[insert_at:]
        )

    # Load from current state immediately after migration.
    load_anchor = "final data = _migrate(original);"
    if "final storedIntegrationState = data['integrationState'];" not in text:
        index = text.find(load_anchor)
        if index < 0:
            raise RuntimeError("AppStore migration load anchor not found")
        line_end = text.find("\n", index)
        insertion = """
          final storedIntegrationState = data['integrationState'];
          integrationState = storedIntegrationState is Map
              ? Map<String, dynamic>.from(storedIntegrationState)
              : <String, dynamic>{};
"""
        text = text[: line_end + 1] + insertion + text[line_end + 1 :]

    # Include integration state in every exact export/save.
    if "'integrationState': integrationState," not in text:
        export_match = re.search(
            r"Map<String,\s*dynamic>\s+exportState\s*\([^)]*\)\s*=>\s*\{",
            text,
        )
        if export_match is None:
            export_match = re.search(
                r"Map<String,\s*dynamic>\s+exportState\s*\([^)]*\)\s*\{",
                text,
            )
        if export_match is None:
            raise RuntimeError("AppStore exportState method not found")
        brace = text.find("{", export_match.start())
        text = text[: brace + 1] + "\n    'integrationState': integrationState," + text[brace + 1 :]

    # Restore integration state before applying the remaining imported values.
    if "integrationState = importedIntegrationState is Map" not in text:
        restore = re.search(
            r"Future<void>\s+restoreState\s*\(\s*Map<String,\s*dynamic>\s+[A-Za-z_][A-Za-z0-9_]*\s*\)\s*async\s*\{",
            text,
        )
        if restore is not None:
            argument = re.search(
                r"restoreState\s*\(\s*Map<String,\s*dynamic>\s+([A-Za-z_][A-Za-z0-9_]*)",
                restore.group(0),
            ).group(1)
            line_end = text.find("\n", restore.end())
            insertion = f"""
    final importedIntegrationState = {argument}['integrationState'];
    integrationState = importedIntegrationState is Map
        ? Map<String, dynamic>.from(importedIntegrationState)
        : <String, dynamic>{{}};
"""
            text = text[: line_end + 1] + insertion + text[line_end + 1 :]

    # Ensure all migrations have a non-null integration-state object.
    if "data.putIfAbsent('integrationState'" not in text:
        migrate = re.search(
            r"static\s+Map<String,\s*dynamic>\s+_migrate\s*\([^)]*\)\s*\{",
            text,
        )
        if migrate is None:
            raise RuntimeError("AppStore migration function not found")
        end = balanced_end(text, text.find("{", migrate.start()))
        return_index = text.rfind("return data;", migrate.start(), end)
        if return_index < 0:
            raise RuntimeError("AppStore migration return not found")
        insertion = """data.putIfAbsent('integrationState', () => <String, dynamic>{});
    data['schemaVersion'] = schemaVersion;
    """
        text = text[:return_index] + insertion + text[return_index:]

    if "Future<void> setIntegrationState(" not in text:
        anchor = re.search(r"\n\s*static\s+int\?\s+_readInt\s*\(", text)
        if anchor is None:
            raise RuntimeError("AppStore helper insertion point not found")
        method = """

  Future<void> setIntegrationState(Map<String, dynamic> value) async {
    final previous = integrationState;
    integrationState = Map<String, dynamic>.from(value);
    try {
      await save();
    } on Object {
      integrationState = previous;
      rethrow;
    }
    notifyListeners();
  }
"""
        text = text[: anchor.start()] + method + text[anchor.start() :]

    # Advance the schema once for this additive state.
    schema = re.search(r"static\s+const\s+int\s+schemaVersion\s*=\s*(\d+)\s*;", text)
    if schema is not None:
        current = int(schema.group(1))
        if current < 15:
            text = text[: schema.start(1)] + "15" + text[schema.end(1) :]

    path.write_text(text)


def persist_integration_preferences() -> None:
    path = Path("lib/integrations_hub.dart")
    text = path.read_text()
    text = text.replace(
        """class IntegrationPreferencesStore extends ChangeNotifier {
  IntegrationPreferencesStore({MethodChannel? channel})
      : _channel = channel ??
            const MethodChannel('progression_lab/integration_preferences');

  final MethodChannel _channel;
""",
        """class IntegrationPreferencesStore extends ChangeNotifier {
  IntegrationPreferencesStore({
    required AppStore store,
    MethodChannel? channel,
  })  : _store = store,
        _channel = channel ??
            const MethodChannel('progression_lab/integration_preferences');

  final AppStore _store;
  final MethodChannel _channel;
""",
    )
    text = text.replace(
        """    try {
      final raw = await _channel.invokeMethod<String>('read');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
""",
        """    try {
      Map<String, dynamic>? decodedMap;
      final embedded = _store.integrationState['integrations'];
      if (embedded is Map) {
        decodedMap = Map<String, dynamic>.from(embedded);
      } else {
        final raw = await _channel.invokeMethod<String>('read');
        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map) decodedMap = Map<String, dynamic>.from(decoded);
        }
      }
      if (decodedMap != null) {
        final decoded = decodedMap;
""",
    )
    text = text.replace(
        """        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
""",
        """        {
          final map = Map<String, dynamic>.from(decoded);
""",
        1,
    )
    old_save = re.search(
        r"  Future<void> save\(\) async \{.*?\n  \}\n\n  Future<void> addExperiment",
        text,
        re.S,
    )
    if old_save is None:
        raise RuntimeError("IntegrationPreferencesStore.save not found")
    new_save = """  Future<void> save() async {
    final data = <String, dynamic>{
      'experiments': experiments.map((item) => item.toJson()).toList(),
      'sharePreferences': sharePreferences.toJson(),
      'weeklyReviewEnabled': weeklyReviewEnabled,
      'externalWorkouts': externalWorkouts.map((item) => item.toJson()).toList(),
    };
    final merged = Map<String, dynamic>.from(_store.integrationState)
      ..['integrations'] = data;
    await _store.setIntegrationState(merged);
    try {
      await _channel.invokeMethod<void>('write', jsonEncode(data));
    } on PlatformException {
      // The exact .plab state remains authoritative if optional platform
      // preference mirroring is unavailable.
    }
  }

  Future<void> addExperiment"""
    text = text[: old_save.start()] + new_save + text[old_save.end() :]
    text = text.replace(
        "_preferences = IntegrationPreferencesStore()..addListener(_refresh);",
        "_preferences = IntegrationPreferencesStore(store: widget.store)..addListener(_refresh);",
    )
    if "AdvancedWorkoutShareCardGenerator.currentPreferences = sharePreferences;" not in text:
        anchor = "weeklyReviewEnabled = map['weeklyReviewEnabled'] == true;"
        text = text.replace(
            anchor,
            anchor + "\n          AdvancedWorkoutShareCardGenerator.currentPreferences = sharePreferences;",
            1,
        )
        save_anchor = "sharePreferences = value;"
        text = text.replace(
            save_anchor,
            save_anchor
            + "\n    AdvancedWorkoutShareCardGenerator.currentPreferences = sharePreferences;",
            1,
        )
    path.write_text(text)


def persist_contextual_guides() -> None:
    path = Path("lib/contextual_guides.dart")
    text = path.read_text()
    if "import 'store.dart';" not in text:
        imports = list(re.finditer(r"^import\s+[^;]+;\s*$", text, re.M))
        pos = imports[-1].end()
        text = text[:pos] + "\nimport 'store.dart';" + text[pos:]
    text = text.replace(
        """  ContextualGuideState({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('progression_lab/guide_state');

  final MethodChannel _channel;
""",
        """  ContextualGuideState({
    AppStore? store,
    MethodChannel? channel,
  })  : _store = store,
        _channel = channel ?? const MethodChannel('progression_lab/guide_state');

  final AppStore? _store;
  final MethodChannel _channel;
""",
    )
    text = text.replace(
        """    try {
      final data = await _channel.invokeMapMethod<Object?, Object?>('read');
""",
        """    try {
      Map<Object?, Object?>? data;
      final embedded = _store?.integrationState['contextualGuides'];
      if (embedded is Map) {
        data = Map<Object?, Object?>.from(embedded);
      } else {
        data = await _channel.invokeMapMethod<Object?, Object?>('read');
      }
""",
    )
    save_match = re.search(
        r"  Future<void> _save\(\) async \{.*?\n  \}\n\}",
        text,
        re.S,
    )
    if save_match is None:
        raise RuntimeError("ContextualGuideState._save not found")
    new_save = """  Future<void> _save() async {
    final data = <String, Object>{
      'tipsEnabled': _tipsEnabled,
      'seen': _seen.map((item) => item.name).toList(),
    };
    final store = _store;
    if (store != null) {
      final merged = Map<String, dynamic>.from(store.integrationState)
        ..['contextualGuides'] = data;
      await store.setIntegrationState(merged);
    }
    try {
      await _channel.invokeMethod<void>('write', data);
    } on PlatformException {
      // Exact app state remains available when platform mirroring fails.
    }
  }
}"""
    text = text[: save_match.start()] + new_save + text[save_match.end() :]
    Path("lib/contextual_guides.dart").write_text(text)

    path = Path("lib/integrations_hub.dart")
    text = path.read_text().replace(
        "_guides = ContextualGuideState()..addListener(_refresh);",
        "_guides = ContextualGuideState(store: widget.store)..addListener(_refresh);",
    )
    path.write_text(text)


def wire_automatic_cloud_sync() -> None:
    path = Path("lib/cloud_sync.dart")
    text = path.read_text()
    if "static final Expando<CloudBackupSyncService>" not in text:
        marker = "class CloudBackupSyncService extends ChangeNotifier {"
        addition = """
  static final Expando<CloudBackupSyncService> _shared =
      Expando<CloudBackupSyncService>('progression-lab-cloud-sync');

  static CloudBackupSyncService shared(AppStore store) =>
      _shared[store] ??= CloudBackupSyncService(store: store);
"""
        text = text.replace(marker, marker + addition, 1)
    path.write_text(text)

    path = Path("lib/integrations_hub.dart")
    text = path.read_text().replace(
        "_cloud = CloudBackupSyncService(store: widget.store)..addListener(_refresh);",
        "_cloud = CloudBackupSyncService.shared(widget.store)..addListener(_refresh);",
    )
    text = text.replace(
        "    _cloud.dispose();\n",
        "    _cloud.removeListener(_refresh);\n",
    )
    path.write_text(text)

    path = Path("lib/main.dart")
    text = path.read_text()
    if "import 'cloud_sync.dart';" not in text:
        imports = list(re.finditer(r"^import\s+[^;]+;\s*$", text, re.M))
        pos = imports[-1].end()
        text = text[:pos] + "\nimport 'cloud_sync.dart';" + text[pos:]
    if "CloudBackupSyncService? _automaticCloudSync;" not in text:
        state = re.search(r"class\s+_ProgressionLabAppState\s+extends\s+State<[^>]+>\s*\{", text)
        if state is not None:
            text = text[: state.end()] + "\n  CloudBackupSyncService? _automaticCloudSync;\n" + text[state.end() :]
            init = re.search(r"\n\s*void\s+initState\s*\(\)\s*\{", text[state.end() :])
            if init is not None:
                init_start = state.end() + init.end()
                insertion = """
    _automaticCloudSync = CloudBackupSyncService.shared(store);
    unawaited(_automaticCloudSync!.initialize());
"""
                line_end = text.find("\n", init_start)
                text = text[: line_end + 1] + insertion + text[line_end + 1 :]
            dispose = re.search(r"\n\s*void\s+dispose\s*\(\)\s*\{", text)
            if dispose is not None:
                line_end = text.find("\n", dispose.end())
                text = text[: line_end + 1] + "    _automaticCloudSync?.dispose();\n" + text[line_end + 1 :]
    if "unawaited(" in text and "import 'dart:async';" not in text:
        text = "import 'dart:async';\n\n" + text
    path.write_text(text)


def delegate_legacy_share_generator() -> None:
    path = Path("lib/share_card.dart")
    text = path.read_text()
    if "import 'share_options.dart';" not in text:
        imports = list(re.finditer(r"^import\s+[^;]+;\s*$", text, re.M))
        pos = imports[-1].end()
        text = text[:pos] + "\nimport 'share_options.dart';" + text[pos:]
    signature = re.search(
        r"static\s+Future<Uint8List>\s+generate\s*\(\s*WorkoutShareData\s+data\s*\)\s*async\s*\{",
        text,
    )
    if signature is not None and "AdvancedWorkoutShareCardGenerator.generate" not in text[signature.start(): signature.start() + 900]:
        open_brace = text.find("{", signature.start())
        end = balanced_end(text, open_brace)
        replacement = """{
    int metricInt(String label) {
      for (final metric in data.metrics) {
        if (metric.label.toLowerCase() == label.toLowerCase()) {
          return int.tryParse(metric.value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        }
      }
      return 0;
    }

    double? metricDouble(String label) {
      for (final metric in data.metrics) {
        if (metric.label.toLowerCase() == label.toLowerCase()) {
          final value = metric.value.toUpperCase();
          final number = double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
          if (number == null) return null;
          if (value.contains('M')) return number * 1000000;
          if (value.contains('K')) return number * 1000;
          return number;
        }
      }
      return null;
    }

    final snapshot = ShareWorkoutSnapshot(
      program: data.program,
      workout: data.title,
      completedAt: data.completedAt,
      duration: Duration(minutes: metricInt('Duration')),
      sets: metricInt('Sets'),
      exercises: metricInt('Exercises'),
      volume: metricDouble('Volume'),
      phaseLabel: data.contextLine,
      achievement: data.achievementLabel,
      highlights: <ShareHighlight>[
        if (data.highlightValue.isNotEmpty)
          ShareHighlight(
            data.highlightLabel.isEmpty ? 'Highlight' : data.highlightLabel,
            data.highlightValue,
            sensitiveWeight: true,
          ),
      ],
    );
    return AdvancedWorkoutShareCardGenerator.generate(
      snapshot,
      AdvancedWorkoutShareCardGenerator.currentPreferences,
    );
  }"""
        text = text[:open_brace] + replacement + text[end:]
    path.write_text(text)


def bump_version_and_docs() -> None:
    path = Path("pubspec.yaml")
    text = re.sub(r"^version:\s*[^\n]+", "version: 2.1.0+14", path.read_text(), count=1, flags=re.M)
    path.write_text(text)

    path = Path("android/app/build.gradle.kts")
    text = path.read_text()
    text = re.sub(r"versionCode\s*=\s*\d+", "versionCode = 14", text)
    text = re.sub(r'versionName\s*=\s*"[^"]+"', 'versionName = "2.1.0"', text)
    path.write_text(text)

    readme = Path("README.md")
    if readme.exists():
        text = readme.read_text().replace("Current version: **2.0.0+13**", "Current version: **2.1.0+14**")
        readme.write_text(text)

    changelog = Path("CHANGELOG.md")
    if changelog.exists():
        text = changelog.read_text()
        if "## 2.1.0+14" not in text:
            entry = """## 2.1.0+14 — 2026-08-21

### Added

- Health Connect and Apple Health authorization, workout-summary sync, and body-metric exchange.
- Local FIT, TCX, and GPX import for wearable and endurance activity history.
- Secure Strava and Garmin provider adapters with PKCE and protected OAuth-broker configuration.
- User-selected automatic cloud backup through Android document providers and iOS Files/iCloud Drive.
- Clean Performance, Achievement, and Session Recap social templates in Story, portrait-feed, and square formats.
- Share-card privacy controls and mature branded caption generation.
- Deterministic personal Lab experiments and user-triggered weekly evidence reviews.
- Replayable contextual coach marks and Reset All Tips.
- Connections & Experiments hub for health, providers, imports, cloud, sharing, experiments, and guides.
- Exact backup coverage for integration preferences, imported external activities, experiments, share settings, and contextual-guide state.

### Security

- Provider client secrets are never embedded in the mobile app.
- OAuth uses PKCE and short-lived device sessions stored in EncryptedSharedPreferences or the iOS Keychain.
- Cloud backups use a folder explicitly selected by the user; Progression Lab does not receive the provider account credentials.

"""
            heading = text.find("\n", text.find("# Changelog")) + 1
            text = text[:heading] + "\n" + entry + text[heading:]
            changelog.write_text(text)


fix_dart_sources()
harden_native_source()
integrate_store_state()
persist_integration_preferences()
persist_contextual_guides()
wire_automatic_cloud_sync()
delegate_legacy_share_generator()
bump_version_and_docs()
