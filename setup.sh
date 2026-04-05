#!/usr/bin/env bash
set -euo pipefail

# Open Arcana Setup Wizard
# Compatible with bash 3.2+ (macOS default)
VERSION="1.0.0"

# ── Colors ─────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[1;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Module registry (indexed arrays, bash 3.2 compatible) ─────────
MODULE_KEYS=(anti-sycophancy token-efficiency enforcement-hooks security-hooks vault-structure retrieval-system commands connected-sources scheduled-tasks vault-health)

MODULE_NAMES=(
  "Anti-Sycophancy Protocol"
  "Token Efficiency Rules"
  "Enforcement Hooks"
  "Security Hooks"
  "Vault Structure + Templates"
  "Retrieval System (Engram)"
  "Slash Commands (18 commands)"
  "Connected Sources Config"
  "Scheduled Tasks"
  "Vault Health Checks"
)

MODULE_DESCS=(
  "6 rules that prevent AI from agreeing without evidence."
  "14 rules to minimize context waste and API costs."
  "Validates frontmatter, enforces daily notes, checks writes."
  "Blocks prompt injection in memory files, guards people data."
  "Opinionated folder structure with 18 note templates."
  "4-layer lookup: concept-index > grep > semantic > fallback."
  "/start, /end, /weekly, /health, /dump, /capture, and more."
  "Template for orchestrating 16+ MCP data sources."
  "Templates for morning briefing, end-of-day, weekly review."
  "500+ automated checks for vault consistency."
)

MODULE_DESCS2=(
  "Adds confidence tags, challenge-previous, conflict reports."
  "Cache awareness, retrieval budgets, output discipline."
  "4 hooks that run automatically on Edit/Write operations."
  "4 hooks for memory safety and data integrity."
  "Includes scaffold script to create the full directory tree."
  "Manages context budget (20% retrieval, 80% reasoning)."
  "Daily workflows automated as Claude Code commands."
  "Teams, Notion, Calendar, Read.AI, GitHub, etc."
  "Patterns for autonomous recurring agent tasks."
  "Frontmatter, orphans, broken links, index sync."
)

# Category grouping: indices into MODULE_KEYS
CAT_NAMES=("GUARDRAILS" "ENFORCEMENT" "VAULT MANAGEMENT" "AUTOMATION")
CAT_INDICES_0="0 1"
CAT_INDICES_1="2 3"
CAT_INDICES_2="4 5"
CAT_INDICES_3="6 7 8 9"

# Module activation state (Y/N), same order as MODULE_KEYS
MODULE_ACTIVE=(Y Y Y Y Y Y Y Y Y Y)

INSTALLED_FILES=0
INSTALLED_HOOKS=0
INSTALLED_COMMANDS=0

# ── Helpers ────────────────────────────────────────────────────────

get_cat_indices() {
  case $1 in
    0) echo $CAT_INDICES_0 ;; 1) echo $CAT_INDICES_1 ;;
    2) echo $CAT_INDICES_2 ;; 3) echo $CAT_INDICES_3 ;;
  esac
}

print_header() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${CYAN}  $1${RESET}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

print_progress() {
  local step=$1 total=$2
  local pct=$(( step * 100 / total ))
  local filled=$(( step * 20 / total ))
  local empty=$(( 20 - filled ))
  local bar=""
  local i
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  echo -e "  ${DIM}[${bar}] ${pct}%${RESET}"
  echo ""
}

hint()    { echo -e "    ${DIM}⚡ $1${RESET}"; }
success() { echo -e "  ${GREEN}→ $1${RESET}  ${GREEN}✓${RESET}"; }
error()   { echo -e "  ${RED}✗ $1${RESET}"; }

ask() {
  local prompt=$1 default=${2:-""} var_name=$3
  if [[ -n "$default" ]]; then
    echo -ne "  ${BOLD}${prompt}${RESET} ${DIM}[${default}]${RESET}: "
  else
    echo -ne "  ${BOLD}${prompt}${RESET}: "
  fi
  local input
  read -r input
  input="${input:-$default}"
  # Sanitize: strip characters that could break shell or sed
  input=$(printf '%s' "$input" | tr -d '\n\r' | sed 's/[`$"\\]//g')
  printf -v "$var_name" '%s' "$input"
}

ask_yn() {
  local prompt=$1 default=${2:-"Y"} var_name=$3
  if [[ "$default" == "Y" ]]; then
    echo -ne "    ${BOLD}[Y/n]${RESET} ${BOLD}$prompt${RESET} "
  else
    echo -ne "    ${BOLD}[y/N]${RESET} ${BOLD}$prompt${RESET} "
  fi
  local input
  read -r input
  input="${input:-$default}"
  input=$(echo "$input" | tr '[:lower:]' '[:upper:]')
  # Only accept Y or N
  if [[ "$input" != "Y" && "$input" != "N" ]]; then
    input="$default"
  fi
  printf -v "$var_name" '%s' "$input"
}

validate_path() {
  local path=$1
  path="${path/#\~/$HOME}"
  if [[ ! -d "$path" ]]; then
    error "Directory does not exist: $path"
    return 1
  fi
  echo "$path"
}

splash() {
  clear 2>/dev/null || true
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
  echo -e "${CYAN}║                                              ║${RESET}"
  echo -e "${CYAN}║     ${BOLD}◆  O P E N   A R C A N A  ◆${RESET}${CYAN}             ║${RESET}"
  echo -e "${CYAN}║                                              ║${RESET}"
  echo -e "${CYAN}║     AI Agent Orchestration Framework         ║${RESET}"
  echo -e "${CYAN}║     for Obsidian + Claude Code               ║${RESET}"
  echo -e "${CYAN}║                                              ║${RESET}"
  echo -e "${CYAN}║     v${VERSION}                                   ║${RESET}"
  echo -e "${CYAN}║                                              ║${RESET}"
  echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"
  echo ""
}

cleanup() {
  echo ""
  echo -e "  ${YELLOW}Setup cancelled. No files were modified.${RESET}"
  echo ""
  exit 1
}
trap cleanup INT

derive_memory_dir() {
  local vault_path=$1
  local encoded_path
  encoded_path=$(echo "$vault_path" | sed 's|/|-|g')
  echo "$HOME/.claude/projects/${encoded_path}/memory"
}

# ── Template processing ───────────────────────────────────────────

escape_sed() {
  # Escape characters that are special in sed replacement strings
  printf '%s' "$1" | sed -e 's/[&/\]/\\&/g'
}

process_template() {
  local src=$1 dst=$2
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"

  # Escape all values for safe sed replacement (handles / | & \ in paths)
  local e_name e_role e_lang e_vault e_mem e_notion e_email e_domain e_company e_domains
  e_name=$(escape_sed "$USER_NAME")
  e_role=$(escape_sed "$USER_ROLE")
  e_lang=$(escape_sed "$USER_LANG")
  e_vault=$(escape_sed "$VAULT_PATH")
  e_mem=$(escape_sed "$MEMORY_DIR")
  e_notion=$(escape_sed "$NOTION_DB_ID")
  e_email=$(escape_sed "$USER_EMAIL")
  e_domain=$(escape_sed "$PRIMARY_DOMAIN")
  e_company=$(escape_sed "$COMPANY")
  e_domains=$(escape_sed "$DOMAINS")

  sed -i.bak \
    -e "s/{{USER_NAME}}/${e_name}/g" \
    -e "s/{{USER_ROLE}}/${e_role}/g" \
    -e "s/{{USER_LANG}}/${e_lang}/g" \
    -e "s/{{VAULT_PATH}}/${e_vault}/g" \
    -e "s/{{MEMORY_DIR}}/${e_mem}/g" \
    -e "s/{{NOTION_DB_ID}}/${e_notion}/g" \
    -e "s/{{USER_EMAIL}}/${e_email}/g" \
    -e "s/{{PRIMARY_DOMAIN}}/${e_domain}/g" \
    -e "s/{{COMPANY}}/${e_company}/g" \
    -e "s/{{DOMAINS}}/${e_domains}/g" \
    "$dst"
  rm -f "${dst}.bak"
  INSTALLED_FILES=$((INSTALLED_FILES + 1))
}

copy_file() {
  local src=$1 dst=$2
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  INSTALLED_FILES=$((INSTALLED_FILES + 1))
}

# ── Install core ──────────────────────────────────────────────────

install_core() {
  local target="$VAULT_PATH/.claude"
  mkdir -p "$target/rules" "$target/hooks" "$target/memory"

  if [[ -f "$target/settings.local.json" ]]; then
    cp "$target/settings.local.json" "$target/settings.local.json.bak"
    success "Backed up existing settings.local.json"
  fi

  process_template "$SCRIPT_DIR/core/CLAUDE.md.template" "$VAULT_PATH/CLAUDE.md"
  success "Processing CLAUDE.md template..."

  copy_file "$SCRIPT_DIR/core/rules/core-rules.md" "$target/rules/core-rules.md"
  success "Creating .claude/rules/..."

  for hook in "$SCRIPT_DIR"/core/hooks/*.sh; do
    local name
    name=$(basename "$hook")
    process_template "$hook" "$target/hooks/$name"
    chmod +x "$target/hooks/$name"
    INSTALLED_HOOKS=$((INSTALLED_HOOKS + 1))
  done
  success "Creating .claude/hooks/..."

  process_template "$SCRIPT_DIR/core/settings.template.json" "$target/settings.local.json"
  success "Wiring hooks into settings.json..."

  mkdir -p "$MEMORY_DIR" 2>/dev/null || true
  if [[ -d "$MEMORY_DIR" ]]; then
    process_template "$SCRIPT_DIR/core/memory/MEMORY.md.template" "$MEMORY_DIR/MEMORY.md"
  fi
  success "Setting up memory system..."
}

# ── Install module ────────────────────────────────────────────────

install_module() {
  local module=$1
  local module_dir="$SCRIPT_DIR/modules/$module"
  local target="$VAULT_PATH/.claude"

  if [[ ! -d "$module_dir" ]]; then
    error "Module not found: $module"
    return 1
  fi

  # Rules
  if [[ -d "$module_dir/rules" ]]; then
    for rule in "$module_dir"/rules/*; do
      [[ -f "$rule" ]] || continue
      local name
      name=$(basename "$rule")
      if [[ "$name" == *.template ]]; then
        process_template "$rule" "$target/rules/${name%.template}"
      else
        copy_file "$rule" "$target/rules/$name"
      fi
    done
  fi

  # Hooks
  if [[ -d "$module_dir/hooks" ]]; then
    for hook in "$module_dir"/hooks/*.sh; do
      [[ -f "$hook" ]] || continue
      local name
      name=$(basename "$hook")
      process_template "$hook" "$target/hooks/$name"
      chmod +x "$target/hooks/$name"
      INSTALLED_HOOKS=$((INSTALLED_HOOKS + 1))
    done
  fi

  # Commands
  if [[ -d "$module_dir/commands" ]]; then
    mkdir -p "$target/commands"
    for cmd in "$module_dir"/commands/*; do
      [[ -f "$cmd" ]] || continue
      local name
      name=$(basename "$cmd")
      if [[ "$name" == *.template ]]; then
        process_template "$cmd" "$target/commands/${name%.template}"
      else
        process_template "$cmd" "$target/commands/$name"
      fi
      INSTALLED_COMMANDS=$((INSTALLED_COMMANDS + 1))
    done
  fi

  # Templates (vault-structure)
  if [[ -d "$module_dir/templates" ]]; then
    mkdir -p "$VAULT_PATH/80-Templates"
    for tmpl in "$module_dir"/templates/*; do
      [[ -f "$tmpl" ]] || continue
      copy_file "$tmpl" "$VAULT_PATH/80-Templates/$(basename "$tmpl")"
    done
  fi

  # Dashboard (retrieval-system)
  if [[ -d "$module_dir/dashboard" ]]; then
    mkdir -p "$VAULT_PATH/00-Dashboard"
    for dash in "$module_dir"/dashboard/*; do
      [[ -f "$dash" ]] || continue
      local name
      name=$(basename "$dash")
      if [[ "$name" == *.template ]]; then
        process_template "$dash" "$VAULT_PATH/00-Dashboard/${name%.template}"
      else
        copy_file "$dash" "$VAULT_PATH/00-Dashboard/$name"
      fi
    done
  fi

  # Examples (scheduled-tasks)
  if [[ -d "$module_dir/examples" ]]; then
    mkdir -p "$target/scheduled-tasks"
    for ex in "$module_dir"/examples/*; do
      [[ -f "$ex" ]] || continue
      copy_file "$ex" "$target/scheduled-tasks/$(basename "$ex")"
    done
  fi

  # Scaffold (vault-structure)
  if [[ -f "$module_dir/scaffold.sh" ]]; then
    bash "$module_dir/scaffold.sh" "$VAULT_PATH"
  fi

  # Vault test (vault-health)
  if [[ -f "$module_dir/vault-test.sh" ]]; then
    process_template "$module_dir/vault-test.sh" "$VAULT_PATH/.vault-test.sh"
    chmod +x "$VAULT_PATH/.vault-test.sh"
  fi

  # Find display name by index
  local display_name="$module"
  local idx
  for idx in "${!MODULE_KEYS[@]}"; do
    if [[ "${MODULE_KEYS[$idx]}" == "$module" ]]; then
      display_name="${MODULE_NAMES[$idx]}"
      break
    fi
  done

  success "Installing ${display_name}..."
}

# ── Generate config ───────────────────────────────────────────────

generate_config() {
  local config_path="$VAULT_PATH/.claude/arcana.config.yaml"
  cat > "$config_path" << YAML
# Open Arcana Configuration
# Generated by setup.sh v${VERSION} on $(date +%Y-%m-%d)

version: "${VERSION}"

profile:
  name: "${USER_NAME}"
  role: "${USER_ROLE}"
  language: "${USER_LANG}"
  vault_path: "${VAULT_PATH}"
  company: "${COMPANY}"
  primary_domain: "${PRIMARY_DOMAIN}"
  domains: "${DOMAINS}"

integrations:
  notion_db_id: "${NOTION_DB_ID}"
  user_email: "${USER_EMAIL}"

modules:
YAML

  local idx
  for idx in "${!MODULE_KEYS[@]}"; do
    if [[ "${MODULE_ACTIVE[$idx]}" == "Y" ]]; then
      echo "  ${MODULE_KEYS[$idx]}: true" >> "$config_path"
    else
      echo "  ${MODULE_KEYS[$idx]}: false" >> "$config_path"
    fi
  done

  success "Generating arcana.config.yaml..."
}

# ── Summary ───────────────────────────────────────────────────────

print_summary() {
  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════╗${RESET}"
  echo -e "${GREEN}║     ✓  Installation Complete!                ║${RESET}"
  echo -e "${GREEN}╚══════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "  Profile:    ${BOLD}${USER_NAME}${RESET} (${USER_ROLE})"
  echo -e "  Vault:      ${BOLD}${VAULT_PATH}${RESET}"
  echo -e "  Language:   ${BOLD}${USER_LANG}${RESET}"
  echo ""
  echo -e "  Modules installed:"

  local idx
  for idx in "${!MODULE_KEYS[@]}"; do
    local mark
    if [[ "${MODULE_ACTIVE[$idx]}" == "Y" ]]; then
      mark="${GREEN}✓${RESET}"
    else
      mark="${DIM}✗${RESET}"
    fi
    printf "    %b %-35s\n" "$mark" "${MODULE_NAMES[$idx]}"
  done

  echo ""
  echo -e "  Files created:  ${BOLD}${INSTALLED_FILES}${RESET}"
  echo -e "  Hooks wired:    ${BOLD}${INSTALLED_HOOKS}${RESET}"
  echo -e "  Commands added: ${BOLD}${INSTALLED_COMMANDS}${RESET}"
  echo -e "  Config:         ${BOLD}${VAULT_PATH}/.claude/arcana.config.yaml${RESET}"
  echo ""
  echo -e "  ${CYAN}◆${RESET} Next steps:"
  echo "    1. Open a Claude Code session in your vault"
  echo "    2. Run /health to verify everything works"
  echo "    3. Run /start to begin your first AI-assisted day"
  echo ""
  echo -e "  ${CYAN}◆${RESET} Manage modules later:"
  echo "    ./setup.sh --add <module>"
  echo "    ./setup.sh --remove <module>"
  echo "    ./setup.sh --list"
  echo ""
}

# ── Presets ────────────────────────────────────────────────────────

apply_preset() {
  local preset=$1
  local idx
  case "$preset" in
    minimal)
      for idx in "${!MODULE_ACTIVE[@]}"; do MODULE_ACTIVE[$idx]="N"; done
      ;;
    writer)
      for idx in "${!MODULE_ACTIVE[@]}"; do MODULE_ACTIVE[$idx]="N"; done
      MODULE_ACTIVE[0]="Y"  # anti-sycophancy
      MODULE_ACTIVE[1]="Y"  # token-efficiency
      MODULE_ACTIVE[4]="Y"  # vault-structure
      MODULE_ACTIVE[5]="Y"  # retrieval-system
      MODULE_ACTIVE[6]="Y"  # commands
      ;;
    full)
      for idx in "${!MODULE_ACTIVE[@]}"; do MODULE_ACTIVE[$idx]="Y"; done
      ;;
    *)
      error "Unknown preset: $preset. Options: minimal, writer, full"
      exit 1
      ;;
  esac
}

# ── Parse arguments ───────────────────────────────────────────────

PRESET=""
DRY_RUN=false
AUTO_YES=false
LIST_MODULES=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --preset)  PRESET="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --yes|-y)  AUTO_YES=true; shift ;;
    --list)    LIST_MODULES=true; shift ;;
    --help|-h)
      echo "Open Arcana Setup v${VERSION}"
      echo ""
      echo "Usage: ./setup.sh [options]"
      echo ""
      echo "Options:"
      echo "  --preset <name>    Use preset (minimal, writer, full)"
      echo "  --yes, -y          Accept all defaults"
      echo "  --dry-run          Show what would be installed"
      echo "  --list             Show available modules"
      echo "  --help, -h         Show this help"
      exit 0
      ;;
    *) error "Unknown option: $1"; exit 1 ;;
  esac
done

# ── List mode ─────────────────────────────────────────────────────

if $LIST_MODULES; then
  echo "Open Arcana Modules:"
  echo ""
  local idx
  for idx in "${!MODULE_KEYS[@]}"; do
    echo "  ${MODULE_KEYS[$idx]}: ${MODULE_NAMES[$idx]}"
  done
  exit 0
fi

# ── Main flow ─────────────────────────────────────────────────────

splash

if [[ -n "$PRESET" ]]; then
  apply_preset "$PRESET"
fi

# Step 1: Profile
print_header "Step 1 of 4: Your Profile"
print_progress 1 4

DEFAULT_NAME=$(git config --global user.name 2>/dev/null || echo "")
DEFAULT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")
DEFAULT_VAULT="$HOME/Documents/Obsidian/Personal"

if $AUTO_YES; then
  USER_NAME="${DEFAULT_NAME:-User}"
  USER_ROLE="Engineer"
  USER_LANG="en"
  VAULT_PATH="$DEFAULT_VAULT"
else
  ask "Your name" "$DEFAULT_NAME" USER_NAME
  hint "Used in CLAUDE.md and rule attribution"
  echo ""

  ask "Your role (e.g. \"Senior Engineer\", \"CTO\")" "" USER_ROLE
  hint "Helps the AI calibrate its responses"
  echo ""

  ask "Primary language" "en" USER_LANG
  hint "en, pt-BR, es, fr, de, ja, ko..."
  echo ""

  local_vault=""
  while [[ -z "$local_vault" ]]; do
    ask "Vault path" "$DEFAULT_VAULT" local_vault
    hint "Must be an existing Obsidian vault directory"
    VAULT_PATH=$(validate_path "$local_vault" 2>/dev/null) || {
      error "Directory not found. Try again."
      local_vault=""
    }
  done
fi

VAULT_PATH="${VAULT_PATH/#\~/$HOME}"
MEMORY_DIR=$(derive_memory_dir "$VAULT_PATH")

# Step 2: Integrations
print_header "Step 2 of 4: Integrations (optional)"
print_progress 2 4

if $AUTO_YES; then
  NOTION_DB_ID=""
  USER_EMAIL="$DEFAULT_EMAIL"
  COMPANY=""
  PRIMARY_DOMAIN="work"
  DOMAINS="work,personal"
else
  ask "Notion tasks database ID" "skip" NOTION_DB_ID
  hint "Find it in your Notion URL: notion.so/[workspace]/[THIS-PART]"
  hint "Leave blank or 'skip' to skip Notion integration"
  [[ "$NOTION_DB_ID" == "skip" ]] && NOTION_DB_ID=""
  echo ""

  ask "Email for notifications" "${DEFAULT_EMAIL:-skip}" USER_EMAIL
  hint "Used by alert hooks (macOS only)"
  [[ "$USER_EMAIL" == "skip" ]] && USER_EMAIL=""
  echo ""

  ask "Company/project name" "skip" COMPANY
  hint "Your primary work context (e.g. \"Acme Corp\")"
  [[ "$COMPANY" == "skip" ]] && COMPANY=""
  echo ""

  ask "Primary domain name" "work" PRIMARY_DOMAIN
  hint "Main category for your notes (e.g. work, research, writing)"
  echo ""

  ask "All domains (comma-separated)" "${PRIMARY_DOMAIN},personal" DOMAINS
  hint "Categories you work across (e.g. work,research,writing,personal)"
fi

# Step 3: Modules
if [[ -z "$PRESET" ]] && ! $AUTO_YES; then
  print_header "Step 3 of 4: Modules"
  print_progress 3 4

  echo -e "  Select which modules to activate:"
  echo -e "  ${DIM}(press y/n for each, Enter = default)${RESET}"
  echo ""

  for cat_idx in 0 1 2 3; do
    echo -e "  ${CYAN}◆${RESET} ${BOLD}${CAT_NAMES[$cat_idx]}${RESET}"

    for mod_idx in $(get_cat_indices $cat_idx); do
      echo -e "          ${DIM}${MODULE_DESCS[$mod_idx]}${RESET}"
      echo -e "          ${DIM}${MODULE_DESCS2[$mod_idx]}${RESET}"
      yn=""
      ask_yn "${MODULE_NAMES[$mod_idx]}" "Y" yn
      MODULE_ACTIVE[$mod_idx]="$yn"
      echo ""
    done
  done
fi

# Dry run
if $DRY_RUN; then
  print_header "Dry Run (no files will be created)"
  echo ""
  echo "  Would install to: $VAULT_PATH"
  echo ""
  echo "  Core: always installed"
  for idx in "${!MODULE_KEYS[@]}"; do
    if [[ "${MODULE_ACTIVE[$idx]}" == "Y" ]]; then
      status="${GREEN}✓${RESET}"
    else
      status="${DIM}✗${RESET}"
    fi
    printf "  %b %-35s\n" "$status" "${MODULE_NAMES[$idx]}"
  done
  echo ""
  echo -e "  ${YELLOW}Dry run complete. Run without --dry-run to install.${RESET}"
  exit 0
fi

# Step 4: Install
print_header "Step 4 of 4: Installing"
print_progress 4 4

if [[ -f "$VAULT_PATH/.claude/arcana.config.yaml" ]]; then
  echo -e "  ${YELLOW}Existing Open Arcana installation detected.${RESET}"
  overwrite_val=""
  ask "Overwrite? (existing settings.local.json will be backed up)" "Y" overwrite_val
  if [[ "$overwrite_val" != "Y" && "$overwrite_val" != "y" ]]; then
    echo -e "  ${YELLOW}Cancelled.${RESET}"
    exit 0
  fi
fi

install_core

for idx in "${!MODULE_KEYS[@]}"; do
  if [[ "${MODULE_ACTIVE[$idx]}" == "Y" ]]; then
    install_module "${MODULE_KEYS[$idx]}"
  fi
done

generate_config

echo ""
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

print_summary
