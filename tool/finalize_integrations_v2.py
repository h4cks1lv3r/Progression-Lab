from __future__ import annotations

from pathlib import Path
import re

import finalize_integrations as base


def balanced_block(text: str, start: int) -> tuple[int, str] | None:
    open_pos = text.find("(", start)
    if open_pos < 0:
        return None
    depth = 0
    quote: str | None = None
    escaped = False
    for index in range(open_pos, len(text)):
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
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                end = index + 1
                while end < len(text) and text[end] in " ,\n":
                    end += 1
                return end, text[start:end]
    return None


def update_main_menu() -> None:
    path = Path("lib/main.dart")
    base.insert_after_last_import(path, "import 'integrations_hub.dart';")
    text = path.read_text()
    if "Connections & Experiments" in text:
        return

    marker_index = text.find("Data & Backup")
    route_index = text.find("DataManagementScreen")
    if marker_index < 0 or route_index < 0:
        raise RuntimeError("Data & Backup route was not found in main.dart")

    line_starts = [0]
    line_starts.extend(match.end() for match in re.finditer("\n", text[: min(marker_index, route_index)]))
    candidates: list[tuple[int, int, str]] = []
    for start in reversed(line_starts):
        line_end = text.find("\n", start)
        if line_end < 0:
            line_end = len(text)
        line = text[start:line_end]
        if re.match(r"\s*[A-Za-z_][A-Za-z0-9_<>]*\s*\(", line) is None:
            continue
        block = balanced_block(text, start)
        if block is None:
            continue
        end, value = block
        if "Data & Backup" in value and "DataManagementScreen" in value:
            candidates.append((start, end, value))
            break
    if not candidates:
        raise RuntimeError("Could not isolate the complete Data & Backup tile")
    start, end, block = candidates[0]
    clone = block.replace("Data & Backup", "Connections & Experiments", 1)
    clone = clone.replace("DataManagementScreen", "IntegrationsHubScreen")
    clone = re.sub(r"Icons\.[A-Za-z0-9_]+", "Icons.hub_rounded", clone, count=1)

    # Replace one descriptive string, but never the title or route name.
    matches = list(re.finditer(r"'([^'\\]|\\.)*'", clone))
    for match in matches:
        value = match.group(0)
        lower = value.lower()
        if "connections & experiments" in lower:
            continue
        if any(word in lower for word in ("backup", "restore", "import", "export", "data")):
            clone = (
                clone[: match.start()]
                + "'Health, wearables, cloud sync, sharing, and Lab experiments.'"
                + clone[match.end() :]
            )
            break
    path.write_text(text[:end] + clone + text[end:])


base.update_main_menu = update_main_menu
base.main()

# Dart's clamp returns num. Make the coach-card position explicitly double.
contextual = Path("lib/contextual_guides.dart")
text = contextual.read_text()
text = text.replace(
    ".clamp(16.0, screen.width - cardWidth - 16.0);",
    ".clamp(16.0, screen.width - cardWidth - 16.0).toDouble();",
)
contextual.write_text(text)

# iOS document-picker bookmarks are portable with default bookmark options.
swift = Path("ios/Runner/IntegrationBridge.swift")
text = swift.read_text()
text = text.replace("options: [.withSecurityScope]", "options: []")
text = text.replace("options: [.withSecurityScope],", "options: [],")
swift.write_text(text)

# Restore the archived external-workout summaries when optional preferences load.
hub = Path("lib/integrations_hub.dart")
text = hub.read_text()
needle = """          weeklyReviewEnabled = map['weeklyReviewEnabled'] == true;
"""
replacement = """          weeklyReviewEnabled = map['weeklyReviewEnabled'] == true;
          final rawExternal = map['externalWorkouts'];
          if (rawExternal is List) {
            externalWorkouts
              ..clear()
              ..addAll(
                rawExternal.whereType<Map>().map((raw) {
                  final value = Map<String, dynamic>.from(raw);
                  final start = DateTime.parse('${value['startedAt']}').toUtc();
                  final end = DateTime.parse('${value['endedAt']}').toUtc();
                  ExternalWorkoutSource source = ExternalWorkoutSource.file;
                  ExternalWorkoutFormat format = ExternalWorkoutFormat.fit;
                  for (final candidate in ExternalWorkoutSource.values) {
                    if (candidate.name == '${value['source']}') source = candidate;
                  }
                  for (final candidate in ExternalWorkoutFormat.values) {
                    if (candidate.name == '${value['format']}') format = candidate;
                  }
                  return ExternalWorkout(
                    id: '${value['id']}',
                    source: source,
                    format: format,
                    title: '${value['title']}',
                    sport: '${value['sport']}',
                    startedAt: start,
                    endedAt: end,
                    distanceMeters: (value['distanceMeters'] as num?)?.toDouble(),
                    durationSeconds: (value['durationSeconds'] as num?)?.toDouble(),
                    calories: (value['calories'] as num?)?.toInt(),
                    averageHeartRate: (value['averageHeartRate'] as num?)?.toInt(),
                    maximumHeartRate: (value['maximumHeartRate'] as num?)?.toInt(),
                    averageCadence: (value['averageCadence'] as num?)?.toInt(),
                    averagePowerWatts: (value['averagePowerWatts'] as num?)?.toInt(),
                    notes: value['notes'] is String ? value['notes'] as String : '',
                    metadata: value['metadata'] is Map
                        ? Map<String, dynamic>.from(value['metadata'] as Map)
                        : const <String, dynamic>{},
                  );
                }),
              );
          }
"""
if needle in text and "final rawExternal = map['externalWorkouts'];" not in text:
    text = text.replace(needle, replacement, 1)
hub.write_text(text)
