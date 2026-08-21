from __future__ import annotations

from pathlib import Path
import hashlib
import re


def insert_after_last_import(path: Path, import_line: str) -> None:
    text = path.read_text()
    if import_line in text:
        return
    imports = list(re.finditer(r"^import\s+[^;]+;\s*$", text, re.M))
    if not imports:
        raise RuntimeError(f"No imports found in {path}")
    pos = imports[-1].end()
    path.write_text(text[:pos] + "\n" + import_line + text[pos:])


def update_pubspec() -> None:
    path = Path("pubspec.yaml")
    text = path.read_text()
    additions: list[str] = []
    if re.search(r"^  xml:", text, re.M) is None:
        additions.append("  xml: ^6.5.0")
    if re.search(r"^  crypto:", text, re.M) is None:
        additions.append("  crypto: ^3.0.6")
    if not additions:
        return
    match = re.search(r"^  cupertino_icons:.*$", text, re.M)
    if match is None:
        raise RuntimeError("Could not locate dependencies in pubspec.yaml")
    path.write_text(text[: match.end()] + "\n" + "\n".join(additions) + text[match.end() :])


def update_android_gradle() -> None:
    path = Path("android/app/build.gradle.kts")
    text = path.read_text()
    if "androidx.health.connect:connect-client" in text:
        return
    text = text.rstrip() + """


dependencies {
    implementation("androidx.health.connect:connect-client:1.1.0-alpha11")
    implementation("androidx.documentfile:documentfile:1.0.1")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}
"""
    path.write_text(text)


def update_android_manifest() -> None:
    path = Path("android/app/src/main/AndroidManifest.xml")
    text = path.read_text()
    permissions = [
        "android.permission.INTERNET",
        "android.permission.health.READ_EXERCISE",
        "android.permission.health.WRITE_EXERCISE",
        "android.permission.health.READ_WEIGHT",
        "android.permission.health.WRITE_WEIGHT",
        "android.permission.health.READ_BODY_FAT",
    ]
    application_index = text.find("<application")
    if application_index < 0:
        raise RuntimeError("Android manifest has no application element")
    missing = [item for item in permissions if item not in text]
    if missing:
        prefix = "".join(f'    <uses-permission android:name="{item}" />\n' for item in missing)
        text = text[:application_index] + prefix + text[application_index:]
    if 'android:scheme="progressionlab"' not in text:
        activity_start = text.find("<activity")
        activity_end = text.find("</activity>", activity_start)
        if activity_start < 0 or activity_end < 0:
            raise RuntimeError("Android activity element not found")
        intent_filter = """
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="progressionlab" android:host="oauth" />
            </intent-filter>
"""
        text = text[:activity_end] + intent_filter + text[activity_end:]
    path.write_text(text)


def update_main_activity() -> None:
    path = Path("android/app/src/main/kotlin/com/h4cks1lv3/iron_cadence/MainActivity.kt")
    text = path.read_text()
    if "import android.content.Intent" not in text:
        package_end = text.find("\n", text.find("package ")) + 1
        text = text[:package_end] + "\nimport android.content.Intent\n" + text[package_end:]
    if "private var integrationBridge: IntegrationBridge?" not in text:
        class_match = re.search(r"class\s+MainActivity\s*:\s*FlutterActivity\s*\(\s*\)\s*\{", text)
        if class_match is None:
            raise RuntimeError("MainActivity declaration not found")
        text = text[: class_match.end()] + "\n    private var integrationBridge: IntegrationBridge? = null\n" + text[class_match.end() :]
    if "IntegrationBridge(this, flutterEngine.dartExecutor.binaryMessenger)" not in text:
        method = re.search(r"override\s+fun\s+configureFlutterEngine\s*\([^)]*\)\s*\{", text)
        if method is None:
            class_close = text.rfind("}")
            insertion = """
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        integrationBridge = IntegrationBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

"""
            text = text[:class_close] + insertion + text[class_close:]
        else:
            super_call = text.find("super.configureFlutterEngine(flutterEngine)", method.end())
            if super_call < 0:
                raise RuntimeError("configureFlutterEngine super call not found")
            line_end = text.find("\n", super_call)
            text = text[: line_end + 1] + "        integrationBridge = IntegrationBridge(this, flutterEngine.dartExecutor.binaryMessenger)\n" + text[line_end + 1 :]
    if "integrationBridge?.handleIntent(intent)" not in text:
        class_close = text.rfind("}")
        insertion = """
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        integrationBridge?.handleIntent(intent)
    }

    override fun onDestroy() {
        integrationBridge?.dispose()
        integrationBridge = null
        super.onDestroy()
    }

"""
        text = text[:class_close] + insertion + text[class_close:]
    path.write_text(text)


def update_main_menu() -> None:
    path = Path("lib/main.dart")
    insert_after_last_import(path, "import 'integrations_hub.dart';")
    text = path.read_text()
    if "Connections & Experiments" in text:
        return
    marker = "Data & Backup"
    marker_index = text.find(marker)
    if marker_index < 0:
        raise RuntimeError("Data & Backup menu item not found")

    # Search backward for a widget constructor and use balanced parentheses.
    line_start = text.rfind("\n", 0, marker_index) + 1
    candidate = line_start
    block_start: int | None = None
    while candidate > 0:
        previous = text.rfind("\n", 0, max(0, candidate - 1)) + 1
        line_end = text.find("\n", previous)
        if line_end < 0:
            line_end = len(text)
        line = text[previous:line_end]
        if re.match(r"\s*[A-Za-z_][A-Za-z0-9_<>]*\s*\(", line):
            block_start = previous
            break
        candidate = previous
    if block_start is None:
        raise RuntimeError("Could not identify Data & Backup widget block")
    open_pos = text.find("(", block_start)
    depth = 0
    quote: str | None = None
    escaped = False
    block_end: int | None = None
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
                block_end = index + 1
                while block_end < len(text) and text[block_end] in " ,\n":
                    block_end += 1
                break
    if block_end is None:
        raise RuntimeError("Data & Backup widget block did not close")
    block = text[block_start:block_end]
    clone = block.replace(marker, "Connections & Experiments", 1)
    clone = clone.replace("DataManagementScreen", "IntegrationsHubScreen")
    clone = re.sub(r"Icons\.[A-Za-z0-9_]+", "Icons.hub_rounded", clone, count=1)

    # Replace one likely subtitle while preserving the tile API.
    string_matches = list(re.finditer(r"'([^'\\]|\\.)*'", clone))
    for match in string_matches:
        raw = match.group(0)
        if "Connections & Experiments" in raw:
            continue
        lower = raw.lower()
        if any(word in lower for word in ("backup", "restore", "import", "export", "data")):
            clone = clone[: match.start()] + "'Health, wearables, cloud sync, sharing, and Lab experiments.'" + clone[match.end() :]
            break

    if "IntegrationsHubScreen" not in clone:
        callback = re.search(r"onTap\s*:\s*\(\)\s*=>.*?,\s*$", clone, re.S)
        if callback:
            replacement = "onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => IntegrationsHubScreen(store: store))),\n"
            clone = clone[: callback.start()] + replacement + clone[callback.end() :]
    if "IntegrationsHubScreen" not in clone:
        raise RuntimeError("Could not route Connections & Experiments menu item")
    path.write_text(text[:block_end] + clone + text[block_end:])


def update_ios_app_delegate() -> None:
    path = Path("ios/Runner/AppDelegate.swift")
    text = path.read_text()
    if "IntegrationBridgeIOS.shared.register" in text:
        return
    marker = "GeneratedPluginRegistrant.register(with: self)"
    index = text.find(marker)
    if index < 0:
        raise RuntimeError("GeneratedPluginRegistrant registration not found")
    line_end = text.find("\n", index)
    insertion = """
    if let controller = window?.rootViewController as? FlutterViewController {
      IntegrationBridgeIOS.shared.register(
        messenger: controller.binaryMessenger,
        viewController: controller
      )
    }
"""
    path.write_text(text[: line_end + 1] + insertion + text[line_end + 1 :])


def update_ios_project() -> None:
    project = Path("ios/Runner.xcodeproj/project.pbxproj")
    text = project.read_text()
    file_name = "IntegrationBridge.swift"
    if file_name in text:
        return
    digest = hashlib.sha1(file_name.encode()).hexdigest().upper()
    file_ref = digest[:24]
    build_ref = digest[8:32]

    build_section = "/* Begin PBXBuildFile section */"
    file_section = "/* Begin PBXFileReference section */"
    if build_section not in text or file_section not in text:
        raise RuntimeError("Xcode project sections not found")
    text = text.replace(
        build_section,
        build_section + f"\n\t\t{build_ref} /* {file_name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref} /* {file_name} */; }};",
        1,
    )
    text = text.replace(
        file_section,
        file_section + f"\n\t\t{file_ref} /* {file_name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {file_name}; sourceTree = \"<group>\"; }};",
        1,
    )

    # Add to Runner group immediately after AppDelegate.swift.
    app_delegate_line = re.search(r"\n\s*[A-F0-9]{24} /\* AppDelegate\.swift \*/,", text)
    if app_delegate_line is None:
        raise RuntimeError("Runner group AppDelegate entry not found")
    pos = app_delegate_line.end()
    text = text[:pos] + f"\n\t\t\t\t{file_ref} /* {file_name} */," + text[pos:]

    sources = re.search(
        r"([A-F0-9]{24} /\* Sources \*/ = \{\n\s*isa = PBXSourcesBuildPhase;.*?files = \()(.*?)(\n\s*\);)",
        text,
        re.S,
    )
    if sources is None:
        raise RuntimeError("Runner Sources build phase not found")
    insert_pos = sources.start(2)
    text = text[:insert_pos] + f"\n\t\t\t\t{build_ref} /* {file_name} in Sources */," + text[insert_pos:]

    # HealthKit entitlement for all build configurations.
    if "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;" not in text:
        text = re.sub(
            r"(PRODUCT_BUNDLE_IDENTIFIER = com\.h4cks1lv3r\.progressionlab;)",
            r"CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n\t\t\t\t\1",
            text,
        )
    project.write_text(text)


def update_ios_plist_and_entitlements() -> None:
    plist = Path("ios/Runner/Info.plist")
    text = plist.read_text()
    additions: list[str] = []
    if "NSHealthShareUsageDescription" not in text:
        additions += [
            "\t<key>NSHealthShareUsageDescription</key>",
            "\t<string>Progression Lab reads authorized workouts, bodyweight, heart rate, sleep, steps, and recovery context to compare training trends.</string>",
        ]
    if "NSHealthUpdateUsageDescription" not in text:
        additions += [
            "\t<key>NSHealthUpdateUsageDescription</key>",
            "\t<string>Progression Lab writes completed workout summaries and optional bodyweight entries when you enable Apple Health sync.</string>",
        ]
    if "CFBundleURLTypes" not in text:
        additions += [
            "\t<key>CFBundleURLTypes</key>",
            "\t<array>",
            "\t\t<dict>",
            "\t\t\t<key>CFBundleURLName</key>",
            "\t\t\t<string>com.h4cks1lv3r.progressionlab.oauth</string>",
            "\t\t\t<key>CFBundleURLSchemes</key>",
            "\t\t\t<array><string>progressionlab</string></array>",
            "\t\t</dict>",
            "\t</array>",
        ]
    if additions:
        closing = text.rfind("</dict>")
        text = text[:closing] + "\n".join(additions) + "\n" + text[closing:]
        plist.write_text(text)

    entitlements = Path("ios/Runner/Runner.entitlements")
    entitlements.write_text("""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array/>
</dict>
</plist>
""")


def main() -> None:
    update_pubspec()
    update_android_gradle()
    update_android_manifest()
    update_main_activity()
    update_main_menu()
    update_ios_app_delegate()
    update_ios_project()
    update_ios_plist_and_entitlements()


if __name__ == "__main__":
    main()
