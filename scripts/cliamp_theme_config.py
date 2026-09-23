#!/usr/bin/env python3
"""Change only cliamp's top-level theme setting, preserving the rest of its config."""

import json
import re
import sys
from pathlib import Path


action = sys.argv[1]
state_dir = Path(sys.argv[2])
config = Path.home() / ".config/cliamp/config.toml"
record = state_dir / "previous-cliamp-theme.json"
originally_existed = config.exists()
lines = config.read_text().splitlines(keepends=True) if originally_existed else []


def theme_line_index():
    for index, line in enumerate(lines):
        if line.lstrip().startswith("["):
            break
        if re.match(r"\s*theme\s*=", line):
            return index
    return None


index = theme_line_index()
if action == "set":
    if not record.exists():
        state_dir.mkdir(parents=True, exist_ok=True)
        record.write_text(json.dumps({"existed": originally_existed,
                                      "line": lines[index] if index is not None else None}) + "\n")
    if index is None:
        lines.insert(0, 'theme = "night-circuit"\n')
    else:
        lines[index] = 'theme = "night-circuit"\n'
elif action == "restore":
    if not record.exists():
        raise SystemExit(0)
    previous = json.loads(record.read_text())
    if index is not None and re.fullmatch(r'\s*theme\s*=\s*["\']night-circuit["\']\s*', lines[index].strip()):
        if previous["line"] is None:
            del lines[index]
        else:
            lines[index] = previous["line"]
    if not previous["existed"] and not "".join(lines).strip():
        config.unlink(missing_ok=True)
        raise SystemExit(0)
else:
    raise SystemExit("usage: cliamp_theme_config.py set|restore STATE_DIR")

config.parent.mkdir(parents=True, exist_ok=True)
config.write_text("".join(lines))
