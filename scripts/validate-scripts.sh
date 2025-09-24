#!/usr/bin/env bash
set -euo pipefail

# 🔍 Archive Model Script Collection Validator
# Validates the aggregated script collection and reports on constellation coverage

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE_MODEL_ROOT="$(dirname "$SCRIPT_DIR")"
CONSTELLATION_ROOT="$(dirname "$ARCHIVE_MODEL_ROOT")"

echo "🔍 Archive Model Script Collection Validator"
echo "📜 Analyzing the Archive's constellation script coverage..."
echo

# Function to analyze script file
analyze_script() {
    local file="$1"
    local filename
    filename=$(basename "$file")
    
    echo "📄 Analyzing: $filename"
    
    # Check if it's executable
    if [[ -x "$file" ]]; then
        echo "  ✓ Executable"
    else
        echo "  ⚠️ Not executable"
    fi
    
    # Check for source metadata (added by aggregator)
    if grep -q "# Source:" "$file" 2>/dev/null; then
        local source
        source=$(grep "# Source:" "$file" | head -1 | sed 's/# Source: //')
        echo "  📍 Source: $source"
    else
        echo "  🏠 Native archive script"
    fi
    
    # Check file size
    local size
    if command -v stat >/dev/null 2>&1; then
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        echo "  📏 Size: ${size} bytes"
    fi
    
    # Check for shebang
    if [[ "$filename" == *.sh ]] && head -1 "$file" | grep -q "^#!"; then
        echo "  ✓ Has shebang"
    elif [[ "$filename" == *.sh ]]; then
        echo "  ⚠️ Missing shebang"
    fi
    
    echo
}

# Count and analyze current scripts
echo "📊 Current Archive Script Collection:"
echo

TOTAL_SCRIPTS=0
EXECUTABLE_SCRIPTS=0
SOURCED_SCRIPTS=0
NATIVE_SCRIPTS=0
MARKDOWN_FILES=0

for file in "$SCRIPT_DIR"/*; do
    if [[ -f "$file" ]]; then
        filename=$(basename "$file")
        
        # Skip this validator script itself
        if [[ "$filename" == "validate-scripts.sh" ]]; then
            continue
        fi
        
        if [[ "$filename" == *.md ]]; then
            MARKDOWN_FILES=$((MARKDOWN_FILES + 1))
            echo "📝 Documentation: $filename"
        else
            TOTAL_SCRIPTS=$((TOTAL_SCRIPTS + 1))
            
            if [[ -x "$file" ]]; then
                EXECUTABLE_SCRIPTS=$((EXECUTABLE_SCRIPTS + 1))
            fi
            
            if grep -q "# Source:" "$file" 2>/dev/null; then
                SOURCED_SCRIPTS=$((SOURCED_SCRIPTS + 1))
            else
                NATIVE_SCRIPTS=$((NATIVE_SCRIPTS + 1))
            fi
            
            analyze_script "$file"
        fi
    fi
done

# Check constellation coverage
echo "🌌 Constellation Coverage Analysis:"
echo

TOTAL_STARS=0
STARS_WITH_SCRIPTS=0
declare -A star_script_counts

for star_dir in "$CONSTELLATION_ROOT"/*-model; do
    if [[ ! -d "$star_dir" ]]; then
        continue
    fi
    
    repo_name=$(basename "$star_dir")
    TOTAL_STARS=$((TOTAL_STARS + 1))
    
    if [[ -d "$star_dir/scripts" ]]; then
        STARS_WITH_SCRIPTS=$((STARS_WITH_SCRIPTS + 1))
        
        # Count scripts in this star
        script_count=0
        while IFS= read -r -d '' script_file; do
            if [[ -f "$script_file" ]] && [[ $(basename "$script_file") != .* ]]; then
                script_count=$((script_count + 1))
            fi
        done < <(find "$star_dir/scripts" -maxdepth 1 -type f -print0)
        
        star_script_counts[$repo_name]=$script_count
        echo "⭐ $repo_name: $script_count scripts"
    else
        echo "⚪ $repo_name: no scripts directory"
    fi
done

echo

# Check for potential missing aggregations
echo "🔍 Aggregation Coverage Check:"
echo

MISSING_AGGREGATIONS=0
for star in "${!star_script_counts[@]}"; do
    if [[ "$star" == "archive-model" ]]; then
        continue
    fi
    
    # Check if we have any scripts from this star in our collection
    if ! grep -r "# Source: $star/" "$SCRIPT_DIR" >/dev/null 2>&1; then
        echo "⚠️ No scripts found from: $star (has ${star_script_counts[$star]} scripts)"
        MISSING_AGGREGATIONS=$((MISSING_AGGREGATIONS + 1))
    else
        echo "✓ Scripts present from: $star"
    fi
done

echo

# Summary report
echo "📈 Archive Script Collection Summary:"
echo "  📄 Total scripts in archive: $TOTAL_SCRIPTS"
echo "  ✅ Executable scripts: $EXECUTABLE_SCRIPTS"
echo "  🌟 Scripts from constellation: $SOURCED_SCRIPTS"
echo "  🏠 Native archive scripts: $NATIVE_SCRIPTS"
echo "  📝 Documentation files: $MARKDOWN_FILES"
echo
echo "🌌 Constellation Coverage:"
echo "  ⭐ Total stars: $TOTAL_STARS"
echo "  📜 Stars with scripts: $STARS_WITH_SCRIPTS"
echo "  ⚠️ Stars missing from aggregation: $MISSING_AGGREGATIONS"

# Check for recent backups
echo
echo "💾 Recent Script Backups:"
if [[ -d "$ARCHIVE_MODEL_ROOT/data/script_backups" ]]; then
    backup_count=$(find "$ARCHIVE_MODEL_ROOT/data/script_backups" -maxdepth 1 -type d | wc -l)
    backup_count=$((backup_count - 1)) # Exclude the parent directory
    echo "  📁 Total backups available: $backup_count"
    
    if [[ $backup_count -gt 0 ]]; then
        echo "  🕒 Most recent backups:"
        ls -1t "$ARCHIVE_MODEL_ROOT/data/script_backups" | head -3 | while read -r backup; do
            echo "    💾 $backup"
        done
    fi
else
    echo "  ⚪ No backup directory found"
fi

echo
if [[ $MISSING_AGGREGATIONS -eq 0 ]] && [[ $EXECUTABLE_SCRIPTS -eq $TOTAL_SCRIPTS ]]; then
    echo "🎉 Archive script collection is complete and healthy!"
    exit 0
else
    echo "⚠️ Archive script collection needs attention"
    if [[ $MISSING_AGGREGATIONS -gt 0 ]]; then
        echo "   Run ./aggregate-scripts.sh to update constellation coverage"
    fi
    exit 1
fi