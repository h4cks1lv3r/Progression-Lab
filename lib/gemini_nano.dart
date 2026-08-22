import 'package:flutter/services.dart';

enum GeminiNanoAvailability {
  available,
  downloadable,
  downloading,
  unavailable,
  unsupported,
  error,
}

class GeminiNanoStatus {
  const GeminiNanoStatus({
    required this.availability,
    this.modelName,
    this.message,
  });

  final GeminiNanoAvailability availability;
  final String? modelName;
  final String? message;

  bool get canGenerate => availability == GeminiNanoAvailability.available;
  bool get canDownload =>
      availability == GeminiNanoAvailability.downloadable ||
      availability == GeminiNanoAvailability.downloading;

  factory GeminiNanoStatus.fromMap(Map<Object?, Object?> value) {
    final raw = value['status'];
    final availability = switch (raw) {
      'available' => GeminiNanoAvailability.available,
      'downloadable' => GeminiNanoAvailability.downloadable,
      'downloading' => GeminiNanoAvailability.downloading,
      'unavailable' => GeminiNanoAvailability.unavailable,
      'unsupported' => GeminiNanoAvailability.unsupported,
      _ => GeminiNanoAvailability.error,
    };
    return GeminiNanoStatus(
      availability: availability,
      modelName: value['modelName'] is String
          ? value['modelName'] as String
          : null,
      message: value['message'] is String ? value['message'] as String : null,
    );
  }
}

class GeminiNanoResult {
  const GeminiNanoResult({required this.text, this.modelName});

  final String text;
  final String? modelName;
}

class GeminiNanoService {
  const GeminiNanoService();

  static const _channel = MethodChannel('progression_lab/gemini');

  Future<GeminiNanoStatus> status() async {
    try {
      final result = await _channel.invokeMethod<Object?>('status');
      if (result is Map) return GeminiNanoStatus.fromMap(result);
      return const GeminiNanoStatus(
        availability: GeminiNanoAvailability.error,
        message: 'The device returned an invalid Gemini status.',
      );
    } on MissingPluginException {
      return const GeminiNanoStatus(
        availability: GeminiNanoAvailability.unsupported,
        message: 'Gemini Nano narration is not available on this platform.',
      );
    } on PlatformException catch (error) {
      return GeminiNanoStatus(
        availability: _availabilityForError(error.code),
        message: error.message ?? 'Gemini Nano could not be initialized.',
      );
    }
  }

  Future<GeminiNanoStatus> download() async {
    try {
      final result = await _channel.invokeMethod<Object?>('download');
      if (result is Map) return GeminiNanoStatus.fromMap(result);
      return await status();
    } on MissingPluginException {
      return const GeminiNanoStatus(
        availability: GeminiNanoAvailability.unsupported,
        message: 'Gemini Nano narration is not available on this platform.',
      );
    } on PlatformException catch (error) {
      return GeminiNanoStatus(
        availability: _availabilityForError(error.code),
        message:
            error.message ?? 'The Gemini Nano model could not be downloaded.',
      );
    }
  }

  Future<GeminiNanoResult> generate({
    required String systemInstruction,
    required String prompt,
  }) async {
    try {
      final value = await _channel.invokeMethod<Object?>('generate', {
        'systemInstruction': systemInstruction,
        'prompt': prompt,
      });
      if (value is! Map || value['text'] is! String) {
        throw PlatformException(
          code: 'invalid_response',
          message: 'Gemini Nano returned an invalid response.',
        );
      }
      return GeminiNanoResult(
        text: (value['text'] as String).trim(),
        modelName: value['modelName'] is String
            ? value['modelName'] as String
            : null,
      );
    } on MissingPluginException {
      throw PlatformException(
        code: 'unsupported',
        message: 'Gemini Nano narration is not available on this platform.',
      );
    }
  }

  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on MissingPluginException {
      // No native inference exists on this platform.
    }
  }

  GeminiNanoAvailability _availabilityForError(String code) {
    final normalized = code.toLowerCase();
    if (normalized.contains('unsupported') ||
        normalized.contains('not_available') ||
        normalized.contains('aicore')) {
      return GeminiNanoAvailability.unsupported;
    }
    if (normalized.contains('download')) {
      return GeminiNanoAvailability.downloadable;
    }
    return GeminiNanoAvailability.error;
  }
}
