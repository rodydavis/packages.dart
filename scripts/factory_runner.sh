#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# Dart & Flutter Software AI Factory Runner
# Executes Antigravity CLI (agy) headlessly in local or Gitea CI environments.
# ==============================================================================

# Ensure critical bin directories are in PATH
export PATH="/Users/rodydavis/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/opt/homebrew/Caskroom/flutter/2.10.4/flutter/bin:/opt/homebrew/Caskroom/flutter/2.10.4/flutter/bin/cache/dart-sdk/bin:/Users/rodydavis/.pub-cache/bin:$PATH"

AGY_BIN="$(which agy 2>/dev/null || echo "/Users/rodydavis/.local/bin/agy")"

if [ ! -x "$AGY_BIN" ]; then
  echo "Error: Antigravity CLI (agy) not found or not executable at $AGY_BIN" >&2
  exit 1
fi

TASK="${1:-sweep}"
PACKAGE="${2:-all}"
TIMEOUT="${3:-30m}"

echo "=========================================================="
echo "🚀 Antigravity Dart Package Factory"
echo "Task:     $TASK"
echo "Package:  $PACKAGE"
echo "CLI:      $AGY_BIN"
echo "Timeout:  $TIMEOUT"
echo "Workspace: $(pwd)"
echo "Date:     $(date -u)"
echo "=========================================================="

case "$TASK" in
  dependencies|deps)
    PROMPT="Run the dart-dependency-steward skill on ${PACKAGE} in this repository. Identify outdated dependencies, bump constraints safely, test the changes with dart test, and fix any breaking updates or deprecations."
    ;;
  pana|health)
    PROMPT="Run the dart-pana-auditor skill on ${PACKAGE} in this repository. Audit packages using pana, check for 140/140 score compliance, fix missing documentation comments or platform constraints, and verify all tests pass."
    ;;
  semver|api)
    PROMPT="Run the dart-semver-gatekeeper skill on ${PACKAGE} in this repository. Check for public API modifications, verify SemVer compliance, update CHANGELOG.md, and ensure no unintended breaking changes exist."
    ;;
  release|release-prep)
    PROMPT="Run the dart-release-manager skill on ${PACKAGE} in this repository. Validate package readiness, run dart pub publish --dry-run, and stage the release artifacts."
    ;;
  sweep|all|*)
    PROMPT="Run the dart-factory-orchestrator skill on this repository. Perform a comprehensive maintenance sweep across workspace packages: audit dependencies, run pana scoring checks, verify SemVer compliance, and make sure all tests pass."
    ;;
esac

echo "Invoking Antigravity in headless accept-edits mode..."

"$AGY_BIN" \
  -p "$PROMPT" \
  --dangerously-skip-permissions \
  --mode accept-edits \
  --print-timeout "$TIMEOUT"

EXIT_CODE=$?

echo "=========================================================="
if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ Factory execution finished successfully."
else
  echo "❌ Factory execution exited with code: $EXIT_CODE"
fi
echo "=========================================================="

exit $EXIT_CODE
