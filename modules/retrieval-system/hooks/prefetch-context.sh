#!/bin/bash
# Engram-inspired prefetch: when a vault file changes, inject domain context
# Triggered by FileChanged hook event
# Maps file path -> domain -> suggests related notes from concept-index
#
# CONFIGURATION:
# Set VAULT to your vault path, or the script reads from arcana.config.yaml
# Domain mappings are configurable via arcana.config.yaml
#
# PERMISSION SCOPE:
# ALLOWED: Files within $VAULT (vault)
# ALLOWED: $HOME/.claude/ config files
# NOT ALLOWED: $HOME/.ssh/, $HOME/.aws/, $HOME/.env, credentials
# NOT ALLOWED: Files outside vault and .claude/ directories

# --- Configuration ---
# Try to read vault path from config, fall back to env or default
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE=""

# Search for config file upward from script location
_search="$SCRIPT_DIR"
while [ "$_search" != "/" ]; do
  if [ -f "$_search/arcana.config.yaml" ]; then
    CONFIG_FILE="$_search/arcana.config.yaml"
    break
  fi
  _search="$(dirname "$_search")"
done

# If config exists, try to read VAULT from it (simple grep, no yq dependency)
if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
  _vault_from_config=$(grep "^vault_path:" "$CONFIG_FILE" 2>/dev/null | sed 's/^vault_path:[[:space:]]*//' | tr -d '"' | tr -d "'")
  [ -n "$_vault_from_config" ] && VAULT="$_vault_from_config"
fi

# Fall back to environment variable or placeholder
VAULT="${VAULT:-{{VAULT_PATH}}}"
CLAUDE_DIR="$HOME/.claude"
FILE_PATH="${CLAUDE_FILE_PATH:-$1}"

# Validate path is within allowed scope
if [[ "$FILE_PATH" != "$VAULT"* ]] && [[ "$FILE_PATH" != "$CLAUDE_DIR"* ]]; then
  exit 0
fi

# Block sensitive paths explicitly
if [[ "$FILE_PATH" == *"/.ssh/"* ]] || \
   [[ "$FILE_PATH" == *"/.aws/"* ]] || \
   [[ "$FILE_PATH" == *"/.env"* ]] || \
   [[ "$FILE_PATH" == *"/credentials"* ]] || \
   [[ "$FILE_PATH" == *"/secrets"* ]]; then
  echo "Prefetch blocked: path outside allowed scope"
  exit 1
fi

# Skip non-vault files (redundant with scope check above, kept for clarity)
[[ "$FILE_PATH" != "$VAULT"* ]] && exit 0

# Skip noise files
[[ "$FILE_PATH" == *".DS_Store"* ]] && exit 0
[[ "$FILE_PATH" == *"node_modules"* ]] && exit 0
[[ "$FILE_PATH" == *".git/"* ]] && exit 0

# Extract relative path
REL_PATH="${FILE_PATH#$VAULT/}"

# --- Domain Detection ---
# Domains are detected from the file path. The mapping below is the default.
# To customize, edit the case block or provide domain overrides in arcana.config.yaml.
#
# Default vault structure assumed:
#   10-Work/        -> work (with sub-domains: product, growth, analytics, meetings, errors)
#   15-Projects/    -> projects
#   20-Studio/      -> studio
#   25-Agency/      -> agency
#   30-Content/     -> content (with sub-domains: social, articles, linkedin)
#   60-Research/    -> research
#   70-People/      -> people
#   85-Rules/       -> rules
#   Daily-Notes/    -> daily

DOMAIN=""
DOMAIN_PATH=""
case "$REL_PATH" in
  10-Work/Product/*|10-Work/Produto/*) DOMAIN="work-product"; DOMAIN_PATH="10-Work/Product" ;;
  10-Work/Growth/*) DOMAIN="work-growth"; DOMAIN_PATH="10-Work/Growth" ;;
  10-Work/Analytics/*) DOMAIN="work-analytics"; DOMAIN_PATH="10-Work/Analytics" ;;
  10-Work/Meetings/*|10-Work/Reuniões/*) DOMAIN="work-meetings"; DOMAIN_PATH="10-Work/Meetings" ;;
  10-Work/Errors/*|10-Work/Erros/*) DOMAIN="work-errors"; DOMAIN_PATH="10-Work/Errors" ;;
  10-Work/*) DOMAIN="work"; DOMAIN_PATH="10-Work" ;;
  15-Projects/*) DOMAIN="projects"; DOMAIN_PATH="15-Projects" ;;
  20-Studio/*) DOMAIN="studio"; DOMAIN_PATH="20-Studio" ;;
  25-Agency/*) DOMAIN="agency"; DOMAIN_PATH="25-Agency" ;;
  30-Content/31-*/*|30-Content/Social/*) DOMAIN="social"; DOMAIN_PATH="30-Content" ;;
  30-Content/33-*/*|30-Content/LinkedIn/*) DOMAIN="linkedin"; DOMAIN_PATH="30-Content" ;;
  30-Content/32-*/*|30-Content/Articles/*) DOMAIN="articles"; DOMAIN_PATH="30-Content" ;;
  30-Content/*) DOMAIN="content"; DOMAIN_PATH="30-Content" ;;
  60-Research/*|60-Pesquisa/*) DOMAIN="research"; DOMAIN_PATH="60-Research" ;;
  70-People/*|70-Pessoas/*) DOMAIN="people"; DOMAIN_PATH="70-People" ;;
  85-Rules/*) DOMAIN="rules"; DOMAIN_PATH="85-Rules" ;;
  Daily-Notes/*) DOMAIN="daily"; DOMAIN_PATH="Daily-Notes" ;;
  *) exit 0 ;;  # Unknown domain, skip
esac

# Extract filename for context
FILENAME=$(basename "$FILE_PATH" .md)

# Build prefetch context
echo "Prefetch Context (Engram-inspired)"
echo "File: $REL_PATH"
echo "Domain: $DOMAIN"
echo ""

# --- Domain-specific suggestions ---
# These are generic templates. Customize with your actual note names and hot-cache entries.
case "$DOMAIN" in
  work-product)
    echo "Related context:"
    echo "  - Check concept-index for product-related entries"
    echo "  - Hot Cache: check 10-Work/Product/ for active feature notes"
    echo "  - Look for sprint planning and roadmap notes"
    ;;
  work-growth)
    echo "Related context:"
    echo "  - Check concept-index for growth strategy entries"
    echo "  - Look for nurture, outreach, and funnel notes"
    ;;
  work-meetings)
    echo "Related context:"
    echo "  - Check recent meeting notes in the same folder"
    echo "  - Process with: Read.AI MCP -> vault -> Notion tasks"
    ;;
  studio)
    echo "Related context:"
    echo "  - Check studio pipeline and active projects"
    echo "  - Look for partner and client notes in 70-People/"
    ;;
  content|social|linkedin|articles)
    echo "Related context:"
    echo "  - Check brand/editorial identity notes in 30-Content/"
    echo "  - Look for content pipeline and idea bank notes"
    echo "  - Cross-reference with 60-Research/ for source material"
    ;;
  research)
    echo "Related context:"
    echo "  - Check active research themes and trends"
    echo "  - Cross-reference with content pipeline for publication opportunities"
    echo "  - Look for related MOCs"
    ;;
  people)
    echo "Related context:"
    echo "  - Check aliases.md for person's canonical name"
    echo "  - Cross-reference: Teams chats, Read.AI meetings, Gmail, iMessages"
    echo "  - Look for meeting notes mentioning this person"
    ;;
  projects)
    echo "Related context:"
    echo "  - Full project list: [[15-Projects/index]]"
    echo "  - Check related rules in 85-Rules/"
    ;;
  daily)
    echo "Context: Daily Note editing. Check Estado Atual section for continuity."
    ;;
esac

echo ""
echo "Retrieval strategy: concept-index -> aliases -> filtered grep -> Smart Connections"
