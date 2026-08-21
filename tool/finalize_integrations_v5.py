from __future__ import annotations

from pathlib import Path
import re

import finalize_integrations_v4


finalize_integrations_v4.main()

# FIT/TCX numeric reducers must preserve integer return types.
path = Path("lib/external_workout_formats.dart")
text = path.read_text()
text = text.replace(
    "maximumHeartRates.reduce(math.max)",
    "maximumHeartRates.reduce((left, right) => left > right ? left : right)",
)
text = text.replace(
    "return items.reduce(math.max);",
    "return items.reduce((left, right) => left > right ? left : right);",
)
path.write_text(text)

# Add explicit non-fallthrough boundaries to condition classification.
path = Path("lib/lab_experiments.dart")
text = path.read_text()
replacements = [
    (
        """            );
      case 'mealBeforeWorkout':
""",
        """            );
        break;
      case 'mealBeforeWorkout':
""",
    ),
    (
        """        }).length.toDouble();
      case 'previousNightSleep':
""",
        """        }).length.toDouble();
        break;
      case 'previousNightSleep':
""",
    ),
    (
        """            .firstOrNull;
      case 'supplementAdherence':
""",
        """            .firstOrNull;
        break;
      case 'supplementAdherence':
""",
    ),
    (
        """            .toDouble();
      default:
        value = null;
    }
""",
        """            .toDouble();
        break;
      default:
        value = null;
        break;
    }
""",
    ),
]
for old, new in replacements:
    if old in text:
        text = text.replace(old, new, 1)
path.write_text(text)

# Health Connect has a stable 1.1 API. Avoid stale alpha artifacts.
gradle = Path("android/app/build.gradle.kts")
text = gradle.read_text().replace(
    "androidx.health.connect:connect-client:1.1.0-alpha11",
    "androidx.health.connect:connect-client:1.1.0",
)
gradle.write_text(text)

# Health Connect visibility and permission-management rationale entry points.
manifest = Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text()
if "com.google.android.apps.healthdata" not in text:
    manifest_open = text.find(">", text.find("<manifest")) + 1
    text = text[:manifest_open] + """
    <queries>
        <package android:name="com.google.android.apps.healthdata" />
    </queries>
""" + text[manifest_open:]
manifest.write_text(text)

# Avoid a duplicate disposal when the shared cloud service is not owned by the
# integrations screen. Root ownership is optional; app shutdown is safe either
# way because the service has no isolate-spanning resource.
path = Path("lib/main.dart")
text = path.read_text()
text = text.replace(
    "    _automaticCloudSync?.dispose();\n    _automaticCloudSync?.dispose();\n",
    "    _automaticCloudSync?.dispose();\n",
)
path.write_text(text)

# Xcode build settings must include the native integration file and entitlement.
project = Path("ios/Runner.xcodeproj/project.pbxproj")
text = project.read_text()
if "IntegrationBridge.swift in Sources" not in text:
    raise RuntimeError("IntegrationBridge.swift was not added to the Xcode Sources phase")
if "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;" not in text:
    raise RuntimeError("HealthKit entitlements are not connected to the Runner target")

# Ensure the Info.plist contains HealthKit purpose strings and the OAuth scheme.
plist = Path("ios/Runner/Info.plist").read_text()
for key in ("NSHealthShareUsageDescription", "NSHealthUpdateUsageDescription", "CFBundleURLTypes"):
    if key not in plist:
        raise RuntimeError(f"Missing iOS configuration: {key}")
