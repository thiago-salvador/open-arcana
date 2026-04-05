#!/bin/bash
# Stop hook: lightweight Daily Note logging enforcement
# Checks if today's DN has any timestamped log entries (HH:MM pattern).
# If not, warns the agent but DOES NOT block (always approves).
# This replaces both the old blocking approach (DIFF -gt 300) and the no-op.

TODAY=$(date +%Y-%m-%d)
DAILY="{{VAULT_PATH}}/Daily-Notes/$TODAY.md"

# Always approve. This hook never blocks
APPROVE='{"decision":"approve"}'

if [ ! -f "$DAILY" ]; then
  echo "{\"decision\":\"approve\",\"hookSpecificOutput\":{\"additionalContext\":\"WARNING: Daily Note $TODAY.md does not exist. Create it and log actions before ending the session.\"}}"
  exit 0
fi

# Count timestamped log entries (lines like "- HH:MM" which is the logging format)
LOG_COUNT=$(grep -cE '^\s*-\s+[0-2][0-9]:[0-5][0-9]' "$DAILY" 2>/dev/null || echo 0)

if [ "$LOG_COUNT" -eq 0 ]; then
  echo "{\"decision\":\"approve\",\"hookSpecificOutput\":{\"additionalContext\":\"WARNING: Daily Note exists but has 0 timestamped log entries. Core rule #1: log EVERY action to Daily Note.\"}}"
else
  echo "$APPROVE"
fi
