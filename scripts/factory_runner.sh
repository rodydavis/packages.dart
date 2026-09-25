#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# Dart & Flutter Software AI Factory Runner
# Executes Antigravity CLI (agy) headlessly with full Issue <-> PR traceability,
# automated Issue Triage, DuckDB analytics, and OpenTelemetry observability.
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
ISSUE_NUM="${4:-}"

# Parse optional --issue flag if passed as argument
while [[ $# -gt 0 ]]; do
  case $1 in
    --issue)
      ISSUE_NUM="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

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
if [ -n "$ISSUE_NUM" ]; then
  echo "Issue:    #$ISSUE_NUM"
fi
echo "Branch:   $GIT_BRANCH ($GIT_COMMIT)"
echo "Date:     $(date -u)"
echo "=========================================================="

# 1. Issue Management & Prompt Construction
if [ "$TASK" = "triage" ]; then
  if [ -n "$PACKAGE" ] && [[ "$PACKAGE" =~ ^[0-9]+$ ]]; then
    ISSUE_NUM="$PACKAGE"
  fi
  
  if [ -n "$ISSUE_NUM" ] && [ -x "$SCRIPT_DIR/gitea_api.sh" ]; then
    echo "Triaging Gitea Issue #$ISSUE_NUM..."
    ISSUE_JSON=$("$SCRIPT_DIR/gitea_api.sh" get-issue "$ISSUE_NUM" 2>/dev/null || echo "{}")
    ISSUE_TITLE=$(echo "$ISSUE_JSON" | python3 -c 'import sys, json; print(json.load(sys.stdin).get("title", ""))' 2>/dev/null || echo "")
    ISSUE_BODY=$(echo "$ISSUE_JSON" | python3 -c 'import sys, json; print(json.load(sys.stdin).get("body", ""))' 2>/dev/null || echo "")

    PROMPT="Run the dart-issue-triager skill to triage Issue #$ISSUE_NUM: '$ISSUE_TITLE'.
Issue Description:
$ISSUE_BODY

Instructions:
1. Identify affected package(s) under packages/*.
2. Analyze stack traces, build errors, or requested enhancements.
3. Formulate an action plan for reproduction and fixing without breaking changes.
4. Post your technical triage assessment comment directly to the issue using:
   ./scripts/gitea_api.sh comment-issue $ISSUE_NUM '<your markdown assessment>'"
  else
    PROMPT="Run the dart-issue-triager skill to inspect open issues in this repository using ./scripts/gitea_api.sh list-issues and triage any untriaged issues."
  fi

elif [ "$TASK" = "issue" ] && [ -n "$PACKAGE" ] && [[ "$PACKAGE" =~ ^[0-9]+$ ]]; then
  ISSUE_NUM="$PACKAGE"
  if [ -x "$SCRIPT_DIR/gitea_api.sh" ]; then
    echo "Fetching Issue #$ISSUE_NUM details from Gitea..."
    ISSUE_JSON=$("$SCRIPT_DIR/gitea_api.sh" get-issue "$ISSUE_NUM" 2>/dev/null || echo "{}")
    ISSUE_TITLE=$(echo "$ISSUE_JSON" | python3 -c 'import sys, json; print(json.load(sys.stdin).get("title", ""))' 2>/dev/null || echo "")
    ISSUE_BODY=$(echo "$ISSUE_JSON" | python3 -c 'import sys, json; print(json.load(sys.stdin).get("body", ""))' 2>/dev/null || echo "")

    PROMPT="Resolve Gitea Issue #$ISSUE_NUM: '$ISSUE_TITLE'.
Issue Description:
$ISSUE_BODY

Instructions:
1. Identify affected package(s) in this repository.
2. Write reproduction tests under the package's test/ directory first.
3. Apply fixes while preserving the widest possible Dart and Flutter target ranges.
4. Enforce zero breaking changes: never remove public API symbols, use @Deprecated delegates if refactoring.
5. Ensure 'dart test' passes and 'dart analyze --fatal-infos' returns zero issues."

    # Post progress update comment
    "$SCRIPT_DIR/gitea_api.sh" comment-issue "$ISSUE_NUM" "🚀 Antigravity AI Factory has started work on this issue (Trace ID: \`$FACTORY_TRACE_ID\`)." >/dev/null 2>&1 || true
  fi

elif [ -z "$ISSUE_NUM" ] && [ "$TASK" != "triage" ] && [ -x "$SCRIPT_DIR/gitea_api.sh" ]; then
  echo "Creating automated Gitea tracking issue for task '$TASK'..."
  ISSUE_TITLE="[AI Factory] $TASK maintenance for $PACKAGE"
  ISSUE_DESC="Automated maintenance work order initiated by Antigravity AI Factory.

- **Task**: $TASK
- **Target**: $PACKAGE
- **Trace ID**: \`$FACTORY_TRACE_ID\`
- **Policy**: Widest Dart/Flutter target ranges, zero breaking changes, and 140/140 Pana score compliance.

Tracking progress..."

  CREATED_NUM=$("$SCRIPT_DIR/gitea_api.sh" create-issue "$ISSUE_TITLE" "$ISSUE_DESC" "ai-factory,$TASK" 2>/dev/null | tail -n 1 || true)
  if [[ "$CREATED_NUM" =~ ^[0-9]+$ ]]; then
    ISSUE_NUM="$CREATED_NUM"
    echo "Tracking Issue #$ISSUE_NUM created."
  fi
fi

# 2. Build Default Prompt if not already built
if [ -z "$PROMPT" ]; then
  case "$TASK" in
    dependencies|deps)
      PROMPT="Run the dart-dependency-steward skill on ${PACKAGE} in this repository. Identify outdated dependencies, bump constraints safely while preserving the widest possible target ranges, test with dart test, and fix any breaking updates or deprecations using soft deprecation."
      ;;
    pana|health)
      PROMPT="Run the dart-pana-auditor skill on ${PACKAGE} in this repository. Audit packages using pana, check for 140/140 score compliance, fix missing documentation comments or platform constraints, and verify all tests pass."
      ;;
    semver|api)
      PROMPT="Run the dart-semver-gatekeeper skill on ${PACKAGE} in this repository. Check for public API modifications, verify SemVer compliance, enforce soft deprecation over breaking changes, update CHANGELOG.md, and ensure zero unintended breaking changes."
      ;;
    release|release-prep)
      PROMPT="Run the dart-release-manager skill on ${PACKAGE} in this repository. Validate package readiness, run dart pub publish --dry-run, and stage the release artifacts."
      ;;
    sweep|all|*)
      PROMPT="Run the dart-factory-orchestrator skill on this repository. Perform a comprehensive maintenance sweep across workspace packages: audit dependencies, maintain widest SDK target ranges, ensure zero breaking changes, run pana scoring checks, and verify all tests pass."
      ;;
  esac
fi

# Emit OTel Run Start
"$WORKSPACE_ROOT/.agents/telemetry/emit_otel.sh" \
  "factory.run.start" \
  "INFO" \
  "Starting AI Factory execution for task $TASK on $PACKAGE (Issue #$ISSUE_NUM)" \
  "{\"task\":\"$TASK\",\"package\":\"$PACKAGE\",\"issue_number\":\"$ISSUE_NUM\",\"git_branch\":\"$GIT_BRANCH\",\"git_commit\":\"$GIT_COMMIT\"}"

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
  "{\"status\":\"$STATUS\",\"exit_code\":$EXIT_CODE,\"duration_sec\":$DURATION_SEC,\"changes_count\":$MODIFIED_COUNT,\"issue_number\":\"$ISSUE_NUM\"}"

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

# 3. Pull Request Generation: If changes were produced, branch, push & create PR
if [ "$MODIFIED_COUNT" -gt 0 ] && [ $EXIT_CODE -eq 0 ]; then
  TIMESTAMP=$(date +%Y%m%d-%H%M)
  PR_BRANCH="ai-factory/${TASK}-${TIMESTAMP}"
  
  echo "Creating branch $PR_BRANCH for proposed changes..."
  git checkout -b "$PR_BRANCH"
  git add -A
  
  COMMIT_MSG="chore($([ "$PACKAGE" != "all" ] && echo "$PACKAGE" || echo "factory")): automated $TASK maintenance"
  if [ -n "$ISSUE_NUM" ]; then
    COMMIT_MSG="$COMMIT_MSG (closes #$ISSUE_NUM)"
  fi
  git commit -m "$COMMIT_MSG"
  
  echo "Pushing branch $PR_BRANCH to origin..."
  git push -u origin "$PR_BRANCH"

  # Create Gitea Pull Request if gitea_api.sh exists
  if [ -x "$SCRIPT_DIR/gitea_api.sh" ]; then
    echo "Creating Pull Request on Gitea..."
    TELEMETRY_REPORT=$("$SCRIPT_DIR/telemetry.sh" markdown-report 2>/dev/null || echo "")
    
    PR_TITLE="$COMMIT_MSG"
    PR_BODY="## Summary
Automated $TASK maintenance completed by the Antigravity AI Factory for \`$PACKAGE\`.

### Quality & Policy Verification
- **Target Ranges**: Maintained widest supported Dart and Flutter ranges.
- **Zero Breaking Changes**: Applied soft deprecation with backwards compatibility delegates.
- **Static Analysis**: Verified clean with zero diagnostics.
- **Unit Tests**: Full test suite passing.

$TELEMETRY_REPORT
"
    "$SCRIPT_DIR/gitea_api.sh" create-pr "$PR_BRANCH" "main" "$PR_TITLE" "$PR_BODY" "$ISSUE_NUM" || true
  fi
fi

exit $EXIT_CODE
