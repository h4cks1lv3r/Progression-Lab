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


def repair_ios_date_formatter() -> None:
    path = Path("ios/Runner/IntegrationBridge.swift")
    text = path.read_text()
    declaration = "static let progressionLabWholeSeconds: ISO8601DateFormatter"
    if declaration in text:
        return
    marker = """  static let progressionLab: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()
"""
    if marker not in text:
        raise RuntimeError("The primary iOS ISO-8601 formatter was not found")
    addition = """

  static let progressionLabWholeSeconds: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()
"""
    path.write_text(text.replace(marker, marker + addition, 1))


def repair_health_bridges() -> None:
    android = Path(
        "android/app/src/main/kotlin/com/h4cks1lv3/iron_cadence/IntegrationBridge.kt"
    )
    text = android.read_text()
    if "import androidx.health.connect.client.units.Percentage" not in text:
        text = text.replace(
            "import androidx.health.connect.client.units.Mass\n",
            "import androidx.health.connect.client.units.Mass\n"
            "import androidx.health.connect.client.units.Percentage\n",
            1,
        )
    read_body_fat = (
        "        HealthPermission.getReadPermission(BodyFatRecord::class),\n"
    )
    write_body_fat = (
        "        HealthPermission.getWritePermission(BodyFatRecord::class),\n"
    )
    if write_body_fat not in text:
        if read_body_fat not in text:
            raise RuntimeError("Android BodyFatRecord read permission was not found")
        text = text.replace(
            read_body_fat,
            read_body_fat + write_body_fat,
            1,
        )

    if '            "writeBodyFat" -> scope.launch {' not in text:
        health_start = text.find("    private fun handleHealth(")
        health_end = text.find("\n    private fun handleCloud(", health_start)
        if health_start < 0 or health_end < 0:
            raise RuntimeError("Android health handler was not bounded")
        health_section = text[health_start:health_end]
        default_marker = "            else -> result.notImplemented()"
        insertion_index = health_section.rfind(default_marker)
        if insertion_index < 0:
            raise RuntimeError("Android health handler default case was not found")
        body_fat_case = """            "writeBodyFat" -> scope.launch {
                try {
                    val arguments = call.arguments as? Map<*, *>
                        ?: throw IllegalArgumentException("Body-fat arguments are missing.")
                    val time = Instant.parse(arguments["recordedAt"] as String)
                    val raw = (arguments["value"] as Number).toDouble()
                    require(raw in 0.0..100.0) {
                        "Body-fat percentage must be between 0 and 100."
                    }
                    val zoneOffset: ZoneOffset = ZoneId.systemDefault().rules.getOffset(time)
                    healthClient.insertRecords(
                        listOf(
                            BodyFatRecord(
                                time = time,
                                zoneOffset = zoneOffset,
                                percentage = Percentage(raw),
                                metadata = Metadata.manualEntry(
                                    clientRecordId =
                                        "progression-lab-body-fat-${time.toEpochMilli()}",
                                    clientRecordVersion = 1,
                                ),
                            )
                        )
                    )
                    result.success(true)
                } catch (error: Exception) {
                    result.error("health_body_fat_write_failed", error.message, null)
                }
            }
"""
        health_section = (
            health_section[:insertion_index]
            + body_fat_case
            + health_section[insertion_index:]
        )
        text = text[:health_start] + health_section + text[health_end:]
    android.write_text(text)

    ios = Path("ios/Runner/IntegrationBridge.swift")
    text = ios.read_text()
    old_authorization = """      let workout = HKObjectType.workoutType()
      let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass)!
      let bodyFat = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!
      let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate)!
      let steps = HKObjectType.quantityType(forIdentifier: .stepCount)!
      let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
      let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
      healthStore.requestAuthorization(
        toShare: [workout, bodyMass],
        read: [workout, bodyMass, bodyFat, heartRate, steps, energy, sleep]
      ) { granted, error in
"""
    new_authorization = """      let workout = HKObjectType.workoutType()
      let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass)!
      let bodyFat = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!
      healthStore.requestAuthorization(
        toShare: [workout, bodyMass, bodyFat],
        read: [workout, bodyMass, bodyFat]
      ) { granted, error in
"""
    if old_authorization in text:
        text = text.replace(old_authorization, new_authorization, 1)
    elif "toShare: [workout, bodyMass, bodyFat]" not in text:
        raise RuntimeError("iOS HealthKit authorization block was not recognized")

    if '    case "writeBodyFat":' not in text:
        health_start = text.find(
            "  private func handleHealth(_ call: FlutterMethodCall,"
        )
        health_end = text.find("\n  private func readBodyMetrics(", health_start)
        if health_start < 0 or health_end < 0:
            raise RuntimeError("iOS health handler was not bounded")
        health_section = text[health_start:health_end]
        default_marker = "    default:\n      result(FlutterMethodNotImplemented)"
        insertion_index = health_section.rfind(default_marker)
        if insertion_index < 0:
            raise RuntimeError("iOS health handler default case was not found")
        body_fat_case = """    case "writeBodyFat":
      guard let arguments = call.arguments as? [String: Any],
            let recordedAt = isoDate(arguments["recordedAt"]),
            let raw = arguments["value"] as? NSNumber,
            raw.doubleValue >= 0,
            raw.doubleValue <= 100 else {
        result(FlutterError(code: "invalid_arguments", message: "Body-fat percentage must be between 0 and 100.", details: nil))
        return
      }
      let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!
      let sample = HKQuantitySample(
        type: type,
        quantity: HKQuantity(unit: .percent(), doubleValue: raw.doubleValue / 100.0),
        start: recordedAt,
        end: recordedAt,
        metadata: [HKMetadataKeyExternalUUID: "progression-lab-body-fat-\(recordedAt.timeIntervalSince1970)"]
      )
      healthStore.save(sample) { saved, error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(code: "health_body_fat_write_failed", message: error.localizedDescription, details: nil))
          } else {
            result(saved)
          }
        }
      }

"""
        health_section = (
            health_section[:insertion_index]
            + body_fat_case
            + health_section[insertion_index:]
        )
        text = text[:health_start] + health_section + text[health_end:]
    ios.write_text(text)


def repair_android_gradle() -> None:
    path = Path("android/app/build.gradle.kts")
    text = path.read_text()
    dependencies_index = text.find("\ndependencies {")
    if dependencies_index < 0:
        raise RuntimeError("The Android dependencies block was not found")
    dependencies = """

dependencies {
    implementation("com.google.mlkit:genai-prompt:1.0.0-beta4")
    implementation("androidx.health.connect:connect-client:1.1.0")
    implementation("androidx.documentfile:documentfile:1.0.1")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
}
"""
    path.write_text(text[:dependencies_index].rstrip() + dependencies)


def repair_android_activity_lifecycle() -> None:
    path = Path(
        "android/app/src/main/kotlin/com/h4cks1lv3/iron_cadence/MainActivity.kt"
    )
    text = path.read_text()

    document_only = """    @Deprecated("Deprecated in Android; retained for the document picker bridge.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            REQUEST_CREATE_DOCUMENT -> finishSaveFile(resultCode, data?.data)
            REQUEST_OPEN_DOCUMENT -> finishPickFile(resultCode, data?.data)
        }
    }
"""
    combined_activity_result = """    @Deprecated("Deprecated in Android; retained for native integration bridges.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (integrationBridge?.onActivityResult(requestCode, resultCode, data) == true) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            REQUEST_CREATE_DOCUMENT -> finishSaveFile(resultCode, data?.data)
            REQUEST_OPEN_DOCUMENT -> finishPickFile(resultCode, data?.data)
        }
    }
"""
    if document_only in text:
        text = text.replace(document_only, combined_activity_result, 1)

    bridge_only_activity_result = """    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (integrationBridge?.onActivityResult(requestCode, resultCode, data) == true) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
"""
    text = text.replace(bridge_only_activity_result, "", 1)

    ai_only_destroy = """    override fun onDestroy() {
        generationJob?.cancel()
        generativeModel?.close()
        generativeModel = null
        aiScope.cancel()
        super.onDestroy()
    }
"""
    combined_destroy = """    override fun onDestroy() {
        generationJob?.cancel()
        generativeModel?.close()
        generativeModel = null
        aiScope.cancel()
        integrationBridge?.dispose()
        integrationBridge = null
        super.onDestroy()
    }
"""
    if ai_only_destroy in text:
        text = text.replace(ai_only_destroy, combined_destroy, 1)

    bridge_only_destroy = """    override fun onDestroy() {
        integrationBridge?.dispose()
        integrationBridge = null
        super.onDestroy()
    }
"""
    text = text.replace(bridge_only_destroy, "", 1)

    if text.count("override fun onActivityResult(") != 1:
        raise RuntimeError("MainActivity must contain exactly one onActivityResult override")
    if text.count("override fun onDestroy()") != 1:
        raise RuntimeError("MainActivity must contain exactly one onDestroy override")
    path.write_text(text)


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
    text = share_card.read_text().replace("import 'dart:ui' as ui;\n\n", "", 1)
    text = text.replace(
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

import finalize_integrations_v5  # noqa: E402,F401

repair_ios_project_membership()
repair_ios_date_formatter()
repair_health_bridges()
repair_android_gradle()
repair_android_activity_lifecycle()
repair_dart_compile_errors()

manifest = Path("android/app/src/main/AndroidManifest.xml")
manifest.write_text(
    "\n".join(line.rstrip() for line in manifest.read_text().splitlines()) + "\n"
)
