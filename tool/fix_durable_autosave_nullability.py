from pathlib import Path


path = Path("lib/store.dart")
text = path.read_text()
old = """      final raw = await _channel.invokeMethod<String>('read');
      hadStoredStateAtLaunch = raw != null && raw.trim().isNotEmpty;
      if (hadStoredStateAtLaunch) {
        final decoded = jsonDecode(raw);
"""
new = """      final raw = await _channel.invokeMethod<String>('read');
      final stored = raw?.trim();
      hadStoredStateAtLaunch = stored != null && stored.isNotEmpty;
      if (stored != null && stored.isNotEmpty) {
        final decoded = jsonDecode(stored);
"""
if new not in text:
    if old not in text:
        raise RuntimeError("The generated storage-load block was not found")
    path.write_text(text.replace(old, new, 1))
