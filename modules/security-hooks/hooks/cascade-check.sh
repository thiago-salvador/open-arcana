#!/bin/bash
# PostToolUse hook: reminds about cascade edits after modifying vault notes
# Fires after Edit on vault .md files (not Daily Notes, not .claude/)
# Injects a reminder to check for cross-references that need updating

VAULT="{{VAULT_PATH}}"
INPUT=$(cat)

# Extract file_path
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

# Only trigger for vault .md files (not Daily Notes, not .claude/, not settings)
if [[ "$FILE_PATH" == "$VAULT"/* && "$FILE_PATH" == *.md && \
      "$FILE_PATH" != *".claude/"* && \
      "$FILE_PATH" != *"Daily-Notes/"* && \
      "$FILE_PATH" != *"index.md" ]]; then

  NOTE=$(basename "$FILE_PATH" .md)
  # Check if this is a high-risk file (person, project, rule)
  if [[ "$FILE_PATH" == *"70-Pessoas/"* || \
        "$FILE_PATH" == *"10-"* || \
        "$FILE_PATH" == *"15-Projetos/"* || \
        "$FILE_PATH" == *"85-Rules/"* ]]; then
    echo "{\"hookSpecificOutput\":{\"additionalContext\":\"CASCADE CHECK: You just edited '${NOTE}'. If you changed a FACT (role, status, name, location): (1) grep vault for the old value (2) Check: concept-index, aliases, domain rules, memory files (3) Update ALL locations. Fact changes in one file without updating references cause inconsistencies that compound over time.\"}}"
  fi
else
  # Not a vault note, no action
  true
fi
