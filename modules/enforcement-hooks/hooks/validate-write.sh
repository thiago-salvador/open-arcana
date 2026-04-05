#!/bin/bash
# PostToolUse hook: validates vault notes AFTER Write/Edit operations
# Receives JSON with tool_input and tool_result on stdin
# Non-blocking: injects warnings via additionalContext

VAULT="{{VAULT_PATH}}"
INPUT=$(cat)

# Extract file_path from tool_input
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input', {})
    print(ti.get('file_path', ''))
except:
    print('')
" 2>/dev/null)

# Gate: only validate .md files in vault subdirectories, skip root files, .claude/, Templates
if [[ "$FILE_PATH" != "$VAULT"/*.md ]] || \
   [[ "$FILE_PATH" == *".claude/"* ]] || \
   [[ "$FILE_PATH" == *"80-Templates/"* ]] || \
   [[ "$FILE_PATH" == *"node_modules"* ]] || \
   [[ "$FILE_PATH" == *".git/"* ]]; then
  exit 0
fi
# Skip root-level files (CLAUDE.md, README.md, etc.). Only validate notes in subdirectories
RELATIVE="${FILE_PATH#$VAULT/}"
if [[ "$RELATIVE" != */* ]]; then
  exit 0
fi

# Gate: file must exist on disk
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

BASENAME=$(basename "$FILE_PATH" .md)
ERRORS=""

# Check 1: Frontmatter exists
FIRST_LINE=$(head -1 "$FILE_PATH")
if [[ "$FIRST_LINE" != "---" ]]; then
  ERRORS="${ERRORS}FRONTMATTER MISSING. "
else
  # Extract frontmatter (between first --- and second ---), macOS compatible
  FM=$(awk 'NR==1{next} /^---$/{exit} {print}' "$FILE_PATH")

  # Check required fields (skip index.md which may have lighter frontmatter)
  if [[ "$BASENAME" != "index" ]]; then
    for field in title summary type domain tags status created; do
      if ! echo "$FM" | grep -q "^${field}:"; then
        ERRORS="${ERRORS}Missing field: ${field}. "
      fi
    done
  fi

  # Check type enum
  TYPE_VAL=$(echo "$FM" | grep "^type:" | sed 's/type: *//' | tr -d '"' | tr -d "'" | xargs)
  VALID_TYPES="concept project reference meeting daily moc template person event decision error-solution devlog toolbox knowledge hub"
  if [[ -n "$TYPE_VAL" ]] && ! echo " $VALID_TYPES " | grep -q " $TYPE_VAL "; then
    ERRORS="${ERRORS}Invalid type: '$TYPE_VAL'. "
  fi

  # Check domain enum
  DOMAIN_VAL=$(echo "$FM" | grep "^domain:" | sed 's/domain: *//' | tr -d '"' | tr -d "'" | xargs)
  VALID_DOMAINS="${DOMAINS:-zaaz mode content partnerships speaking research personal}"
  if [[ -n "$DOMAIN_VAL" ]] && ! echo " $VALID_DOMAINS " | grep -q " $DOMAIN_VAL "; then
    ERRORS="${ERRORS}Invalid domain: '$DOMAIN_VAL'. "
  fi
fi

# Check 2: At least one wikilink (skip Daily Notes and index files)
if [[ "$FILE_PATH" != *"Daily-Notes/"* ]] && [[ "$BASENAME" != "index" ]] && [[ "$BASENAME" != "MEMORY" ]]; then
  if ! grep -q '\[\[' "$FILE_PATH"; then
    ERRORS="${ERRORS}No wikilinks (note may be isolated). "
  fi
fi

# Check 3: Descriptive filename
BAD_NAMES="note untitled new temp test"
LOWER_NAME=$(echo "$BASENAME" | tr '[:upper:]' '[:lower:]')
for bad in $BAD_NAMES; do
  if [[ "$LOWER_NAME" == "$bad" ]]; then
    ERRORS="${ERRORS}Generic filename '$BASENAME'. "
    break
  fi
done

# Output
if [[ -n "$ERRORS" ]]; then
  ESCAPED=$(echo "$ERRORS" | sed 's/"/\\"/g')
  echo "{\"hookSpecificOutput\":{\"additionalContext\":\"VAULT VALIDATION (post-write): ${ESCAPED}Fix in: $FILE_PATH\"}}"
else
  exit 0
fi
