#!/usr/bin/env bash
set -euo pipefail

# Archive Model - Check Automation Status
# This script checks if The Archive's automation is properly configured and running

echo "🫀 Archive Model - Automation Status Check"
echo "=========================================="
echo

ARCHIVE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$ARCHIVE_DIR/scripts/pulse-constellation.sh"
LOG_FILE="$ARCHIVE_DIR/logs/pulse.log"

# Check if pulse script exists and is executable
echo "📋 Checking pulse script..."
if [ -f "$SCRIPT_PATH" ] && [ -x "$SCRIPT_PATH" ]; then
    echo "  ✅ Pulse script found and executable: $SCRIPT_PATH"
else
    echo "  ❌ Pulse script missing or not executable: $SCRIPT_PATH"
fi

# Check cron job
echo
echo "🕒 Checking cron automation..."
CRON_ENTRIES=$(crontab -l 2>/dev/null || echo "")
if echo "$CRON_ENTRIES" | grep -F "$SCRIPT_PATH" >/dev/null 2>&1; then
    echo "  ✅ Cron job found:"
    echo "$CRON_ENTRIES" | grep -F "$SCRIPT_PATH" | sed 's/^/    /'
else
    echo "  ❌ No cron job found for pulse script"
    echo "  💡 Run: ./scripts/setup-automation.sh"
fi

# Check logs
echo
echo "📝 Checking logging..."
if [ -f "$LOG_FILE" ]; then
    echo "  ✅ Log file exists: $LOG_FILE"
    LOG_SIZE=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
    echo "  📊 Log entries: $LOG_SIZE lines"

    if [ "$LOG_SIZE" -gt 0 ]; then
        echo "  📅 Last log entries:"
        tail -5 "$LOG_FILE" 2>/dev/null | sed 's/^/    /' || echo "    (unable to read log)"
    else
        echo "  📝 Log is empty (no automated runs yet)"
    fi
else
    echo "  ❌ Log file not found: $LOG_FILE"
    echo "  💡 Run: ./scripts/setup-automation.sh"
fi

# Check signals
echo
echo "📡 Checking broadcast signals..."
LATEST_SIGNAL="$ARCHIVE_DIR/signals/latest.json"
ARCHIVE_SIGNAL="$ARCHIVE_DIR/signals/archive.latest.json"

if [ -f "$LATEST_SIGNAL" ]; then
    echo "  ✅ Latest signal exists"
    if command -v jq >/dev/null 2>&1; then
        LAST_ID=$(jq -r '.id' "$LATEST_SIGNAL" 2>/dev/null || echo "unknown")
        LAST_TIME=$(jq -r '.ts_utc' "$LATEST_SIGNAL" 2>/dev/null || echo "unknown")
        echo "    📡 Last broadcast: $LAST_ID"
        echo "    🕒 Timestamp: $LAST_TIME"
    fi
else
    echo "  ❌ No latest signal found"
fi

if [ -f "$ARCHIVE_SIGNAL" ]; then
    if command -v jq >/dev/null 2>&1; then
        ARCHIVE_COUNT=$(jq '. | length' "$ARCHIVE_SIGNAL" 2>/dev/null || echo "unknown")
        echo "  📚 Archive contains: $ARCHIVE_COUNT historical broadcasts"
    else
        echo "  📚 Archive file exists (jq needed for details)"
    fi
else
    echo "  📚 No archive yet (will be created after first pulse)"
fi

# Overall status
echo
echo "🎯 Overall Status:"
HAS_SCRIPT=$([[ -f "$SCRIPT_PATH" && -x "$SCRIPT_PATH" ]] && echo "true" || echo "false")
HAS_CRON=$(echo "$CRON_ENTRIES" | grep -F "$SCRIPT_PATH" >/dev/null 2>&1 && echo "true" || echo "false")
HAS_LOGS=$([[ -f "$LOG_FILE" ]] && echo "true" || echo "false")

if [[ "$HAS_SCRIPT" == "true" && "$HAS_CRON" == "true" && "$HAS_LOGS" == "true" ]]; then
    echo "  🎉 FULLY AUTOMATED - The Archive's heartbeat is active!"
    echo "  ⏰ Next pulse: Tonight at 2:00 AM UTC"
elif [[ "$HAS_SCRIPT" == "true" && "$HAS_CRON" == "true" ]]; then
    echo "  🟡 MOSTLY READY - Automation configured, logs may initialize on first run"
elif [[ "$HAS_SCRIPT" == "true" ]]; then
    echo "  🟠 PARTIALLY READY - Pulse script ready, automation needs setup"
    echo "  💡 Run: ./scripts/setup-automation.sh"
else
    echo "  🔴 NOT READY - Core components missing"
    echo "  💡 Check script installation and permissions"
fi