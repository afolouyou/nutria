#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_SVG="${1:-$ROOT_DIR/apps/nutria_app/priv/static/images/logo.svg}"
OUT_DIR="${2:-$ROOT_DIR/apps/nutria_app/priv/static/images}"
SIZES=(32 64 128 512 1024)

if ! command -v rsvg-convert >/dev/null 2>&1; then
  printf 'error: rsvg-convert not found. Install librsvg first.\n' >&2
  exit 1
fi

if [[ ! -f "$SRC_SVG" ]]; then
  printf 'error: source svg not found: %s\n' "$SRC_SVG" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

for size in "${SIZES[@]}"; do
  out_file="$OUT_DIR/logo-${size}.png"
  rsvg-convert \
    --width "$size" \
    --height "$size" \
    --format png \
    --output "$out_file" \
    "$SRC_SVG"
  printf 'generated %s\n' "$out_file"
done

cp "$OUT_DIR/logo-512.png" "$OUT_DIR/logo.png"
printf 'updated %s\n' "$OUT_DIR/logo.png"
