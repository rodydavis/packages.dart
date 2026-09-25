#!/usr/bin/env bash
# ==============================================================================
# OpenTelemetry Event Emitter for Antigravity AI Factory
# Emits OTel-compliant JSONL events and optionally forwards to OTLP collector.
# ==============================================================================

EVENT_NAME="${1:-custom.event}"
SEVERITY="${2:-INFO}"
BODY="${3:-Event emitted}"
RAW_ATTRS="$4"
if [ -z "$RAW_ATTRS" ]; then
  RAW_ATTRS="{}"
fi

# Ensure target telemetry dir exists
TELEMETRY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$TELEMETRY_DIR/events.jsonl"
mkdir -p "$TELEMETRY_DIR"

# Generate or reuse Trace ID (32 hex characters)
if [ -z "$FACTORY_TRACE_ID" ]; then
  FACTORY_TRACE_ID="$(openssl rand -hex 16 2>/dev/null || python3 -c 'import secrets; print(secrets.token_hex(16))')"
fi

# Generate Span ID (16 hex characters)
SPAN_ID="$(openssl rand -hex 8 2>/dev/null || python3 -c 'import secrets; print(secrets.token_hex(8))')"

TIMESTAMP_ISO="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
TIMESTAMP_NANO="$(python3 -c 'import time; print(int(time.time() * 1e9))' 2>/dev/null || date +%s000000000)"
HOST_NAME="$(hostname 2>/dev/null || echo 'localhost')"

# Build OpenTelemetry JSON Log Record passing parameters as arguments to prevent escaping collisions
EVENT_JSON=$(python3 - "$RAW_ATTRS" "$BODY" "$FACTORY_TRACE_ID" "$SPAN_ID" "$TIMESTAMP_ISO" "$TIMESTAMP_NANO" "$SEVERITY" "$EVENT_NAME" "$HOST_NAME" << 'EOF'
import json, sys

raw_attrs = sys.argv[1] if len(sys.argv) > 1 else "{}"
body = sys.argv[2] if len(sys.argv) > 2 else ""
trace_id = sys.argv[3]
span_id = sys.argv[4]
ts_iso = sys.argv[5]
ts_nano = int(sys.argv[6])
severity = sys.argv[7]
event_name = sys.argv[8]
host_name = sys.argv[9]

attrs = {}
try:
    attrs = json.loads(raw_attrs)
except Exception:
    attrs = {'raw': raw_attrs}

record = {
    'traceId': trace_id,
    'spanId': span_id,
    'timestamp': ts_iso,
    'timestampUnixNano': ts_nano,
    'severityText': severity,
    'name': event_name,
    'body': body,
    'resource': {
        'attributes': {
            'service.name': 'antigravity-dart-factory',
            'service.version': '1.0.0',
            'host.name': host_name,
            'os.type': sys.platform
        }
    },
    'attributes': attrs
}
print(json.dumps(record))
EOF
)

# Append to JSONL log
echo "$EVENT_JSON" >> "$LOG_FILE"

# Optional OTLP Exporter forward (if configured)
if [ -n "$OTEL_EXPORTER_OTLP_ENDPOINT" ]; then
  curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "$EVENT_JSON" \
    "$OTEL_EXPORTER_OTLP_ENDPOINT/v1/logs" >/dev/null 2>&1 &
fi
