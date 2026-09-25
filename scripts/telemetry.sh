#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# DuckDB & OpenTelemetry Manager for Antigravity AI Factory
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TELEMETRY_DIR="$WORKSPACE_ROOT/.agents/telemetry"
DB_FILE="$TELEMETRY_DIR/factory.duckdb"
SCHEMA_FILE="$TELEMETRY_DIR/schema.sql"
LOG_FILE="$TELEMETRY_DIR/events.jsonl"
DUCKDB_BIN="$(which duckdb 2>/dev/null || echo "/opt/homebrew/bin/duckdb")"

if [ ! -x "$DUCKDB_BIN" ]; then
  echo "Error: duckdb CLI not found or not executable at $DUCKDB_BIN" >&2
  exit 1
fi

ACTION="${1:-summary}"
ARG="${2:-}"

mkdir -p "$TELEMETRY_DIR"

sync_db() {
  if [ ! -f "$LOG_FILE" ] || [ ! -s "$LOG_FILE" ]; then
    echo "Notice: No telemetry events found at $LOG_FILE"
    return 0
  fi

  "$DUCKDB_BIN" "$DB_FILE" <<EOF
.read '$SCHEMA_FILE'

-- Idempotent full load from JSONL events
DELETE FROM telemetry_events;
INSERT INTO telemetry_events (
    traceId,
    spanId,
    timestamp,
    timestampUnixNano,
    severityText,
    name,
    body,
    resource,
    attributes
)
SELECT 
    traceId,
    spanId,
    TRY_CAST(timestamp AS TIMESTAMP WITH TIME ZONE),
    timestampUnixNano,
    severityText,
    name,
    body,
    resource,
    attributes
FROM read_json_auto('$LOG_FILE');
EOF
  echo "Synced telemetry events into $DB_FILE"
}

case "$ACTION" in
  sync)
    sync_db
    ;;
  summary)
    sync_db >/dev/null
    echo "================================================================="
    echo "📊 Antigravity Factory: Executive Telemetry Summary"
    echo "================================================================="
    "$DUCKDB_BIN" -box "$DB_FILE" "SELECT * FROM v_executive_summary;"
    echo ""
    echo "Recent Factory Runs:"
    "$DUCKDB_BIN" -box "$DB_FILE" "SELECT trace_id, task, package, status, duration_sec, exit_code, started_at FROM v_factory_runs LIMIT 10;"
    ;;
  hooks)
    sync_db >/dev/null
    echo "================================================================="
    echo "🪝 Antigravity Factory: Hook Activity"
    echo "================================================================="
    "$DUCKDB_BIN" -box "$DB_FILE" "SELECT hook_name, decision, duration_ms, files_formatted, event_time FROM v_hook_activity LIMIT 20;"
    ;;
  query|sql)
    if [ -z "$ARG" ]; then
      echo "Usage: ./scripts/telemetry.sh query \"<SQL>\"" >&2
      exit 1
    fi
    sync_db >/dev/null
    "$DUCKDB_BIN" -box "$DB_FILE" "$ARG"
    ;;
  markdown-report)
    sync_db >/dev/null
    echo "### 📊 Antigravity AI Factory Telemetry Report"
    echo ""
    echo "**Executive Metrics**"
    "$DUCKDB_BIN" -markdown "$DB_FILE" "SELECT * FROM v_executive_summary;"
    echo ""
    echo "**Latest Factory Run**"
    "$DUCKDB_BIN" -markdown "$DB_FILE" "SELECT trace_id, task, package, status, duration_sec, changes_count, started_at FROM v_factory_runs LIMIT 1;"
    echo ""
    echo "**Quality Gate & Hook Execution Details**"
    "$DUCKDB_BIN" -markdown "$DB_FILE" "SELECT hook_name, decision, duration_ms, event_time FROM v_hook_activity LIMIT 5;"
    ;;
  export)
    sync_db >/dev/null
    EXPORT_PATH="${ARG:-$TELEMETRY_DIR/factory_runs.parquet}"
    "$DUCKDB_BIN" "$DB_FILE" "COPY (SELECT * FROM v_factory_runs) TO '$EXPORT_PATH' (FORMAT PARQUET);"
    echo "Exported factory runs to Parquet at: $EXPORT_PATH"
    ;;
  *)
    echo "Usage: $0 {sync|summary|hooks|query <SQL>|markdown-report|export [path]}"
    exit 1
    ;;
esac
