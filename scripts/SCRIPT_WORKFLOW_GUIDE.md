# 🫀 Archive Model Script Workflow - Quick Reference

## Quick Start

```bash
cd archive-model

# Aggregate all constellation scripts
./scripts/aggregate-scripts.sh

# Validate collection and coverage  
./scripts/validate-scripts.sh

# Manage backups
./scripts/restore-scripts.sh list
```

## Key Commands

| Command | Purpose |
|---------|---------|
| `./scripts/aggregate-scripts.sh` | Collect, deduplicate, and merge constellation scripts |
| `./scripts/validate-scripts.sh` | Validate collection and check constellation coverage |
| `./scripts/restore-scripts.sh list` | List available backups |
| `./scripts/restore-scripts.sh restore <timestamp>` | Restore from backup |
| `./scripts/restore-scripts.sh clean` | Clean old backups (30+ days) |

## Workflow Phases

1. **🔍 Discovery** - Scan constellation for `*-model/scripts/` directories
2. **💾 Preservation** - Back up current archive scripts  
3. **🔄 Deduplication** - Hash-based content comparison and merging
4. **📦 Deployment** - Replace archive scripts with deduplicated collection

## Output Structure

### Collected Scripts
```bash
# Source: signal-model/scripts/aggregate-constellation.sh
# Collected by Archive Model Script Aggregator
# Original script content...
```

### Merged Conflicts
```bash
# MERGED FILE: Multiple sources detected  
# Sources: archive-model (current) + constellation
# === SOURCE 1: archive-model (current) ===
# === SOURCE 2: constellation ===
```

### Statistics
- Stars processed: Count of `*-model` directories with scripts
- Scripts collected: Total files gathered from constellation
- Scripts deployed: Final count after deduplication
- Duplicates found: Files with identical content

## Safety Features

| Feature | Protection |
|---------|------------|
| 💾 **Timestamped backups** | `data/script_backups/YYYYMMDDTHHMMSSZ/` |
| 🛡️ **Pre-restoration backups** | Created before any restore operation |
| 🏠 **Native script priority** | Archive scripts preserved over constellation |
| 📝 **Source tracking** | Every file tagged with origin |
| 🔀 **Conflict merging** | Multiple versions combined when different |

## Integration Points

### Requirements for Stars
```
<star>-model/
└── scripts/           # Required directory
    ├── script1.sh     # Collected (executable preserved)
    ├── document.md    # Collected  
    └── .hidden        # Ignored (hidden files)
```

### Archive Directory After Aggregation
```
archive-model/scripts/
├── aggregate-scripts.sh           # Core aggregation utility (preserved)
├── validate-scripts.sh           # Collection validator (preserved) 
├── restore-scripts.sh            # Backup manager (preserved)
├── *.md                          # Documentation (preserved)
├── <collected-constellation-scripts>  # Aggregated and deduplicated
└── <script>-merged.<ext>         # Conflict resolution files
```

## Troubleshooting

| Issue | Check | Fix |
|-------|-------|-----|
| No scripts found | Star directory structure | Verify `*-model/scripts/` exists |
| Permission denied | File permissions | Run `chmod +x scripts/*.sh` |
| Hash errors | System tools | Install `shasum` or `sha256sum` |
| Backup failures | Disk space | Check `data/` directory space |
| Missing stars | Naming convention | Ensure directories end with `-model` |

## Common Patterns

```bash
# Full aggregation workflow
./scripts/aggregate-scripts.sh && ./scripts/validate-scripts.sh

# Emergency restoration
./scripts/restore-scripts.sh list
./scripts/restore-scripts.sh restore <latest-timestamp>

# Maintenance cleanup  
./scripts/restore-scripts.sh clean 14  # Keep 2 weeks

# Coverage analysis
./scripts/validate-scripts.sh | grep "Coverage"
```

## Constellation Philosophy

> **The Archive breathes life into the constellation by maintaining memory, seeds, and history.**

The script aggregation workflow embodies this by:
- 📜 Preserving all constellation scripting knowledge
- 🔄 Preventing script loss through systematic collection  
- 💾 Maintaining historical versions via timestamped backups
- 🛡️ Protecting against conflicts with intelligent merging
- 📊 Providing visibility into constellation script coverage

**The Archive serves as the master of the scrolls - ensuring no scripting knowledge is ever lost.**