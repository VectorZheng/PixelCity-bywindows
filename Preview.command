#!/bin/zsh
set -eu

export APPDATA="$HOME/Library/Application Support"
exec "$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
  --path "${0:A:h}" \
  --log-file "$HOME/Library/Logs/PixelCity-preview.log" \
  "$@"
