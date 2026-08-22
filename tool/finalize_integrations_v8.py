from __future__ import annotations

from pathlib import Path

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


text = hub.read_text().replace(
    "metric.value.toStringAsFixed(metric.type == 'bodyWeight' ? 1 : 1)",
    "metric.value.toStringAsFixed(1)",
)
hub.write_text(text)
