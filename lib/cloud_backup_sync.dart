import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'data_portability.dart';
import 'data_portability_core.dart';
import 'integration_settings.dart';
import 'store.dart';

class CloudBackupMetadata {
  const CloudBackupMetadata({
    required this.exists,
    this.etag,
    this.lastModified,
    this.contentLength,
  });

  final bool exists;
  final String? etag;
  final DateTime? lastModified;
  final int? contentLength;
}

class CloudBackupSyncResult {
  const CloudBackupSyncResult({
    required this.action,
    required this.message,
    this.metadata,
  });

  final String action;
  final String message;
  final CloudBackupMetadata? metadata;
}

/// Cross-platform cloud backup through a user-selected WebDAV account.
///
/// This avoids a proprietary Progression Lab account and works with providers
/// such as Nextcloud, ownCloud, or another standards-compliant WebDAV host.
/// Credentials remain in Android Keystore / iOS Keychain through
/// `flutter_secure_storage`.
class WebDavBackupSync {
  WebDavBackupSync({
    required IntegrationSettingsRepository settingsRepository,
    HttpClient? client,
  }) : _settingsRepository = settingsRepository,
       _client = client ?? HttpClient();

  final IntegrationSettingsRepository _settingsRepository;
  final HttpClient _client;

  Future<Uri> _target(IntegrationSettings settings) async {
    final base = Uri.tryParse(settings.cloudSyncUrl.trim());
    if (base == null || !base.hasScheme || base.host.isEmpty) {
      throw const FormatException('Enter a valid HTTPS WebDAV address.');
    }
    if (base.scheme != 'https') {
      throw const FormatException('Cloud backup requires HTTPS.');
    }
    final path = settings.cloudSyncPath.trim().replaceFirst(RegExp(r'^/+'), '');
    final prefix = base.path.endsWith('/') ? base.path : '${base.path}/';
    return base.replace(path: '$prefix$path');
  }

  Future<void> _authorize(
    HttpClientRequest request,
    IntegrationSettings settings,
  ) async {
    final password = await _settingsRepository.readCloudPassword();
    if (settings.cloudSyncUser.isNotEmpty || password.isNotEmpty) {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Basic ${base64Encode(utf8.encode('${settings.cloudSyncUser}:$password'))}',
      );
    }
    request.headers.set(HttpHeaders.userAgentHeader, 'Progression-Lab/2.0');
  }

  Future<CloudBackupMetadata> inspect(IntegrationSettings settings) async {
    final request = await _client.openUrl('HEAD', await _target(settings));
    await _authorize(request, settings);
    final response = await request.close();
    await response.drain<void>();
    if (response.statusCode == HttpStatus.notFound) {
      return const CloudBackupMetadata(exists: false);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'WebDAV returned ${response.statusCode} while checking the backup.',
      );
    }
    return CloudBackupMetadata(
      exists: true,
      etag: response.headers.value(HttpHeaders.etagHeader),
      lastModified: response.headers.value(HttpHeaders.lastModifiedHeader) case
          final String value
          ? HttpDate.parse(value)
          : null,
      contentLength: response.contentLength >= 0 ? response.contentLength : null,
    );
  }

  Future<CloudBackupSyncResult> upload({
    required AppStore store,
    required IntegrationSettings settings,
    String? expectedEtag,
  }) async {
    final bytes = DataPortabilityController(store).buildBackup(
      reason: 'webdav-sync',
    );
    final request = await _client.putUrl(await _target(settings));
    await _authorize(request, settings);
    request.headers.contentType = ContentType('application', 'zip');
    request.headers.contentLength = bytes.length;
    if (expectedEtag != null && expectedEtag.isNotEmpty) {
      request.headers.set(HttpHeaders.ifMatchHeader, expectedEtag);
    }
    request.add(bytes);
    final response = await request.close();
    await response.drain<void>();
    if (response.statusCode == HttpStatus.preconditionFailed) {
      throw const FileSystemException(
        'The cloud backup changed on another device. Review the conflict before replacing it.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'WebDAV returned ${response.statusCode} while uploading the backup.',
      );
    }
    return CloudBackupSyncResult(
      action: 'uploaded',
      message: 'Encrypted transport completed. The latest .plab backup is in your WebDAV account.',
      metadata: CloudBackupMetadata(
        exists: true,
        etag: response.headers.value(HttpHeaders.etagHeader),
        lastModified: DateTime.now().toUtc(),
        contentLength: bytes.length,
      ),
    );
  }

  Future<Uint8List> download(IntegrationSettings settings) async {
    final request = await _client.getUrl(await _target(settings));
    await _authorize(request, settings);
    final response = await request.close();
    if (response.statusCode == HttpStatus.notFound) {
      throw const FileSystemException('No cloud backup exists at this path.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.drain<void>();
      throw HttpException(
        'WebDAV returned ${response.statusCode} while downloading the backup.',
      );
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    // Validate before the caller is allowed to restore anything.
    ProgressionBackupCodec.decode(bytes);
    return bytes;
  }

  Future<CloudBackupSyncResult> restore({
    required AppStore store,
    required IntegrationSettings settings,
  }) async {
    final bytes = await download(settings);
    final document = ProgressionBackupCodec.decode(bytes);
    await store.createAutomaticBackup(reason: 'before-cloud-restore', required: true);
    await store.restoreState(document.state);
    await store.createAutomaticBackup(reason: 'after-cloud-restore');
    return const CloudBackupSyncResult(
      action: 'restored',
      message: 'Cloud backup restored. A local safety backup was kept first.',
    );
  }

  void close() => _client.close(force: true);
}

class CloudSyncCoordinator {
  CloudSyncCoordinator({
    required this.store,
    IntegrationSettingsRepository settingsRepository =
        const IntegrationSettingsRepository(),
  }) : _settingsRepository = settingsRepository;

  final AppStore store;
  final IntegrationSettingsRepository _settingsRepository;
  Timer? _timer;
  bool _running = false;
  String? _lastStateFingerprint;

  Future<void> start() async {
    store.addListener(_schedule);
    await syncNowIfEnabled();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 12), syncNowIfEnabled);
  }

  Future<void> syncNowIfEnabled() async {
    if (_running) return;
    final settings = await _settingsRepository.load();
    if (!settings.cloudSyncEnabled || settings.cloudSyncUrl.isEmpty) return;
    final state = jsonEncode(store.exportState());
    final fingerprint = base64UrlEncode(utf8.encode(state.hashCode.toString()));
    if (_lastStateFingerprint == fingerprint) return;
    _running = true;
    try {
      final service = WebDavBackupSync(
        settingsRepository: _settingsRepository,
      );
      try {
        final remote = await service.inspect(settings);
        await service.upload(
          store: store,
          settings: settings,
          expectedEtag: remote.etag,
        );
        _lastStateFingerprint = fingerprint;
      } finally {
        service.close();
      }
    } on Object {
      // Background sync is best effort. The Data & Connections screen shows
      // actionable errors during a user-triggered sync.
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    store.removeListener(_schedule);
  }
}
