#!/bin/bash
set -e

# Read stdin JSON payload
cat > /dev/null

# If there is a pubspec.yaml in the root or in packages/, verify static analysis
if [ -f "pubspec.yaml" ]; then
  # Check if dart analyze fails
  ANALYSIS_OUTPUT=$(dart analyze --fatal-infos 2>&1 || true)
  if echo "$ANALYSIS_OUTPUT" | grep -qE "error •|warning •"; then
    CLEAN_OUTPUT=$(echo "$ANALYSIS_OUTPUT" | head -n 15 | tr '\n' ' ' | sed 's/"/\\"/g')
    cat <<EOF
{
  "decision": "continue",
  "reason": "Static analysis detected issues that must be resolved before completing: $CLEAN_OUTPUT"
}
EOF
    exit 0
  fi
fi

# Otherwise allow completion
echo '{"decision": "allow"}'
