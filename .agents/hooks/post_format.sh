#!/bin/bash
set -e

HOOK_START=$(python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null || date +%s000)
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$HOOK_DIR/../.." && pwd)"

# Read stdin to consume payload
cat > /dev/null

# Find modified or newly created Dart files and format them
MODIFIED_DART_FILES=$(git status --porcelain 2>/dev/null | awk '{print $2}' | grep '\.dart$' || true)
FORMATTED_COUNT=0

if [ -n "$MODIFIED_DART_FILES" ]; then
  for file in $MODIFIED_DART_FILES; do
    if [ -f "$file" ]; then
      dart format "$file" >/dev/null 2>&1 || true
      FORMATTED_COUNT=$((FORMATTED_COUNT + 1))
    fi
  done
fi

HOOK_END=$(python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null || date +%s000)
DURATION_MS=$((HOOK_END - HOOK_START))

# Emit OpenTelemetry Hook Event
if [ -x "$WORKSPACE_ROOT/.agents/telemetry/emit_otel.sh" ]; then
  "$WORKSPACE_ROOT/.agents/telemetry/emit_otel.sh" \
    "hook.post_format" \
    "INFO" \
    "Auto-formatted $FORMATTED_COUNT Dart files" \
    "{\"hook\":\"post_format\",\"files_formatted\":$FORMATTED_COUNT,\"duration_ms\":$DURATION_MS,\"decision\":\"allow\"}" \
    >/dev/null 2>&1 || true
fi

# PostToolUse requires empty JSON object on stdout
echo "{}"
