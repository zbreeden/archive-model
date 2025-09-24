#!/usr/bin/env bash
set -euo pipefail

# 🧹 Archive Model Script Scrubber
# Manual workflow to analyze, normalize, and optimize the archive script collection
# Designed to protect The Archive's size while maintaining all essential knowledge

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE_MODEL_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🧹 Archive Model Script Scrubber"
echo "🫀 Analyzing and optimizing The Archive's script collection..."
echo "📊 Protecting storage while preserving all essential knowledge"
echo

# Create temporary analysis workspace
TEMP_DIR=$(mktemp -d)
ANALYSIS_DIR="$TEMP_DIR/analysis"
OPTIMIZATION_DIR="$TEMP_DIR/optimized"

# Cleanup on exit
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

mkdir -p "$ANALYSIS_DIR" "$OPTIMIZATION_DIR"

# Function to get file size in bytes
get_file_size() {
    local file="$1"
    if command -v stat >/dev/null 2>&1; then
        stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null
    else
        wc -c < "$file"
    fi
}

# Function to get file hash for duplicate detection
get_file_hash() {
    local file="$1"
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | cut -d' ' -f1
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | cut -d' ' -f1
    else
        cksum "$file" | cut -d' ' -f1
    fi
}

# Function to analyze script content patterns
analyze_script_patterns() {
    local file="$1"
    local filename=$(basename "$file")
    
    # Count lines and estimate optimization potential
    local total_lines=$(wc -l < "$file")
    local comment_lines=$(grep -c "^#" "$file" 2>/dev/null || echo 0)
    local blank_lines=$(grep -c "^[[:space:]]*$" "$file" 2>/dev/null || echo 0)
    local code_lines=$((total_lines - comment_lines - blank_lines))
    
    # Check for redundant content patterns
    local has_metadata_header=0
    local has_shebang=0
    local has_set_options=0
    local redundant_comments=0
    
    if head -5 "$file" | grep -q "^# Source:"; then
        has_metadata_header=1
    fi
    
    if head -1 "$file" | grep -q "^#!"; then
        has_shebang=1
    fi
    
    if grep -q "set -euo pipefail" "$file" 2>/dev/null; then
        has_set_options=1
    fi
    
    # Count potentially redundant comment blocks
    redundant_comments=$(grep -c "^# ──\|^# ==\|^#.*─" "$file" 2>/dev/null || echo 0)
    
    echo "$filename,$total_lines,$comment_lines,$blank_lines,$code_lines,$has_metadata_header,$has_shebang,$has_set_options,$redundant_comments"
}

# Function to identify duplicate content blocks
find_duplicate_blocks() {
    local file1="$1"
    local file2="$2"
    
    # Create temporary files without metadata headers
    local temp1="$TEMP_DIR/$(basename "$file1").clean"
    local temp2="$TEMP_DIR/$(basename "$file2").clean"
    
    # Remove metadata headers and normalize spacing
    sed '/^# Source:/,/^$/d' "$file1" | sed '/^[[:space:]]*$/N;/\n[[:space:]]*$/d' > "$temp1"
    sed '/^# Source:/,/^$/d' "$file2" | sed '/^[[:space:]]*$/N;/\n[[:space:]]*$/d' > "$temp2"
    
    # Check similarity (simple approach)
    local size1=$(get_file_size "$temp1")
    local size2=$(get_file_size "$temp2")
    
    if [[ $size1 -eq $size2 ]]; then
        if diff -q "$temp1" "$temp2" >/dev/null 2>&1; then
            echo "IDENTICAL"
        else
            echo "SIMILAR_SIZE"
        fi
    else
        echo "DIFFERENT"
    fi
}

# Phase 1: Analysis and Discovery
echo "🔍 Phase 1: Analyzing script collection patterns..."
echo

declare -A file_sizes
declare -A file_hashes
declare -A duplicate_groups
declare -a all_scripts

TOTAL_SIZE=0
SCRIPT_COUNT=0
DUPLICATE_COUNT=0
OPTIMIZATION_POTENTIAL=0

echo "filename,total_lines,comment_lines,blank_lines,code_lines,has_metadata,has_shebang,has_set_options,redundant_comments" > "$ANALYSIS_DIR/script_analysis.csv"

# Analyze all scripts
for script_file in "$SCRIPT_DIR"/*.sh; do
    if [[ -f "$script_file" ]]; then
        filename=$(basename "$script_file")
        
        # Skip the scrubber itself and core utilities
        if [[ "$filename" == "scrub-scripts.sh" ]] || [[ "$filename" == "aggregate-scripts.sh" ]] || [[ "$filename" == "validate-scripts.sh" ]] || [[ "$filename" == "restore-scripts.sh" ]]; then
            continue
        fi
        
        all_scripts+=("$script_file")
        
        size=$(get_file_size "$script_file")
        hash=$(get_file_hash "$script_file")
        
        file_sizes["$filename"]=$size
        file_hashes["$filename"]=$hash
        
        TOTAL_SIZE=$((TOTAL_SIZE + size))
        SCRIPT_COUNT=$((SCRIPT_COUNT + 1))
        
        # Analyze patterns
        analyze_script_patterns "$script_file" >> "$ANALYSIS_DIR/script_analysis.csv"
        
        echo "  📄 Analyzed: $filename (${size} bytes)"
    fi
done

echo
echo "📊 Collection Overview:"
echo "  📁 Total scripts analyzed: $SCRIPT_COUNT"
echo "  💾 Total size: $TOTAL_SIZE bytes ($(echo "scale=2; $TOTAL_SIZE/1024" | bc 2>/dev/null || echo $((TOTAL_SIZE/1024))) KB)"

# Phase 2: Duplicate Detection
echo
echo "🔍 Phase 2: Detecting duplicates and similarities..."
echo

declare -A hash_groups
for filename in "${!file_hashes[@]}"; do
    hash="${file_hashes[$filename]}"
    if [[ -n "${hash_groups[$hash]:-}" ]]; then
        hash_groups[$hash]="${hash_groups[$hash]} $filename"
        DUPLICATE_COUNT=$((DUPLICATE_COUNT + 1))
    else
        hash_groups[$hash]="$filename"
    fi
done

echo "Hash-based duplicates found:" > "$ANALYSIS_DIR/duplicates.txt"
for hash in "${!hash_groups[@]}"; do
    files="${hash_groups[$hash]}"
    file_count=$(echo $files | wc -w)
    if [[ $file_count -gt 1 ]]; then
        echo "  🔄 Duplicate group: $files" | tee -a "$ANALYSIS_DIR/duplicates.txt"
        
        # Calculate space savings
        first_file=$(echo $files | cut -d' ' -f1)
        duplicate_size=${file_sizes[$first_file]}
        savings=$(((file_count - 1) * duplicate_size))
        OPTIMIZATION_POTENTIAL=$((OPTIMIZATION_POTENTIAL + savings))
    fi
done

# Phase 3: Content Pattern Analysis  
echo
echo "🔍 Phase 3: Analyzing content patterns for optimization..."
echo

# Group similar files by naming patterns
declare -A pattern_groups
for script_file in "${all_scripts[@]}"; do
    filename=$(basename "$script_file")
    
    # Extract base patterns
    if [[ "$filename" =~ ^(.+)-(accountant|anchor|bank|catalyst|coach|developer|evaluator|firm|gambler|grower|launch|mirror|orbiter|player|protector|signal|story|trainer|visualizer)-model\.sh$ ]]; then
        base_pattern="${BASH_REMATCH[1]}"
        star_name="${BASH_REMATCH[2]}-model"
        
        if [[ -z "${pattern_groups[$base_pattern]:-}" ]]; then
            pattern_groups[$base_pattern]="$filename"
        else
            pattern_groups[$base_pattern]="${pattern_groups[$base_pattern]} $filename"
        fi
    elif [[ "$filename" =~ ^(.+)-merged\.sh$ ]]; then
        pattern_groups["merged"]="${pattern_groups["merged"]:-} $filename"
    fi
done

echo "Pattern groups found:" | tee "$ANALYSIS_DIR/patterns.txt"
for pattern in "${!pattern_groups[@]}"; do
    files="${pattern_groups[$pattern]}"
    file_count=$(echo $files | wc -w)
    if [[ $file_count -gt 1 ]]; then
        echo "  📋 Pattern '$pattern': $file_count files" | tee -a "$ANALYSIS_DIR/patterns.txt"
        echo "    Files: $files" | tee -a "$ANALYSIS_DIR/patterns.txt"
        
        # Analyze first few for similarities
        first_file=$(echo $files | cut -d' ' -f1)
        second_file=$(echo $files | cut -d' ' -f2)
        if [[ -n "$second_file" ]] && [[ -f "$SCRIPT_DIR/$first_file" ]] && [[ -f "$SCRIPT_DIR/$second_file" ]]; then
            similarity=$(find_duplicate_blocks "$SCRIPT_DIR/$first_file" "$SCRIPT_DIR/$second_file")
            echo "    Similarity: $similarity" | tee -a "$ANALYSIS_DIR/patterns.txt"
        fi
    fi
done

# Phase 4: Optimization Recommendations
echo
echo "💡 Phase 4: Generating optimization recommendations..."
echo

cat > "$ANALYSIS_DIR/optimization_report.md" << EOF
# 🧹 Archive Script Collection Optimization Report

## 📊 Current State
- **Total Scripts**: $SCRIPT_COUNT files
- **Total Size**: $TOTAL_SIZE bytes ($(echo "scale=2; $TOTAL_SIZE/1024" | bc 2>/dev/null || echo $((TOTAL_SIZE/1024))) KB)
- **Exact Duplicates**: $DUPLICATE_COUNT files
- **Potential Savings**: $OPTIMIZATION_POTENTIAL bytes

## 🔍 Optimization Opportunities

### 1. Exact Duplicate Removal
EOF

if [[ $DUPLICATE_COUNT -gt 0 ]]; then
    echo "Remove exact duplicates while preserving source attribution:" >> "$ANALYSIS_DIR/optimization_report.md"
    cat "$ANALYSIS_DIR/duplicates.txt" >> "$ANALYSIS_DIR/optimization_report.md"
else
    echo "✅ No exact duplicates found" >> "$ANALYSIS_DIR/optimization_report.md"
fi

cat >> "$ANALYSIS_DIR/optimization_report.md" << EOF

### 2. Pattern-Based Consolidation
Consider consolidating similar scripts by pattern:
EOF

cat "$ANALYSIS_DIR/patterns.txt" >> "$ANALYSIS_DIR/optimization_report.md"

cat >> "$ANALYSIS_DIR/optimization_report.md" << EOF

### 3. Content Optimization Suggestions

#### High-Impact Optimizations:
- **Remove redundant metadata**: Some files have excessive source attribution headers
- **Consolidate merged files**: Review merged scripts for essential vs redundant content
- **Normalize formatting**: Standardize spacing and comment styles
- **Archive old versions**: Move superseded scripts to backup directory

#### Pattern Consolidation Strategies:
1. **Star-specific variants**: Consider parameterized scripts instead of per-star copies
2. **Common functionality**: Extract shared functions into library scripts
3. **Template-based generation**: Use templates for repetitive script patterns

#### Recommended Actions:
1. ✅ Keep all unique functionality (preserve knowledge)
2. 🔄 Consolidate exact duplicates (remove redundancy) 
3. 📝 Standardize metadata headers (consistent format)
4. 🗂️ Group related scripts (better organization)
5. 📋 Create consolidated templates (reduce repetition)

## 🛡️ Safety Recommendations:
- Always backup before optimization
- Preserve source attribution in consolidated files
- Maintain functionality testing after changes
- Document consolidation decisions for future reference

EOF

echo "📋 Optimization report generated: $ANALYSIS_DIR/optimization_report.md"

# Phase 5: Interactive Cleanup Options
echo
echo "🛠️ Phase 5: Interactive cleanup options..."
echo

echo "Available optimization actions:"
echo "1. 🗑️  Remove exact duplicates (safe)"
echo "2. 📝 Standardize metadata headers"  
echo "3. 🧹 Clean up whitespace and formatting"
echo "4. 📊 Generate detailed analysis report"
echo "5. 💾 Create optimization backup"
echo "6. ❌ Exit without changes"
echo

read -rp "Select action (1-6): " action

case $action in
    1)
        echo "🗑️ Removing exact duplicates..."
        removed_count=0
        for hash in "${!hash_groups[@]}"; do
            files="${hash_groups[$hash]}"
            file_count=$(echo $files | wc -w)
            if [[ $file_count -gt 1 ]]; then
                # Keep first file, remove others
                files_array=($files)
                keeper="${files_array[0]}"
                echo "  ✅ Keeping: $keeper"
                
                for ((i=1; i<${#files_array[@]}; i++)); do
                    duplicate="${files_array[i]}"
                    echo "  🗑️ Removing duplicate: $duplicate"
                    rm "$SCRIPT_DIR/$duplicate"
                    removed_count=$((removed_count + 1))
                done
            fi
        done
        echo "✅ Removed $removed_count duplicate files"
        ;;
    2)
        echo "📝 Standardizing metadata headers..."
        standardized_count=0
        for script_file in "${all_scripts[@]}"; do
            if [[ -f "$script_file" ]]; then
                filename=$(basename "$script_file")
                
                # Check if it has metadata header
                if grep -q "^# Source:" "$script_file"; then
                    # Standardize the header format
                    temp_file="$TEMP_DIR/$(basename "$script_file").temp"
                    
                    # Extract source info and normalize
                    source_line=$(grep "^# Source:" "$script_file" | head -1)
                    
                    # Create standardized header
                    {
                        echo "# Archive Collection: $(basename "$script_file")"
                        echo "$source_line"
                        echo "# Collected by Archive Model Script Aggregator"
                        echo ""
                        # Skip old header and output rest
                        sed '1,/^# Original path:/d' "$script_file" | sed '1,/^$/d'
                    } > "$temp_file"
                    
                    mv "$temp_file" "$script_file"
                    standardized_count=$((standardized_count + 1))
                    echo "  📝 Standardized: $filename"
                fi
            fi
        done
        echo "✅ Standardized $standardized_count files"
        ;;
    3)
        echo "🧹 Cleaning whitespace and formatting..."
        cleaned_count=0
        for script_file in "${all_scripts[@]}"; do
            if [[ -f "$script_file" ]]; then
                filename=$(basename "$script_file")
                temp_file="$TEMP_DIR/$(basename "$script_file").temp"
                
                # Clean up formatting
                sed -e 's/[[:space:]]*$//' \
                    -e '/^[[:space:]]*$/N;/\n[[:space:]]*$/s/\n[[:space:]]*$/\n/' \
                    "$script_file" > "$temp_file"
                
                # Only update if changed
                if ! diff -q "$script_file" "$temp_file" >/dev/null 2>&1; then
                    mv "$temp_file" "$script_file"
                    cleaned_count=$((cleaned_count + 1))
                    echo "  🧹 Cleaned: $filename"
                else
                    rm "$temp_file"
                fi
            fi
        done
        echo "✅ Cleaned $cleaned_count files"
        ;;
    4)
        echo "📊 Copying analysis report to archive..."
        cp "$ANALYSIS_DIR/optimization_report.md" "$SCRIPT_DIR/"
        cp "$ANALYSIS_DIR/script_analysis.csv" "$ARCHIVE_MODEL_ROOT/data/"
        cp "$ANALYSIS_DIR/duplicates.txt" "$ARCHIVE_MODEL_ROOT/data/"
        cp "$ANALYSIS_DIR/patterns.txt" "$ARCHIVE_MODEL_ROOT/data/"
        echo "✅ Analysis files copied to scripts/ and data/ directories"
        ;;
    5)
        echo "💾 Creating optimization backup..."
        backup_dir="$ARCHIVE_MODEL_ROOT/data/script_backups/$(date -u +%Y%m%dT%H%M%SZ)-pre-scrub"
        mkdir -p "$backup_dir"
        cp -r "$SCRIPT_DIR"/* "$backup_dir/" 2>/dev/null || true
        echo "✅ Backup created: data/script_backups/$(basename "$backup_dir")"
        ;;
    *)
        echo "❌ Exiting without changes"
        ;;
esac

# Update signal if changes were made
if [[ $action =~ ^[1-3]$ ]]; then
    scrub_signal=$(cat <<EOF
{
  "id": "$(date -u +%Y%m%dT%H%M%SZ)-archive-model-script_scrub",
  "ts_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "date": "$(date -u +%Y-%m-%d)",
  "module": "Archive Model",
  "repo": "archive-model", 
  "title": "Script Collection Optimization Complete",
  "summary": "The Archive has optimized its script collection - analyzed $SCRIPT_COUNT scripts totaling $TOTAL_SIZE bytes",
  "rating": "normal",
  "origin": {
    "name": "Archive Model Script Scrubber",
    "url": "https://zbreeden.github.io/archive-model/",
    "emoji": "🫀"
  },
  "links": {
    "readme": "https://github.com/zbreeden/archive-model#readme", 
    "page": "https://zbreeden.github.io/archive-model/"
  },
  "payload": {
    "module_key": "archive_model",
    "broadcast_key": "script_scrub",
    "scrub_stats": {
      "scripts_analyzed": $SCRIPT_COUNT,
      "total_size_bytes": $TOTAL_SIZE,
      "duplicates_found": $DUPLICATE_COUNT,
      "optimization_action": $action,
      "potential_savings": $OPTIMIZATION_POTENTIAL
    }
  }
}
EOF
)
    
    echo "$scrub_signal" > "$ARCHIVE_MODEL_ROOT/signals/latest.json"
    echo "📡 Updated archive-model signal broadcast"
fi

echo
echo "🧹 Script scrubbing workflow complete!"
echo "📊 Analyzed $SCRIPT_COUNT scripts totaling $TOTAL_SIZE bytes"
echo "🫀 The Archive's knowledge remains preserved while optimizing storage"