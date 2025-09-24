# Archive Collection: update-hub-launch-model.sh
# Source: launch-model/scripts/update-hub.sh
# Collected by Archive Model Script Aggregator

echo "📡 Updating hub constellation with this module..."

MODULE_KEY="launch_model"
REPO_NAME="launch-model"
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

- key: launch_model
  label: "Launch Model"
  repo: "launch-model"
  owner: "zbreeden"
  emoji: "🚀"
  orbit: core
  status: seed
  tags: [the,launch,is]
  description: "The Launch is the machine manifesto"
  repo_url: https://github.com/zbreeden/launch-model
  pages_url: https://zbreeden.github.io/launch-model/
  owners: [zach]
MODULE
  echo "  ✅ Module added to hub constellation"
else
  echo "  ℹ️ Module already exists in hub constellation"
fi

echo "🚀 Hub integration complete!"
echo "   Don't forget to commit changes in $HUB_PATH"
