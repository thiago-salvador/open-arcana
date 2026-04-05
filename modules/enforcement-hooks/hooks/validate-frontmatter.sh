#!/bin/bash
# PreToolUse hook: validates frontmatter on Write to vault
# Reads tool input from stdin, checks if file is in vault and has frontmatter

VAULT="{{VAULT_PATH}}"
INPUT=$(cat)

# Extract file_path and first 10 chars of content using jq
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
CONTENT_START=$(echo "$INPUT" | jq -r '.tool_input.content // "" | .[0:10]' 2>/dev/null)

# Only check .md files in the vault (not .claude/, not settings)
if [[ "$FILE_PATH" == "$VAULT"/* && "$FILE_PATH" == *.md && "$FILE_PATH" != *".claude/"* ]]; then
  # Check if content starts with frontmatter delimiter
  if [[ "$CONTENT_START" != "---"* ]]; then
    echo '{"hookSpecificOutput":{"additionalContext":"FRONTMATTER MISSING: This vault note is being created WITHOUT YAML frontmatter (---). Every vault note MUST have: title, summary, type, domain, tags, status, created. Add frontmatter before writing."}}'
  else
    echo '{"decision":"approve"}'
  fi
else
  echo '{"decision":"approve"}'
fi
