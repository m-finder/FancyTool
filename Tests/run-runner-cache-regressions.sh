#!/bin/bash
set -euo pipefail
runner_root="$(cd "$(dirname "$0")/.." && pwd)"
runner_build="$(mktemp -d "${TMPDIR:-/tmp}/runner-cache-regressions.XXXXXX")"
trap 'rm -rf "$runner_build"' EXIT
python3 - "$runner_root" "$runner_build" <<'PY'
from pathlib import Path
import plistlib
import shutil
import sys
root, build = map(Path, sys.argv[1:])
contents = build / 'RunnerCacheRegression.app/Contents'
(contents / 'MacOS').mkdir(parents=True)
(contents / 'Resources').mkdir()
(contents / 'Info.plist').write_bytes(plistlib.dumps({
    'CFBundleExecutable': 'regressions',
    'CFBundleIdentifier': 'com.wu.FancyTool.RunnerCacheRegression',
    'CFBundlePackageType': 'APPL',
}))
for resource in (root / 'FancyTool/Modules/Runner/GIF').glob('*.gif'):
    shutil.copyfile(resource, contents / 'Resources' / resource.name)
source = (root / 'FancyTool/Modules/Runner/RunnerGIFProcessor.swift').read_text()
marker = '    guard data.count <= maximumInputBytes else { throw ImportError.tooLarge }'
assert source.count(marker) == 1
source = source.replace(marker, '    RunnerPreparationCounter.record()\n' + marker)
(build / 'RunnerGIFProcessor.swift').write_text(source)
PY
swiftc -O -swift-version 6 -parse-as-library -module-cache-path "$runner_build/modules" \
  "$runner_root/FancyTool/Modules/Runner/RunnerStore.swift" \
  "$runner_root/FancyTool/Modules/Runner/RunnerModel.swift" \
  "$runner_build/RunnerGIFProcessor.swift" \
  "$runner_root/Tests/RunnerStoreCacheRegression.swift" \
  -o "$runner_build/RunnerCacheRegression.app/Contents/MacOS/regressions"
RUNNER_TEST_ROOT="$runner_build/data" "$runner_build/RunnerCacheRegression.app/Contents/MacOS/regressions"
