from __future__ import annotations

from pathlib import Path

import finalize_integrations as base


_original_update_ios_app_delegate = base.update_ios_app_delegate


def update_ios_app_delegate_compat() -> None:
    path = Path("ios/Runner/AppDelegate.swift")
    text = path.read_text()
    if "IntegrationBridgeIOS.shared.register" in text:
        return

    implicit_engine_marker = "let messenger = registrar.messenger()"
    marker_index = text.find(implicit_engine_marker)
    if marker_index >= 0 and "didInitializeImplicitFlutterEngine" in text:
        line_end = text.find("\n", marker_index)
        if line_end < 0:
            raise RuntimeError("The implicit-engine messenger line did not terminate")
        insertion = """
    if let controller = window?.rootViewController {
      IntegrationBridgeIOS.shared.register(
        messenger: messenger,
        viewController: controller
      )
    }
"""
        path.write_text(text[: line_end + 1] + insertion + text[line_end + 1 :])
        return

    _original_update_ios_app_delegate()


base.update_ios_app_delegate = update_ios_app_delegate_compat

# Importing v5 runs the complete canonical finalization after the compatibility
# override above has been installed.
import finalize_integrations_v5  # noqa: E402,F401
