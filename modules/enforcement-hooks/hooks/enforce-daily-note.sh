#!/bin/bash
# enforce-daily-note.sh: Blocks any tool use if today's Daily Note doesn't exist
# Runs as PreToolUse hook. Returns JSON to block or allow.
# Exception: allows Write and Bash targeting the Daily Note itself (prevents deadlock)

TODAY=$(date +%Y-%m-%d)
DN="{{VAULT_PATH}}/Daily-Notes/$TODAY.md"
mkdir -p "$HOME/.claude/logs"

# If Daily Note exists, allow everything (fast path)
if [ -f "$DN" ]; then
  echo '{"decision":"allow"}'
  exit 0
fi

# DN doesn't exist. Read tool input from stdin (Claude Code passes JSON via stdin)
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null)
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)

# Allow if the tool targets the Daily Note path (prevents deadlock)
if echo "$FILE_PATH" | grep -q "Daily-Notes/$TODAY" 2>/dev/null; then
  echo "$(date +%Y-%m-%dT%H:%M:%S) [enforce-daily-note] decision=allow reason=dn-creation date=$TODAY" >> "$HOME/.claude/logs/hooks.log" 2>/dev/null
  echo '{"decision":"allow"}'
  exit 0
fi

# Allow Bash commands that target the Daily Note
if echo "$COMMAND" | grep -q "Daily-Notes/$TODAY" 2>/dev/null; then
  echo "$(date +%Y-%m-%dT%H:%M:%S) [enforce-daily-note] decision=allow reason=dn-bash-creation date=$TODAY" >> "$HOME/.claude/logs/hooks.log" 2>/dev/null
  echo '{"decision":"allow"}'
  exit 0
fi

# Block everything else until DN is created
echo "$(date +%Y-%m-%dT%H:%M:%S) [enforce-daily-note] decision=block reason=dn-missing date=$TODAY" >> "$HOME/.claude/logs/hooks.log" 2>/dev/null
echo '{"decision":"block","reason":"Daily Note '"$TODAY"' does not exist. Create the Daily Note BEFORE any other action. Path: '"$DN"'"}'
