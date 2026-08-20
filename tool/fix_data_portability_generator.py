#!/usr/bin/env python3
from pathlib import Path

path = Path('tool/generate_data_portability.py')
text = path.read_text()
text = text.replace(
    '''    state_arg_start = write_statement.find("jsonEncode(") + len("jsonEncode(")\n    state_arg_end = write_statement.rfind(")")\n    write_with_state = write_statement[:state_arg_start] + "state" + write_statement[state_arg_end:]\n''',
    '''    write_with_state = write_statement.replace(state_literal, "state", 1)\n''',
)
text = text.replace(
    ".replaceAll(RegExp(r'\\([^)]*\\)'), (match) => '_${match.group(0)!.substring(1, match.group(0)!.length - 1)}')",
    ".replaceAllMapped(RegExp(r'\\([^)]*\\)'), (match) => '_${match.group(0)!.substring(1, match.group(0)!.length - 1)}')",
)
for before, after in [
    ("        rpeHeader = key('rpe');\n      case WorkoutImportSource.hevy:", "        rpeHeader = key('rpe');\n        break;\n      case WorkoutImportSource.hevy:"),
    ("        assumedUnit = 'kg';\n      case WorkoutImportSource.fitNotes:", "        assumedUnit = 'kg';\n        break;\n      case WorkoutImportSource.fitNotes:"),
    ("        lbHeader = key('weight_lbs');\n      case WorkoutImportSource.generic:", "        lbHeader = key('weight_lbs');\n        break;\n      case WorkoutImportSource.generic:"),
    ("        rpeHeader = selected.rpe;\n    }", "        rpeHeader = selected.rpe;\n        break;\n    }"),
]:
    text = text.replace(before, after)
path.write_text(text)
