# Archive Collection: update-hub-gambler-model.sh
# Source: gambler-model/scripts/update-hub.sh
# Collected by Archive Model Script Aggregator

echo "📡 Updating hub constellation with this module..."

MODULE_KEY="gambler_model"
REPO_NAME="gambler-model"
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

- key: gambler_model
  label: "Gambler Model"
  repo: "gambler-model"
  owner: "zbreeden"
  emoji: "🎲"
  orbit: growth-experiment
  status: seed
  tags: [the,gambler,is]
  description: "The Gambler is the probability sampler"
  repo_url: https://github.com/zbreeden/gambler-model
  pages_url: https://zbreeden.github.io/gambler-model/
  owners: [zach]
MODULE
  echo "  ✅ Module added to hub constellation"
else
  echo "  ℹ️ Module already exists in hub constellation"
fi

echo "🚀 Hub integration complete!"
echo "   Don't forget to commit changes in $HUB_PATH"
