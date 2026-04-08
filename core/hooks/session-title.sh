#!/bin/bash
# session-title.sh — UserPromptSubmit hook
# Auto-sets session title based on slash commands or domain keywords.
# Requires Claude Code >= 2.1.94 (hookSpecificOutput.sessionTitle)
# Output: JSON with sessionTitle field for --resume display

VAULT_PATH="{{VAULT_PATH}}"

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('prompt', d.get('user_prompt', '')))
except:
    print('')
" 2>/dev/null)

# Skip if prompt is empty
[ -z "$PROMPT" ] && exit 0

TITLE=""

# Detect slash commands first (highest priority)
if echo "$PROMPT" | grep -qE '^\s*/'; then
    SLASH=$(echo "$PROMPT" | grep -oE '^\s*/[a-z_-]+' | tr -d ' ')
    case "$SLASH" in
        /start)           TITLE="Morning Kickoff" ;;
        /end)             TITLE="End of Day" ;;
        /recap)           TITLE="Day Recap" ;;
        /weekly)          TITLE="Weekly Review" ;;
        /dump)            TITLE="Brain Dump" ;;
        /capture)         TITLE="Knowledge Capture" ;;
        /process)         TITLE="Material Processing" ;;
        /pessoa)          TITLE="Person Briefing" ;;
        /post-meeting)    TITLE="Post-Meeting" ;;
        /health)          TITLE="Vault Health" ;;
        /scan)            TITLE="File Scan" ;;
        /connections)     TITLE="Cross-Domain Links" ;;
        /link-check)      TITLE="Link Check" ;;
        /audit-gaps)      TITLE="Gap Audit" ;;
        /sync-all)        TITLE="Full Sync" ;;
        /ship)            TITLE="Ship Pipeline" ;;
        /commit)          TITLE="Git Commit" ;;
        /contrarian)      TITLE="Contrarian Review" ;;
        /distill)         TITLE="Workflow Distill" ;;
        /model-review)    TITLE="Model Review" ;;
        *)                TITLE="Vault: $SLASH" ;;
    esac
fi

# If no slash command, detect domain from keywords
if [ -z "$TITLE" ]; then
    PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

    if echo "$PROMPT_LOWER" | grep -qE '\bvault\b|obsidian\b|hook\b|rule\b|skill\b|plugin\b|claude.md\b'; then
        TITLE="Vault Ops"
    elif echo "$PROMPT_LOWER" | grep -qE '\bdeploy\b|vercel\b|supabase\b|firebase\b|build\b'; then
        TITLE="Dev/Deploy"
    elif echo "$PROMPT_LOWER" | grep -qE '\bpost\b|artigo\b|content\b|linkedin\b|instagram\b'; then
        TITLE="Content"
    elif echo "$PROMPT_LOWER" | grep -qE '\bdebug\b|fix\b|error\b|bug\b|broken\b'; then
        TITLE="Debug"
    fi
fi

# Only output if we detected something (don't override manual titles)
if [ -n "$TITLE" ]; then
    echo "{\"hookSpecificOutput\":{\"sessionTitle\":\"$TITLE\"}}"
fi
