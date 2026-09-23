#!/bin/sh
set -eu
config_dir="$HOME/.config/quickshell/night-circuit-widgets"
python3 "$config_dir/theme_sync.py"
exec quickshell --no-duplicate --daemonize --path "$config_dir"
