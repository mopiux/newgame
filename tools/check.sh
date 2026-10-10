#!/usr/bin/env bash
# Re-imports the project and lists unique script/resource errors.
cd "$(dirname "$0")/.."
source tools/godot_env.sh
"$GODOT" --headless --import --path . 2>&1 \
  | grep -v "ALSA\|audio_driver_alsa\|All audio drivers\|init_output_device\|audio_server.cpp" \
  | grep -A1 "ERROR\|WARNING" | grep -v "^--$" | awk '!seen[$0]++'
