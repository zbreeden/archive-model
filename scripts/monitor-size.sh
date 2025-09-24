#!/usr/bin/env bash
set -euo pipefail

# 📊 Archive Model Size Monitor
# Tracks The Archive's growth and provides size management insights

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE_MODEL_ROOT="$(dirname "$SCRIPT_DIR")"
MONITOR_DATA="$ARCHIVE_MODEL_ROOT/data/size_monitoring"

echo "📊 Archive Model Size Monitor"
echo "🫀 Tracking The Archive's growth and storage optimization"
echo

# Create monitoring data directory
mkdir -p "$MONITOR_DATA"

# Function to get directory size
get_dir_size() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        du -sk "$dir" 2>/dev/null | cut -f1
    else
        echo "0"
    fi
}

# Function to count files in directory
count_files() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        find "$dir" -type f | wc -l
    else
        echo "0"
    fi
}

# Function to format size for display
format_size() {
    local size_kb="$1"
    if [[ $size_kb -gt 1024 ]]; then
        echo "$(echo "scale=2; $size_kb/1024" | bc 2>/dev/null || echo $((size_kb/1024))) MB"
    else
        echo "${size_kb} KB"
    fi
}

# Collect current metrics
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
DATE_SIMPLE=$(date -u +%Y-%m-%d)

# Directory sizes
SCRIPTS_SIZE=$(get_dir_size "$SCRIPT_DIR")
DATA_SIZE=$(get_dir_size "$ARCHIVE_MODEL_ROOT/data")
SEEDS_SIZE=$(get_dir_size "$ARCHIVE_MODEL_ROOT/seeds")
SIGNALS_SIZE=$(get_dir_size "$ARCHIVE_MODEL_ROOT/signals")
SCHEMA_SIZE=$(get_dir_size "$ARCHIVE_MODEL_ROOT/schema")
BACKUPS_SIZE=$(get_dir_size "$ARCHIVE_MODEL_ROOT/data/script_backups")
TOTAL_SIZE=$(get_dir_size "$ARCHIVE_MODEL_ROOT")

# File counts
SCRIPTS_COUNT=$(count_files "$SCRIPT_DIR")
DATA_COUNT=$(count_files "$ARCHIVE_MODEL_ROOT/data")
BACKUP_COUNT=$(count_files "$ARCHIVE_MODEL_ROOT/data/script_backups")

# Script-specific metrics
SHELL_SCRIPTS=$(find "$SCRIPT_DIR" -name "*.sh" -type f | wc -l)
MARKDOWN_DOCS=$(find "$SCRIPT_DIR" -name "*.md" -type f | wc -l)
AGGREGATED_SCRIPTS=$(grep -l "^# Source:" "$SCRIPT_DIR"/*.sh 2>/dev/null | wc -l)
NATIVE_SCRIPTS=$((SHELL_SCRIPTS - AGGREGATED_SCRIPTS))

# Display current status
echo "📏 Current Archive Size Metrics:"
echo "  🫀 Total Archive: $(format_size $TOTAL_SIZE)"
echo "  📜 Scripts directory: $(format_size $SCRIPTS_SIZE) ($SCRIPTS_COUNT files)"
echo "  💾 Data directory: $(format_size $DATA_SIZE) ($DATA_COUNT files)"
echo "  📡 Signals directory: $(format_size $SIGNALS_SIZE)"
echo "  🌱 Seeds directory: $(format_size $SEEDS_SIZE)"
echo "  📋 Schema directory: $(format_size $SCHEMA_SIZE)"
echo "  💾 Backups: $(format_size $BACKUPS_SIZE) ($BACKUP_COUNT files)"
echo
echo "🔍 Script Collection Breakdown:"
echo "  🔧 Shell scripts: $SHELL_SCRIPTS"
echo "  📝 Documentation: $MARKDOWN_DOCS"
echo "  🌟 Constellation scripts: $AGGREGATED_SCRIPTS"
echo "  🏠 Native archive scripts: $NATIVE_SCRIPTS"

# Log metrics to CSV for historical tracking
METRICS_FILE="$MONITOR_DATA/size_history.csv"

# Create CSV header if file doesn't exist
if [[ ! -f "$METRICS_FILE" ]]; then
    echo "timestamp,date,total_size_kb,scripts_size_kb,data_size_kb,backups_size_kb,scripts_count,shell_scripts,aggregated_scripts,native_scripts" > "$METRICS_FILE"
fi

# Append current metrics
echo "$TIMESTAMP,$DATE_SIMPLE,$TOTAL_SIZE,$SCRIPTS_SIZE,$DATA_SIZE,$BACKUPS_SIZE,$SCRIPTS_COUNT,$SHELL_SCRIPTS,$AGGREGATED_SCRIPTS,$NATIVE_SCRIPTS" >> "$METRICS_FILE"

# Analyze growth trends if we have historical data
HISTORY_LINES=$(wc -l < "$METRICS_FILE" 2>/dev/null || echo 1)

if [[ $HISTORY_LINES -gt 2 ]]; then
    echo
    echo "📈 Growth Analysis:"

    # Get previous measurement (second to last line)
    PREV_LINE=$(tail -2 "$METRICS_FILE" | head -1)
    PREV_TOTAL=$(echo "$PREV_LINE" | cut -d',' -f3)
    PREV_SCRIPTS=$(echo "$PREV_LINE" | cut -d',' -f4)
    PREV_COUNT=$(echo "$PREV_LINE" | cut -d',' -f7)

    # Calculate changes
    SIZE_CHANGE=$((TOTAL_SIZE - PREV_TOTAL))
    SCRIPTS_SIZE_CHANGE=$((SCRIPTS_SIZE - PREV_SCRIPTS))
    COUNT_CHANGE=$((SCRIPTS_COUNT - PREV_COUNT))

    echo "  📊 Since last measurement:"
    echo "    Total size: $(format_size $PREV_TOTAL) → $(format_size $TOTAL_SIZE) ($(if [[ $SIZE_CHANGE -gt 0 ]]; then echo "+"; fi)$(format_size $SIZE_CHANGE))"
    echo "    Scripts size: $(format_size $PREV_SCRIPTS) → $(format_size $SCRIPTS_SIZE) ($(if [[ $SCRIPTS_SIZE_CHANGE -gt 0 ]]; then echo "+"; fi)$(format_size $SCRIPTS_SIZE_CHANGE))"
    echo "    Script count: $PREV_COUNT → $SCRIPTS_COUNT ($(if [[ $COUNT_CHANGE -gt 0 ]]; then echo "+"; fi)$COUNT_CHANGE)"

    # Historical summary
    FIRST_LINE=$(tail -$((HISTORY_LINES - 1)) "$METRICS_FILE" | head -1)
    FIRST_TOTAL=$(echo "$FIRST_LINE" | cut -d',' -f3)
    FIRST_DATE=$(echo "$FIRST_LINE" | cut -d',' -f2)

    TOTAL_GROWTH=$((TOTAL_SIZE - FIRST_TOTAL))
    echo
    echo "  🕒 Historical Growth (since $FIRST_DATE):"
    echo "    Total growth: $(format_size $TOTAL_GROWTH)"
    echo "    Measurements recorded: $((HISTORY_LINES - 1))"
fi

# Size optimization recommendations
echo
echo "💡 Size Optimization Insights:"

# Check for optimization opportunities
if [[ $BACKUPS_SIZE -gt $((SCRIPTS_SIZE * 2)) ]]; then
    echo "  🧹 Backups are ${BACKUPS_SIZE}KB vs scripts ${SCRIPTS_SIZE}KB - consider cleanup"
fi

if [[ $AGGREGATED_SCRIPTS -gt $((NATIVE_SCRIPTS * 3)) ]]; then
    echo "  🔄 High aggregation ratio ($AGGREGATED_SCRIPTS:$NATIVE_SCRIPTS) - consider consolidation"
fi

# Largest files analysis
echo "  📋 Largest scripts:"
find "$SCRIPT_DIR" -name "*.sh" -type f -exec du -k {} + | sort -nr | head -5 | while read size file; do
    filename=$(basename "$file")
    echo "    $(format_size $size): $filename"
done

# Check for potential duplicates by size
echo "  🔍 Potential duplicates (same size):"
find "$SCRIPT_DIR" -name "*.sh" -type f -exec du -k {} + | sort -k1 | uniq -d -f0 | head -3 | while read size file; do
    if [[ -n "$file" ]]; then
        filename=$(basename "$file")
        echo "    $(format_size $size): $filename (check for duplicates)"
    fi
done

# Backup cleanup recommendations
if [[ -d "$ARCHIVE_MODEL_ROOT/data/script_backups" ]]; then
    OLD_BACKUPS=$(find "$ARCHIVE_MODEL_ROOT/data/script_backups" -type d -mtime +30 | wc -l)
    if [[ $OLD_BACKUPS -gt 0 ]]; then
        echo "  🗑️ $OLD_BACKUPS backups older than 30 days available for cleanup"
    fi
fi

echo
echo "🛠️ Recommended Actions:"
echo "  1. Run './scrub-scripts.sh' for detailed optimization analysis"
echo "  2. Use './restore-scripts.sh clean' to remove old backups"
echo "  3. Monitor growth trends with regular size monitoring"
echo "  4. Consider script consolidation if aggregation ratio is high"

# Generate summary report
REPORT_FILE="$MONITOR_DATA/size_report_$(date -u +%Y%m%d).md"
cat > "$REPORT_FILE" << EOF
# Archive Model Size Report - $(date -u +%Y-%m-%d)

## Current Metrics
- **Total Archive Size**: $(format_size $TOTAL_SIZE)
- **Scripts Collection**: $(format_size $SCRIPTS_SIZE) ($SCRIPTS_COUNT files)
- **Data Storage**: $(format_size $DATA_SIZE) ($DATA_COUNT files)
- **Backup Storage**: $(format_size $BACKUPS_SIZE) ($BACKUP_COUNT files)

## Script Breakdown
- **Shell Scripts**: $SHELL_SCRIPTS total
- **Constellation Scripts**: $AGGREGATED_SCRIPTS ($(echo "scale=1; $AGGREGATED_SCRIPTS*100/$SHELL_SCRIPTS" | bc 2>/dev/null || echo 0)%)
- **Native Scripts**: $NATIVE_SCRIPTS ($(echo "scale=1; $NATIVE_SCRIPTS*100/$SHELL_SCRIPTS" | bc 2>/dev/null || echo 0)%)
- **Documentation**: $MARKDOWN_DOCS files

## Storage Efficiency
EOF

if [[ $HISTORY_LINES -gt 2 ]]; then
    echo "- **Growth Rate**: $(format_size $SIZE_CHANGE) since last measurement" >> "$REPORT_FILE"
    echo "- **Historical Growth**: $(format_size $TOTAL_GROWTH) since tracking began" >> "$REPORT_FILE"
fi

cat >> "$REPORT_FILE" << EOF
- **Backup Ratio**: $(echo "scale=1; $BACKUPS_SIZE*100/$TOTAL_SIZE" | bc 2>/dev/null || echo 0)% of total size
- **Script Density**: $(echo "scale=1; $SCRIPTS_SIZE*100/$TOTAL_SIZE" | bc 2>/dev/null || echo 0)% of total size

## Recommendations
1. Regular monitoring maintains storage efficiency
2. Backup cleanup prevents excessive growth
3. Script consolidation optimizes knowledge density
4. Pattern analysis identifies optimization opportunities

*Generated by Archive Model Size Monitor*
EOF

echo "📄 Size report generated: $REPORT_FILE"
echo
echo "🫀 Archive size monitoring complete - The Archive's growth is being tracked and optimized!"