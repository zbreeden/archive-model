# Archive Collection: update-hub-bank-model.sh
# Source: bank-model/scripts/update-hub.sh
# Collected by Archive Model Script Aggregator

echo "📡 Updating hub constellation with this module..."

MODULE_KEY="bank_model"
REPO_NAME="bank-model"
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

- key: bank_model
  label: "Bank Model"
  repo: "bank-model"
  owner: "zbreeden"
  emoji: "🏦"
  orbit: delivery-insight
  status: seed
  tags: [the,bank,is]
  description: "The Bank is the financial servicer"
  repo_url: https://github.com/zbreeden/bank-model
  pages_url: https://zbreeden.github.io/bank-model/
  owners: [zach]
MODULE
  echo "  ✅ Module added to hub constellation"
else
  echo "  ℹ️ Module already exists in hub constellation"
fi

echo "🚀 Hub integration complete!"
echo "   Don't forget to commit changes in $HUB_PATH"
