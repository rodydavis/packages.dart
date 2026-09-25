#!/bin/bash
set -e

HOOK_START=$(python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null || date +%s000)
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$HOOK_DIR/../.." && pwd)"

# Read stdin JSON payload
cat > /dev/null

# If there is a pubspec.yaml in the root or in packages/, verify static analysis
if [ -f "pubspec.yaml" ]; then
  ANALYSIS_OUTPUT=$(dart analyze --fatal-infos 2>&1 || true)
  HOOK_END=$(python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null || date +%s000)
  DURATION_MS=$((HOOK_END - HOOK_START))

  if echo "$ANALYSIS_OUTPUT" | grep -qE "error •|warning •"; then
    CLEAN_OUTPUT=$(echo "$ANALYSIS_OUTPUT" | head -n 15 | tr '\n' ' ' | sed 's/"/\\"/g')
    
    if [ -x "$WORKSPACE_ROOT/.agents/telemetry/emit_otel.sh" ]; then
      "$WORKSPACE_ROOT/.agents/telemetry/emit_otel.sh" \
        "hook.stop_guard" \
        "WARN" \
        "Static analysis failed during stop guard" \
        "{\"hook\":\"stop_guard\",\"decision\":\"continue\",\"duration_ms\":$DURATION_MS,\"details\":\"$CLEAN_OUTPUT\"}" \
        >/dev/null 2>&1 || true
    fi

    cat <<EOF
{
  "decision": "continue",
  "reason": "Static analysis detected issues that must be resolved before completing: $CLEAN_OUTPUT"
}
EOF
    exit 0
  fi
fi

HOOK_END=$(python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null || date +%s000)
DURATION_MS=$((HOOK_END - HOOK_START))

if [ -x "$WORKSPACE_ROOT/.agents/telemetry/emit_otel.sh" ]; then
  "$WORKSPACE_ROOT/.agents/telemetry/emit_otel.sh" \
    "hook.stop_guard" \
    "INFO" \
    "Static analysis passed cleanly during stop guard" \
    "{\"hook\":\"stop_guard\",\"decision\":\"allow\",\"duration_ms\":$DURATION_MS}" \
    >/dev/null 2>&1 || true
fi

# Otherwise allow completion
echo '{"decision": "allow"}'
