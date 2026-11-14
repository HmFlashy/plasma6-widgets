#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
mkdir -p "$DIST_DIR"

for dir in "$ROOT_DIR"/applets/*/; do
  id="$(basename "$dir")"
  version="$(python3 -c "import json; print(json.load(open('$dir/metadata.json'))['KPlugin']['Version'])")"
  out="$DIST_DIR/${id}-${version}.plasmoid"
  rm -f "$out"
  (cd "$dir" && zip -rq "$out" metadata.json contents/)
  echo "Built: $out"
done
