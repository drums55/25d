#!/usr/bin/env bash
# Headless import + GUT unit tests. GODOT=/path/to/godot (default: godot on PATH).
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
bash tools/fetch_gut.sh
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json
