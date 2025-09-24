# Archive Collection: update-hub-evaluator-model.sh
# Source: evaluator-model/scripts/update-hub.sh
# Collected by Archive Model Script Aggregator

echo "📡 Updating hub constellation with this module..."

MODULE_KEY="evaluator_model"
REPO_NAME="evaluator-model"
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

- key: evaluator_model
  label: "Evaluator Model"
  repo: "evaluator-model"
  owner: "zbreeden"
  emoji: "🧠"
  orbit: delivery-insight
  status: seed
  tags: [the,evaluator,is]
  description: "The Evaluator is the sucess metric"
  repo_url: https://github.com/zbreeden/evaluator-model
  pages_url: https://zbreeden.github.io/evaluator-model/
  owners: [zach]
MODULE
  echo "  ✅ Module added to hub constellation"
else
  echo "  ℹ️ Module already exists in hub constellation"
fi

echo "🚀 Hub integration complete!"
echo "   Don't forget to commit changes in $HUB_PATH"
