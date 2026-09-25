#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# Dart & Flutter Software AI Factory Runner
# Executes Antigravity CLI (agy) headlessly in local or Gitea CI environments.
# Instrumented with OpenTelemetry and DuckDB for full system observability.
# ==============================================================================

# Ensure critical bin directories are in PATH
export PATH="/Users/rodydavis/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/opt/homebrew/Caskroom/flutter/2.10.4/flutter/bin:/opt/homebrew/Caskroom/flutter/2.10.4/flutter/bin/cache/dart-sdk/bin:/Users/rodydavis/.pub-cache/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGY_BIN="$(which agy 2>/dev/null || echo "/Users/rodydavis/.local/bin/agy")"

if [ ! -x "$AGY_BIN" ]; then
  echo "Error: Antigravity CLI (agy) not found or not executable at $AGY_BIN" >&2
  exit 1
fi

TASK="${1:-sweep}"
PACKAGE="${2:-all}"
TIMEOUT="${3:-30m}"

# Initialize OpenTelemetry Trace ID for this entire factory execution
export FACTORY_TRACE_ID="$(openssl rand -hex 16 2>/dev/null || python3 -c 'import secrets; print(secrets.token_hex(16))')"
START_EPOCH=$(date +%s)
GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"

echo "=========================================================="
echo "🚀 Antigravity Dart Package Factory"
echo "Trace ID: $FACTORY_TRACE_ID"
echo "Task:     $TASK"
echo "Package:  $PACKAGE"
echo "CLI:      $AGY_BIN"
echo "Timeout:  $TIMEOUT"
echo "Branch:   $GIT_BRANCH ($GIT_COMMIT)"
echo "Date:     $(date -u)"
echo "=========================================================="

# Emit OTel Run Start
"$WORKSPACE_ROOT/.agents/telemetry/emit_otel.sh" \
  "factory.run.start" \
  "INFO" \
  "Starting AI Factory execution for task $TASK on $PACKAGE" \
  "{\"task\":\"$TASK\",\"package\":\"$PACKAGE\",\"git_branch\":\"$GIT_BRANCH\",\"git_commit\":\"$GIT_COMMIT\"}"

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

set +e
"$AGY_BIN" \
  -p "$PROMPT" \
  --dangerously-skip-permissions \
  --mode accept-edits \
  --print-timeout "$TIMEOUT"
EXIT_CODE=$?
set -e

END_EPOCH=$(date +%s)
DURATION_SEC=$((END_EPOCH - START_EPOCH))
MODIFIED_COUNT=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ' || echo 0)

if [ $EXIT_CODE -eq 0 ]; then
  STATUS="SUCCESS"
else
  STATUS="FAILED"
fi

# Emit OTel Run Finish
"$WORKSPACE_ROOT/.agents/telemetry/emit_otel.sh" \
  "factory.run.finish" \
  "$([ $EXIT_CODE -eq 0 ] && echo 'INFO' || echo 'ERROR')" \
  "AI Factory execution finished with status $STATUS" \
  "{\"status\":\"$STATUS\",\"exit_code\":$EXIT_CODE,\"duration_sec\":$DURATION_SEC,\"changes_count\":$MODIFIED_COUNT}"

# Sync to DuckDB
"$SCRIPT_DIR/telemetry.sh" sync >/dev/null 2>&1 || true

echo "=========================================================="
if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ Factory execution finished successfully in ${DURATION_SEC}s."
else
  echo "❌ Factory execution exited with code: $EXIT_CODE after ${DURATION_SEC}s."
fi
echo "=========================================================="

# Display summary from DuckDB
"$SCRIPT_DIR/telemetry.sh" summary 2>/dev/null || true

exit $EXIT_CODE
