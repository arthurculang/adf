#!/usr/bin/env bash
# Pack the source tree into a conformant .adf container.
#
# An .adf is a ZIP whose FIRST entry is an uncompressed `mimetype` file
# containing exactly "application/adf" (no newline). This mirrors EPUB/ODF and
# lets the type be sniffed from raw bytes without inflating the archive.
#
# Before packing, this script recomputes the SHA-256 integrity hashes for the
# content and layout parts (manifest.json's `integrity` map, per spec §3.3) and
# bakes them into the manifest *inside the container*, so the produced .adf is
# internally consistent. The source manifest.json keeps its RECOMPUTE-AT-BUILD
# sentinels and is never modified. (Font `metrics_hash` values are left as
# authored: computing them needs the embedded fonts and the pinned metrics
# canonicalization, which this illustrative example does not ship.)
set -euo pipefail
cd "$(dirname "$0")"

OUT="../quarterly-report.adf"
rm -f "$OUT"

# Sanity: mimetype must have no trailing newline.
if [ "$(wc -c < mimetype)" -ne 15 ]; then
  echo "mimetype must be exactly 15 bytes ('application/adf', no newline)" >&2
  exit 1
fi

# Recompute integrity hashes for the referenced parts and write them into a
# build-time copy of the manifest (the source stays a template).
build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT

content_hash="sha256-$(sha256sum content/main.adt | cut -d' ' -f1)"
layout_hash="sha256-$(sha256sum layout/pages.adl | cut -d' ' -f1)"

sed -e "s#\"content/main.adt\": \"sha256-RECOMPUTE-AT-BUILD\"#\"content/main.adt\": \"${content_hash}\"#" \
    -e "s#\"layout/pages.adl\": \"sha256-RECOMPUTE-AT-BUILD\"#\"layout/pages.adl\": \"${layout_hash}\"#" \
    manifest.json > "$build_dir/manifest.json"

if grep -q "RECOMPUTE-AT-BUILD" "$build_dir/manifest.json"; then
  echo "failed to substitute integrity hashes into manifest.json" >&2
  exit 1
fi

# 1) Add mimetype FIRST, stored (-0), uncompressed.
zip -X -0 "$OUT" mimetype >/dev/null

# 2) Add the computed manifest (-j junks the path so it stores as `manifest.json`).
zip -X -jq "$OUT" "$build_dir/manifest.json" >/dev/null

# 3) Add the remaining parts, compressed, preserving their paths.
parts="content layout"
[ -d assets ] && parts="$parts assets"
# shellcheck disable=SC2086
zip -X -rq "$OUT" $parts -x "*.DS_Store" >/dev/null

echo "Built $OUT"
echo "  content/main.adt  ${content_hash}"
echo "  layout/pages.adl  ${layout_hash}"
echo
echo "Content an LLM would read (note: no layout, no coordinates, just words):"
echo "  unzip -p $OUT content/main.adt"
