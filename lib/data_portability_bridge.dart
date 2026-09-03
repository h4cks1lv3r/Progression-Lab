import 'dart:typed_data';

import 'package:flutter/services.dart';

class PortablePickedFile {
  const PortablePickedFile({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });

  final String name;
  final Uint8List bytes;
  final String mimeType;
}

class AutomaticBackupInfo {
  const AutomaticBackupInfo({
    required this.name,
    required this.path,
    required this.size,
    required this.modifiedAt,
  });

  final String name;
  final String path;
  final int size;
  final DateTime modifiedAt;

  factory AutomaticBackupInfo.fromMap(Map<Object?, Object?> value) =>
      AutomaticBackupInfo(
        name: '${value['name'] ?? ''}',
        path: '${value['path'] ?? ''}',
        size: value['size'] is num ? (value['size'] as num).toInt() : 0,
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(
          value['modified'] is num ? (value['modified'] as num).toInt() : 0,
        ),
      );
}

abstract final class DataPortabilityBridge {
  static const _channel = MethodChannel('progression_lab/data_portability');

  static Future<String?> saveFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) => _channel.invokeMethod<String>('saveFile', {
    'bytes': bytes,
    'fileName': fileName,
    'mimeType': mimeType,
  });

  static Future<PortablePickedFile?> pickFile({
    List<String> extensions = const [
      'plab',
      'csv',
      'tsv',
      'json',
      'txt',
      'zip',
      'fitnotes',
    ],
  }) async {
    final raw = await _channel.invokeMethod<Object?>('pickFile', {
      'extensions': extensions,
    });
    if (raw == null) return null;
    if (raw is! Map) {
      throw const FormatException('The selected file could not be read.');
    }
    final bytes = raw['bytes'];
    if (bytes is! Uint8List || bytes.isEmpty) {
      throw const FormatException('The selected file is empty.');
    }
    return PortablePickedFile(
      name: '${raw['name'] ?? 'import'}',
      bytes: bytes,
      mimeType: '${raw['mimeType'] ?? 'application/octet-stream'}',
    );
  }

  static Future<PortablePickedFile> convertFitNotes(
    PortablePickedFile source,
  ) async {
    final raw = await _channel.invokeMethod<Object?>('convertFitNotes', {
      'bytes': source.bytes,
      'fileName': source.name,
    });
    if (raw is! Map || raw['bytes'] is! Uint8List) {
      throw const FormatException(
        'The FitNotes backup could not be converted.',
      );
    }
    final bytes = raw['bytes']! as Uint8List;
    if (bytes.isEmpty) {
      throw const FormatException(
        'The FitNotes backup contains no workout data.',
      );
    }
    return PortablePickedFile(
      name: '${raw['name'] ?? '${source.name}.csv'}',
      bytes: bytes,
      mimeType: '${raw['mimeType'] ?? 'text/csv'}',
    );
  }

  static Future<void> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) => _channel.invokeMethod<void>('shareFile', {
    'bytes': bytes,
    'fileName': fileName,
    'mimeType': mimeType,
  });

  static Future<String?> writeAutomaticBackup({
    required Uint8List bytes,
    required String fileName,
    int retention = 16,
  }) => _channel.invokeMethod<String>('writeAutomaticBackup', {
    'bytes': bytes,
    'fileName': fileName,
    'retention': retention,
  });

  static Future<List<AutomaticBackupInfo>> listAutomaticBackups() async {
    final raw = await _channel.invokeMethod<List<Object?>>(
      'listAutomaticBackups',
    );
    if (raw == null) return const [];
    final values = <AutomaticBackupInfo>[];
    for (final item in raw) {
      if (item is Map) {
        values.add(AutomaticBackupInfo.fromMap(item));
      }
    }
    values.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return values;
  }

  static Future<Uint8List> readAutomaticBackup(String path) async {
    final bytes = await _channel.invokeMethod<Uint8List>(
      'readAutomaticBackup',
      {'path': path},
    );
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException('The automatic backup is empty.');
    }
    return bytes;
  }

  static Future<void> deleteAutomaticBackup(String path) =>
      _channel.invokeMethod<void>('deleteAutomaticBackup', {'path': path});
}
