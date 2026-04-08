#!/bin/bash
# PreToolUse hook: guards against fabricating people data
# Fires on Write AND Edit to 70-People/ files
# Injects a warning reminder, does NOT block (blocking would break legitimate edits)

VAULT="{{VAULT_PATH}}"
INPUT=$(cat)

# Extract file_path from tool input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

# Only trigger for 70-People/ markdown files
if [[ "$FILE_PATH" == "$VAULT/70-People/"* && "$FILE_PATH" == *.md ]]; then
  PERSON=$(basename "$FILE_PATH" .md)
  echo "{\"hookSpecificOutput\":{\"additionalContext\":\"PEOPLE GUARD: You are editing ${PERSON}'s note. BEFORE writing ANY fact (location, role, background, employer): (1) Can you trace it to a PRIMARY SOURCE (chat message, meeting transcript, LinkedIn, user statement)? (2) If NO, write 'unconfirmed' or leave blank. (3) NEVER infer or fabricate. This hook exists because past sessions fabricated people data that was later treated as fact.\"}}"
else
  echo '{"decision":"approve"}'
fi
