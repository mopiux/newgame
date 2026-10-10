#!/usr/bin/env bash
# Runs the headless unit test suite. Exit code 0 = all passed.
cd "$(dirname "$0")/.."
source tools/godot_env.sh
"$GODOT" --headless --import --path . >/dev/null 2>&1
"$GODOT" --headless --path . res://tests/test_runner.tscn 2>&1 \
  | grep -v "ALSA\|audio_driver_alsa\|All audio drivers\|init_output_device\|audio_server.cpp"
exit ${PIPESTATUS[0]}
