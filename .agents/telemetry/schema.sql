-- ==============================================================================
-- DuckDB Telemetry Schema for Antigravity AI Factory
-- ==============================================================================

-- Raw events table
CREATE TABLE IF NOT EXISTS telemetry_events (
    traceId VARCHAR,
    spanId VARCHAR,
    timestamp TIMESTAMP WITH TIME ZONE,
    timestampUnixNano BIGINT,
    severityText VARCHAR,
    name VARCHAR,
    body VARCHAR,
    resource JSON,
    attributes JSON,
    ingested_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index for trace queries
CREATE INDEX IF NOT EXISTS idx_trace_id ON telemetry_events (traceId);
CREATE INDEX IF NOT EXISTS idx_event_name ON telemetry_events (name);

-- Factory Runs View (Correlates Start & Finish by traceId)
CREATE OR REPLACE VIEW v_factory_runs AS
WITH starts AS (
    SELECT 
        traceId,
        timestamp as started_at,
        attributes->>'task' as task,
        attributes->>'package' as package,
        attributes->>'git_branch' as git_branch,
        attributes->>'git_commit' as git_commit
    FROM telemetry_events
    WHERE name = 'factory.run.start'
),
finishes AS (
    SELECT 
        traceId,
        timestamp as ended_at,
        attributes->>'status' as status,
        TRY_CAST(attributes->>'exit_code' AS INTEGER) as exit_code,
        TRY_CAST(attributes->>'duration_sec' AS DOUBLE) as duration_sec,
        TRY_CAST(attributes->>'changes_count' AS INTEGER) as changes_count
    FROM telemetry_events
    WHERE name = 'factory.run.finish'
)
SELECT 
    s.traceId as trace_id,
    s.task,
    s.package,
    s.started_at,
    f.ended_at,
    f.duration_sec,
    COALESCE(f.status, 'IN_PROGRESS') as status,
    f.exit_code,
    COALESCE(f.changes_count, 0) as changes_count,
    s.git_branch,
    s.git_commit
FROM starts s
LEFT JOIN finishes f ON s.traceId = f.traceId
ORDER BY s.started_at DESC;

-- Hook Activity View
CREATE OR REPLACE VIEW v_hook_activity AS
SELECT 
    traceId as trace_id,
    name as hook_name,
    timestamp as event_time,
    attributes->>'decision' as decision,
    TRY_CAST(attributes->>'duration_ms' AS DOUBLE) as duration_ms,
    TRY_CAST(attributes->>'step_idx' AS INTEGER) as step_idx,
    attributes->>'files_formatted' as files_formatted,
    attributes->>'details' as details
FROM telemetry_events
WHERE name LIKE 'hook.%'
ORDER BY timestamp DESC;

-- High-Level Executive Metrics View
CREATE OR REPLACE VIEW v_executive_summary AS
SELECT 
    COUNT(*) as total_runs,
    COUNT(*) FILTER (WHERE status = 'SUCCESS') as successful_runs,
    COUNT(*) FILTER (WHERE status = 'FAILED') as failed_runs,
    ROUND(AVG(duration_sec), 2) as avg_duration_sec,
    SUM(changes_count) as total_changes_generated
FROM v_factory_runs
WHERE status != 'IN_PROGRESS';
