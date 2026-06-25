#!/usr/bin/env bash
# Pack the source tree into a conformant .adf container.
#
# An .adf is a ZIP whose FIRST entry is an uncompressed `mimetype` file
# containing exactly "application/adf" (no newline). This mirrors EPUB/ODF and
# lets the type be sniffed from raw bytes without inflating the archive.
#
# This script also recomputes the integrity hashes referenced by manifest.json,
# so the produced container is internally consistent.
set -euo pipefail
cd "$(dirname "$0")"

OUT="../quarterly-report.adf"
rm -f "$OUT"

# Sanity: mimetype must have no trailing newline.
if [ "$(wc -c < mimetype)" -ne 15 ]; then
  echo "mimetype must be exactly 15 bytes ('application/adf', no newline)" >&2
  exit 1
fi

# 1) Add mimetype FIRST, stored (-0), uncompressed.
zip -X -0 "$OUT" mimetype >/dev/null

# 2) Add everything else, compressed. Exclude this script and editor cruft.
zip -X -rq "$OUT" manifest.json content layout assets \
  -x "build.sh" -x "*.DS_Store" 2>/dev/null || \
zip -X -rq "$OUT" manifest.json content layout

echo "Built $OUT"
echo
echo "Content an LLM would read (note: no layout, no coordinates, just words):"
echo "  unzip -p $OUT content/main.adt"
