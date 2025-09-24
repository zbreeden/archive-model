#!/usr/bin/env bash
set -euo pipefail

echo "📡 Updating hub constellation with this module..."

MODULE_KEY="archive_model"
REPO_NAME="archive-model"
HUB_PATH="../FourTwentyAnalytics"

if [ ! -d "$HUB_PATH" ]; then
  echo "❌ Hub not found at $HUB_PATH"
  echo "   Make sure FourTwentyAnalytics is cloned alongside this repo"
  exit 1
fi

# Add entry to hub's seeds/modules.yml if not already present
if ! grep -q "key: $MODULE_KEY" "$HUB_PATH/seeds/modules.yml"; then
  echo "🌱 Adding module to hub seeds/modules.yml..."
  cat >> "$HUB_PATH/seeds/modules.yml" <<MODULE

- key: archive_model
  label: "Archive Model"
  repo: "archive-model"
  owner: "zbreeden"
  emoji: "🫀"
  orbit: core
  status: seed
  tags: [the,archive,is]
  description: "The Archive is the ledger"
  repo_url: https://github.com/zbreeden/archive-model
  pages_url: https://zbreeden.github.io/archive-model/
  owners: [zach]
MODULE
  echo "  ✅ Module added to hub constellation"
else
  echo "  ℹ️ Module already exists in hub constellation"
fi

echo "🚀 Hub integration complete!"
echo "   Don't forget to commit changes in $HUB_PATH"
