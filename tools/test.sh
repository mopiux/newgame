#!/usr/bin/env bash
# Runs the headless unit test suite and the end-to-end "Continue" and
# screen-flow checks.
# Exit code 0 = everything passed.
cd "$(dirname "$0")/.."
source tools/godot_env.sh
filter() { grep -v "ALSA\|audio_driver_alsa\|All audio drivers\|init_output_device\|audio_server.cpp"; }
"$GODOT" --headless --import --path . >/dev/null 2>&1
"$GODOT" --headless --path . res://tests/test_runner.tscn 2>&1 | filter
unit=${PIPESTATUS[0]}
"$GODOT" --headless --path . -- --continue-check 2>&1 | grep -E "CONTINUE_|SCRIPT ERROR"
cont=${PIPESTATUS[0]}
"$GODOT" --headless --path . -- --flow-check 2>&1 | grep -E "FLOW_|SCRIPT ERROR"
flow=${PIPESTATUS[0]}
[ "$unit" -eq 0 ] && [ "$cont" -eq 0 ] && [ "$flow" -eq 0 ]
