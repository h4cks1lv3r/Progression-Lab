from __future__ import annotations

from pathlib import Path

# v7 runs the complete canonical PR #17/native bridge finalization first, then
# exposes bodyweight and body-fat exchange through the integrations hub.
import finalize_integrations_v7  # noqa: F401


hub = Path("lib/integrations_hub.dart")
text = hub.read_text().replace(
    "metric.value.toStringAsFixed(metric.type == 'bodyWeight' ? 1 : 1)",
    "metric.value.toStringAsFixed(1)",
)
hub.write_text(text)
