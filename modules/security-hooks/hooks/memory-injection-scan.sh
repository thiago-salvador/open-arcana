#!/bin/bash
# Memory Injection Scanner: PreToolUse hook for Write|Edit
# Blocks prompt injection patterns in memory files before they're written
# Adapted from Hermes Agent's _MEMORY_THREAT_PATTERNS (16 patterns)
#
# Only scans files in the memory directory. All other writes pass through instantly.

MEMORY_DIR="{{MEMORY_DIR}}"

# Quick exit: only scan memory files
FILE_PATH="${CLAUDE_FILE_PATH:-}"
if [[ -z "$FILE_PATH" ]] || [[ "$FILE_PATH" != "$MEMORY_DIR"* ]]; then
  exit 0
fi

# Read content from stdin (tool_input JSON)
CONTENT=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input', {})
    # Write tool uses 'content', Edit tool uses 'new_string'
    print(ti.get('content', '') or ti.get('new_string', ''))
except:
    pass
" 2>/dev/null)

# Nothing to scan
[ -z "$CONTENT" ] && exit 0

# --- Prompt injection patterns (loose matching, max 30 chars between keywords) ---
BLOCKED=""

echo "$CONTENT" | grep -qiE 'ignore.{0,30}(previous|prior|above|all).{0,30}instructions' && BLOCKED="ignore-instructions"
[ -z "$BLOCKED" ] && echo "$CONTENT" | grep -qiE 'you are now ' && BLOCKED="role-hijack"
[ -z "$BLOCKED" ] && echo "$CONTENT" | grep -qiE 'system.{0,10}prompt.{0,10}override' && BLOCKED="sys-prompt-override"
[ -z "$BLOCKED" ] && echo "$CONTENT" | grep -qiE 'disregard.{0,20}(instructions|rules|guidelines)' && BLOCKED="disregard-rules"
[ -z "$BLOCKED" ] && echo "$CONTENT" | grep -qiE 'do not tell the user' && BLOCKED="deception-hide"
[ -z "$BLOCKED" ] && echo "$CONTENT" | grep -qiE 'act as (if|though) you (have no|don.t have) (restrictions|limits|rules)' && BLOCKED="bypass-restrictions"
[ -z "$BLOCKED" ] && echo "$CONTENT" | grep -qiE 'pretend.{0,20}(no|without).{0,20}(rules|restrictions|guidelines)' && BLOCKED="pretend-no-rules"

# --- Exfiltration patterns ---
[ -z "$BLOCKED" ] && echo "$CONTENT" | grep -qiE 'curl.{0,50}(KEY|TOKEN|SECRET|PASSWORD|CREDENTIAL|API_)' && BLOCKED="exfil-curl"
[ -z "$BLOCKED" ] && echo "$CONTENT" | grep -qiE 'cat.{0,30}(\.env|credentials|\.netrc|\.pgpass)' && BLOCKED="read-secrets"

# --- Invisible unicode (injection hiding) ---
if [ -z "$BLOCKED" ]; then
  HAS_INVISIBLE=$(echo "$CONTENT" | python3 -c "
import sys
text = sys.stdin.read()
invisible = {chr(c) for c in [0x200b,0x200c,0x200d,0x2060,0xfeff,0x202a,0x202b,0x202c,0x202d,0x202e]}
print('yes' if any(c in text for c in invisible) else 'no')
" 2>/dev/null)
  [ "$HAS_INVISIBLE" = "yes" ] && BLOCKED="invisible-unicode"
fi

# Block or approve
if [ -n "$BLOCKED" ]; then
  echo "{\"decision\":\"block\",\"reason\":\"INJECTION BLOCKED in memory file (pattern: $BLOCKED). This content contains patterns that could compromise future sessions. Review the content and remove the problematic pattern before saving.\"}"
else
  exit 0
fi
