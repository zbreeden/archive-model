#!/usr/bin/env bash
set -euo pipefail

# 🔄 Archive Model Script Restoration Utility
# Manages script backups and provides restoration capabilities

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE_MODEL_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_ROOT="$ARCHIVE_MODEL_ROOT/data/script_backups"

echo "🔄 Archive Model Script Restoration Utility"
echo "💾 Managing constellation script backups..."
echo

# Function to list available backups
list_backups() {
    if [[ ! -d "$BACKUP_ROOT" ]]; then
        echo "⚪ No backup directory found"
        return 1
    fi
    
    local backups
    backups=$(find "$BACKUP_ROOT" -maxdepth 1 -type d -name "????????T??????Z" | sort -r)
    
    if [[ -z "$backups" ]]; then
        echo "⚪ No timestamped backups found"
        return 1
    fi
    
    echo "📅 Available script backups:"
    local count=1
    while IFS= read -r backup_dir; do
        if [[ -n "$backup_dir" ]]; then
            local backup_name
            backup_name=$(basename "$backup_dir")
            local file_count
            file_count=$(find "$backup_dir" -maxdepth 1 -type f | wc -l)
            
            # Convert timestamp to readable format
            local year month day hour min sec
            year=${backup_name:0:4}
            month=${backup_name:4:2}
            day=${backup_name:6:2}
            hour=${backup_name:9:2}
            min=${backup_name:11:2}
            sec=${backup_name:13:2}
            
            echo "  $count) $backup_name ($year-$month-$day $hour:$min:$sec UTC) - $file_count files"
            count=$((count + 1))
        fi
    done <<< "$backups"
    
    return 0
}

# Function to restore from backup
restore_backup() {
    local backup_timestamp="$1"
    local backup_dir="$BACKUP_ROOT/$backup_timestamp"
    
    if [[ ! -d "$backup_dir" ]]; then
        echo "❌ Backup not found: $backup_timestamp"
        return 1
    fi
    
    echo "🔄 Restoring scripts from backup: $backup_timestamp"
    echo
    
    # Create a backup of current state before restoration
    local current_backup_dir="$BACKUP_ROOT/$(date -u +%Y%m%dT%H%M%SZ)-pre-restore"
    mkdir -p "$current_backup_dir"
    
    echo "💾 Creating pre-restoration backup..."
    for file in "$SCRIPT_DIR"/*; do
        if [[ -f "$file" ]]; then
            filename=$(basename "$file")
            if [[ "$filename" != "aggregate-scripts.sh" ]] && [[ "$filename" != "validate-scripts.sh" ]] && [[ "$filename" != "restore-scripts.sh" ]] && [[ "$filename" != *.md ]]; then
                cp "$file" "$current_backup_dir/"
                echo "  💾 Backed up: $filename"
            fi
        fi
    done
    
    # Remove current scripts (except core utilities and docs)
    echo
    echo "🗑️ Removing current scripts..."
    for file in "$SCRIPT_DIR"/*; do
        if [[ -f "$file" ]]; then
            filename=$(basename "$file")
            if [[ "$filename" != "aggregate-scripts.sh" ]] && [[ "$filename" != "validate-scripts.sh" ]] && [[ "$filename" != "restore-scripts.sh" ]] && [[ "$filename" != *.md ]]; then
                rm "$file"
                echo "  🗑️ Removed: $filename"
            fi
        fi
    done
    
    # Restore from backup
    echo
    echo "📦 Restoring from backup..."
    local restored_count=0
    for file in "$backup_dir"/*; do
        if [[ -f "$file" ]]; then
            filename=$(basename "$file")
            # Don't restore core utilities that we preserve
            if [[ "$filename" != "aggregate-scripts.sh" ]] && [[ "$filename" != "validate-scripts.sh" ]] && [[ "$filename" != "restore-scripts.sh" ]]; then
                cp "$file" "$SCRIPT_DIR/"
                echo "  📦 Restored: $filename"
                
                # Make executable if it's a shell script
                if [[ "$filename" == *.sh ]]; then
                    chmod +x "$SCRIPT_DIR/$filename"
                fi
                
                restored_count=$((restored_count + 1))
            fi
        fi
    done
    
    echo
    echo "✅ Restoration complete!"
    echo "📊 Restored $restored_count files from backup $backup_timestamp"
    echo "💾 Pre-restoration backup saved as: $(basename "$current_backup_dir")"
    
    # Update signal
    local restoration_signal
    restoration_signal=$(cat <<EOF
{
  "id": "$(date -u +%Y%m%dT%H%M%SZ)-archive-model-script_restoration",
  "ts_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "date": "$(date -u +%Y-%m-%d)",
  "module": "Archive Model",
  "repo": "archive-model",
  "title": "Script Collection Restored from Backup",
  "summary": "The Archive has restored $restored_count scripts from backup $backup_timestamp",
  "rating": "high",
  "origin": {
    "name": "Archive Model Script Restorer",
    "url": "https://zbreeden.github.io/archive-model/",
    "emoji": "🫀"
  },
  "links": {
    "readme": "https://github.com/zbreeden/archive-model#readme",
    "page": "https://zbreeden.github.io/archive-model/"
  },
  "payload": {
    "module_key": "archive_model",
    "broadcast_key": "script_restoration",
    "restoration_stats": {
      "backup_restored": "$backup_timestamp",
      "files_restored": $restored_count,
      "pre_restore_backup": "$(basename "$current_backup_dir")"
    }
  }
}
EOF
)
    
    echo "$restoration_signal" > "$ARCHIVE_MODEL_ROOT/signals/latest.json"
    echo "📡 Updated archive-model signal broadcast"
}

# Function to clean old backups
clean_backups() {
    local days_to_keep="$1"
    
    if [[ ! -d "$BACKUP_ROOT" ]]; then
        echo "⚪ No backup directory found"
        return 0
    fi
    
    echo "🧹 Cleaning backups older than $days_to_keep days..."
    
    local deleted_count=0
    while IFS= read -r -d '' backup_dir; do
        if [[ -d "$backup_dir" ]]; then
            local backup_name
            backup_name=$(basename "$backup_dir")
            
            # Check if it matches timestamp pattern
            if [[ "$backup_name" =~ ^[0-9]{8}T[0-9]{6}Z ]]; then
                # Check modification time
                if [[ $(find "$backup_dir" -maxdepth 0 -mtime +$days_to_keep) ]]; then
                    echo "  🗑️ Removing old backup: $backup_name"
                    rm -rf "$backup_dir"
                    deleted_count=$((deleted_count + 1))
                fi
            fi
        fi
    done < <(find "$BACKUP_ROOT" -maxdepth 1 -type d -print0)
    
    echo "🧹 Cleaned $deleted_count old backups"
}

# Main script logic
case "${1:-}" in
    "list"|"ls")
        list_backups
        ;;
    "restore")
        if [[ -z "${2:-}" ]]; then
            echo "Usage: $0 restore <backup_timestamp>"
            echo
            list_backups
            exit 1
        fi
        
        echo "⚠️ This will replace current scripts with backup: $2"
        read -rp "Continue? (y/N): " confirm
        if [[ $confirm == [yY] ]]; then
            restore_backup "$2"
        else
            echo "❌ Restoration cancelled"
        fi
        ;;
    "clean")
        days_to_keep="${2:-30}"
        echo "⚠️ This will delete backups older than $days_to_keep days"
        read -rp "Continue? (y/N): " confirm
        if [[ $confirm == [yY] ]]; then
            clean_backups "$days_to_keep"
        else
            echo "❌ Cleanup cancelled"
        fi
        ;;
    *)
        echo "📜 Archive Model Script Restoration Utility"
        echo
        echo "Usage:"
        echo "  $0 list                    - List available backups"
        echo "  $0 restore <timestamp>     - Restore from specific backup"
        echo "  $0 clean [days]           - Clean backups older than N days (default: 30)"
        echo
        echo "Examples:"
        echo "  $0 list"
        echo "  $0 restore 20250923T120000Z"
        echo "  $0 clean 7"
        echo
        list_backups
        ;;
esac