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


def patch_main() -> None:
    path = "lib/main.dart"
    replace_once(
        path,
        "import 'exercise_library_screen.dart';\n",
        "import 'exercise_library_screen.dart';\nimport 'first_launch_data_setup.dart';\n",
    )
    replace_once(
        path,
        "class _ProgressionLabAppState extends State<ProgressionLabApp> {",
        "class _ProgressionLabAppState extends State<ProgressionLabApp>\n    with WidgetsBindingObserver {",
    )
    replace_once(
        path,
        """  void initState() {
    super.initState();
    _automaticCloudSync = CloudBackupSyncService.shared(store);
""",
        """  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _automaticCloudSync = CloudBackupSyncService.shared(store);
""",
    )
    replace_once(
        path,
        """  void dispose() {
    _automaticCloudSync?.dispose();
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
""",
        """  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _automaticCloudSync?.dispose();
    store.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(store.flushPendingSaves());
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
""",
    )
    replace_once(
        path,
        """  int? _tourStep;
  bool _autoTourHandled = false;
""",
        """  int? _tourStep;
  bool _dataSetupHandled = false;
  bool _autoTourHandled = false;
""",
    )
    replace_once(
        path,
        """    widget.store.addListener(_maybeStartAutomaticTour);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeStartAutomaticTour();
    });
""",
        """    widget.store.addListener(_maybeStartAutomaticOnboarding);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeStartAutomaticOnboarding();
    });
""",
    )
    replace_once(
        path,
        """      oldWidget.store.removeListener(_maybeStartAutomaticTour);
      widget.store.addListener(_maybeStartAutomaticTour);
      _autoTourHandled = false;
      _maybeStartAutomaticTour();
""",
        """      oldWidget.store.removeListener(_maybeStartAutomaticOnboarding);
      widget.store.addListener(_maybeStartAutomaticOnboarding);
      _dataSetupHandled = false;
      _autoTourHandled = false;
      _maybeStartAutomaticOnboarding();
""",
    )
    replace_once(
        path,
        """  void dispose() {
    widget.store.removeListener(_maybeStartAutomaticTour);
    super.dispose();
  }

  void _maybeStartAutomaticTour() {
    if (!mounted || _autoTourHandled || !widget.store.isLoaded) return;
    _autoTourHandled = true;
    if (widget.store.onboardingVersionSeen < _tourVersion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startTour();
      });
    }
  }
""",
        """  void dispose() {
    widget.store.removeListener(_maybeStartAutomaticOnboarding);
    super.dispose();
  }

  void _maybeStartAutomaticOnboarding() {
    if (!mounted || !widget.store.isLoaded) return;
    if (!_dataSetupHandled &&
        widget.store.dataSetupVersionSeen <
            FirstLaunchDataSetupScreen.currentVersion) {
      _dataSetupHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => FirstLaunchDataSetupScreen(store: widget.store),
          ),
        );
        if (mounted) _maybeStartAutomaticTour();
      });
      return;
    }
    _maybeStartAutomaticTour();
  }

  void _maybeStartAutomaticTour() {
    if (!mounted || _autoTourHandled || !widget.store.isLoaded) return;
    if (widget.store.dataSetupVersionSeen <
        FirstLaunchDataSetupScreen.currentVersion) {
      return;
    }
    _autoTourHandled = true;
    if (widget.store.onboardingVersionSeen < _tourVersion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startTour();
      });
    }
  }
""",
    )


def patch_store() -> None:
    path = "lib/store.dart"
    replace_once(
        path,
        """  static const _channel = MethodChannel('iron_cadence/storage');
  static const int schemaVersion = 15;
  static const double poundsToKilograms = 0.45359237;
  bool isLoaded = false;
""",
        """  static const _channel = MethodChannel('iron_cadence/storage');
  static const int schemaVersion = 16;
  static const double poundsToKilograms = 0.45359237;

  Future<void> _saveTail = Future<void>.value();
  bool isLoaded = false;
  bool hadStoredStateAtLaunch = false;
  DateTime? lastSavedAt;
  Object? lastSaveError;
""",
    )
    replace_once(
        path,
        """  int onboardingVersionSeen = 0;
  TrainingTrack preferredTrack = TrainingTrack.strength;
""",
        """  int onboardingVersionSeen = 0;
  int dataSetupVersionSeen = 0;
  TrainingTrack preferredTrack = TrainingTrack.strength;
""",
    )
    replace_once(
        path,
        """  List<LabMessage> labMessages = [];

  Future<void> load() async {
""",
        """  List<LabMessage> labMessages = [];

  bool get hasMeaningfulData =>
      logs.isNotEmpty ||
      workoutHistory.isNotEmpty ||
      drafts.isNotEmpty ||
      draft != null ||
      customExercises.isNotEmpty ||
      athleticHistory.isNotEmpty ||
      athleticAssessments.isNotEmpty ||
      importedWorkouts.isNotEmpty ||
      importHistory.isNotEmpty ||
      supplementEvents.isNotEmpty ||
      mealEvents.isNotEmpty ||
      hydrationEvents.isNotEmpty ||
      recoveryCheckIns.isNotEmpty ||
      workoutResponses.isNotEmpty ||
      labMessages.isNotEmpty ||
      integrationState.isNotEmpty ||
      week != 1 ||
      workoutIndex != 0 ||
      athleticWeek != 1 ||
      athleticSessionIndex != 0;

  Future<void> load() async {
""",
    )
    replace_once(
        path,
        """      final raw = await _channel.invokeMethod<String>('read');
      if (raw != null && raw.isNotEmpty) {
""",
        """      final raw = await _channel.invokeMethod<String>('read');
      hadStoredStateAtLaunch = raw != null && raw.trim().isNotEmpty;
      if (hadStoredStateAtLaunch) {
""",
    )
    replace_once(
        path,
        """              await _channel.invokeMethod('write', jsonEncode(exportState()));
""",
        """              await _enqueueStateWrite(jsonEncode(exportState()));
""",
    )
    replace_once(
        path,
        """    onboardingVersionSeen = (_readInt(data['onboardingVersionSeen']) ?? 0)
        .clamp(0, 1000000)
        .toInt();
    preferredTrack = data['preferredTrack'] == 'athletic'
""",
        """    onboardingVersionSeen = (_readInt(data['onboardingVersionSeen']) ?? 0)
        .clamp(0, 1000000)
        .toInt();
    dataSetupVersionSeen = (_readInt(data['dataSetupVersionSeen']) ?? 0)
        .clamp(0, 1000000)
        .toInt();
    preferredTrack = data['preferredTrack'] == 'athletic'
""",
    )
    replace_once(
        path,
        """      await _channel.invokeMethod('write', jsonEncode(exportState()));
""",
        """      await save(createAutomaticBackup: false);
""",
    )
    replace_once(
        path,
        """    'onboardingVersionSeen': onboardingVersionSeen,
    'preferredTrack': preferredTrack.name,
""",
        """    'onboardingVersionSeen': onboardingVersionSeen,
    'dataSetupVersionSeen': dataSetupVersionSeen,
    'preferredTrack': preferredTrack.name,
""",
    )
    replace_once(
        path,
        """  Future<void> save({bool createAutomaticBackup = true}) async {
    final state = exportState();
    await _channel.invokeMethod('write', jsonEncode(state));
    if (automaticBackupsEnabled && createAutomaticBackup) {
      await _writeAutomaticBackup(
        state,
        reason: 'automatic',
        suppressErrors: true,
      );
    }
  }
""",
        """  Future<void> save({bool createAutomaticBackup = true}) async {
    final state = exportState();
    await _enqueueStateWrite(jsonEncode(state));
    if (automaticBackupsEnabled && createAutomaticBackup) {
      await _writeAutomaticBackup(
        state,
        reason: 'automatic',
        suppressErrors: true,
      );
    }
  }

  Future<void> _enqueueStateWrite(String encoded) {
    final previous = _saveTail;
    final operation = () async {
      try {
        await previous;
      } on Object {
        // A later complete snapshot must still be allowed to repair storage.
      }
      try {
        await _channel.invokeMethod<void>('write', encoded);
        lastSavedAt = DateTime.now();
        lastSaveError = null;
      } on Object catch (error) {
        lastSaveError = error;
        rethrow;
      }
    }();
    _saveTail = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> flushPendingSaves() => _saveTail;
""",
    )
    replace_once(
        path,
        """  Future<void> markOnboardingSeen(int version) async {
    if (version <= onboardingVersionSeen) return;
    final previous = onboardingVersionSeen;
    onboardingVersionSeen = version;
    notifyListeners();
    try {
      await save(createAutomaticBackup: false);
    } on Object {
      onboardingVersionSeen = previous;
      notifyListeners();
      rethrow;
    }
  }

  List<SupplementPreset> get activeSupplementPresets =>
""",
        """  Future<void> markOnboardingSeen(int version) async {
    if (version <= onboardingVersionSeen) return;
    final previous = onboardingVersionSeen;
    onboardingVersionSeen = version;
    notifyListeners();
    try {
      await save(createAutomaticBackup: false);
    } on Object {
      onboardingVersionSeen = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markDataSetupSeen(int version) async {
    if (version <= dataSetupVersionSeen) return;
    final previous = dataSetupVersionSeen;
    dataSetupVersionSeen = version;
    notifyListeners();
    try {
      await save(createAutomaticBackup: false);
    } on Object {
      dataSetupVersionSeen = previous;
      notifyListeners();
      rethrow;
    }
  }

  List<SupplementPreset> get activeSupplementPresets =>
""",
    )
    replace_once(
        path,
        """    data.putIfAbsent('integrationState', () => <String, dynamic>{});
    data['schemaVersion'] = schemaVersion;
""",
        """    data.putIfAbsent('integrationState', () => <String, dynamic>{});
    if (version < 16) {
      data.putIfAbsent('dataSetupVersionSeen', () => 0);
      version = 16;
      data['schemaVersion'] = version;
    }
    data['schemaVersion'] = schemaVersion;
""",
    )


def patch_data_management() -> None:
    path = "lib/data_management_screen.dart"
    replace_once(
        path,
        """class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key, required this.store});

  final AppStore store;
""",
        """class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({
    super.key,
    required this.store,
    this.startImportOnOpen = false,
    this.closeAfterImport = false,
  });

  final AppStore store;
  final bool startImportOnOpen;
  final bool closeAfterImport;
""",
    )
    replace_once(
        path,
        """    controller = DataPortabilityController(widget.store);
    _refreshBackups();
  }
""",
        """    controller = DataPortabilityController(widget.store);
    _refreshBackups();
    if (widget.startImportOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_pickImport());
      });
    }
  }
""",
    )
    replace_once(
        path,
        """  Future<void> _pickImport() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final candidate = await controller.pickImportFile();
      if (!mounted || candidate == null) return;
      switch (candidate) {
        case BackupImportCandidate():
          await _confirmRestore(candidate);
          break;
        case CsvImportCandidate():
          await _configureCsvImport(candidate);
          break;
      }
""",
        """  Future<void> _pickImport() async {
    if (_busy) return;
    setState(() => _busy = true);
    var completed = false;
    try {
      final candidate = await controller.pickImportFile();
      if (!mounted || candidate == null) return;
      switch (candidate) {
        case BackupImportCandidate():
          completed = await _confirmRestore(candidate);
          break;
        case CsvImportCandidate():
          completed = await _configureCsvImport(candidate);
          break;
      }
      if (completed && widget.closeAfterImport && mounted) {
        Navigator.of(context).pop(true);
      }
""",
    )
    replace_once(
        path,
        """  Future<void> _confirmRestore(BackupImportCandidate candidate) async {
""",
        """  Future<bool> _confirmRestore(BackupImportCandidate candidate) async {
""",
    )
    replace_once(
        path,
        """    if (confirmed != true || !mounted) return;
    await controller.restoreDocument(candidate.document);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup restored successfully.')),
    );
  }

  Future<void> _configureCsvImport(CsvImportCandidate candidate) async {
""",
        """    if (confirmed != true || !mounted) return false;
    await controller.restoreDocument(candidate.document);
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup restored successfully.')),
    );
    return true;
  }

  Future<bool> _configureCsvImport(CsvImportCandidate candidate) async {
""",
    )
    replace_once(
        path,
        """    if (mapping == null || !mounted) return;
""",
        """    if (mapping == null || !mounted) return false;
""",
    )
    replace_once(
        path,
        """      if (selected == null || !mounted) return;
""",
        """      if (selected == null || !mounted) return false;
""",
    )
    replace_once(
        path,
        """    if (imported == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Imported ${imported.workoutCount} workouts and ${imported.setCount} sets.',
        ),
      ),
    );
  }
""",
        """    if (imported == null || !mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Imported ${imported.workoutCount} workouts and ${imported.setCount} sets.',
        ),
      ),
    );
    return true;
  }
""",
    )


def patch_backup_metadata() -> None:
    path = "lib/data_portability_core.dart"
    replace_once(
        path,
        "const String progressionAppVersion = '1.6.0';",
        "const String progressionAppVersion = '2.2.0';",
    )
    replace_once(
        path,
        """        'onboardingVersionSeen': state['onboardingVersionSeen'],
        'automaticBackupsEnabled': state['automaticBackupsEnabled'],
""",
        """        'onboardingVersionSeen': state['onboardingVersionSeen'],
        'dataSetupVersionSeen': state['dataSetupVersionSeen'],
        'automaticBackupsEnabled': state['automaticBackupsEnabled'],
""",
    )


def patch_android() -> None:
    path = "android/app/src/main/kotlin/com/h4cks1lv3/iron_cadence/MainActivity.kt"
    replace_once(
        path,
        "import android.content.Intent\n",
        "import android.content.Intent\nimport android.content.SharedPreferences\n",
    )
    replace_once(
        path,
        "import android.provider.OpenableColumns\n",
        "import android.provider.OpenableColumns\nimport android.util.AtomicFile\n",
    )
    replace_once(
        path,
        "import java.io.File\n",
        "import java.io.File\nimport java.io.FileOutputStream\n",
    )
    replace_once(
        path,
        """class MainActivity : FlutterActivity() {
    private var integrationBridge: IntegrationBridge? = null
""",
        """class MainActivity : FlutterActivity() {
    private var integrationBridge: IntegrationBridge? = null
    private val stateLock = Any()
""",
    )
    replace_once(
        path,
        """                when (call.method) {
                    "read" -> result.success(preferences.getString("state", null))
                    "write" -> {
                        preferences.edit().putString("state", call.arguments as? String ?: "{}").apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
""",
        """                when (call.method) {
                    "read" -> result.success(readLocalState(preferences))
                    "write" -> {
                        val encoded = call.arguments as? String ?: "{}"
                        writeLocalState(encoded)
                        preferences.edit().remove("state").commit()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
""",
    )
    replace_once(
        path,
        """    private fun handleShareImageCall(call: MethodCall, result: MethodChannel.Result) {
""",
        """    private fun progressionStateFile(): AtomicFile {
        val directory = File(filesDir, "progression_lab_state").apply { mkdirs() }
        return AtomicFile(File(directory, "state.json"))
    }

    private fun readLocalState(preferences: SharedPreferences): String? = synchronized(stateLock) {
        val stateFile = progressionStateFile()
        if (stateFile.baseFile.exists()) {
            return@synchronized String(stateFile.readFully(), Charsets.UTF_8)
        }
        val legacy = preferences.getString("state", null)?.takeIf { it.isNotBlank() }
        if (legacy != null) {
            writeLocalState(legacy)
            preferences.edit().remove("state").commit()
        }
        legacy
    }

    private fun writeLocalState(encoded: String): Boolean = synchronized(stateLock) {
        val stateFile = progressionStateFile()
        val output: FileOutputStream = stateFile.startWrite()
        try {
            output.write(encoded.toByteArray(Charsets.UTF_8))
            output.flush()
            stateFile.finishWrite(output)
            true
        } catch (error: Exception) {
            stateFile.failWrite(output)
            throw error
        }
    }

    private fun handleShareImageCall(call: MethodCall, result: MethodChannel.Result) {
""",
    )


def patch_ios() -> None:
    path = "ios/Runner/AppDelegate.swift"
    replace_once(
        path,
        """    storageChannel.setMethodCallHandler { call, result in
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
""",
        """    storageChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(
          FlutterError(
            code: "storage_unavailable",
            message: "Progression Lab storage is unavailable.",
            details: nil
          )
        )
        return
      }
      do {
        switch call.method {
        case "read":
          result(try self.readLocalState())
        case "write":
          try self.writeLocalState(call.arguments as? String ?? "{}")
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(
          FlutterError(
            code: "storage_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    }
""",
    )
    replace_once(
        path,
        """  private func handleShareImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
""",
        """  private func localStateURL() throws -> URL {
    let applicationSupport = try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let directory = applicationSupport.appendingPathComponent(
      "ProgressionLab",
      isDirectory: true
    )
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    return directory.appendingPathComponent("state.json")
  }

  private func readLocalState() throws -> String? {
    let url = try localStateURL()
    if FileManager.default.fileExists(atPath: url.path) {
      return try String(contentsOf: url, encoding: .utf8)
    }
    let legacyKey = "progression_lab_state"
    guard let legacy = UserDefaults.standard.string(forKey: legacyKey),
          !legacy.isEmpty else {
      return nil
    }
    try writeLocalState(legacy)
    UserDefaults.standard.removeObject(forKey: legacyKey)
    return legacy
  }

  private func writeLocalState(_ encoded: String) throws {
    let data = Data(encoded.utf8)
    try data.write(to: localStateURL(), options: .atomic)
  }

  private func handleShareImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
""",
    )


def patch_versions_and_docs() -> None:
    replace_once("pubspec.yaml", "version: 2.1.1+15", "version: 2.2.0+16")
    replace_once(
        "android/app/build.gradle.kts",
        "versionCode = 15",
        "versionCode = 16",
    )
    replace_once(
        "android/app/build.gradle.kts",
        'versionName = "2.1.1"',
        'versionName = "2.2.0"',
    )
    replace_once(
        "README.md",
        "Current version: **2.1.1+15**",
        "Current version: **2.2.0+16**",
    )
    replace_once(
        "README.md",
        """Progression Lab supports:

- versioned `.plab` backup and restore
""",
        """Progression Lab supports:

- atomic app-private state writes after every committed workout or settings mutation
- serialized save ordering so an older asynchronous write cannot overwrite a newer change
- versioned `.plab` backup and restore
""",
    )
    replace_once(
        "README.md",
        """A skippable first-launch tour uses a branded guide to highlight the live interface. It can be replayed from **More → Help & Guides → App Tour**. Integration-specific coach marks can be replayed or reset from **Connections & Experiments**.
""",
        """Before the visual tour, a first-open data setup checks whether existing Progression Lab state was loaded, looks for app-local automatic backups, and offers guided import from Strong, Hevy, FitNotes, generic CSV/ZIP, Health Connect, or Apple Health. Other apps' private databases are never read directly; the user selects an export file or grants health-platform access.

A skippable first-launch tour then uses a branded guide to highlight the live interface. It can be replayed from **More → Help & Guides → App Tour**. Integration-specific coach marks can be replayed or reset from **Connections & Experiments**.
""",
    )

    changelog = Path("CHANGELOG.md")
    text = changelog.read_text()
    heading = "## 2.2.0+16 — 2026-09-01"
    if heading not in text:
        entry = """# Changelog

## 2.2.0+16 — 2026-09-01

### Added

- Added a first-open data setup that checks for existing Progression Lab state and recoverable automatic backups before the visual app tour.
- Added guided first-open import for Strong, Hevy, FitNotes, generic CSV/ZIP, Health Connect, and Apple Health sources.
- Added a clear existing-data summary so upgrades do not look like empty installations.

### Changed

- Moved primary Android state from asynchronous SharedPreferences writes to an app-private `AtomicFile` with legacy migration.
- Moved primary iOS state from UserDefaults to an atomically replaced Application Support file with legacy migration.
- Serialized Dart persistence writes so concurrent mutations cannot complete out of order.
- Added app-lifecycle flushing for queued local writes.

### Corrected

- Prevented the visual app tour from opening over the first-launch recovery and import decision.
- Preserved the first-launch data-setup decision in exact backups and schema migration.

"""
        if not text.startswith("# Changelog\n"):
            raise RuntimeError("Unexpected CHANGELOG.md header")
        changelog.write_text(entry + text[len("# Changelog\n\n") :])


def main() -> None:
    patch_main()
    patch_store()
    patch_data_management()
    patch_backup_metadata()
    patch_android()
    patch_ios()
    patch_versions_and_docs()


if __name__ == "__main__":
    main()
