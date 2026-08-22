import Flutter
import Photos
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UIDocumentPickerDelegate {
  private enum PickerOperation {
    case open(FlutterResult)
    case save(FlutterResult, URL)
  }

  private var pickerOperation: PickerOperation?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "ProgressionLabDataPortability"
    ) else { return }
    let messenger = registrar.messenger()

    if let controller = window?.rootViewController {
      IntegrationBridgeIOS.shared.register(
        messenger: messenger,
        viewController: controller
      )
    }
    let storageChannel = FlutterMethodChannel(
      name: "iron_cadence/storage",
      binaryMessenger: messenger
    )
    storageChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "read":
        result(UserDefaults.standard.string(forKey: "progression_lab_state"))
      case "write":
        UserDefaults.standard.set(call.arguments as? String ?? "{}", forKey: "progression_lab_state")
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let shareChannel = FlutterMethodChannel(
      name: "progression_lab/share",
      binaryMessenger: messenger
    )
    shareChannel.setMethodCallHandler { [weak self] call, result in
      self?.handleShareImage(call: call, result: result)
    }

    let portabilityChannel = FlutterMethodChannel(
      name: "progression_lab/data_portability",
      binaryMessenger: messenger
    )
    portabilityChannel.setMethodCallHandler { [weak self] call, result in
      self?.handleDataPortability(call: call, result: result)
    }
  }

  private func handleShareImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      let arguments = try dictionary(call.arguments)
      let data = try requiredData(arguments)
      let name = safeFileName(
        arguments["fileName"] as? String,
        fallback: "progression-lab-workout.png"
      )
      switch call.method {
      case "saveImage":
        try saveImageToPhotos(data: data, result: result)
      case "shareImage":
        try share(data: data, fileName: name, mimeType: "image/png")
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch {
      result(
        FlutterError(
          code: "share_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func saveImageToPhotos(data: Data, result: @escaping FlutterResult) throws {
    guard let image = UIImage(data: data) else {
      throw DataPortabilityError("The generated workout image is invalid.")
    }
    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
      guard status == .authorized || status == .limited else {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "photos_denied",
              message: "Allow Progression Lab to add workout cards to Photos.",
              details: nil
            )
          )
        }
        return
      }
      PHPhotoLibrary.shared().performChanges {
        PHAssetChangeRequest.creationRequestForAsset(from: image)
      } completionHandler: { success, error in
        DispatchQueue.main.async {
          if success {
            result("photos")
          } else {
            result(
              FlutterError(
                code: "save_failed",
                message: error?.localizedDescription ?? "The workout card could not be saved.",
                details: nil
              )
            )
          }
        }
      }
    }
  }

  private func handleDataPortability(call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      switch call.method {
      case "saveFile":
        try beginSaveFile(arguments: call.arguments, result: result)
      case "pickFile":
        try beginPickFile(result: result)
      case "shareFile":
        let arguments = try dictionary(call.arguments)
        let data = try requiredData(arguments)
        let name = safeFileName(arguments["fileName"] as? String, fallback: "Progression-Lab-Export.plab")
        let mime = arguments["mimeType"] as? String ?? "application/octet-stream"
        try share(data: data, fileName: name, mimeType: mime)
        result(nil)
      case "writeAutomaticBackup":
        let arguments = try dictionary(call.arguments)
        let data = try requiredData(arguments)
        let name = safeFileName(arguments["fileName"] as? String, fallback: "Progression-Lab-Auto.plab")
        let retention = max(1, min(100, (arguments["retention"] as? NSNumber)?.intValue ?? 16))
        result(try writeAutomaticBackup(data: data, fileName: name, retention: retention))
      case "listAutomaticBackups":
        result(try listAutomaticBackups())
      case "readAutomaticBackup":
        let arguments = try dictionary(call.arguments)
        guard let path = arguments["path"] as? String else {
          throw DataPortabilityError("Backup path is missing.")
        }
        let data = try Data(contentsOf: verifiedBackupURL(path: path))
        result(FlutterStandardTypedData(bytes: data))
      case "deleteAutomaticBackup":
        let arguments = try dictionary(call.arguments)
        guard let path = arguments["path"] as? String else {
          throw DataPortabilityError("Backup path is missing.")
        }
        let url = try verifiedBackupURL(path: path)
        if FileManager.default.fileExists(atPath: url.path) {
          try FileManager.default.removeItem(at: url)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch {
      result(
        FlutterError(
          code: "data_portability_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func dictionary(_ arguments: Any?) throws -> [String: Any] {
    guard let value = arguments as? [String: Any] else {
      throw DataPortabilityError("File arguments are missing.")
    }
    return value
  }

  private func requiredData(_ arguments: [String: Any]) throws -> Data {
    if let typed = arguments["bytes"] as? FlutterStandardTypedData, !typed.data.isEmpty {
      return typed.data
    }
    if let bytes = arguments["bytes"] as? [UInt8], !bytes.isEmpty {
      return Data(bytes)
    }
    throw DataPortabilityError("The file is empty.")
  }

  private func beginSaveFile(arguments: Any?, result: @escaping FlutterResult) throws {
    guard pickerOperation == nil else {
      throw DataPortabilityError("Another file picker is already open.")
    }
    let values = try dictionary(arguments)
    let data = try requiredData(values)
    let name = safeFileName(values["fileName"] as? String, fallback: "Progression-Lab-Export.plab")
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("progression_lab_exports", isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    let url = directory.appendingPathComponent(name)
    try data.write(to: url, options: .atomic)
    pickerOperation = .save(result, url)
    let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    picker.delegate = self
    present(picker)
  }

  private func beginPickFile(result: @escaping FlutterResult) throws {
    guard pickerOperation == nil else {
      throw DataPortabilityError("Another file picker is already open.")
    }
    pickerOperation = .open(result)
    let picker = UIDocumentPickerViewController(
      forOpeningContentTypes: [.zip, .commaSeparatedText, .data],
      asCopy: true
    )
    picker.allowsMultipleSelection = false
    picker.delegate = self
    present(picker)
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard let operation = pickerOperation else { return }
    pickerOperation = nil
    switch operation {
    case .save(let result, let temporaryURL):
      try? FileManager.default.removeItem(at: temporaryURL)
      result(urls.first?.path)
    case .open(let result):
      guard let url = urls.first else {
        result(nil)
        return
      }
      let accessed = url.startAccessingSecurityScopedResource()
      defer {
        if accessed { url.stopAccessingSecurityScopedResource() }
      }
      do {
        let data = try Data(contentsOf: url)
        if data.count > 100 * 1024 * 1024 {
          throw DataPortabilityError("The selected file is larger than 100 MB.")
        }
        let values = try url.resourceValues(forKeys: [.contentTypeKey])
        result([
          "name": url.lastPathComponent,
          "bytes": FlutterStandardTypedData(bytes: data),
          "mimeType": values.contentType?.preferredMIMEType ?? "application/octet-stream",
        ])
      } catch {
        result(
          FlutterError(
            code: "open_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    guard let operation = pickerOperation else { return }
    pickerOperation = nil
    switch operation {
    case .open(let result):
      result(nil)
    case .save(let result, let temporaryURL):
      try? FileManager.default.removeItem(at: temporaryURL)
      result(nil)
    }
  }

  private func present(_ controller: UIViewController) {
    DispatchQueue.main.async { [weak self] in
      guard let root = self?.window?.rootViewController else { return }
      var top = root
      while let presented = top.presentedViewController { top = presented }
      top.present(controller, animated: true)
    }
  }

  private func share(data: Data, fileName: String, mimeType: String) throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("progression_lab_shared", isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    let url = directory.appendingPathComponent(fileName)
    try data.write(to: url, options: .atomic)
    let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    activity.completionWithItemsHandler = { _, _, _, _ in
      try? FileManager.default.removeItem(at: url)
    }
    if let popover = activity.popoverPresentationController {
      popover.sourceView = window?.rootViewController?.view
      popover.sourceRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    }
    present(activity)
  }

  private func backupsDirectory() throws -> URL {
    let base = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first!
    let directory = base.appendingPathComponent("Progression Lab Backups", isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    return directory
  }

  private func writeAutomaticBackup(
    data: Data,
    fileName: String,
    retention: Int
  ) throws -> String {
    let directory = try backupsDirectory()
    let existing = try automaticBackupURLs(directory: directory)
    if let latest = existing.first,
       let latestData = try? Data(contentsOf: latest),
       latestData == data {
      return latest.path
    }
    let destination = directory.appendingPathComponent(fileName)
    try data.write(to: destination, options: .atomic)
    let refreshed = try automaticBackupURLs(directory: directory)
    try pruneAutomaticBackups(refreshed, retention: retention)
    return destination.path
  }

  private func pruneAutomaticBackups(_ files: [URL], retention: Int) throws {
    guard files.count > 1 else { return }
    let calendar = Calendar.current
    let now = Date()
    var keep = Set(files.prefix(5))
    var dailyKeys = Set<String>()
    var weeklyKeys = Set<String>()

    for url in files {
      let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
      let modified = values.contentModificationDate ?? .distantPast
      let age = max(0, now.timeIntervalSince(modified))
      if age <= 7 * 24 * 60 * 60 {
        let parts = calendar.dateComponents([.year, .month, .day], from: modified)
        let key = "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
        if dailyKeys.insert(key).inserted { keep.insert(url) }
      }
      if age <= 28 * 24 * 60 * 60 {
        let parts = calendar.dateComponents(
          [.yearForWeekOfYear, .weekOfYear],
          from: modified
        )
        let key = "\(parts.yearForWeekOfYear ?? 0)-\(parts.weekOfYear ?? 0)"
        if weeklyKeys.insert(key).inserted { keep.insert(url) }
      }
    }

    let retained = Set(files.filter { keep.contains($0) }.prefix(retention))
    for url in files where !retained.contains(url) {
      try? FileManager.default.removeItem(at: url)
    }
  }

  private func automaticBackupURLs(directory: URL) throws -> [URL] {
    let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
    let urls = try FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: Array(keys),
      options: [.skipsHiddenFiles]
    )
    return try urls
      .filter { $0.pathExtension.lowercased() == "plab" }
      .sorted {
        let left = try $0.resourceValues(forKeys: keys).contentModificationDate ?? .distantPast
        let right = try $1.resourceValues(forKeys: keys).contentModificationDate ?? .distantPast
        return left > right
      }
  }

  private func listAutomaticBackups() throws -> [[String: Any]] {
    let directory = try backupsDirectory()
    return try automaticBackupURLs(directory: directory).map { url in
      let values = try url.resourceValues(
        forKeys: [.contentModificationDateKey, .fileSizeKey]
      )
      return [
        "name": url.lastPathComponent,
        "path": url.path,
        "size": values.fileSize ?? 0,
        "modified": Int((values.contentModificationDate ?? .distantPast).timeIntervalSince1970 * 1000),
      ]
    }
  }

  private func verifiedBackupURL(path: String) throws -> URL {
    let directory = try backupsDirectory().standardizedFileURL
    let url = URL(fileURLWithPath: path).standardizedFileURL
    guard url.deletingLastPathComponent() == directory else {
      throw DataPortabilityError("The selected path is not an app backup.")
    }
    return url
  }

  private func safeFileName(_ value: String?, fallback: String) -> String {
    let source = (value?.isEmpty == false ? value! : fallback)
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
    let cleaned = source.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
    return String(cleaned.prefix(160))
  }
}

private struct DataPortabilityError: LocalizedError {
  init(_ message: String) { self.message = message }
  let message: String
  var errorDescription: String? { message }
}
