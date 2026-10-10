#!/usr/bin/env bash
# Imports resources if needed and launches the game. Extra args go to the game,
# e.g. tools/run.sh -- --start-run MISEMILLA
cd "$(dirname "$0")/.."
source tools/godot_env.sh
if [ ! -d .godot/imported ] || [ ! -f i18n/strings.es.translation ]; then
  "$GODOT" --headless --import --path . >/dev/null 2>&1
fi
exec "$GODOT" --path . "$@"
