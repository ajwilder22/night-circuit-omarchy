#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT
export HOME="$test_dir/home"
mkdir -p "$HOME/.config/hypr" "$HOME/.config/cliamp" \
  "$HOME/.config/quickshell/night-circuit-widgets" \
  "$HOME/.config/omarchy/themes/night-circuit" \
  "$HOME/.local/share/easyeffects/output" \
  "$HOME/.local/state/omarchy/current" "$test_dir/bin"
export PATH="$test_dir/bin:$PATH"

printf '%s\n' Original > "$HOME/.local/state/omarchy/current-name"
printf '%s\n' '-- existing autostart' > "$HOME/.config/hypr/autostart.lua"
printf '%s\n' 'theme = "old-theme"' 'eq = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]' > "$HOME/.config/cliamp/config.toml"
printf '%s\n' '{"scale":0.5}' > "$HOME/.config/quickshell/night-circuit-widgets/settings.json"
printf '%s\n' 'original-widget-file' > "$HOME/.config/quickshell/night-circuit-widgets/keep.txt"
printf '%s\n' 'original-theme-file' > "$HOME/.config/omarchy/themes/night-circuit/keep.txt"
printf '%s\n' '{"original":true}' > "$HOME/.local/share/easyeffects/output/Night Circuit - Clean.json"

cat > "$test_dir/bin/omarchy" <<'SH'
#!/usr/bin/env bash
if [[ "$1 $2" == 'theme current' ]]; then
  cat "$HOME/.local/state/omarchy/current-name"
elif [[ "$1 $2" == 'theme set' ]]; then
  printf '%s\n' "$3" > "$HOME/.local/state/omarchy/current-name"
  if [[ "$3" == 'Night Circuit' ]]; then
    ln -sfn "$HOME/.config/omarchy/themes/night-circuit" "$HOME/.local/state/omarchy/current/theme"
  fi
fi
SH
cat > "$test_dir/bin/hyprctl" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat > "$test_dir/bin/systemctl" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat > "$test_dir/bin/quickshell" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$test_dir/bin/"*

"$repo_dir/install.sh"
"$repo_dir/install.sh"
[[ "$(cat "$HOME/.config/quickshell/night-circuit-widgets/settings.json")" == '{"scale":0.5}' ]]
[[ "$(grep -cF -- '-- Night Circuit widgets begin' "$HOME/.config/hypr/autostart.lua")" == 1 ]]
[[ -e "$HOME/.config/quickshell/night-circuit-widgets/shell.qml" ]]
[[ "$(cat "$HOME/.local/state/omarchy/current-name")" == 'Night Circuit' ]]

"$repo_dir/uninstall.sh"
[[ "$(cat "$HOME/.local/state/omarchy/current-name")" == Original ]]
[[ "$(cat "$HOME/.config/quickshell/night-circuit-widgets/keep.txt")" == 'original-widget-file' ]]
[[ ! -e "$HOME/.config/quickshell/night-circuit-widgets/shell.qml" ]]
[[ "$(cat "$HOME/.config/omarchy/themes/night-circuit/keep.txt")" == 'original-theme-file' ]]
[[ "$(cat "$HOME/.local/share/easyeffects/output/Night Circuit - Clean.json")" == '{"original":true}' ]]
[[ "$(head -1 "$HOME/.config/cliamp/config.toml")" == 'theme = "old-theme"' ]]
[[ "$(cat "$HOME/.config/hypr/autostart.lua")" == '-- existing autostart' ]]
echo 'Install and uninstall smoke test passed.'
