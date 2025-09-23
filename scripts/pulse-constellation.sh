#!/usr/bin/env bash
set -euo pipefail

# Archive Model - Constellation Status Pulse
# Automated workflow that checks the status of all stars in the constellation
# and updates The Archive's modules.yml with current status information

echo "🫀 Archive Model - Constellation Status Pulse"
echo "================================================"
echo "Scanning constellation for star status updates..."
echo

ARCHIVE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HUB_DIR="$(cd "$ARCHIVE_DIR/.." && pwd)"
MODULES_FILE="$ARCHIVE_DIR/seeds/modules.yml"
TEMP_FILE="$(mktemp)"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Backup current modules.yml
cp "$MODULES_FILE" "$MODULES_FILE.backup.$TIMESTAMP"
echo "📦 Backup created: modules.yml.backup.$TIMESTAMP"

# Function to get status from a star's modules.yml
get_star_status() {
    local star_dir="$1"
    local module_id="$2"
    
    if [ -f "$star_dir/seeds/modules.yml" ]; then
        # Extract status using awk
        awk -v id="$module_id" '
        BEGIN { found=0; in_module=0 }
        /^- id: / { 
            if ($3 == id) { found=1; in_module=1 } 
            else { in_module=0 }
        }
        in_module && /^  status: / { 
            gsub(/^  status: /, "")
            print
            exit
        }
        ' "$star_dir/seeds/modules.yml"
    fi
}

# Function to update status in Archive's modules.yml
update_archive_status() {
    local module_id="$1"
    local new_status="$2"
    
    if [ -n "$new_status" ]; then
        # Use sed to update the status for the specific module
        awk -v id="$module_id" -v status="$new_status" '
        BEGIN { in_module=0 }
        /^- id: / { 
            if ($3 == id) { in_module=1 } 
            else { in_module=0 }
        }
        in_module && /^  status: / { 
            print "  status: " status
            next
        }
        { print }
        ' "$MODULES_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$MODULES_FILE"
        
        echo "  ✅ Updated $module_id: $new_status"
    fi
}

echo "🔍 Scanning constellation stars..."
stars_scanned=0
stars_updated=0

# Read module IDs from Archive's modules.yml and check their status
while IFS= read -r line; do
    if [[ $line =~ ^-[[:space:]]+id:[[:space:]]+(.+)$ ]]; then
        module_id="${BASH_REMATCH[1]}"
        
        # Skip the hub itself
        if [ "$module_id" = "fourtwenty_analytics" ]; then
            continue
        fi
        
        # Convert module_id to directory name (snake_case to kebab-case)
        star_dir_name=$(echo "$module_id" | sed 's/_/-/g')
        star_path="$HUB_DIR/$star_dir_name"
        
        if [ -d "$star_path" ]; then
            echo "📡 Pulsing $module_id ($star_dir_name)..."
            current_status=$(get_star_status "$star_path" "$module_id")
            
            if [ -n "$current_status" ]; then
                echo "  📊 Current status: $current_status"
                update_archive_status "$module_id" "$current_status"
                stars_updated=$((stars_updated + 1))
            else
                echo "  ⚠️  Status not found in $star_path/seeds/modules.yml"
            fi
            
            stars_scanned=$((stars_scanned + 1))
        else
            echo "  ⚠️  Star directory not found: $star_path"
        fi
    fi
done < "$MODULES_FILE"

echo
echo "📈 Pulse Summary:"
echo "  • Stars scanned: $stars_scanned"
echo "  • Status updates: $stars_updated"
echo "  • Timestamp: $TIMESTAMP"

# Generate a pulse broadcast signal
echo
echo "📡 Generating pulse broadcast signal..."

# Archive existing latest.json if it exists
SIGNALS_FILE="$ARCHIVE_DIR/signals/latest.json"
ARCHIVE_FILE="$ARCHIVE_DIR/signals/archive.latest.json"

# Ensure signals directory exists
mkdir -p "$ARCHIVE_DIR/signals"

if [ -f "$SIGNALS_FILE" ]; then
    echo "📦 Archiving existing broadcast..."
    
    if [ -f "$ARCHIVE_FILE" ]; then
        # Archive file exists - insert existing latest.json at beginning of array
        echo "  📚 Adding to existing archive..."
        
        # Read existing latest.json and archive array
        EXISTING_BROADCAST=$(cat "$SIGNALS_FILE")
        EXISTING_ARCHIVE=$(cat "$ARCHIVE_FILE")
        
        # Insert existing broadcast at beginning of archive array (only if jq is available)
        if command -v jq >/dev/null 2>&1; then
            NEW_ARCHIVE=$(echo "$EXISTING_ARCHIVE" | jq --argjson new_item "$EXISTING_BROADCAST" '. = [$new_item] + .')
            
            # Write updated archive
            echo "$NEW_ARCHIVE" > "$ARCHIVE_FILE"
            echo "  ✅ Existing broadcast archived ($(echo "$NEW_ARCHIVE" | jq '. | length') total broadcasts in archive)"
        else
            echo "  ⚠️  jq not available, skipping broadcast archiving"
        fi
        
    else
        # No archive file exists - create new one with existing latest.json
        echo "  📚 Creating new archive..."
        
        if command -v jq >/dev/null 2>&1; then
            EXISTING_BROADCAST=$(cat "$SIGNALS_FILE")
            NEW_ARCHIVE=$(echo "[]" | jq --argjson new_item "$EXISTING_BROADCAST" '. = [$new_item]')
            
            # Write new archive file
            echo "$NEW_ARCHIVE" > "$ARCHIVE_FILE"
            echo "  ✅ Archive created with existing broadcast"
        else
            echo "  ⚠️  jq not available, skipping archive creation"
        fi
    fi
else
    echo "📦 No existing broadcast to archive"
fi

BROADCAST_JSON=$(cat << EOF
{
  "id": "$(date -u +%Y%m%dT%H%M%SZ)-archive-model-constellation_pulse",
  "ts_utc": "$TIMESTAMP",
  "date": "$(date -u +%Y-%m-%d)",
  "module": "Archive Model",
  "repo": "archive-model",
  "title": "Constellation Status Pulse Complete",
  "summary": "The Archive has completed its nightly pulse of the constellation, updating status information for $stars_scanned stars with $stars_updated status changes.",
  "tags": ["pulse", "status", "automation"],
  "rating": "normal",
  "origin": {
    "name": "Archive Model",
    "url": "https://zbreeden.github.io/archive-model/",
    "emoji": "🫀"
  },
  "links": {
    "readme": "https://github.com/zbreeden/archive-model#readme",
    "page": "https://zbreeden.github.io/archive-model/"
  },
  "payload": {
    "module_key": "archive_model",
    "broadcast_key": "constellation_pulse",
    "stars_scanned": $stars_scanned,
    "stars_updated": $stars_updated,
    "pulse_timestamp": "$TIMESTAMP"
  }
}
EOF
)

# Write the broadcast signal
echo "$BROADCAST_JSON" > "$SIGNALS_FILE"

# Validate the JSON
if command -v jq >/dev/null 2>&1; then
    if jq empty "$SIGNALS_FILE" 2>/dev/null; then
        echo "  ✅ Broadcast signal generated and validated"
        
        # Show archive status if available
        if [ -f "$ARCHIVE_FILE" ]; then
            ARCHIVE_COUNT=$(jq '. | length' "$ARCHIVE_FILE" 2>/dev/null || echo "unknown")
            echo "  📚 Archive contains $ARCHIVE_COUNT historical broadcasts"
        fi
    else
        echo "  ❌ Broadcast signal validation failed"
    fi
else
    echo "  ⚠️  jq not available, skipping signal validation"
fi

echo
echo "🫀 The Archive pulse is complete. The constellation's heartbeat has been recorded."