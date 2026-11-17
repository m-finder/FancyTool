#!/bin/bash
set -euo pipefail
shotter_root="$(cd "$(dirname "$0")/.." && pwd)"
shotter_build="$(mktemp -d "${TMPDIR:-/tmp}/shotter-regressions.XXXXXX")"
trap 'rm -rf "$shotter_build"' EXIT
swiftc -Onone -parse-as-library -module-cache-path "$shotter_build/modules" \
  "$shotter_root/FancyTool/Modules/Shotter/ShotterScrollStitcher.swift" \
  "$shotter_root/Tests/ShotterScrollStitcherRegression.swift" \
  -o "$shotter_build/regressions"
"$shotter_build/regressions"
swiftc -O -swift-version 6 -parse-as-library -module-cache-path "$shotter_build/modules" \
  "$shotter_root/FancyTool/Modules/Shotter/ShotterScrollStitcher.swift" \
  "$shotter_root/FancyTool/Modules/Shotter/ShotterScrollFrameProcessor.swift" \
  "$shotter_root/Tests/ShotterScrollPipelineRegression.swift" \
  -o "$shotter_build/pipeline-regressions"
"$shotter_build/pipeline-regressions"
python3 - "$shotter_root" "$shotter_build" <<'PY'
from pathlib import Path
import sys
root, build = map(Path, sys.argv[1:])
source = (root / 'FancyTool/Modules/Shotter/Shotter.swift').read_text()
coordinates = source[source.index('enum ShotterCoordinateSpace {'):source.index('@MainActor\nfinal class Shotter {')]
(build / 'Recovery.swift').write_text(
    'import AppKit\n@MainActor\n' + coordinates
    + (root / 'FancyTool/Modules/Shotter/ShotterScrollCaptureController.swift').read_text()
    + '\n' + (root / 'Tests/ShotterScrollRecoveryRegression.swift').read_text())
PY
swiftc -O -swift-version 6 -parse-as-library -module-cache-path "$shotter_build/modules" \
  "$shotter_root/FancyTool/Modules/Shotter/ShotterScrollStitcher.swift" \
  "$shotter_root/FancyTool/Modules/Shotter/ShotterScrollFrameProcessor.swift" \
  "$shotter_build/Recovery.swift" -o "$shotter_build/recovery-regressions"
"$shotter_build/recovery-regressions"
