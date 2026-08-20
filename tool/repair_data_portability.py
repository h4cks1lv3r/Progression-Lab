#!/usr/bin/env python3
from pathlib import Path
import re

root = Path('.')
pubspec = root / 'pubspec.yaml'
text = pubspec.read_text()
text = re.sub(r'(?m)^\s*archive:\s*[^\n]+', '  archive: ^3.6.1', text)
text = re.sub(r'(?m)^\s*csv:\s*[^\n]+', '  csv: ^5.1.1', text)
pubspec.write_text(text)

path = root / 'lib/data_portability.dart'
text = path.read_text()
old = '''  Widget _field(String label, String? value, ValueChanged<String?> changed) =>
      DropdownButtonFormField<String?>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: <DropdownMenuItem<String?>>[
          const DropdownMenuItem<String?>(value: null, child: Text('Not mapped')),
          ...widget.headers.map((header) => DropdownMenuItem<String?>(value: header, child: Text(header))),
        ],
        onChanged: changed,
      );
'''
new = '''  Widget _field(String label, String? value, ValueChanged<String?> changed) =>
      DropdownButtonFormField<String>(
        initialValue: value ?? '',
        decoration: InputDecoration(labelText: label),
        items: <DropdownMenuItem<String>>[
          const DropdownMenuItem<String>(value: '', child: Text('Not mapped')),
          ...widget.headers.map(
            (header) => DropdownMenuItem<String>(value: header, child: Text(header)),
          ),
        ],
        onChanged: (selected) => changed(
          selected == null || selected.isEmpty ? null : selected,
        ),
      );
'''
if old in text:
    text = text.replace(old, new)
text = text.replace(
    "final encoded = ZipEncoder().encode(archive);\n    if (encoded == null) throw const PortabilityException('Could not create backup archive.');\n    return Uint8List.fromList(encoded);",
    "final encoded = ZipEncoder().encode(archive);\n    return Uint8List.fromList(encoded);",
)
text = text.replace(
    "final encoded = ZipEncoder().encode(archive);\n    if (encoded == null) throw const PortabilityException('Could not create CSV export.');\n    return Uint8List.fromList(encoded);",
    "final encoded = ZipEncoder().encode(archive);\n    return Uint8List.fromList(encoded);",
)
path.write_text(text)
