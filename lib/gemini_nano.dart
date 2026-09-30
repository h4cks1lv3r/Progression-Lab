import 'package:flutter/foundation.dart';
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

  /// Internal diagnostic detail, never screen text. Native details are logged
  /// in debug builds only; userMessage always comes from the fixed copy below.
  final String? message;

  String get userMessage => switch (availability) {
    GeminiNanoAvailability.available =>
      'AI explanations are ready on this device.',
    GeminiNanoAvailability.downloadable =>
      'Your device supports AI. Tap Download AI to get started.',
    GeminiNanoAvailability.downloading =>
      'AI is downloading. Keep the app open, then tap Check status.',
    GeminiNanoAvailability.unavailable =>
      'AI explanations are unavailable right now. Tap Check status to try again. Your training insights still work.',
    GeminiNanoAvailability.unsupported =>
      'AI explanations are not supported on this device. Your training insights still work.',
    GeminiNanoAvailability.error =>
      'AI status could not be checked. Tap Check status to try again. Your training insights still work.',
  };

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
    if (kDebugMode && value['message'] is String) {
      debugPrint('Gemini Nano status detail: ${value['message']}');
    }
    return GeminiNanoStatus(
      availability: availability,
      modelName: value['modelName'] is String
          ? value['modelName'] as String
          : null,
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
      if (kDebugMode) debugPrint('Gemini Nano request failed: $error');
      return GeminiNanoStatus(
        availability: _availabilityForError(error.code),
        message: geminiNanoUserError(error.code),
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
      if (kDebugMode) debugPrint('Gemini Nano request failed: $error');
      return GeminiNanoStatus(
        availability: _availabilityForError(error.code),
        message: geminiNanoUserError(error.code),
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

/// Map known native failure codes to fixed instructions. Error text can contain
/// device paths or native API details and must never be returned to the UI.
String geminiNanoUserError(String code) {
  final normalized = code.toLowerCase();
  if (normalized.contains('busy')) {
    return 'AI is busy. Wait briefly, then try again.';
  }
  if (normalized.contains('battery')) {
    return 'AI cannot run with the current battery level. Charge your device, then try again.';
  }
  if (normalized.contains('quota')) {
    return 'Your device has paused AI requests. Charge it if the battery is low, then try again later.';
  }
  if (normalized.contains('background')) {
    return 'Keep Training insights open while AI prepares your answer.';
  }
  if (normalized.contains('cancel')) return 'The AI analysis was cancelled.';
  if (normalized.contains('unsupported') ||
      normalized.contains('not_available') ||
      normalized.contains('aicore')) {
    return 'AI explanations are not supported on this device. Your training insights still work.';
  }
  if (normalized.contains('download')) {
    return 'AI could not be downloaded. Check your connection and free storage space, then tap Download AI to try again.';
  }
  return 'AI could not complete this analysis. Try again. Your training insights are still available.';
}
