#!/bin/bash
# Read and surface unread alerts on session start, GROUPED BY DOMAIN
# Display only — archiving happens explicitly when agent calls archive-alerts.sh
# This prevents alert loss if the session crashes after display but before processing
# macOS-compatible (no grep -P)

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
URGENT_COUNT=$(echo "$UNREAD" | grep -c "🔴" || true)

echo "PENDING ALERTS ($COUNT)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$URGENT_COUNT" -gt 0 ]; then
  echo "⚠️ $URGENT_COUNT URGENT"
fi
echo ""

# Extract unique domains from alerts (macOS-compatible, no grep -P)
# New format: - 🔴 **[source]** `domain` timestamp — msg
# Legacy format: - 🔴 **[source]** timestamp — msg (no backtick domain)
DOMAINS=$(echo "$UNREAD" | sed -n 's/.*\]\*\* `\([^`]*\)`.*/\1/p' | sort -u)

# Print alerts grouped by domain
if [ -n "$DOMAINS" ]; then
  for DOMAIN in $DOMAINS; do
    DOMAIN_UPPER=$(echo "$DOMAIN" | tr '[:lower:]' '[:upper:]')
    echo "📂 ${DOMAIN_UPPER}"
    echo "$UNREAD" | grep "\`${DOMAIN}\`"
    echo ""
  done
fi

# Print legacy alerts (no domain tag) under "GENERAL"
LEGACY_LINES=$(echo "$UNREAD" | grep -v '\]\*\* `[a-z]*`' 2>/dev/null || true)
if [ -n "$LEGACY_LINES" ]; then
  echo "📂 GENERAL (no domain tag)"
  echo "$LEGACY_LINES"
  echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "These alerts came from scheduled tasks. Review and act as needed."
echo "To archive after review: bash .claude/hooks/archive-alerts.sh"
