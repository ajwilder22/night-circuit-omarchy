#!/usr/bin/env python3
"""Mirror the active Omarchy theme into a small widget palette."""

import json
import os
import re
import tomllib
from pathlib import Path


home = Path.home()
theme = home / '.local/state/omarchy/current/theme'
destination = home / '.config/quickshell/night-circuit-widgets/theme.json'


def read_toml(path):
    try:
        with path.open('rb') as stream:
            return tomllib.load(stream)
    except (OSError, tomllib.TOMLDecodeError):
        return {}


colors = read_toml(theme / 'colors.toml')
style = read_toml(theme / 'widgets.toml')
if not colors:
    raise SystemExit(0)

light = colors.get('mode') == 'light'
radius = style.get('corner-radius')
if radius is None:
    try:
        source = (theme / 'hyprland.lua').read_text()
        match = re.search(r'\brounding\s*=\s*(\d+)', source)
        radius = int(match.group(1)) if match else 16
    except OSError:
        radius = 16

palette = {
    'background': colors.get('lighter_background', colors.get('background', '#15191e')),
    'border': colors.get('muted', colors.get('accent', '#687278')),
    'text': colors.get('foreground', '#f4f1eb'),
    'muted': colors.get('light_foreground' if light else 'dark_foreground', colors.get('foreground', '#a8aaa9')),
    'accent': colors.get('accent', '#d9ae73'),
    'secondary': colors.get('cyan', '#78c6c8'),
    'tertiary': colors.get('magenta', '#b6a8d7'),
    'track': colors.get('selection', '#3d4346'),
    'cornerRadius': max(0, min(48, int(radius))),
}

payload = json.dumps(palette, indent=2) + '\n'
destination.parent.mkdir(parents=True, exist_ok=True)
if destination.exists() and destination.read_text() == payload:
    raise SystemExit(0)
temp = destination.with_suffix('.json.tmp')
temp.write_text(payload)
os.replace(temp, destination)
