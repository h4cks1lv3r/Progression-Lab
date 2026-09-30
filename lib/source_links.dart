import 'package:flutter/services.dart';

/// Opens a public source in the device browser without starting an account flow.
Future<bool> openSourceUrl(String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !['https', 'http'].contains(uri.scheme) ||
      uri.host.isEmpty) {
    return false;
  }
  try {
    return await const MethodChannel(
          'progression_lab/links',
        ).invokeMethod<bool>('open', {'url': uri.toString()}) ??
        false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
