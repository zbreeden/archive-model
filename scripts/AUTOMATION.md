# Archive Model - Constellation Pulse Autom## What the Pulse Does

- 🔍 **Scans** all star directories in the constellation
- 📊 **Reads** the current status from each star's `seeds/modules.yml`
- ✅ **Updates** The Archive's `seeds/modules.yml` with current status information
- 📦 **Archives** previous broadcast signals to `signals/archive.latest.json`
- 📡 **Broadcasts** a new pulse signal to `signals/latest.json`
- 📦 **Creates** timestamped backups before making changes
- 📈 **Reports** scan summary and status changes

## Pulse System Expansion

**Current Scope**: Status tracking only  
**Expandable to**: Tags, glossary, emoji palette, and more

The pulse system is designed for modular expansion. See `EXPANSION.md` for details.

### Ready-to-Implement Modules

- 🏷️ **Tag Reconciliation**: `scripts/reconcile-tags.sh` 
- 📚 **Glossary Sync**: Planned for Phase 3
- 🎨 **Emoji Management**: Planned for Phase 3

### Example Expansion Usage

```bash
# Current pulse (status only)
./scripts/pulse-constellation.sh

# Enhanced pulse with tags (future)
./scripts/pulse-enhanced-example.sh --reconcile-tags

# Full reconciliation (future)  
./scripts/pulse-enhanced-example.sh --reconcile-all
```is file documents The Archive's constellation pulse automation system.
The Archive Model scans all stars in the constellation and updates their
status information each night.

## Quick Setup

**For immediate automation setup:**

```bash
./scripts/setup-automation.sh
```

This script will:
- Create the logs directory
- Install the cron job for nightly execution
- Verify the automation is working
- Show management commands

## Manual Setup (Alternative)

If you prefer manual setup or the automated setup fails:

1. **Create log directory:**

   ```bash
   mkdir -p /Users/zachrybreeden/Desktop/FourTwentyAnalytics/archive-model/logs
   ```

2. **Add to crontab:**

   ```bash
   crontab -e
   # Add the cron line above
   ```

3. **Verify cron job:**

   ```bash
   crontab -l
   ```

## What the Pulse Does

- 🔍 **Scans** all star directories in the constellation
- 📊 **Reads** the current status from each star's `seeds/modules.yml`
- ✅ **Updates** The Archive's `seeds/modules.yml` with current status information
- � **Archives** previous broadcast signals to `signals/archive.latest.json`
- �📡 **Broadcasts** a new pulse signal to `signals/latest.json`
- 📦 **Creates** timestamped backups before making changes
- 📈 **Reports** scan summary and status changes

## Signal Archiving System

The pulse script implements constellation-compliant signal archiving:

- **Current Signal**: `signals/latest.json` (most recent pulse)
- **Historical Archive**: `signals/archive.latest.json` (array of all previous signals)
- **Archiving Process**: Each pulse automatically archives the current signal before creating a new one
- **Archive Growth**: The archive maintains chronological order with newest broadcasts at the beginning

## Backup & Safety

- Each pulse creates a timestamped backup: `modules.yml.backup.YYYYMMDDTHHMMSSZ`
- The script is idempotent - safe to run multiple times
- All changes are logged with timestamps
- Uses constellation-compliant broadcast format

## Monitoring

Check the pulse logs:
```bash
tail -f /Users/zachrybreeden/Desktop/FourTwentyAnalytics/archive-model/logs/pulse.log
```

View current broadcast:
```bash
cat /Users/zachrybreeden/Desktop/FourTwentyAnalytics/archive-model/signals/latest.json | jq
```

View archive history:
```bash
cat /Users/zachrybreeden/Desktop/FourTwentyAnalytics/archive-model/signals/archive.latest.json | jq -r '.[].id'
```

Check archive size:
```bash
cat /Users/zachrybreeden/Desktop/FourTwentyAnalytics/archive-model/signals/archive.latest.json | jq '. | length'
```