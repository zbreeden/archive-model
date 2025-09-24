#!/usr/bin/env bash
set -euo pipefail

# Archive Model - Setup Automation Script
# This script sets up the actual automation infrastructure for The Archive's constellation pulse

echo "🫀 Archive Model - Setting up constellation pulse automation"
echo "=========================================================="
echo

ARCHIVE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$ARCHIVE_DIR/scripts/pulse-constellation.sh"
LOG_DIR="$ARCHIVE_DIR/logs"
LOG_FILE="$LOG_DIR/pulse.log"
CRON_SCHEDULE="0 2 * * *"  # 2:00 AM UTC daily

# Verify the pulse script exists and is executable
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "❌ Pulse script not found: $SCRIPT_PATH"
    exit 1
fi

if [ ! -x "$SCRIPT_PATH" ]; then
    echo "🔧 Making pulse script executable..."
    chmod +x "$SCRIPT_PATH"
fi

# Create logs directory
echo "📁 Setting up logging infrastructure..."
mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
echo "  ✅ Log directory created: $LOG_DIR"
echo "  ✅ Log file initialized: $LOG_FILE"

# Create the cron job entry
CRON_COMMAND="$CRON_SCHEDULE $SCRIPT_PATH >> $LOG_FILE 2>&1"

echo
echo "🕒 Setting up cron automation..."
echo "  📅 Schedule: $CRON_SCHEDULE (2:00 AM UTC daily)"
echo "  🎯 Command: $SCRIPT_PATH"
echo "  📝 Logs to: $LOG_FILE"

# Check if cron job already exists
EXISTING_CRON=""
if command -v crontab >/dev/null 2>&1; then
    EXISTING_CRON=$(crontab -l 2>/dev/null || echo "")
fi

if echo "$EXISTING_CRON" | grep -F "$SCRIPT_PATH" >/dev/null 2>&1; then
    echo "  ⚠️  Cron job already exists for this script"
    echo "  📋 Current entry:"
    echo "$EXISTING_CRON" | grep -F "$SCRIPT_PATH"
else
    # Add the cron job
    echo "  📝 Adding cron job..."

    # Create temp file with new cron entry
    TEMP_CRON=$(mktemp)
    if [ -n "$EXISTING_CRON" ]; then
        echo "$EXISTING_CRON" > "$TEMP_CRON"
    fi
    echo "$CRON_COMMAND" >> "$TEMP_CRON"

    # Install the new crontab
    if crontab "$TEMP_CRON" 2>/dev/null; then
        echo "  ✅ Cron job added successfully!"
    else
        echo "  ❌ Failed to add cron job - you may need to add it manually"
        echo "  💡 Manual command: crontab -e"
        echo "  📝 Add this line: $CRON_COMMAND"
    fi

    # Clean up temp file
    rm -f "$TEMP_CRON"
fi

echo
echo "🔍 Verifying automation setup..."

# Verify cron job was added
CURRENT_CRON=$(crontab -l 2>/dev/null || echo "")
if echo "$CURRENT_CRON" | grep -F "$SCRIPT_PATH" >/dev/null 2>&1; then
    echo "  ✅ Cron job verified in crontab"
    echo "     $(echo "$CURRENT_CRON" | grep -F "$SCRIPT_PATH")"
    AUTOMATION_STATUS="✅ ACTIVE"
else
    echo "  ⚠️  Cron job not found - manual setup required"
    AUTOMATION_STATUS="⚠️ MANUAL SETUP NEEDED"
fi

# Test the script execution (brief test)
echo "  🧪 Testing pulse script..."
if timeout 30s "$SCRIPT_PATH" >/dev/null 2>&1 || [ $? -eq 124 ]; then
    echo "  ✅ Pulse script is executable"
else
    echo "  ⚠️  Pulse script test had issues (but may still work)"
fi

# Show current crontab
echo
echo "📋 Current crontab for $(whoami):"
if [ -n "$CURRENT_CRON" ]; then
    echo "$CURRENT_CRON"
else
    echo "  (no crontab entries)"
fi

echo
echo "🎉 Automation setup complete!"
echo
echo "📊 Summary:"
echo "  • Pulse script: $SCRIPT_PATH"
echo "  • Schedule: Daily at 2:00 AM UTC"
echo "  • Logging: $LOG_FILE"
echo "  • Status: $AUTOMATION_STATUS"
echo
echo "📋 Management commands:"
echo "  • View logs: tail -f $LOG_FILE"
echo "  • View crontab: crontab -l"
echo "  • Edit crontab: crontab -e"
echo "  • Test pulse: $SCRIPT_PATH"
echo "  • Remove automation: crontab -e (then delete the line)"
echo
if echo "$CURRENT_CRON" | grep -F "$SCRIPT_PATH" >/dev/null 2>&1; then
    echo "⚠️  Note: The first automated pulse will run tonight at 2:00 AM UTC"
    echo "🫀 The Archive's heartbeat is now fully automated!"
else
    echo "⚠️  Manual setup required:"
    echo "   1. Run: crontab -e"
    echo "   2. Add: $CRON_COMMAND"
    echo "   3. Save and exit"
fi