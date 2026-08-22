from __future__ import annotations

from pathlib import Path
import re

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


def repair_ios_project_membership() -> None:
    project = Path("ios/Runner.xcodeproj/project.pbxproj")
    text = project.read_text()
    build_match = re.search(
        r"([A-F0-9]{24}) /\* IntegrationBridge\.swift in Sources \*/ =",
        text,
    )
    if build_match is None:
        raise RuntimeError("IntegrationBridge.swift build reference was not found")
    build_ref = build_match.group(1)
    entry = f"{build_ref} /* IntegrationBridge.swift in Sources */"

    # The original finalizer selected the first Sources phase, which is the
    # RunnerTests target in current Flutter projects. Remove every list entry,
    # then add exactly one entry to the phase that already compiles AppDelegate.
    text = re.sub(rf"\n\s*{re.escape(entry)},", "", text)
    phase_pattern = re.compile(
        r"(\t\t[A-F0-9]{24} /\* Sources \*/ = \{\n"
        r"\t\t\tisa = PBXSourcesBuildPhase;.*?"
        r"\t\t\tfiles = \()(.*?)(\n\t\t\t\);)",
        re.S,
    )
    phases = list(phase_pattern.finditer(text))
    runner_phase = next(
        (phase for phase in phases if "AppDelegate.swift in Sources" in phase.group(2)),
        None,
    )
    if runner_phase is None:
        raise RuntimeError("The Runner Sources build phase was not found")
    body = runner_phase.group(2)
    replacement = (
        runner_phase.group(1)
        + f"\n\t\t\t\t{entry},"
        + body
        + runner_phase.group(3)
    )
    text = text[: runner_phase.start()] + replacement + text[runner_phase.end() :]
    project.write_text(text)


def repair_dart_compile_errors() -> None:
    experiments = Path("lib/lab_experiments.dart")
    text = experiments.read_text()
    text = text.replace(
        """    final percent = difference == null || meanB == 0
        ? null
        : difference / meanB * 100;
""",
        """    final percent = difference == null || meanB == null || meanB == 0
        ? null
        : difference / meanB * 100.0;
""",
    )
    experiments.write_text(text)

    share_card = Path("lib/share_card.dart")
    text = share_card.read_text().replace(
        "achievement: data.achievementLabel,",
        "achievement: data.achievementLabel ?? '',",
    )
    helper_start = text.find("\n  static void _drawGrid")
    if helper_start >= 0:
        helper_end_marker = "\n}\n\nclass ShareImageBridge"
        helper_end = text.find(helper_end_marker, helper_start)
        if helper_end < 0:
            raise RuntimeError("The obsolete share-card helper block was not bounded")
        text = text[:helper_start] + text[helper_end:]
    share_card.write_text(text)

    main = Path("lib/main.dart")
    text = main.read_text()
    old_root_lifecycle = """  @override
  void initState() {
    _automaticCloudSync = CloudBackupSyncService.shared(store);
    unawaited(_automaticCloudSync!.initialize());
    super.initState();
    store.load();
  }

"""
    new_root_lifecycle = """  @override
  void initState() {
    super.initState();
    _automaticCloudSync = CloudBackupSyncService.shared(store);
    unawaited(_automaticCloudSync!.initialize());
    unawaited(store.load());
  }

  @override
  void dispose() {
    _automaticCloudSync?.dispose();
    store.dispose();
    super.dispose();
  }

"""
    if old_root_lifecycle in text:
        text = text.replace(old_root_lifecycle, new_root_lifecycle, 1)

    old_shell_dispose = """  @override
  void dispose() {
    _automaticCloudSync?.dispose();
    widget.store.removeListener(_maybeStartAutomaticTour);
    super.dispose();
  }
"""
    new_shell_dispose = """  @override
  void dispose() {
    widget.store.removeListener(_maybeStartAutomaticTour);
    super.dispose();
  }
"""
    text = text.replace(old_shell_dispose, new_shell_dispose, 1)
    main.write_text(text)


base.update_ios_app_delegate = update_ios_app_delegate_compat

# Importing v5 runs the complete canonical finalization after the compatibility
# override above has been installed.
import finalize_integrations_v5  # noqa: E402,F401

repair_ios_project_membership()
repair_dart_compile_errors()

# The manifest transformation can preserve indentation on an otherwise empty
# line. Normalize it so the committed direct source passes git's whitespace
# checks and remains stable when the finalizer is rerun.
manifest = Path("android/app/src/main/AndroidManifest.xml")
manifest.write_text(
    "\n".join(line.rstrip() for line in manifest.read_text().splitlines()) + "\n"
)
