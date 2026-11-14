#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-all}"

install_applet() {
  local dir="$1"
  local id
  id="$(basename "$dir")"
  if kpackagetool6 -t Plasma/Applet --list | grep -qx "$id"; then
    kpackagetool6 -t Plasma/Applet -u "$dir"
  else
    kpackagetool6 -t Plasma/Applet -i "$dir"
  fi
}

if [ "$TARGET" = "all" ]; then
  for dir in "$ROOT_DIR"/applets/*/; do
    install_applet "$dir"
  done
else
  install_applet "$ROOT_DIR/applets/$TARGET"
fi
