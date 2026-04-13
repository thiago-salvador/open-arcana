#!/bin/bash
# Alert System for Scheduled Tasks & Automation
# Creates persistent alerts in the vault's alerts queue
#
# Usage: bash alert.sh <priority> <source> <domain> <message>
# Priority: urgent | high | normal
# Source: identifier for the alert origin (e.g., teams-sync, email-scan, follow-up-tracker)
# Domain: your project/context domain (e.g., work, personal, content, research)
#
# Backward-compatible: 3 args = legacy (domain defaults to "personal")
#   bash alert.sh <priority> <source> <message>
#
# Examples:
#   bash alert.sh urgent email-scan work "CI pipeline failed on main branch"
#   bash alert.sh high post-meeting-check work "2 meetings processed with 5 action items"
#   bash alert.sh normal follow-up-tracker personal "3 items overdue >3 days"

VAULT_PATH="{{VAULT_PATH}}"
ALERTS_FILE="$VAULT_PATH/00-Dashboard/alerts.md"
PRIORITY="${1:-normal}"
SOURCE="${2:-unknown}"

# Domain validation list — customize with your own domains
# Add domains that match your vault structure (folder prefixes, project names, etc.)
VALID_DOMAINS="work|personal|content|research|partnerships|speaking"

# Backward-compatible: detect 3-arg (legacy) vs 4-arg (new) invocation
if [ $# -ge 4 ]; then
  # 4+ args: new format. Validate domain, default to "personal" if invalid.
  if echo "$3" | grep -qE "^($VALID_DOMAINS)$"; then
    DOMAIN="$3"
  else
    DOMAIN="personal"
  fi
  MESSAGE="${4:-No message}"
elif [ $# -eq 3 ]; then
  # Legacy 3-arg call: no domain
  DOMAIN="personal"
  MESSAGE="${3:-No message}"
else
  DOMAIN="personal"
  MESSAGE="No message"
fi
TIMESTAMP=$(date +"%Y-%m-%d %H:%M")

# Create alerts file if it doesn't exist
if [ ! -f "$ALERTS_FILE" ]; then
  cat > "$ALERTS_FILE" << 'HEADER'
---
title: "Alerts Queue"
summary: "Alert queue from scheduled tasks and automation — read on each session boot"
type: toolbox
domain: personal
tags: [alerts, automation]
status: active
---

## Unread Alerts

## Read Alerts

HEADER
fi

# Map priority to emoji
case "$PRIORITY" in
  urgent) EMOJI="🔴" ;;
  high)   EMOJI="🟡" ;;
  normal) EMOJI="🔵" ;;
  *)      EMOJI="⚪" ;;
esac

ALERT_LINE="- ${EMOJI} **[${SOURCE}]** \`${DOMAIN}\` ${TIMESTAMP} — ${MESSAGE}"

# Insert alert at end of "## Unread Alerts" section (before next ## header)
# This avoids appending to EOF which would land after "## Read Alerts"
NEXT_SECTION_LINE=$(awk '/^## Unread Alerts$/{found=1; next} found && /^## /{print NR; exit}' "$ALERTS_FILE")

if [ -n "$NEXT_SECTION_LINE" ]; then
  # There's a section after Unread — insert before it
  TMPFILE="${ALERTS_FILE}.tmp"
  head -n $((NEXT_SECTION_LINE - 1)) "$ALERTS_FILE" > "$TMPFILE"
  echo "$ALERT_LINE" >> "$TMPFILE"
  tail -n +"${NEXT_SECTION_LINE}" "$ALERTS_FILE" >> "$TMPFILE"
  mv "$TMPFILE" "$ALERTS_FILE"
else
  # No section after Unread (fresh file), safe to append
  echo "$ALERT_LINE" >> "$ALERTS_FILE"
fi

# macOS notification for urgent and high priority (optional, fails silently on Linux)
if [ "$PRIORITY" = "urgent" ] || [ "$PRIORITY" = "high" ]; then
  SAFE_MSG=$(echo "$MESSAGE" | sed 's/"/\\"/g; s/\\/\\\\/g')
  SAFE_SRC=$(echo "$SOURCE" | sed 's/"/\\"/g; s/\\/\\\\/g')
  osascript -e "display notification \"${SAFE_MSG}\" with title \"Claude Alert (${SAFE_SRC})\" subtitle \"${PRIORITY}\"" 2>/dev/null || true
fi
