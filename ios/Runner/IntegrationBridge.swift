import AuthenticationServices
import Flutter
import HealthKit
import Security
import UIKit
import UniformTypeIdentifiers

final class IntegrationBridgeIOS: NSObject, UIDocumentPickerDelegate, ASWebAuthenticationPresentationContextProviding {
  static let shared = IntegrationBridgeIOS()

  private let healthStore = HKHealthStore()
  private weak var viewController: UIViewController?
  private var folderResult: FlutterResult?
  private var fileResult: FlutterResult?
  private var oauthSession: ASWebAuthenticationSession?
  private let defaults = UserDefaults.standard

  private override init() {
    super.init()
  }

  func register(messenger: FlutterBinaryMessenger, viewController: UIViewController) {
    self.viewController = viewController

    FlutterMethodChannel(name: "progression_lab/health", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        self?.handleHealth(call, result: result)
      }
    FlutterMethodChannel(name: "progression_lab/cloud_sync", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        self?.handleCloud(call, result: result)
      }
    FlutterMethodChannel(name: "progression_lab/integrations", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        self?.handleFileImport(call, result: result)
      }
    FlutterMethodChannel(name: "progression_lab/oauth", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        self?.handleOAuth(call, result: result)
      }
    FlutterMethodChannel(name: "progression_lab/secure_storage", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        self?.handleSecureStorage(call, result: result)
      }
    FlutterMethodChannel(name: "progression_lab/integration_preferences", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        self?.handleIntegrationPreferences(call, result: result)
      }
    FlutterMethodChannel(name: "progression_lab/guide_state", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        self?.handleGuideState(call, result: result)
      }
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    if let window = viewController?.view.window { return window }
    return UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first { $0.isKeyWindow } ?? ASPresentationAnchor()
  }

  private func handleHealth(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status":
      guard HKHealthStore.isHealthDataAvailable() else {
        result([
          "platform": "appleHealth",
          "available": false,
          "authorization": "unavailable",
          "message": "Apple Health is not available on this device.",
        ])
        return
      }
      let workout = healthStore.authorizationStatus(for: HKObjectType.workoutType())
      let state: String
      switch workout {
      case .sharingAuthorized: state = "authorized"
      case .sharingDenied: state = "denied"
      case .notDetermined: state = "notDetermined"
      @unknown default: state = "unknown"
      }
      result([
        "platform": "appleHealth",
        "available": true,
        "authorization": state,
      ])

    case "requestAuthorization":
      guard HKHealthStore.isHealthDataAvailable() else {
        result(false)
        return
      }
      let workout = HKObjectType.workoutType()
      let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass)!
      let bodyFat = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!
      healthStore.requestAuthorization(
        toShare: [workout, bodyMass, bodyFat],
        read: [workout, bodyMass, bodyFat]
      ) { granted, error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(code: "health_authorization_failed", message: error.localizedDescription, details: nil))
          } else {
            result(granted)
          }
        }
      }

    case "readWorkouts":
      guard let arguments = call.arguments as? [String: Any],
            let start = isoDate(arguments["start"]),
            let end = isoDate(arguments["end"]) else {
        result(FlutterError(code: "invalid_arguments", message: "Workout date range is missing.", details: nil))
        return
      }
      let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate])
      let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
      let query = HKSampleQuery(
        sampleType: HKObjectType.workoutType(),
        predicate: predicate,
        limit: HKObjectQueryNoLimit,
        sortDescriptors: [sort]
      ) { _, samples, error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(code: "health_read_failed", message: error.localizedDescription, details: nil))
            return
          }
          let workouts = (samples as? [HKWorkout] ?? []).map { workout -> [String: Any] in
            var value: [String: Any] = [
              "id": workout.uuid.uuidString,
              "platform": "appleHealth",
              "source": workout.sourceRevision.source.bundleIdentifier,
              "title": workout.metadata?[HKMetadataKeyWorkoutBrandName] as? String ?? "Apple Health Workout",
              "sport": self.workoutName(workout.workoutActivityType),
              "startedAt": self.isoString(workout.startDate),
              "endedAt": self.isoString(workout.endDate),
              "durationSeconds": workout.duration,
            ]
            if let energy = workout.totalEnergyBurned {
              value["calories"] = energy.doubleValue(for: .kilocalorie())
            }
            if let distance = workout.totalDistance {
              value["distanceMeters"] = distance.doubleValue(for: .meter())
            }
            if let notes = workout.metadata?[HKMetadataKeyExternalUUID] as? String {
              value["notes"] = notes
            }
            return value
          }
          result(workouts)
        }
      }
      healthStore.execute(query)

    case "readBodyMetrics":
      guard let arguments = call.arguments as? [String: Any],
            let start = isoDate(arguments["start"]),
            let end = isoDate(arguments["end"]) else {
        result(FlutterError(code: "invalid_arguments", message: "Metric date range is missing.", details: nil))
        return
      }
      readBodyMetrics(start: start, end: end, result: result)

    case "writeWorkout":
      guard let arguments = call.arguments as? [String: Any],
            let start = isoDate(arguments["startedAt"]),
            let end = isoDate(arguments["endedAt"]),
            start < end else {
        result(FlutterError(code: "invalid_arguments", message: "Workout times are invalid.", details: nil))
        return
      }
      let energy = (arguments["calories"] as? NSNumber).map {
        HKQuantity(unit: .kilocalorie(), doubleValue: $0.doubleValue)
      }
      let distance = (arguments["distanceMeters"] as? NSNumber).map {
        HKQuantity(unit: .meter(), doubleValue: $0.doubleValue)
      }
      var metadata: [String: Any] = [
        HKMetadataKeyExternalUUID: arguments["externalId"] as? String ?? UUID().uuidString,
        HKMetadataKeyWorkoutBrandName: arguments["title"] as? String ?? "Progression Lab",
      ]
      if let notes = arguments["notes"] as? String, !notes.isEmpty {
        metadata["ProgressionLabNotes"] = notes
      }
      let workout = HKWorkout(
        activityType: workoutType(arguments["sport"] as? String),
        start: start,
        end: end,
        workoutEvents: nil,
        totalEnergyBurned: energy,
        totalDistance: distance,
        metadata: metadata
      )
      healthStore.save(workout) { saved, error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(code: "health_write_failed", message: error.localizedDescription, details: nil))
          } else {
            result(saved)
          }
        }
      }

    case "writeBodyWeight":
      guard let arguments = call.arguments as? [String: Any],
            let recordedAt = isoDate(arguments["recordedAt"]),
            let raw = arguments["value"] as? NSNumber else {
        result(FlutterError(code: "invalid_arguments", message: "Bodyweight value is missing.", details: nil))
        return
      }
      let unit = arguments["unit"] as? String == "lb" ? HKUnit.pound() : HKUnit.gramUnit(with: .kilo)
      let type = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
      let sample = HKQuantitySample(
        type: type,
        quantity: HKQuantity(unit: unit, doubleValue: raw.doubleValue),
        start: recordedAt,
        end: recordedAt,
        metadata: [HKMetadataKeyExternalUUID: "progression-lab-weight-\(recordedAt.timeIntervalSince1970)"]
      )
      healthStore.save(sample) { saved, error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(code: "health_weight_write_failed", message: error.localizedDescription, details: nil))
          } else {
            result(saved)
          }
        }
      }

    case "writeBodyFat":
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

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func readBodyMetrics(start: Date, end: Date, result: @escaping FlutterResult) {
    let group = DispatchGroup()
    let lock = NSLock()
    var values: [[String: Any]] = []
    var firstError: Error?
    let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate])
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

    func read(
      identifier: HKQuantityTypeIdentifier,
      outputType: String,
      unit: HKUnit,
      unitName: String,
      transform: @escaping (Double) -> Double = { $0 }
    ) {
      guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return }
      group.enter()
      let query = HKSampleQuery(
        sampleType: type,
        predicate: predicate,
        limit: HKObjectQueryNoLimit,
        sortDescriptors: [sort]
      ) { _, samples, error in
        lock.lock()
        defer { lock.unlock(); group.leave() }
        if let error = error {
          firstError = firstError ?? error
          return
        }
        for sample in samples as? [HKQuantitySample] ?? [] {
          values.append([
            "type": outputType,
            "value": transform(sample.quantity.doubleValue(for: unit)),
            "unit": unitName,
            "recordedAt": self.isoString(sample.startDate),
            "source": sample.sourceRevision.source.bundleIdentifier,
          ])
        }
      }
      healthStore.execute(query)
    }

    read(identifier: .bodyMass, outputType: "bodyWeight", unit: .gramUnit(with: .kilo), unitName: "kg")
    read(
      identifier: .bodyFatPercentage,
      outputType: "bodyFatPercentage",
      unit: .percent(),
      unitName: "%",
      transform: { $0 * 100 }
    )

    group.notify(queue: .main) {
      if let error = firstError {
        result(FlutterError(code: "health_metric_read_failed", message: error.localizedDescription, details: nil))
      } else {
        result(values)
      }
    }
  }

  private func handleCloud(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status":
      let url = cloudFolderURL()
      result([
        "configured": url != nil,
        "provider": url?.path.contains("Mobile Documents") == true ? "iCloudDrive" : "filesProvider",
        "displayName": url?.lastPathComponent ?? "",
        "locationToken": url?.path ?? "",
        "automaticSyncEnabled": defaults.bool(forKey: Keys.automaticSync),
        "lastSuccessfulSync": defaults.string(forKey: Keys.lastSync) as Any,
      ])

    case "chooseFolder":
      guard folderResult == nil else {
        result(FlutterError(code: "busy", message: "A folder picker is already open.", details: nil))
        return
      }
      folderResult = result
      let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
      picker.delegate = self
      picker.allowsMultipleSelection = false
      viewController?.present(picker, animated: true)

    case "disconnectFolder":
      defaults.removeObject(forKey: Keys.cloudBookmark)
      defaults.set(false, forKey: Keys.automaticSync)
      result(nil)

    case "setAutomaticSyncEnabled":
      let enabled = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
      if enabled && cloudFolderURL() == nil {
        result(FlutterError(code: "folder_required", message: "Choose a cloud folder first.", details: nil))
        return
      }
      defaults.set(enabled, forKey: Keys.automaticSync)
      result(nil)

    case "listBackups":
      withCloudFolder(result: result) { folder in
        let urls = try FileManager.default.contentsOfDirectory(
          at: folder,
          includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
          options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension.lowercased() == "plab" }
        let values = try urls.map { url -> [String: Any] in
          let resources = try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
          return [
            "name": url.lastPathComponent,
            "modifiedAt": self.isoString(resources.contentModificationDate ?? Date.distantPast),
            "size": resources.fileSize ?? 0,
            "token": url.lastPathComponent,
          ]
        }
        result(values)
      }

    case "writeBackup":
      guard let arguments = call.arguments as? [String: Any],
            let name = arguments["name"] as? String,
            let bytes = arguments["bytes"] as? FlutterStandardTypedData else {
        result(FlutterError(code: "invalid_arguments", message: "Backup data is missing.", details: nil))
        return
      }
      withCloudFolder(result: result) { folder in
        let url = folder.appendingPathComponent(name)
        try bytes.data.write(to: url, options: [.atomic])
        let now = Date()
        self.defaults.set(self.isoString(now), forKey: Keys.lastSync)
        result([
          "name": name,
          "modifiedAt": self.isoString(now),
          "createdAt": arguments["createdAt"] as Any,
          "schemaVersion": arguments["schemaVersion"] as Any,
          "size": bytes.data.count,
          "token": name,
        ])
      }

    case "readBackup":
      guard let arguments = call.arguments as? [String: Any],
            let token = arguments["token"] as? String else {
        result(FlutterError(code: "invalid_arguments", message: "Backup token is missing.", details: nil))
        return
      }
      withCloudFolder(result: result) { folder in
        let safeName = URL(fileURLWithPath: token).lastPathComponent
        let data = try Data(contentsOf: folder.appendingPathComponent(safeName))
        result(FlutterStandardTypedData(bytes: data))
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleFileImport(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "pickWorkoutFile" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard fileResult == nil else {
      result(FlutterError(code: "busy", message: "A file picker is already open.", details: nil))
      return
    }
    fileResult = result
    let types = ["fit", "tcx", "gpx"].compactMap { UTType(filenameExtension: $0) }
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: types.isEmpty ? [.data] : types, asCopy: true)
    picker.delegate = self
    picker.allowsMultipleSelection = false
    viewController?.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let url = urls.first else {
      documentPickerWasCancelled(controller)
      return
    }
    if let result = folderResult {
      folderResult = nil
      do {
        let bookmark = try url.bookmarkData(
          options: [],
          includingResourceValuesForKeys: nil,
          relativeTo: nil
        )
        defaults.set(bookmark, forKey: Keys.cloudBookmark)
        result([
          "configured": true,
          "provider": url.path.contains("Mobile Documents") ? "iCloudDrive" : "filesProvider",
          "displayName": url.lastPathComponent,
          "locationToken": url.path,
          "automaticSyncEnabled": defaults.bool(forKey: Keys.automaticSync),
        ])
      } catch {
        result(FlutterError(code: "folder_bookmark_failed", message: error.localizedDescription, details: nil))
      }
      return
    }
    if let result = fileResult {
      fileResult = nil
      do {
        let data = try Data(contentsOf: url)
        result([
          "name": url.lastPathComponent,
          "bytes": FlutterStandardTypedData(bytes: data),
        ])
      } catch {
        result(FlutterError(code: "file_read_failed", message: error.localizedDescription, details: nil))
      }
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    if let result = folderResult {
      folderResult = nil
      result(nil)
    }
    if let result = fileResult {
      fileResult = nil
      result(nil)
    }
  }

  private func handleOAuth(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "authorize",
          let arguments = call.arguments as? [String: Any],
          let rawURL = arguments["url"] as? String,
          let url = URL(string: rawURL),
          let redirect = arguments["redirectUri"] as? String,
          let scheme = URL(string: redirect)?.scheme else {
      result(FlutterError(code: "invalid_arguments", message: "Authorization URL is invalid.", details: nil))
      return
    }
    oauthSession?.cancel()
    oauthSession = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callback, error in
      DispatchQueue.main.async {
        self.oauthSession = nil
        if let error = error as? ASWebAuthenticationSessionError,
           error.code == .canceledLogin {
          result(nil)
          return
        }
        if let error = error {
          result(FlutterError(code: "oauth_failed", message: error.localizedDescription, details: nil))
          return
        }
        guard let callback = callback,
              let components = URLComponents(url: callback, resolvingAgainstBaseURL: false) else {
          result(FlutterError(code: "oauth_callback_missing", message: "Authorization returned no callback.", details: nil))
          return
        }
        var values: [String: Any] = [:]
        for item in components.queryItems ?? [] {
          values[item.name] = item.value
        }
        result(values)
      }
    }
    oauthSession?.presentationContextProvider = self
    oauthSession?.prefersEphemeralWebBrowserSession = true
    if oauthSession?.start() != true {
      oauthSession = nil
      result(FlutterError(code: "oauth_start_failed", message: "Could not open authorization.", details: nil))
    }
  }

  private func handleSecureStorage(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let key = arguments["key"] as? String else {
      result(FlutterError(code: "invalid_arguments", message: "Secure-storage key is missing.", details: nil))
      return
    }
    switch call.method {
    case "read":
      result(keychainRead(key))
    case "write":
      guard let value = arguments["value"] as? String else {
        result(FlutterError(code: "invalid_arguments", message: "Secure-storage value is missing.", details: nil))
        return
      }
      do {
        try keychainWrite(key, value: value)
        result(nil)
      } catch {
        result(FlutterError(code: "secure_storage_failed", message: error.localizedDescription, details: nil))
      }
    case "delete":
      keychainDelete(key)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleIntegrationPreferences(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "read": result(defaults.string(forKey: Keys.integrationPreferences))
    case "write":
      defaults.set(call.arguments as? String ?? "{}", forKey: Keys.integrationPreferences)
      result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func handleGuideState(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "read":
      result([
        "tipsEnabled": defaults.object(forKey: Keys.guidesEnabled) == nil
          ? true
          : defaults.bool(forKey: Keys.guidesEnabled),
        "seen": defaults.stringArray(forKey: Keys.guidesSeen) ?? [],
      ])
    case "write":
      let values = call.arguments as? [String: Any] ?? [:]
      defaults.set(values["tipsEnabled"] as? Bool ?? true, forKey: Keys.guidesEnabled)
      defaults.set(values["seen"] as? [String] ?? [], forKey: Keys.guidesSeen)
      result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func cloudFolderURL() -> URL? {
    guard let bookmark = defaults.data(forKey: Keys.cloudBookmark) else { return nil }
    var stale = false
    do {
      let url = try URL(
        resolvingBookmarkData: bookmark,
        options: [],
        relativeTo: nil,
        bookmarkDataIsStale: &stale
      )
      if stale {
        let refreshed = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(refreshed, forKey: Keys.cloudBookmark)
      }
      return url
    } catch {
      return nil
    }
  }

  private func withCloudFolder(
    result: @escaping FlutterResult,
    operation: (URL) throws -> Void
  ) {
    guard let folder = cloudFolderURL() else {
      result(FlutterError(code: "folder_required", message: "No cloud folder is configured.", details: nil))
      return
    }
    let scoped = folder.startAccessingSecurityScopedResource()
    defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
    do {
      try operation(folder)
    } catch {
      result(FlutterError(code: "cloud_operation_failed", message: error.localizedDescription, details: nil))
    }
  }

  private func keychainRead(_ key: String) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "com.h4cks1lv3r.progressionlab",
      kSecAttrAccount as String: key,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
          let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private func keychainWrite(_ key: String, value: String) throws {
    keychainDelete(key)
    let data = Data(value.utf8)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "com.h4cks1lv3r.progressionlab",
      kSecAttrAccount as String: key,
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    let status = SecItemAdd(query as CFDictionary, nil)
    if status != errSecSuccess {
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
  }

  private func keychainDelete(_ key: String) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "com.h4cks1lv3r.progressionlab",
      kSecAttrAccount as String: key,
    ]
    SecItemDelete(query as CFDictionary)
  }

  private func isoDate(_ value: Any?) -> Date? {
    guard let value = value as? String else { return nil }
    return ISO8601DateFormatter.progressionLab.date(from: value)
      ?? ISO8601DateFormatter.progressionLabWholeSeconds.date(from: value)
  }

  private func isoString(_ value: Date) -> String {
    ISO8601DateFormatter.progressionLab.string(from: value)
  }

  private func workoutType(_ sport: String?) -> HKWorkoutActivityType {
    let value = sport?.lowercased() ?? ""
    if value.contains("run") { return .running }
    if value.contains("walk") { return .walking }
    if value.contains("cycle") || value.contains("bike") { return .cycling }
    if value.contains("swim") { return .swimming }
    if value.contains("row") { return .rowing }
    if value.contains("strength") || value.contains("weight") { return .traditionalStrengthTraining }
    if value.contains("mobility") || value.contains("stretch") { return .flexibility }
    return .other
  }

  private func workoutName(_ type: HKWorkoutActivityType) -> String {
    switch type {
    case .running: return "running"
    case .walking: return "walking"
    case .cycling: return "cycling"
    case .swimming: return "swimming"
    case .rowing: return "rowing"
    case .traditionalStrengthTraining, .functionalStrengthTraining: return "strength training"
    case .flexibility: return "mobility"
    default: return "other"
    }
  }

  private enum Keys {
    static let cloudBookmark = "progression_lab.cloud_bookmark"
    static let automaticSync = "progression_lab.cloud_automatic_sync"
    static let lastSync = "progression_lab.cloud_last_sync"
    static let integrationPreferences = "progression_lab.integration_preferences"
    static let guidesEnabled = "progression_lab.guides_enabled"
    static let guidesSeen = "progression_lab.guides_seen"
  }
}

private extension ISO8601DateFormatter {
  static let progressionLab: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()


  static let progressionLabWholeSeconds: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()
}
