# 🫀 Archive Model Script Aggregation Workflow

## Overview

The Archive Model serves as the **master of the scrolls** - the central repository for all constellation scripting knowledge. This workflow implements a comprehensive script aggregation system that collects, deduplicates, and manages scripts from across all FourTwenty Analytics stars.

## Philosophy

> *"Breathes life into the constellation by maintaining memory, seeds, and history. Think master of the scrolls."*

The Archive Model's script aggregation embodies the constellation's memory by:
- 📜 **Collecting** all scripting knowledge from every star
- 🔄 **Deduplicating** to prevent redundancy while preserving variants
- 💾 **Preserving** historical versions through timestamped backups
- 🛡️ **Protecting** against data loss with restoration capabilities

## Architecture

### Files Created

```
archive-model/
├── scripts/
│   ├── aggregate-scripts.sh         # Core aggregation logic
│   ├── validate-scripts.sh         # Collection validation and coverage analysis
│   ├── restore-scripts.sh          # Backup management and restoration
│   ├── README_SCRIPT_AGGREGATION.md # This documentation
│   └── SCRIPT_WORKFLOW_GUIDE.md    # Quick reference guide
├── data/
│   └── script_backups/
│       ├── YYYYMMDDTHHMMSSZ/       # Timestamped backups
│       └── YYYYMMDDTHHMMSSZ-pre-restore/ # Pre-restoration backups
└── signals/
    └── latest.json                  # Broadcast aggregation status
```

### Aggregation Process

The workflow follows a **four-phase approach**:

#### Phase 1: Discovery and Collection
- 🔍 Scans all `*-model` directories in constellation
- 📁 Identifies modules with `scripts/` directories  
- 📄 Collects all non-hidden files from each star's scripts
- 🏷️ Adds source metadata headers for traceability

#### Phase 2: Current State Preservation
- 🗃️ Backs up existing archive-model scripts
- 🛡️ Preserves current state before any modifications
- 📊 Counts and catalogs existing scripts

#### Phase 3: Intelligent Deduplication
- 🔍 Uses SHA-256 hashing for content comparison
- 🔀 Detects identical files across stars
- 📝 Creates merged versions for content differences
- ✨ Maintains both sources when conflicts exist

#### Phase 4: Deployment and Backup
- 💾 Creates timestamped backup of current state
- 🔄 Deploys deduplicated script collection
- ✅ Sets appropriate file permissions
- 📡 Broadcasts completion status

## Usage

### Manual Aggregation

```bash
cd archive-model

# Run complete aggregation workflow
./scripts/aggregate-scripts.sh

# Validate the aggregated collection
./scripts/validate-scripts.sh

# View aggregation coverage and statistics
./scripts/validate-scripts.sh
```

### Backup Management

```bash
# List available backups
./scripts/restore-scripts.sh list

# Restore from specific backup
./scripts/restore-scripts.sh restore 20250923T120000Z

# Clean old backups (older than 30 days)
./scripts/restore-scripts.sh clean

# Clean backups older than 7 days
./scripts/restore-scripts.sh clean 7
```

## Output Structure

### Source Tracking
Every aggregated script includes metadata headers:

```bash
# Source: signal-model/scripts/aggregate-constellation.sh  
# Collected by Archive Model Script Aggregator
# Original path: /path/to/signal-model/scripts/aggregate-constellation.sh

#!/usr/bin/env bash
# Original script content follows...
```

### Conflict Resolution
When multiple stars have scripts with the same name but different content:

```bash
# MERGED FILE: Multiple sources detected
# Sources: archive-model (current) + constellation
# Merged by Archive Model Script Aggregator

# === SOURCE 1: archive-model (current) ===
# Original archive version...

# === SOURCE 2: constellation ===  
# Alternative constellation version...
```

### Aggregation Statistics
Each run produces detailed statistics:

```json
{
  "aggregation_stats": {
    "stars_processed": 15,
    "scripts_collected": 42,
    "scripts_deployed": 38,
    "duplicates_found": 4,
    "backup_location": "data/script_backups/20250923T120000Z"
  }
}
```

## Validation & Coverage

### Script Collection Health
The validator checks:
- ✅ File executability and permissions
- 📍 Source attribution and traceability  
- 📏 File sizes and basic structure
- 🔧 Shell script shebangs and headers

### Constellation Coverage
Analyzes coverage across all stars:
- ⭐ Total stars with scripts directories
- 📜 Scripts per star mapping
- ⚠️ Missing aggregations detection
- 📊 Coverage percentage reporting

### Backup Integrity
Monitors backup ecosystem:
- 💾 Available backup timestamps
- 🕒 Most recent backup dates
- 📁 Backup file counts and sizes
- 🧹 Cleanup recommendations

## Integration with Constellation

### Discovery Logic
Automatically finds constellation stars:
```bash
# Matches directories: *-model with scripts/ subdirectory
# Excludes: archive-model (self) 
# Processes: All files except hidden (.*)
```

### Star Requirements
For scripts to be aggregated:
```
<star-name>-model/
└── scripts/
    ├── script1.sh     # Will be collected
    ├── script2.py     # Will be collected  
    ├── README.md      # Will be collected
    └── .hidden        # Will be ignored
```

### Downstream Integration
The aggregated collection enables:
- 🔍 **Cross-constellation script analysis** - Find patterns and duplications
- 🛠️ **Centralized tooling access** - Single location for all constellation scripts
- 📊 **Script evolution tracking** - Historical versions through backups
- 🚀 **Deployment standardization** - Consistent scripting patterns
- 🔄 **Knowledge preservation** - Prevents script loss across stars

## Safety Mechanisms

### Backup Protection
- 💾 **Automatic backups** before every aggregation
- 🕒 **Timestamped preservation** with YYYYMMDDTHHMMSSZ format  
- 🛡️ **Pre-restoration backups** before any recovery operation
- 🧹 **Configurable cleanup** to manage storage usage

### Content Preservation
- 🏠 **Native script priority** - Archive scripts take precedence
- 🔀 **Merge conflict handling** - Creates combined versions when needed
- 📝 **Source attribution** - Every file tracks its origin
- ✨ **Permission maintenance** - Executable bits preserved

### Error Handling
- 🔄 **Graceful failures** - Individual star failures don't stop aggregation
- 📊 **Detailed logging** - Complete operation tracking
- ✅ **Validation integration** - Built-in health checks
- 🚨 **Signal broadcasting** - Status updates to constellation

## Maintenance

### Regular Operations
```bash
# Weekly aggregation to capture new scripts
./scripts/aggregate-scripts.sh

# Monthly validation to check coverage
./scripts/validate-scripts.sh  

# Quarterly backup cleanup
./scripts/restore-scripts.sh clean 90
```

### Troubleshooting

| Issue | Diagnosis | Solution |
|-------|-----------|----------|
| No scripts collected | Check constellation star structure | Verify `*-model/scripts/` directories exist |
| Permission errors | File ownership issues | Run `chmod +x scripts/*.sh` |
| Backup failures | Disk space or permissions | Check `data/` directory writability |
| Missing coverage | Stars not discovered | Ensure stars follow `*-model` naming |
| Hash conflicts | SHA tools unavailable | Install `shasum` or `sha256sum` |

### Recovery Procedures
```bash
# Emergency restoration to last known good state
./scripts/restore-scripts.sh list
./scripts/restore-scripts.sh restore <latest-backup>

# Validate restoration success  
./scripts/validate-scripts.sh

# Re-run aggregation if needed
./scripts/aggregate-scripts.sh
```

## Schema Conformance

All operations maintain constellation standards:
- Scripts conform to existing executable patterns
- Signals broadcast using `latest.schema.yml` structure  
- Directory organization follows module standards
- Metadata headers provide full traceability

The Archive Model's script aggregation ensures that the constellation's scripting knowledge is never lost, always accessible, and continuously evolving - truly serving as the **master of the scrolls** for the entire FourTwenty Analytics ecosystem.