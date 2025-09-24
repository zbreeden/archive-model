#!/usr/bin/env bash
set -euo pipefail

# 🫀 Archive Model Script Constellation Aggregator
# Aggregates all scripts from constellation stars, deduplicates, and merges with archive-model scripts
# The Archive serves as the master repository of all constellation scripting knowledge

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE_MODEL_ROOT="$(dirname "$SCRIPT_DIR")"
CONSTELLATION_ROOT="$(dirname "$ARCHIVE_MODEL_ROOT")"

echo "🫀 Archive Model Script Constellation Aggregator"
echo "📜 The Archive will now collect all constellation scripting knowledge..."
echo

# Create temporary workspace
TEMP_DIR=$(mktemp -d)
AGGREGATION_DIR="$TEMP_DIR/aggregated_scripts"
CURRENT_SCRIPTS_DIR="$TEMP_DIR/current_scripts"
MERGED_SCRIPTS_DIR="$TEMP_DIR/merged_scripts"

# Ensure cleanup on exit
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

mkdir -p "$AGGREGATION_DIR" "$CURRENT_SCRIPTS_DIR" "$MERGED_SCRIPTS_DIR"

# Function to get file hash for deduplication
get_file_hash() {
    local file="$1"
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | cut -d' ' -f1
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | cut -d' ' -f1
    else
        # Fallback to basic checksum
        cksum "$file" | cut -d' ' -f1
    fi
}

# Function to check if directory is a star module
is_star_module() {
    local dir="$1"
    local repo_name
    repo_name=$(basename "$dir")
    
    # Check if it ends with -model and has scripts directory
    if [[ "$repo_name" == *-model ]] && [[ -d "$dir/scripts" ]]; then
        return 0
    fi
    return 1
}

# Function to copy script with metadata
copy_script_with_metadata() {
    local source_file="$1"
    local dest_dir="$2"
    local source_module="$3"
    local filename
    filename=$(basename "$source_file")
    
    # Create destination file with module prefix if there might be conflicts
    local dest_file="$dest_dir/$filename"
    
    # If file already exists, create module-prefixed version
    if [[ -f "$dest_file" ]]; then
        local base_name="${filename%.*}"
        local extension="${filename##*.}"
        if [[ "$base_name" == "$filename" ]]; then
            # No extension
            dest_file="$dest_dir/${source_module}-${filename}"
        else
            dest_file="$dest_dir/${base_name}-${source_module}.${extension}"
        fi
    fi
    
    # Copy file and add metadata header for tracking
    {
        echo "# Source: $source_module/scripts/$filename"
        echo "# Collected by Archive Model Script Aggregator"
        echo "# Original path: $source_file"
        echo ""
        cat "$source_file"
    } > "$dest_file"
    
    echo "  📄 Copied: $filename → $(basename "$dest_file")"
}

# Phase 1: Aggregate scripts from all constellation stars
echo "🔍 Phase 1: Discovering and aggregating constellation scripts..."
echo

STARS_PROCESSED=0
SCRIPTS_COLLECTED=0

# Scan constellation root for star modules
for star_dir in "$CONSTELLATION_ROOT"/*-model; do
    if [[ ! -d "$star_dir" ]]; then
        continue
    fi
    
    repo_name=$(basename "$star_dir")
    scripts_dir="$star_dir/scripts"
    
    # Skip archive-model (ourselves)
    if [[ "$repo_name" == "archive-model" ]]; then
        continue
    fi
    
    if [[ -d "$scripts_dir" ]]; then
        echo "⭐ Processing star: $repo_name"
        STARS_PROCESSED=$((STARS_PROCESSED + 1))
        
        # Find all files in scripts directory (excluding hidden files)
        while IFS= read -r -d '' script_file; do
            if [[ -f "$script_file" ]] && [[ $(basename "$script_file") != .* ]]; then
                copy_script_with_metadata "$script_file" "$AGGREGATION_DIR" "$repo_name"
                SCRIPTS_COLLECTED=$((SCRIPTS_COLLECTED + 1))
            fi
        done < <(find "$scripts_dir" -maxdepth 1 -type f -print0)
        echo
    else
        echo "⚪ Star $repo_name has no scripts directory"
    fi
done

echo "📊 Aggregation complete: $SCRIPTS_COLLECTED scripts from $STARS_PROCESSED stars"
echo

# Phase 2: Copy current archive-model scripts
echo "🗃️ Phase 2: Preserving current archive-model scripts..."
echo

CURRENT_SCRIPTS=0
for script_file in "$SCRIPT_DIR"/*; do
    if [[ -f "$script_file" ]] && [[ $(basename "$script_file") != .* ]]; then
        filename=$(basename "$script_file")
        # Skip this aggregation script itself
        if [[ "$filename" != "aggregate-scripts.sh" ]]; then
            cp "$script_file" "$CURRENT_SCRIPTS_DIR/"
            echo "  📄 Preserved: $filename"
            CURRENT_SCRIPTS=$((CURRENT_SCRIPTS + 1))
        fi
    fi
done

echo "📊 Preserved: $CURRENT_SCRIPTS existing archive scripts"
echo

# Phase 3: Deduplication and merging
echo "🔄 Phase 3: Deduplication and intelligent merging..."
echo

declare -A file_hashes
declare -A file_sources
UNIQUE_FILES=0
DUPLICATES_FOUND=0

# Function to process files for deduplication
process_file_for_dedup() {
    local source_dir="$1"
    local file="$2"
    local source_label="$3"
    
    if [[ -f "$source_dir/$file" ]]; then
        local hash
        hash=$(get_file_hash "$source_dir/$file")
        
        if [[ -n "${file_hashes[$file]:-}" ]]; then
            # File exists, check if content is different
            if [[ "${file_hashes[$file]}" != "$hash" ]]; then
                echo "  🔀 Content difference found: $file"
                echo "    Sources: ${file_sources[$file]} vs $source_label"
                
                # Create merged version with both sources
                local base_name="${file%.*}"
                local extension="${file##*.}"
                if [[ "$base_name" == "$file" ]]; then
                    # No extension
                    local merged_file="${file}-merged"
                else
                    local merged_file="${base_name}-merged.${extension}"
                fi
                
                {
                    echo "# MERGED FILE: Multiple sources detected"
                    echo "# Sources: ${file_sources[$file]} + $source_label"
                    echo "# Merged by Archive Model Script Aggregator"
                    echo ""
                    echo "# === SOURCE 1: ${file_sources[$file]} ==="
                    cat "$MERGED_SCRIPTS_DIR/$file"
                    echo ""
                    echo "# === SOURCE 2: $source_label ==="
                    cat "$source_dir/$file"
                } > "$MERGED_SCRIPTS_DIR/$merged_file"
                
                echo "    📝 Created merged version: $merged_file"
            else
                echo "  ✓ Duplicate (same content): $file from $source_label"
                DUPLICATES_FOUND=$((DUPLICATES_FOUND + 1))
            fi
        else
            # New unique file
            cp "$source_dir/$file" "$MERGED_SCRIPTS_DIR/"
            file_hashes[$file]="$hash"
            file_sources[$file]="$source_label"
            echo "  ✓ Unique file: $file from $source_label"
            UNIQUE_FILES=$((UNIQUE_FILES + 1))
        fi
    fi
}

# Process current archive scripts first (priority)
for file in "$CURRENT_SCRIPTS_DIR"/*; do
    if [[ -f "$file" ]]; then
        filename=$(basename "$file")
        process_file_for_dedup "$CURRENT_SCRIPTS_DIR" "$filename" "archive-model (current)"
    fi
done

# Process aggregated constellation scripts
for file in "$AGGREGATION_DIR"/*; do
    if [[ -f "$file" ]]; then
        filename=$(basename "$file")
        process_file_for_dedup "$AGGREGATION_DIR" "$filename" "constellation"
    fi
done

echo
echo "📊 Deduplication complete: $UNIQUE_FILES unique files, $DUPLICATES_FOUND duplicates found"
echo

# Phase 4: Create backup and replace scripts directory
echo "💾 Phase 4: Backup and deployment..."
echo

# Create timestamped backup
BACKUP_DIR="$ARCHIVE_MODEL_ROOT/data/script_backups/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$BACKUP_DIR"

if [[ -d "$SCRIPT_DIR" ]]; then
    cp -r "$SCRIPT_DIR"/* "$BACKUP_DIR/" 2>/dev/null || true
    echo "💾 Backup created: data/script_backups/$(basename "$BACKUP_DIR")"
fi

# Replace scripts directory contents (except this script)
echo "🔄 Deploying aggregated scripts..."

# Remove old scripts (except the aggregator itself and markdowns)
for file in "$SCRIPT_DIR"/*; do
    if [[ -f "$file" ]]; then
        filename=$(basename "$file")
        if [[ "$filename" != "aggregate-scripts.sh" ]] && [[ "$filename" != *.md ]]; then
            rm "$file"
            echo "  🗑️ Removed old: $filename"
        fi
    fi
done

# Copy merged scripts
DEPLOYED_FILES=0
for file in "$MERGED_SCRIPTS_DIR"/*; do
    if [[ -f "$file" ]]; then
        filename=$(basename "$file")
        cp "$file" "$SCRIPT_DIR/"
        echo "  📦 Deployed: $filename"
        DEPLOYED_FILES=$((DEPLOYED_FILES + 1))
        
        # Make executable if it's a shell script
        if [[ "$filename" == *.sh ]]; then
            chmod +x "$SCRIPT_DIR/$filename"
        fi
    fi
done

echo
echo "✅ Script aggregation complete!"
echo "📊 Final statistics:"
echo "  🌟 Stars processed: $STARS_PROCESSED"
echo "  📄 Scripts collected: $SCRIPTS_COLLECTED"
echo "  🔄 Scripts deployed: $DEPLOYED_FILES"
echo "  💾 Backup location: data/script_backups/$(basename "$BACKUP_DIR")"
echo
echo "🫀 The Archive has successfully collected and preserved all constellation scripting knowledge!"

# Update archive-model's latest.json with aggregation info
AGGREGATION_SIGNAL=$(cat <<EOF
{
  "id": "$(date -u +%Y%m%dT%H%M%SZ)-archive-model-script_aggregation",
  "ts_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "date": "$(date -u +%Y-%m-%d)",
  "module": "Archive Model", 
  "repo": "archive-model",
  "title": "Constellation Script Aggregation Complete",
  "summary": "The Archive has collected and deduplicated $DEPLOYED_FILES scripts from $STARS_PROCESSED constellation stars",
  "rating": "normal",
  "origin": {
    "name": "Archive Model Script Aggregator",
    "url": "https://zbreeden.github.io/archive-model/",
    "emoji": "🫀"
  },
  "links": {
    "readme": "https://github.com/zbreeden/archive-model#readme",
    "page": "https://zbreeden.github.io/archive-model/"
  },
  "payload": {
    "module_key": "archive_model",
    "broadcast_key": "script_aggregation",
    "aggregation_stats": {
      "stars_processed": $STARS_PROCESSED,
      "scripts_collected": $SCRIPTS_COLLECTED,
      "scripts_deployed": $DEPLOYED_FILES,
      "duplicates_found": $DUPLICATES_FOUND,
      "backup_location": "data/script_backups/$(basename "$BACKUP_DIR")"
    }
  }
}
EOF
)

echo "$AGGREGATION_SIGNAL" > "$ARCHIVE_MODEL_ROOT/signals/latest.json"
echo "📡 Updated archive-model signal broadcast"