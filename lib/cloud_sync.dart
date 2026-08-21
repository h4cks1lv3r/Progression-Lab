import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'data_portability.dart';
import 'data_portability_core.dart';
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
        deviceId: value['deviceId'] is String ? value['deviceId']! as String : '',
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

/// Coordinates user-selected folder sync. The platform implementation uses
/// Android's Storage Access Framework or the iOS document picker so Drive,
/// iCloud Drive, OneDrive, Dropbox, and other Files providers can participate
/// without Progression Lab receiving those account credentials.
class CloudBackupSyncService extends ChangeNotifier {
  CloudBackupSyncService({
    required AppStore store,
    MethodChannel? channel,
  })  : _store = store,
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

  CloudFolderStatus get status => _status;
  bool get automaticSyncEnabled => _automaticSyncEnabled;
  bool get busy => _busy;
  String? get lastError => _lastError;

  Future<void> initialize() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>('status');
    _status = CloudFolderStatus.fromJson(result ?? const <Object?, Object?>{});
    _automaticSyncEnabled = result?['automaticSyncEnabled'] == true;
    if (_automaticSyncEnabled) _startListening();
    notifyListeners();
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
      notifyListeners();
      return _status;
    });
  }

  Future<void> disconnectFolder() async {
    await _guard(() async {
      await _channel.invokeMethod<void>('disconnectFolder');
      _status = const CloudFolderStatus(configured: false);
      _automaticSyncEnabled = false;
      _stopListening();
      notifyListeners();
    });
  }

  Future<void> setAutomaticSyncEnabled(bool enabled) async {
    if (enabled && !_status.configured) {
      throw StateError('Choose a backup folder before enabling automatic sync.');
    }
    await _channel.invokeMethod<void>(
      'setAutomaticSyncEnabled',
      <String, bool>{'enabled': enabled},
    );
    _automaticSyncEnabled = enabled;
    if (enabled) {
      _startListening();
    } else {
      _stopListening();
    }
    notifyListeners();
  }

  Future<List<CloudBackupInfo>> listBackups() async {
    return _guard(() async {
      final result = await _channel.invokeListMethod<Object?>('listBackups') ??
          const <Object?>[];
      final values = result
          .whereType<Map>()
          .map((item) => CloudBackupInfo.fromJson(Map<Object?, Object?>.from(item)))
          .toList();
      values.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      return values;
    });
  }

  Future<CloudSyncPreview> preview() async {
    final localBytes = _portability.buildBackup(reason: 'cloud-preview');
    final localDocument = ProgressionBackupCodec.decode(localBytes);
    final localCreatedAt = DateTime.tryParse('${localDocument.manifest['createdAt']}')?.toUtc();
    final backups = await listBackups();
    if (backups.isEmpty) {
      return CloudSyncPreview(
        direction: CloudSyncDirection.upload,
        localCreatedAt: localCreatedAt,
        reason: 'No cloud backup exists yet.',
      );
    }
    final remote = backups.first;
    final remoteCreatedAt = remote.createdAt ?? remote.modifiedAt;
    if (localCreatedAt == null) {
      return CloudSyncPreview(
        direction: CloudSyncDirection.conflict,
        remote: remote,
        reason: 'The local backup timestamp could not be verified.',
      );
    }
    final delta = remoteCreatedAt.difference(localCreatedAt).abs();
    if (delta < const Duration(seconds: 2)) {
      return CloudSyncPreview(
        direction: CloudSyncDirection.none,
        remote: remote,
        localCreatedAt: localCreatedAt,
        reason: 'Local and cloud backups are aligned.',
      );
    }
    if (remoteCreatedAt.isAfter(localCreatedAt)) {
      return CloudSyncPreview(
        direction: CloudSyncDirection.download,
        remote: remote,
        localCreatedAt: localCreatedAt,
        reason: 'The cloud backup is newer. Review before restoring it.',
      );
    }
    return CloudSyncPreview(
      direction: CloudSyncDirection.upload,
      remote: remote,
      localCreatedAt: localCreatedAt,
      reason: 'The local data is newer than the cloud backup.',
    );
  }

  Future<CloudBackupInfo> uploadNow({String reason = 'manual-cloud-sync'}) async {
    if (!_status.configured) throw StateError('No cloud backup folder is configured.');
    return _guard(() async {
      final bytes = _portability.buildBackup(reason: reason);
      final document = ProgressionBackupCodec.decode(bytes);
      final createdAt = '${document.manifest['createdAt']}';
      final fileName = 'Progression-Lab-${_safeTimestamp(createdAt)}.plab';
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'writeBackup',
        <String, Object>{
          'name': fileName,
          'bytes': bytes,
          'createdAt': createdAt,
          'schemaVersion': AppStore.schemaVersion,
        },
      );
      if (result == null) throw StateError('The cloud provider did not return a saved backup.');
      _status = CloudFolderStatus(
        configured: _status.configured,
        provider: _status.provider,
        displayName: _status.displayName,
        locationToken: _status.locationToken,
        lastSuccessfulSync: DateTime.now().toUtc(),
      );
      notifyListeners();
      return CloudBackupInfo.fromJson(result);
    });
  }

  Future<void> restoreRemote(CloudBackupInfo backup) async {
    await _guard(() async {
      await _store.createAutomaticBackup(
        reason: 'before-cloud-restore',
        required: true,
      );
      final bytes = await _channel.invokeMethod<Uint8List>(
        'readBackup',
        <String, String>{'token': backup.token, 'name': backup.name},
      );
      if (bytes == null || bytes.isEmpty) {
        throw StateError('The selected cloud backup could not be read.');
      }
      final document = ProgressionBackupCodec.decode(bytes);
      await _store.restoreState(document.state);
      await _store.createAutomaticBackup(reason: 'after-cloud-restore');
      _status = CloudFolderStatus(
        configured: _status.configured,
        provider: _status.provider,
        displayName: _status.displayName,
        locationToken: _status.locationToken,
        lastSuccessfulSync: DateTime.now().toUtc(),
      );
      notifyListeners();
    });
  }

  void _startListening() {
    if (_listening) return;
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
    if (!_automaticSyncEnabled || !_status.configured) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 8), () async {
      try {
        await uploadNow(reason: 'automatic-cloud-sync');
      } on Object {
        // Status remains visible for manual retry. Automatic sync never blocks
        // the workout save that triggered it.
      }
    });
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    if (_busy) throw StateError('A cloud-sync operation is already running.');
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      return await action();
    } on PlatformException catch (error) {
      _lastError = error.message ?? error.code;
      rethrow;
    } catch (error) {
      _lastError = '$error';
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
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
