# Archive Collection: update-hub-merged.sh
# Source: accountant-model/scripts/update-hub.sh
# Collected by Archive Model Script Aggregator

echo "📡 Updating hub constellation with this module..."

MODULE_KEY="accountant_model"
REPO_NAME="accountant-model"
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

- key: accountant_model
  label: "Accountant Model"
  repo: "accountant-model"
  owner: "zbreeden"
  emoji: "💰"
  orbit: ancillary-operations
  status: seed
  tags: [the,accountant,is]
  description: "The Accountant is the bookkeeper"
  repo_url: https://github.com/zbreeden/accountant-model
  pages_url: https://zbreeden.github.io/accountant-model/
  owners: [zach]
MODULE
  echo "  ✅ Module added to hub constellation"
else
  echo "  ℹ️ Module already exists in hub constellation"
fi

echo "🚀 Hub integration complete!"
echo "   Don't forget to commit changes in $HUB_PATH"
