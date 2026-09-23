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

if ! command -v omarchy >/dev/null || ! command -v hyprctl >/dev/null; then
  echo 'Night Circuit requires Omarchy with Hyprland.' >&2
  exit 1
fi

missing_packages=()
for package in quickshell cliamp easyeffects calf lsp-plugins-lv2; do
  if ! pacman -Q "$package" >/dev/null 2>&1; then
    missing_packages+=("$package")
  fi
done
if ((${#missing_packages[@]})); then
  omarchy pkg add "${missing_packages[@]}"
fi

backup_once() {
  local source="$1" name="$2"
  if [[ -e "$source" && ! -e "$backup_dir/$name" ]]; then
    mkdir -p "$(dirname "$backup_dir/$name")"
    cp -a -- "$source" "$backup_dir/$name"
  fi
}

if [[ ! -e "$state_dir/installed" ]]; then
  mkdir -p "$backup_dir"
  omarchy theme current > "$state_dir/previous-theme"
  backup_once "$widgets_dir" widgets
  backup_once "$theme_dir" theme
  backup_once "$hook_file" hook
  backup_once "$service_file" service
  backup_once "$cliamp_theme" cliamp-theme
  for preset in "$repo_dir"/effects/presets/*.json; do
    backup_once "$effects_dir/$(basename "$preset")" "effects/$(basename "$preset")"
  done
  touch "$state_dir/installed"
fi

mkdir -p "$widgets_dir" "$theme_dir" "$(dirname "$hook_file")" \
  "$(dirname "$service_file")" "$(dirname "$cliamp_theme")" "$effects_dir" \
  "$(dirname "$autostart_file")"
cp -a "$repo_dir/theme/." "$theme_dir/"
for app_file in "$repo_dir"/app/*; do
  [[ "$(basename "$app_file")" == 'settings.json' ]] && continue
  cp -a -- "$app_file" "$widgets_dir/"
done
if [[ ! -e "$widgets_dir/settings.json" ]]; then
  cp "$repo_dir/app/settings.json" "$widgets_dir/settings.json"
fi
chmod +x "$widgets_dir/launch.sh" "$widgets_dir/theme-hook.sh" "$widgets_dir/telemetry.py" \
  "$widgets_dir/cliamp_state.py" "$widgets_dir/cliamp_library.py" "$widgets_dir/theme_sync.py"
install -m 0755 "$repo_dir/app/theme-hook.sh" "$hook_file"
install -m 0644 "$repo_dir/systemd/night-circuit-effects.service" "$service_file"
install -m 0644 "$repo_dir/app/cliamp-theme.toml" "$cliamp_theme"
for preset in "$repo_dir"/effects/presets/*.json; do
  install -m 0644 "$preset" "$effects_dir/$(basename "$preset")"
done

python3 "$repo_dir/scripts/cliamp_theme_config.py" set "$state_dir"
if [[ ! -e "$autostart_file" ]]; then
  touch "$autostart_file"
fi
if ! grep -qF -- '-- Night Circuit widgets begin' "$autostart_file"; then
  cat >> "$autostart_file" <<'LUA'

-- Night Circuit widgets begin
o.launch_on_start(os.getenv("HOME") .. "/.config/quickshell/night-circuit-widgets/launch.sh")
-- Night Circuit widgets end
LUA
fi

systemctl --user daemon-reload
systemctl --user enable --now night-circuit-effects.service
omarchy theme set 'Night Circuit'
python3 "$widgets_dir/theme_sync.py"
hyprctl reload >/dev/null
if [[ -n "$(hyprctl configerrors)" ]]; then
  echo 'Hyprland reported configuration errors:' >&2
  hyprctl configerrors >&2
  exit 1
fi
"$widgets_dir/launch.sh"
echo 'Night Circuit installed. Click EDIT on the desktop widget to customize it.'
