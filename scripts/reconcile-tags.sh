#!/usr/bin/env bash
set -euo pipefail

# Archive Model - Tag Reconciliation Module
# Extends the pulse system to synchronize tags across the constellation

# Function to extract tags from a star's modules.yml
extract_star_tags() {
    local star_dir="$1"
    local module_id="$2"

    if [ -f "$star_dir/seeds/modules.yml" ]; then
        # Extract tags using awk
        awk -v id="$module_id" '
        BEGIN { found=0; in_module=0; in_tags=0 }
        /^- id: / {
            if ($3 == id) { found=1; in_module=1 }
            else { in_module=0; in_tags=0 }
        }
        in_module && /^  tags: / {
            in_tags=1
            next
        }
        in_tags && /^  [a-zA-Z]/ {
            in_tags=0
        }
        in_tags && /^\s*-/ {
            gsub(/^\s*-\s*/, "")
            gsub(/\[|\]|,/, "")
            if ($0 != "") print $0
        }
        ' "$star_dir/seeds/modules.yml"
    fi
}

# Function to check if tag exists in Archive's tags.yml
tag_exists_in_archive() {
    local tag_key="$1"
    local archive_tags_file="$2"

    if [ -f "$archive_tags_file" ]; then
        grep -q "^- key: $tag_key$" "$archive_tags_file"
    else
        return 1
    fi
}

# Function to add new tag to Archive's tags.yml
add_tag_to_archive() {
    local tag_key="$1"
    local archive_tags_file="$2"
    local temp_file=$(mktemp)

    # Create a basic tag entry
    cat >> "$temp_file" << EOF

- key: $tag_key
  label: "$(echo "$tag_key" | sed 's/_/ /g' | sed 's/\b\w/\u&/g')"
  description: "Auto-discovered tag from constellation pulse"
  kind: discovered
  deprecated: false
  discovered_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF

    # Append to tags file
    cat "$archive_tags_file" "$temp_file" > "${archive_tags_file}.tmp"
    mv "${archive_tags_file}.tmp" "$archive_tags_file"
    rm -f "$temp_file"
}

# Main reconciliation function
reconcile_constellation_tags() {
    local archive_dir="$1"
    local hub_dir="$2"
    local modules_file="$3"

    local archive_tags_file="$archive_dir/seeds/tags.yml"
    local discovered_tags=()
    local new_tags=0

    echo "🏷️ Reconciling constellation tags..."

    # Create tags file if it doesn't exist
    if [ ! -f "$archive_tags_file" ]; then
        echo "# Constellation Tags Registry" > "$archive_tags_file"
        echo "# Auto-managed by Archive Model pulse system" >> "$archive_tags_file"
        echo >> "$archive_tags_file"
    fi

    # Read module IDs and scan for tags
    while IFS= read -r line; do
        if [[ $line =~ ^-[[:space:]]+id:[[:space:]]+(.+)$ ]]; then
            module_id="${BASH_REMATCH[1]}"

            # Skip the hub itself
            if [ "$module_id" = "fourtwenty_analytics" ]; then
                continue
            fi

            # Convert module_id to directory name
            star_dir_name=$(echo "$module_id" | sed 's/_/-/g')
            star_path="$hub_dir/$star_dir_name"

            if [ -d "$star_path" ]; then
                echo "  🔍 Scanning tags from $module_id..."

                # Extract tags from this star
                while IFS= read -r tag; do
                    if [ -n "$tag" ]; then
                        discovered_tags+=("$tag")

                        # Check if tag exists in Archive
                        if ! tag_exists_in_archive "$tag" "$archive_tags_file"; then
                            echo "    ➕ New tag discovered: $tag"
                            add_tag_to_archive "$tag" "$archive_tags_file"
                            new_tags=$((new_tags + 1))
                        else
                            echo "    ✅ Known tag: $tag"
                        fi
                    fi
                done <<< "$(extract_star_tags "$star_path" "$module_id")"
            fi
        fi
    done < "$modules_file"

    # Report results
    echo "  📊 Tag reconciliation summary:"
    echo "    • Total tags discovered: ${#discovered_tags[@]}"
    echo "    • New tags added: $new_tags"

    return $new_tags
}

# This function can be called from the main pulse script
# Example usage:
# reconcile_constellation_tags "$ARCHIVE_DIR" "$HUB_DIR" "$MODULES_FILE"