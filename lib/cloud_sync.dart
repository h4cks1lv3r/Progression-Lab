import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'data_portability.dart';
import 'data_portability_core.dart';
import 'user_feedback.dart';
import 'store.dart';

enum CloudFolderProvider {
  localFolder,
  googleDrive,
  iCloudDrive,
  oneDrive,
  dropbox,
  filesProvider,
  webDav,
  unknown,
}

enum CloudSyncDirection { none, upload, download, conflict }

extension CloudFolderProviderLabel on CloudFolderProvider {
  String get label => switch (this) {
    CloudFolderProvider.localFolder => 'Device folder',
    CloudFolderProvider.googleDrive => 'Google Drive',
    CloudFolderProvider.iCloudDrive => 'iCloud Drive',
    CloudFolderProvider.oneDrive => 'OneDrive',
    CloudFolderProvider.dropbox => 'Dropbox',
    CloudFolderProvider.filesProvider => 'Files',
    CloudFolderProvider.webDav => 'WebDAV',
    CloudFolderProvider.unknown => 'Selected folder',
  };
}

class CloudFolderStatus {
  const CloudFolderStatus({
    required this.configured,
    this.provider = CloudFolderProvider.unknown,
    this.displayName = '',
    this.locationToken = '',
    this.lastSuccessfulSync,
    this.message = '',
  });

  final bool configured;
  final CloudFolderProvider provider;
  final String displayName;
  final String locationToken;
  final DateTime? lastSuccessfulSync;
  final String message;

  factory CloudFolderStatus.fromJson(Map<Object?, Object?> value) {
    final providerName = '${value['provider']}';
    final provider = CloudFolderProvider.values
        .where((item) => item.name == providerName)
        .firstOrNull;
    return CloudFolderStatus(
      configured: value['configured'] == true,
      provider: provider ?? CloudFolderProvider.unknown,
      displayName: value['displayName'] is String
          ? value['displayName']! as String
          : '',
      locationToken: value['locationToken'] is String
          ? value['locationToken']! as String
          : '',
      lastSuccessfulSync: value['lastSuccessfulSync'] is String
          ? DateTime.tryParse(value['lastSuccessfulSync']! as String)?.toUtc()
          : null,
      message: value['message'] is String ? value['message']! as String : '',
    );
  }
}

class CloudBackupInfo {
  const CloudBackupInfo({
    required this.name,
    required this.modifiedAt,
    required this.size,
    this.token = '',
    this.deviceId = '',
    this.schemaVersion,
    this.createdAt,
  });

  final String name;
  final DateTime modifiedAt;
  final int size;
  final String token;
  final String deviceId;
  final int? schemaVersion;
  final DateTime? createdAt;

  factory CloudBackupInfo.fromJson(Map<Object?, Object?> value) =>
      CloudBackupInfo(
        name: '${value['name']}',
        modifiedAt: DateTime.parse('${value['modifiedAt']}').toUtc(),
        size: (value['size'] as num?)?.toInt() ?? 0,
        token: value['token'] is String ? value['token']! as String : '',
        deviceId: value['deviceId'] is String
            ? value['deviceId']! as String
            : '',
        schemaVersion: (value['schemaVersion'] as num?)?.toInt(),
        createdAt: value['createdAt'] is String
            ? DateTime.tryParse(value['createdAt']! as String)?.toUtc()
            : null,
      );
}

class CloudSyncPreview {
  const CloudSyncPreview({
    required this.direction,
    this.remote,
    this.localCreatedAt,
    this.reason = '',
  });

  final CloudSyncDirection direction;
  final CloudBackupInfo? remote;
  final DateTime? localCreatedAt;
  final String reason;
}

class CloudRestorePreview {
  const CloudRestorePreview({
    required this.backup,
    required this.document,
    required this.currentSetCount,
    required this.currentWorkoutCount,
    required this.currentStateFingerprint,
  });

  final CloudBackupInfo backup;
  final PortableBackupDocument document;
  final int currentSetCount;
  final int currentWorkoutCount;
  final String currentStateFingerprint;

  int get backupSetCount => _listLength(document.state['logs']);
  int get backupWorkoutCount => _workoutCount(document.state);
}

int _listLength(Object? value) => value is List ? value.length : 0;

int _workoutCount(Map<String, dynamic> state) =>
    _listLength(state['workoutHistory']) +
    _listLength(state['athleticHistory']) +
    _listLength(state['importedWorkouts']) +
    _listLength((state['openWorkout'] as Map?)?['history']) +
    _listLength((state['curatedTraining'] as Map?)?['history']);

// JSON map order and the time an export was created are not data revisions.
String _stateFingerprint(Map<String, dynamic> state) {
  Object? canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => '$key').toList()..sort();
      return {for (final key in keys) key: canonical(value[key])};
    }
    if (value is List) return value.map(canonical).toList();
    return value;
  }

  return sha256Hex(utf8.encode(jsonEncode(canonical(state))));
}

bool _hasSavedUserData(Map<String, dynamic> state) {
  const domains = [
    'logs',
    'workoutHistory',
    'athleticHistory',
    'athleticAssessments',
    'importedWorkouts',
    'bodyMeasurements',
    'customExercises',
    'supplementEvents',
    'mealEvents',
    'hydrationEvents',
    'recoveryCheckIns',
    'workoutResponses',
    'labMessages',
    'drafts',
    'athleticDrafts',
  ];
  if (domains.any((key) => _listLength(state[key]) > 0)) return true;
  if (state['draft'] != null || state['athleticDraft'] != null) return true;
  for (final key in ['openWorkout', 'curatedTraining']) {
    final value = state[key];
    if (value is Map &&
        (value['draft'] != null ||
            (value['drafts'] is Map && (value['drafts'] as Map).isNotEmpty) ||
            _listLength(value['history']) > 0)) {
      return true;
    }
  }
  return false;
}

/// Coordinates user-selected folder sync. The platform implementation uses
/// Android's Storage Access Framework or the iOS document picker so Drive,
/// iCloud Drive, OneDrive, Dropbox, and other Files providers can participate
/// without Progression Lab receiving those account credentials.
class CloudBackupSyncService extends ChangeNotifier {
  static final Expando<CloudBackupSyncService> _shared =
      Expando<CloudBackupSyncService>('progression-lab-cloud-sync');

  static CloudBackupSyncService shared(AppStore store) =>
      _shared[store] ??= CloudBackupSyncService(store: store);

  CloudBackupSyncService({required AppStore store, MethodChannel? channel})
    : _store = store,
      _portability = DataPortabilityController(store),
      _channel = channel ?? const MethodChannel('progression_lab/cloud_sync');

  final AppStore _store;
  final DataPortabilityController _portability;
  final MethodChannel _channel;
  CloudFolderStatus _status = const CloudFolderStatus(configured: false);
  bool _automaticSyncEnabled = false;
  bool _busy = false;
  String? _lastError;
  Timer? _debounce;
  bool _listening = false;
  bool _pendingChanges = true;
  String? _lastUploadedFingerprint;
  bool _pausedForLocalDeletion = false;
  Completer<void>? _operationFinished;

  CloudFolderStatus get status => _status;
  bool get automaticSyncEnabled => _automaticSyncEnabled;
  bool get busy => _busy;
  String? get lastError => _lastError;
  bool get pendingChanges => _lastUploadedFingerprint == null
      ? _pendingChanges
      : _stateFingerprint(_store.exportState()) != _lastUploadedFingerprint;
  bool get backupStatusVerified => _lastUploadedFingerprint != null;

  Future<void> initialize() async {
    await _guard(() async {
      final result = await _channel.invokeMapMethod<Object?, Object?>('status');
      _status = CloudFolderStatus.fromJson(
        result ?? const <Object?, Object?>{},
      );
      _automaticSyncEnabled = result?['automaticSyncEnabled'] == true;
      _startListening();
      notifyListeners();
    });
  }

  Future<CloudFolderStatus> chooseFolder() async {
    return _guard(() async {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'chooseFolder',
        const <String, Object>{
          'purpose': 'Progression Lab automatic backups',
          'suggestedFolderName': 'Progression Lab',
        },
      );
      if (result == null) return _status;
      _status = CloudFolderStatus.fromJson(result);
      _lastUploadedFingerprint = null;
      _pendingChanges = true;
      _lastError = null;
      _startListening();
      notifyListeners();
      return _status;
    });
  }

  Future<void> disconnectFolder() async {
    await _guard(() async {
      await _channel.invokeMethod<void>('disconnectFolder');
      _status = const CloudFolderStatus(configured: false);
      _automaticSyncEnabled = false;
      _lastUploadedFingerprint = null;
      _pendingChanges = true;
      _lastError = null;
      _stopListening();
      notifyListeners();
    });
  }

  Future<void> setAutomaticSyncEnabled(bool enabled) async {
    if (enabled && !_status.configured) {
      throw StateError(
        'Choose a backup folder before enabling automatic sync.',
      );
    }
    await _guard(() async {
      await _channel.invokeMethod<void>(
        'setAutomaticSyncEnabled',
        <String, bool>{'enabled': enabled},
      );
      _automaticSyncEnabled = enabled;
      _startListening();
      if (enabled && pendingChanges) _scheduleAutomaticUpload();
      if (!enabled) _debounce?.cancel();
      notifyListeners();
    });
  }

  Future<List<CloudBackupInfo>> listBackups() async {
    return _guard(() async {
      final result =
          await _channel.invokeListMethod<Object?>('listBackups') ??
          const <Object?>[];
      final values = result
          .whereType<Map>()
          .map(
            (item) =>
                CloudBackupInfo.fromJson(Map<Object?, Object?>.from(item)),
          )
          .toList();
      values.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      return values;
    });
  }

  Future<CloudSyncPreview> preview() async {
    final backups = await listBackups();
    if (backups.isEmpty) {
      return CloudSyncPreview(
        direction: CloudSyncDirection.upload,
        reason: 'No cloud backup exists yet.',
      );
    }
    final remote = backups.first;
    if (!_hasSavedUserData(_store.exportState())) {
      return CloudSyncPreview(
        direction: CloudSyncDirection.download,
        remote: remote,
        reason:
            'This device has no saved history. Choose a cloud backup to review and restore.',
      );
    }
    final remoteDocument = await _guard(() => _readBackup(remote));
    final fingerprint = _stateFingerprint(_store.exportState());
    if (fingerprint == _stateFingerprint(remoteDocument.state)) {
      _lastUploadedFingerprint = fingerprint;
      _pendingChanges = false;
      notifyListeners();
      return CloudSyncPreview(
        direction: CloudSyncDirection.none,
        remote: remote,
        reason:
            'This device and the latest cloud backup contain the same data.',
      );
    }
    return CloudSyncPreview(
      direction: CloudSyncDirection.conflict,
      remote: remote,
      reason:
          'This device and the cloud contain different data. Choose Back up now to save this device, or Restore from cloud to review a replacement.',
    );
  }

  Future<CloudBackupInfo> uploadNow({
    String reason = 'manual-cloud-sync',
  }) async {
    if (!_status.configured) {
      throw StateError('No cloud backup folder is configured.');
    }
    return _guard(() async {
      final bytes = _portability.buildBackup(reason: reason);
      final document = ProgressionBackupCodec.decode(bytes);
      final uploadedFingerprint = _stateFingerprint(document.state);
      final createdAt = '${document.manifest['createdAt']}';
      final fileName = 'Progression-Lab-${_safeTimestamp(createdAt)}.plab';
      final result = await _channel
          .invokeMapMethod<Object?, Object?>('writeBackup', <String, Object>{
            'name': fileName,
            'bytes': bytes,
            'createdAt': createdAt,
            'schemaVersion': AppStore.schemaVersion,
          });
      if (result == null) {
        throw StateError('The cloud provider did not return a saved backup.');
      }
      final saved = CloudBackupInfo.fromJson(result);
      _lastUploadedFingerprint = uploadedFingerprint;
      _pendingChanges = pendingChanges;
      _lastError = null;
      _status = CloudFolderStatus(
        configured: _status.configured,
        provider: _status.provider,
        displayName: _status.displayName,
        locationToken: _status.locationToken,
        lastSuccessfulSync: DateTime.now().toUtc(),
      );
      notifyListeners();
      return saved;
    });
  }

  Future<void> restoreRemote(CloudBackupInfo backup) async {
    final preview = await prepareRestore(backup);
    await restorePrepared(preview);
  }

  Future<PortableBackupDocument> _readBackup(CloudBackupInfo backup) async {
    final bytes = await _channel.invokeMethod<Uint8List>(
      'readBackup',
      <String, String>{'token': backup.token, 'name': backup.name},
    );
    if (bytes == null || bytes.isEmpty) {
      throw StateError('The selected cloud backup could not be read.');
    }
    return ProgressionBackupCodec.decode(bytes);
  }

  Future<CloudRestorePreview> prepareRestore(CloudBackupInfo backup) => _guard(
    () async => CloudRestorePreview(
      backup: backup,
      document: await _readBackup(backup),
      currentSetCount: _store.logs.length,
      currentWorkoutCount: _workoutCount(_store.exportState()),
      currentStateFingerprint: _stateFingerprint(_store.exportState()),
    ),
  );

  Future<void> restorePrepared(CloudRestorePreview preview) async {
    await _guard(() async {
      if (_stateFingerprint(_store.exportState()) !=
          preview.currentStateFingerprint) {
        throw StateError(
          'Device data changed after this restore was reviewed. Review the backup again. Your current data has not been replaced.',
        );
      }
      await _portability.createVerifiedSafetyBackup(
        reason: 'before-cloud-restore',
      );
      if (_stateFingerprint(_store.exportState()) !=
          preview.currentStateFingerprint) {
        throw StateError(
          'Device data changed while the safety backup was being saved. Review the backup again. Your current data has not been replaced.',
        );
      }
      _debounce?.cancel();
      await _store.restoreState(preview.document.state);
      await _store.createAutomaticBackup(reason: 'after-cloud-restore');
      _debounce?.cancel();
      // Restoring is not an upload. Keep the last successful backup date honest.
      _lastUploadedFingerprint = _stateFingerprint(preview.document.state);
      _pendingChanges = pendingChanges;
      _lastError = null;
      notifyListeners();
    });
  }

  void _startListening() {
    if (_listening || _pausedForLocalDeletion) return;
    _store.addListener(_scheduleAutomaticUpload);
    _listening = true;
  }

  void _stopListening() {
    if (!_listening) return;
    _store.removeListener(_scheduleAutomaticUpload);
    _listening = false;
    _debounce?.cancel();
    _debounce = null;
  }

  void _scheduleAutomaticUpload() {
    if (_pausedForLocalDeletion) return;
    _pendingChanges = true;
    notifyListeners();
    if (!_automaticSyncEnabled || !_status.configured) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 8), () async {
      if (_busy) {
        _scheduleAutomaticUpload();
        return;
      }
      try {
        await uploadNow(reason: 'automatic-cloud-sync');
      } on Object {
        // Status remains visible for manual retry. Automatic sync never blocks
        // the workout save that triggered it.
      }
    });
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    if (_pausedForLocalDeletion) {
      throw StateError('Backups are paused while local data is being deleted.');
    }
    if (_busy) throw StateError('A cloud-sync operation is already running.');
    final finished = Completer<void>();
    _operationFinished = finished;
    _busy = true;
    notifyListeners();
    try {
      return await action();
    } catch (error, stack) {
      debugPrint('Cloud backup operation failed: $error');
      debugPrintStack(stackTrace: stack);
      _lastError = userFacingError(error, action: UserFeedbackAction.backup);
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
      finished.complete();
      if (identical(_operationFinished, finished)) _operationFinished = null;
    }
  }

  /// Block new cloud work and drain existing native calls before local storage
  /// is removed. Cloud copies are not removed by a local data deletion.
  Future<void> pauseForLocalDeletion() async {
    _pausedForLocalDeletion = true;
    _stopListening();
    final finished = _operationFinished;
    if (finished != null) await finished.future;
  }

  /// A failed deletion leaves the current store usable, so listening can resume.
  void resumeAfterFailedLocalDeletion() {
    _pausedForLocalDeletion = false;
    _startListening();
    if (_automaticSyncEnabled && pendingChanges) _scheduleAutomaticUpload();
  }

  String _safeTimestamp(String value) => value
      .replaceAll(':', '')
      .replaceAll('-', '')
      .replaceAll('.', '')
      .replaceAll('T', '-')
      .replaceAll('Z', '');

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
