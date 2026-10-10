#!/usr/bin/env bash
# Builds release executables into build/ (needs Godot 4.5 export templates:
# Editor > Manage Export Templates, or extract the official .tpz into
# ~/.local/share/godot/export_templates/4.5.stable/).
#   tools/export.sh            # Linux and Windows
#   tools/export.sh Linux      # one preset
cd "$(dirname "$0")/.."
source tools/godot_env.sh
"$GODOT" --headless --import --path . >/dev/null 2>&1
presets=("$@")
[ ${#presets[@]} -eq 0 ] && presets=("Linux" "Windows")
for p in "${presets[@]}"; do
  case "$p" in
    Linux) out="build/linux/Lumbre.x86_64" ;;
    Windows) out="build/windows/Lumbre.exe" ;;
    *) echo "unknown preset $p"; exit 1 ;;
  esac
  mkdir -p "$(dirname "$out")"
  echo "== exporting $p -> $out"
  "$GODOT" --headless --path . --export-release "$p" "$out" 2>&1 | grep -v "ALSA\|audio_driver\|All audio\|init_output\|audio_server" | grep -E "ERROR|error|WARNING" | head -20
  [ -f "$out" ] && ls -la "$out" || { echo "export failed for $p"; exit 1; }
done
