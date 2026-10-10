#!/usr/bin/env bash
# Locates the Godot 4.5 binary. Override with GODOT=/path/to/godot.
if [ -z "$GODOT" ]; then
  for c in godot godot4 Godot_v4.5-stable_linux.x86_64 "$HOME/bin/godot" /tmp/claude-0/-home-user-newgame/*/scratchpad/godot/Godot_v4.5-stable_linux.x86_64; do
    if command -v "$c" >/dev/null 2>&1 || [ -x "$c" ]; then GODOT="$c"; break; fi
  done
fi
if [ -z "$GODOT" ]; then
  echo "Godot 4.5 not found. Set GODOT=/path/to/Godot_v4.5-stable" >&2
  exit 1
fi
export GODOT
