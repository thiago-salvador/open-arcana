#!/bin/bash
# Read and surface unread alerts on session start
# Display only. Archiving happens explicitly when agent calls archive-alerts.sh
# This prevents alert loss if the session crashes after display but before processing

VAULT_PATH="{{VAULT_PATH}}"
ALERTS_FILE="$VAULT_PATH/00-Dashboard/alerts.md"

if [ ! -f "$ALERTS_FILE" ]; then
  exit 0
fi

# Extract unread alerts (lines starting with "- " under "## Unread Alerts")
UNREAD=$(sed -n '/^## Unread Alerts/,/^## /{ /^- /p; }' "$ALERTS_FILE" 2>/dev/null)

if [ -z "$UNREAD" ]; then
  exit 0
fi

COUNT=$(echo "$UNREAD" | wc -l | tr -d ' ')

echo "PENDING ALERTS ($COUNT)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "$UNREAD"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "These alerts came from scheduled tasks. Review and act as needed."
echo "To archive after review: bash .claude/hooks/archive-alerts.sh"
