#!/bin/bash
set -euo pipefail
monitor_root="$(cd "$(dirname "$0")/.." && pwd)"
monitor_products="${1:?Pass the Xcode Debug products directory containing SystemInfoKit.o}"
monitor_build="$(mktemp -d "${TMPDIR:-/tmp}/monitor-regressions.XXXXXX")"
trap 'rm -rf "$monitor_build"' EXIT
cat "$monitor_root/FancyTool/Modules/Monitor/SystemMetrics.swift" \
  "$monitor_root/FancyTool/Modules/Monitor/SystemMetricsSampler.swift" \
  "$monitor_root/Tests/MonitorMetricsRegression.swift" > "$monitor_build/Regression.swift"
swiftc -Onone -parse-as-library -module-cache-path "$monitor_build/modules" \
  -I "$monitor_products" "$monitor_products/SystemInfoKit.o" \
  "$monitor_root/FancyTool/Modules/Monitor/MonitorHistory.swift" \
  "$monitor_root/FancyTool/Modules/Monitor/MonitorBatteryReader.swift" \
  "$monitor_build/Regression.swift" -o "$monitor_build/regressions"
"$monitor_build/regressions"
swiftc -O -swift-version 6 -parse-as-library -module-cache-path "$monitor_build/modules" \
  -I "$monitor_products" "$monitor_products/SystemInfoKit.o" \
  "$monitor_root/FancyTool/Modules/Monitor/MonitorRateFormatter.swift" \
  "$monitor_root/FancyTool/Modules/Monitor/MonitorStatusReadings.swift" \
  "$monitor_root/Tests/MonitorFormattingRegression.swift" -o "$monitor_build/formatting"
for monitor_locale in en_US zh_CN de_DE fr_FR ja_JP ar_SA; do
  "$monitor_build/formatting" -AppleLocale "$monitor_locale"
done
