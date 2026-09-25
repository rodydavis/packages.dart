#!/bin/bash
set -e

# Read stdin to consume payload
cat > /dev/null

# Find modified or newly created Dart files and format them
MODIFIED_DART_FILES=$(git status --porcelain 2>/dev/null | awk '{print $2}' | grep '\.dart$' || true)

if [ -n "$MODIFIED_DART_FILES" ]; then
  for file in $MODIFIED_DART_FILES; do
    if [ -f "$file" ]; then
      dart format "$file" >/dev/null 2>&1 || true
    fi
  done
fi

# PostToolUse requires empty JSON object on stdout
echo "{}"
