#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
config_dir="$HOME/.config"
state_dir="$HOME/.local/state/night-circuit-omarchy"
backup_dir="$state_dir/backups"
widgets_dir="$config_dir/quickshell/night-circuit-widgets"
theme_dir="$config_dir/omarchy/themes/night-circuit"
hook_file="$config_dir/omarchy/hooks/theme-set.d/night-circuit-theme-sync.sh"
service_file="$config_dir/systemd/user/night-circuit-effects.service"
cliamp_theme="$config_dir/cliamp/themes/night-circuit.toml"
effects_dir="$HOME/.local/share/easyeffects/output"
autostart_file="$config_dir/hypr/autostart.lua"

if [[ ! -e "$state_dir/installed" ]]; then
  echo 'Night Circuit is not installed by this installer.' >&2
  exit 1
fi

if [[ "$(omarchy theme current)" == 'Night Circuit' ]]; then
  previous_theme="$(cat "$state_dir/previous-theme")"
  omarchy theme set "$previous_theme"
fi

systemctl --user disable --now night-circuit-effects.service 2>/dev/null || true
quickshell kill --path "$widgets_dir" 2>/dev/null || true
if [[ -e "$widgets_dir/settings.json" ]]; then
  cp "$widgets_dir/settings.json" "$state_dir/last-widget-settings.json"
fi

restore_or_remove() {
  local destination="$1" name="$2"
  rm -rf -- "$destination"
  if [[ -e "$backup_dir/$name" ]]; then
    mkdir -p "$(dirname "$destination")"
    cp -a -- "$backup_dir/$name" "$destination"
  fi
}

restore_or_remove "$widgets_dir" widgets
restore_or_remove "$theme_dir" theme
restore_or_remove "$hook_file" hook
restore_or_remove "$service_file" service
restore_or_remove "$cliamp_theme" cliamp-theme
for preset in "$repo_dir"/effects/presets/*.json; do
  restore_or_remove "$effects_dir/$(basename "$preset")" "effects/$(basename "$preset")"
done

python3 "$repo_dir/scripts/cliamp_theme_config.py" restore "$state_dir"
if [[ -e "$autostart_file" ]]; then
  python3 - "$autostart_file" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
start = '-- Night Circuit widgets begin'
end = '-- Night Circuit widgets end'
if start in text and end in text:
    before, remainder = text.split(start, 1)
    _, after = remainder.split(end, 1)
    path.write_text(before.rstrip('\n') + after)
PY
fi

systemctl --user daemon-reload
hyprctl reload >/dev/null
rm "$state_dir/installed"
echo "Night Circuit removed. Your last widget settings are saved in $state_dir."
