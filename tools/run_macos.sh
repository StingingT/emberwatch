#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$godot_bin" ]]; then
  echo "Install Godot 4.7 stable or set GODOT_BIN to its executable." >&2
  exit 1
fi
case "$("$godot_bin" --version)" in
  4.7.stable*) ;;
  *) echo "This project is pinned to Godot 4.7 stable." >&2; exit 1 ;;
esac
exec "$godot_bin" --path "$project_dir"
