from __future__ import annotations

from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    target = Path(path)
    text = target.read_text()
    if new in text:
        return
    if old not in text:
        raise RuntimeError(f"Expected text was not found in {path}: {old!r}")
    target.write_text(text.replace(old, new, 1))


def main() -> None:
    replace_once(
        "lib/main.dart",
        "import 'progress_dashboard.dart';",
        "import 'progress_hub.dart';",
    )
    replace_once(
        "lib/main.dart",
        "ProgressDashboard(store: widget.store),",
        "ProgressHub(store: widget.store),",
    )
    replace_once(
        "lib/progress_hub.dart",
        """          child: ExpansionTile(
            title: const Text(
              'PROGRAM APPEARANCES',
""",
        """          child: ExpansionTile(
            key: PageStorageKey('functional-program-appearances-$active'),
            title: const Text(
              'PROGRAM APPEARANCES',
""",
    )
    replace_once("pubspec.yaml", "version: 2.1.0+14", "version: 2.1.1+15")
    replace_once(
        "android/app/build.gradle.kts",
        "versionCode = 14",
        "versionCode = 15",
    )
    replace_once(
        "android/app/build.gradle.kts",
        'versionName = "2.1.0"',
        'versionName = "2.1.1"',
    )
    replace_once(
        "README.md",
        "Current version: **2.1.0+14**",
        "Current version: **2.1.1+15**",
    )

    changelog = Path("CHANGELOG.md")
    text = changelog.read_text()
    heading = "## 2.1.1+15 — 2026-08-22"
    if heading not in text:
        entry = """# Changelog

## 2.1.1+15 — 2026-08-22

### Corrected

- Replaced the misleading functional-training exercise dropdown with a track-aware Progress view.
- Functional Progress now lists every programmed drill before any session is completed.
- Completed functional sessions now populate drill history, completion counts, effort averages, and program appearances without inventing strength-set data.
- Strength and Functional progress data remain separate and use metrics appropriate to each training track.
- Isolated Functional Progress expansion state from list scroll state to prevent page-storage type collisions.

"""
        if not text.startswith("# Changelog\n"):
            raise RuntimeError("Unexpected CHANGELOG.md header")
        changelog.write_text(entry + text[len("# Changelog\n\n") :])


if __name__ == "__main__":
    main()
