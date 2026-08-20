#!/usr/bin/env python3
from pathlib import Path

path = Path('tool/generate_data_portability.py')
text = path.read_text()
old = '''    await_start = save_body.rfind("await ", 0, json_pos)
    if await_start < 0:
        raise ValueError("Could not find storage write await statement")
    semicolon = save_body.find(";", map_end)
    if semicolon < 0:
        raise ValueError("Could not find end of storage write statement")
    write_statement = save_body[await_start : semicolon + 1]
    state_arg_start = write_statement.find("jsonEncode(") + len("jsonEncode(")
    state_arg_end = write_statement.rfind(")")
    write_with_state = write_statement[:state_arg_start] + "state" + write_statement[state_arg_end:]

    new_save_body = save_body[:await_start] + "await _writePortableState(_portableState());" + save_body[semicolon + 1 :]
'''
if old not in text:
    old = '''    await_start = save_body.rfind("await ", 0, json_pos)
    if await_start < 0:
        raise ValueError("Could not find storage write await statement")
    semicolon = save_body.find(";", map_end)
    if semicolon < 0:
        raise ValueError("Could not find end of storage write statement")
    write_statement = save_body[await_start : semicolon + 1]
    write_with_state = write_statement.replace(state_literal, "state", 1)

    new_save_body = save_body[:await_start] + "await _writePortableState(_portableState());" + save_body[semicolon + 1 :]
'''
new = '''    write_with_state = (
        save_body[:type_prefix_start] + "state" + save_body[map_end + 1 :]
    ).strip()
    new_save_body = "\\n    await _writePortableState(_portableState());\\n  "
'''
if old not in text:
    raise SystemExit('Could not locate store-save generator block')
text = text.replace(old, new, 1)
text = text.replace(
    ".replaceAll(RegExp(r'\\([^)]*\\)'), (match) => '_${match.group(0)!.substring(1, match.group(0)!.length - 1)}')",
    ".replaceAllMapped(RegExp(r'\\([^)]*\\)'), (match) => '_${match.group(0)!.substring(1, match.group(0)!.length - 1)}')",
)
for before, after in [
    ("        rpeHeader = key('rpe');\\n      case WorkoutImportSource.hevy:", "        rpeHeader = key('rpe');\\n        break;\\n      case WorkoutImportSource.hevy:"),
    ("        assumedUnit = 'kg';\\n      case WorkoutImportSource.fitNotes:", "        assumedUnit = 'kg';\\n        break;\\n      case WorkoutImportSource.fitNotes:"),
    ("        lbHeader = key('weight_lbs');\\n      case WorkoutImportSource.generic:", "        lbHeader = key('weight_lbs');\\n        break;\\n      case WorkoutImportSource.generic:"),
    ("        rpeHeader = selected.rpe;\\n    }", "        rpeHeader = selected.rpe;\\n        break;\\n    }"),
]:
    text = text.replace(before, after)
path.write_text(text)
