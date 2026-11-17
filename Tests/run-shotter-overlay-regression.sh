#!/bin/bash
set -euo pipefail
shotter_root="$(cd "$(dirname "$0")/.." && pwd)"
shotter_build="$(mktemp -d "${TMPDIR:-/tmp}/shotter-overlay.XXXXXX")"
trap 'rm -rf "$shotter_build"' EXIT
swiftc -O -swift-version 6 -parse-as-library -module-cache-path "$shotter_build/modules" \
  "$shotter_root/FancyTool/Modules/Shotter/ShotterScrollStitcher.swift" \
  "$shotter_root/FancyTool/Modules/Shotter/ShotterScrollFrameProcessor.swift" \
  "$shotter_root/Tests/ShotterScrollOverlayRegression.swift" \
  -o "$shotter_build/overlay-regression"
"$shotter_build/overlay-regression"
