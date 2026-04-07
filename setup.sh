#!/usr/bin/env bash
set -euo pipefail

# Open Arcana Setup Wizard
# Compatible with bash 3.2+ (macOS default)
VERSION="1.0.4"

# ── Colors & Styles ───────────────────────────────────────
BOLD=$'\033[1m'
DIM=$'\033[2m'
ITALIC=$'\033[3m'
WHITE=$'\033[1;37m'
CYAN=$'\033[1;36m'
MAGENTA=$'\033[1;35m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
RED=$'\033[0;31m'
DIM_WHITE=$'\033[2;37m'
DIM_CYAN=$'\033[2;36m'
RESET=$'\033[0m'

# Detect color support
if [[ ! -t 1 ]] || [[ "${NO_COLOR:-}" != "" ]]; then
  BOLD='' DIM='' ITALIC='' WHITE='' CYAN='' MAGENTA=''
  GREEN='' YELLOW='' RED='' DIM_WHITE='' DIM_CYAN='' RESET=''
  NO_ANIM=true
else
  NO_ANIM=false
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Module registry (indexed arrays, bash 3.2 compatible) ─
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
  "4-layer lookup inspired by DeepSeek's Engram paper."
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

# ── Terminal helpers ──────────────────────────────────────

term_width() {
  local w
  w=$(tput cols 2>/dev/null || echo 80)
  echo "$w"
}

center_text() {
  local text="$1" width
  width=$(term_width)
  # Strip ANSI codes for length calculation
  local stripped
  stripped=$(printf '%s' "$text" | sed 's/\x1b\[[0-9;]*m//g')
  local len=${#stripped}
  local pad=$(( (width - len) / 2 ))
  if [[ $pad -lt 0 ]]; then pad=0; fi
  printf '%*s' "$pad" ''
  printf '%s' "$text"
}

center_line() {
  center_text "$1"
  echo ""
}

anim_delay() {
  if ! $NO_ANIM; then
    sleep "${1:-0.04}"
  fi
}

# ── Helpers ───────────────────────────────────────────────

get_cat_indices() {
  case $1 in
    0) echo $CAT_INDICES_0 ;; 1) echo $CAT_INDICES_1 ;;
    2) echo $CAT_INDICES_2 ;; 3) echo $CAT_INDICES_3 ;;
  esac
}

ray_separator() {
  local w
  w=$(term_width)
  local dots=""
  local count=$(( w / 3 ))
  local i
  for ((i=0; i<count; i++)); do
    dots+="$DIM_CYAN.  $RESET"
  done
  echo ""
  center_line "$dots"
  echo ""
}

mini_header() {
  local step=$1 total=$2
  local w
  w=$(term_width)
  local left="${DIM_WHITE}  ${RESET}${MAGENTA}◈${RESET}${DIM_WHITE} OPEN ARCANA ${RESET}"
  local right="${DIM_WHITE}Step ${step} of ${total}${RESET}"
  local left_stripped="  ◈ OPEN ARCANA "
  local right_stripped="Step ${step} of ${total}"
  local dashes_count=$(( w - ${#left_stripped} - ${#right_stripped} - 2 ))
  if [[ $dashes_count -lt 4 ]]; then dashes_count=4; fi
  local dashes=""
  local i
  for ((i=0; i<dashes_count; i++)); do dashes+="─"; done
  echo ""
  echo -e "${left}${DIM}${dashes}${RESET} ${right}"
  echo ""
}

print_progress() {
  local step=$1 total=$2
  local w
  w=$(term_width)
  local bar_width=$(( w - 14 ))
  if [[ $bar_width -gt 50 ]]; then bar_width=50; fi
  local filled=$(( step * bar_width / total ))
  local empty=$(( bar_width - filled ))
  local pct=$(( step * 100 / total ))

  local bar=""
  local i
  # Gradient: first third white, second third cyan, last third magenta
  local third=$(( filled / 3 ))
  if [[ $third -lt 1 ]] && [[ $filled -gt 0 ]]; then third=1; fi
  local seg1=$third
  local seg2=$third
  local seg3=$(( filled - seg1 - seg2 ))

  for ((i=0; i<seg1; i++)); do bar+="${WHITE}━${RESET}"; done
  for ((i=0; i<seg2; i++)); do bar+="${CYAN}━${RESET}"; done
  for ((i=0; i<seg3; i++)); do bar+="${MAGENTA}━${RESET}"; done
  for ((i=0; i<empty; i++)); do bar+="${DIM}░${RESET}"; done

  echo -e "  ${MAGENTA}◈${RESET}${bar} ${DIM}${pct}%${RESET}"
  echo ""
}

hint()    { echo -e "    ${DIM_CYAN}$1${RESET}"; }
success() { echo -e "  ${MAGENTA}◈${RESET}${DIM}────${RESET} $1  ${GREEN}✓${RESET}"; }
error()   { echo -e "  ${RED}✗${RESET} $1"; }

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
    echo -ne "    ${DIM}[Y/n]${RESET} ${BOLD}$prompt${RESET} "
  else
    echo -ne "    ${DIM}[y/N]${RESET} ${BOLD}$prompt${RESET} "
  fi
  local input
  read -r input
  input="${input:-$default}"
  input=$(echo "$input" | tr '[:lower:]' '[:upper:]')
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

# ── Cinematic Splash ─────────────────────────────────────

splash() {
  clear 2>/dev/null || true

  local w
  w=$(term_width)

  # Blank space for dramatic effect
  echo ""
  echo ""
  echo ""
  echo ""
  echo ""
  echo ""

  local line_text="─────────────────"

  if ! $NO_ANIM; then
    # Frame 1: Line draws from center
    center_line "${CYAN}${line_text}${RESET}"
    anim_delay 0.3

    # Frame 2: "arcana" types below
    local partial=""
    local chars=("a" " " " " "r" " " " " "c" " " " " "a" " " " " "n" " " " " "a")
    printf '\033[1A'  # Move up 1 line
    center_line "${CYAN}${line_text}${RESET}"
    for ch in "${chars[@]}"; do
      partial+="$ch"
      printf '\r'
      center_text "${WHITE}${BOLD}${partial}${RESET}"
      anim_delay 0.04
    done
    echo ""

    anim_delay 0.2

    # Frame 3: "open" appears above
    printf '\033[2A'  # Up 2
    center_line "${DIM_WHITE}o  p  e  n${RESET}"
    center_line "${CYAN}${line_text}${RESET}"
    center_line "${WHITE}${BOLD}a  r  c  a  n  a${RESET}"

    anim_delay 0.4
  else
    # Static mode: print in correct order, no cursor movement
    center_line "${DIM_WHITE}o  p  e  n${RESET}"
    center_line "${CYAN}${line_text}${RESET}"
    center_line "${WHITE}${BOLD}a  r  c  a  n  a${RESET}"
  fi

  # Frame 4: Tagline + version
  echo ""
  center_line "${DIM_CYAN}AI Agent Orchestration Framework${RESET}"

  if ! $NO_ANIM; then
    anim_delay 0.2
  fi

  center_line "${DIM}Obsidian + Claude Code  ·  v${VERSION}${RESET}"

  echo ""
  echo ""

  anim_delay 0.6
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

# ── Template processing ──────────────────────────────────

escape_sed() {
  printf '%s' "$1" | sed -e 's/[&/\]/\\&/g'
}

process_template() {
  local src=$1 dst=$2
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"

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

# ── Install core ─────────────────────────────────────────

install_core() {
  local target="$VAULT_PATH/.claude"
  mkdir -p "$target/rules" "$target/hooks" "$target/memory"

  if [[ -f "$target/settings.local.json" ]]; then
    cp "$target/settings.local.json" "$target/settings.local.json.bak"
    success "Backed up existing settings.local.json"
  fi

  process_template "$SCRIPT_DIR/core/CLAUDE.md.template" "$VAULT_PATH/CLAUDE.md"
  success "Processing CLAUDE.md template"

  for rule in "$SCRIPT_DIR"/core/rules/*.md; do
    [[ -f "$rule" ]] || continue
    local name
    name=$(basename "$rule")
    copy_file "$rule" "$target/rules/$name"
  done
  success "Creating .claude/rules/"

  for hook in "$SCRIPT_DIR"/core/hooks/*.sh; do
    local name
    name=$(basename "$hook")
    process_template "$hook" "$target/hooks/$name"
    chmod +x "$target/hooks/$name"
    INSTALLED_HOOKS=$((INSTALLED_HOOKS + 1))
  done
  success "Creating .claude/hooks/"

  process_template "$SCRIPT_DIR/core/settings.template.json" "$target/settings.local.json"
  success "Wiring hooks into settings.json"

  mkdir -p "$MEMORY_DIR" 2>/dev/null || true
  if [[ -d "$MEMORY_DIR" ]]; then
    process_template "$SCRIPT_DIR/core/memory/MEMORY.md.template" "$MEMORY_DIR/MEMORY.md"
  fi
  success "Setting up memory system"
}

# ── Install module ───────────────────────────────────────

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

  success "Installing ${display_name}"
}

# ── Generate config ──────────────────────────────────────

generate_config() {
  local config_path="$VAULT_PATH/.claude/arcana.config.yaml"
  cat > "$config_path" << YAML
# Open Arcana Configuration
# Generated by setup.sh v${VERSION} on $(date +%Y-%m-%d)

version: "${VERSION}"
source_dir: "${SCRIPT_DIR}"

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

  success "Generating arcana.config.yaml"
}

# ── Portal Reveal Summary ────────────────────────────────

print_summary() {
  local w
  w=$(term_width)
  local inner=$(( w - 4 ))
  if [[ $inner -gt 60 ]]; then inner=60; fi

  # Build dot border
  local dot_line=""
  local i
  local dot_count=$(( inner / 2 ))
  for ((i=0; i<dot_count; i++)); do dot_line+=". "; done

  echo ""
  echo ""

  # Top border (animated)
  if ! $NO_ANIM; then
    local partial=""
    for ((i=0; i<dot_count; i++)); do
      partial+=". "
      printf '\r'
      center_text "  ${MAGENTA}${partial}${RESET}"
      anim_delay 0.02
    done
    echo ""
  else
    center_line "  ${MAGENTA}${dot_line}${RESET}"
  fi

  # Title
  center_line "  ${MAGENTA}.${RESET}$(printf '%*s' $(( inner - 2 )) '')${MAGENTA}.${RESET}"

  local title="T H E   V A U L T   I S   O P E N"
  center_line "  ${MAGENTA}.${RESET}     ${WHITE}${BOLD}${title}${RESET}$(printf '%*s' $(( inner - ${#title} - 7 )) '')${MAGENTA}.${RESET}"

  center_line "  ${MAGENTA}.${RESET}$(printf '%*s' $(( inner - 2 )) '')${MAGENTA}.${RESET}"

  # Separator
  local sep=""
  for ((i=0; i<inner-8; i++)); do sep+="─"; done
  center_line "  ${MAGENTA}.${RESET}    ${DIM}${sep}${RESET}    ${MAGENTA}.${RESET}"

  center_line "  ${MAGENTA}.${RESET}$(printf '%*s' $(( inner - 2 )) '')${MAGENTA}.${RESET}"

  # Profile info
  printf '  '
  center_text "${MAGENTA}.${RESET}    ${DIM}Profile${RESET}     ${BOLD}${USER_NAME}${RESET} (${USER_ROLE})"
  local profile_text="    Profile     ${USER_NAME} (${USER_ROLE})"
  local pad_r=$(( inner - ${#profile_text} - 2 ))
  if [[ $pad_r -gt 0 ]]; then printf '%*s' "$pad_r" ''; fi
  echo -e "${MAGENTA}.${RESET}"

  printf '  '
  center_text "${MAGENTA}.${RESET}    ${DIM}Vault${RESET}       ${BOLD}${VAULT_PATH}${RESET}"
  local vault_display="${VAULT_PATH/#$HOME/~}"
  local vault_text="    Vault       ${vault_display}"
  pad_r=$(( inner - ${#vault_text} - 2 ))
  if [[ $pad_r -gt 0 ]]; then printf '%*s' "$pad_r" ''; fi
  echo -e "${MAGENTA}.${RESET}"

  printf '  '
  center_text "${MAGENTA}.${RESET}    ${DIM}Language${RESET}    ${BOLD}${USER_LANG}${RESET}"
  local lang_text="    Language    ${USER_LANG}"
  pad_r=$(( inner - ${#lang_text} - 2 ))
  if [[ $pad_r -gt 0 ]]; then printf '%*s' "$pad_r" ''; fi
  echo -e "${MAGENTA}.${RESET}"

  center_line "  ${MAGENTA}.${RESET}$(printf '%*s' $(( inner - 2 )) '')${MAGENTA}.${RESET}"

  # Modules
  center_line "  ${MAGENTA}.${RESET}    ${BOLD}Modules${RESET}$(printf '%*s' $(( inner - 13 )) '')${MAGENTA}.${RESET}"

  local idx
  for idx in "${!MODULE_KEYS[@]}"; do
    local mark mark_text
    if [[ "${MODULE_ACTIVE[$idx]}" == "Y" ]]; then
      mark="${GREEN}◈${RESET}"
      mark_text="◈ ${MODULE_NAMES[$idx]}"
    else
      mark="${DIM}·${RESET}"
      mark_text="· ${MODULE_NAMES[$idx]}"
      mark_text+="  (skipped)"
    fi
    local line_text="      ${mark_text}"
    pad_r=$(( inner - ${#line_text} - 2 ))
    if [[ $pad_r -lt 0 ]]; then pad_r=0; fi
    echo -e "  ${MAGENTA}.${RESET}      ${mark} ${MODULE_NAMES[$idx]}$(if [[ "${MODULE_ACTIVE[$idx]}" != "Y" ]]; then echo -e "  ${DIM}(skipped)${RESET}"; fi)$(printf '%*s' "$pad_r" '')${MAGENTA}.${RESET}"
  done

  center_line "  ${MAGENTA}.${RESET}$(printf '%*s' $(( inner - 2 )) '')${MAGENTA}.${RESET}"

  # Separator
  center_line "  ${MAGENTA}.${RESET}    ${DIM}${sep}${RESET}    ${MAGENTA}.${RESET}"

  center_line "  ${MAGENTA}.${RESET}$(printf '%*s' $(( inner - 2 )) '')${MAGENTA}.${RESET}"

  # Stats
  local stats="${INSTALLED_FILES} files  ·  ${INSTALLED_HOOKS} hooks  ·  ${INSTALLED_COMMANDS} commands"
  local stats_text="     ${stats}"
  pad_r=$(( inner - ${#stats_text} - 2 ))
  if [[ $pad_r -lt 0 ]]; then pad_r=0; fi
  echo -e "  ${MAGENTA}.${RESET}     ${BOLD}${INSTALLED_FILES}${RESET} files  ${DIM}·${RESET}  ${BOLD}${INSTALLED_HOOKS}${RESET} hooks  ${DIM}·${RESET}  ${BOLD}${INSTALLED_COMMANDS}${RESET} commands$(printf '%*s' "$pad_r" '')${MAGENTA}.${RESET}"

  center_line "  ${MAGENTA}.${RESET}$(printf '%*s' $(( inner - 2 )) '')${MAGENTA}.${RESET}"

  # Next steps
  echo -e "  ${MAGENTA}.${RESET}    ${CYAN}Next:${RESET}$(printf '%*s' $(( inner - 11 )) '')${MAGENTA}.${RESET}"
  echo -e "  ${MAGENTA}.${RESET}      1. Open Claude Code in your vault$(printf '%*s' $(( inner - 42 )) '')${MAGENTA}.${RESET}"
  echo -e "  ${MAGENTA}.${RESET}      2. Run ${BOLD}/health${RESET} to verify$(printf '%*s' $(( inner - 33 )) '')${MAGENTA}.${RESET}"
  echo -e "  ${MAGENTA}.${RESET}      3. Run ${BOLD}/start${RESET} to begin$(printf '%*s' $(( inner - 32 )) '')${MAGENTA}.${RESET}"

  center_line "  ${MAGENTA}.${RESET}$(printf '%*s' $(( inner - 2 )) '')${MAGENTA}.${RESET}"

  # Bottom border
  center_line "  ${MAGENTA}${dot_line}${RESET}"

  echo ""
  echo ""
}

# ── Presets ───────────────────────────────────────────────

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

# ── Parse arguments ──────────────────────────────────────

PRESET=""
DRY_RUN=false
AUTO_YES=false
LIST_MODULES=false
UPDATE_MODE=false

# ── Read existing config for --update ──────────────────────

read_existing_config() {
  local config="$1"
  if [[ ! -f "$config" ]]; then
    error "No existing installation found at: $config"
    exit 1
  fi

  # Simple YAML reader (no deps, works with bash 3.2)
  yaml_val() { grep "^${1}:" "$config" 2>/dev/null | sed "s/^${1}:[[:space:]]*//" | sed 's/^"//;s/"$//' ; }
  yaml_nested() { grep "^  ${1}:" "$config" 2>/dev/null | sed "s/^  ${1}:[[:space:]]*//" | sed 's/^"//;s/"$//' ; }

  USER_NAME=$(yaml_nested "name")
  USER_ROLE=$(yaml_nested "role")
  USER_LANG=$(yaml_nested "language")
  VAULT_PATH=$(yaml_nested "vault_path")
  COMPANY=$(yaml_nested "company")
  PRIMARY_DOMAIN=$(yaml_nested "primary_domain")
  DOMAINS=$(yaml_nested "domains")
  NOTION_DB_ID=$(yaml_nested "notion_db_id")
  USER_EMAIL=$(yaml_nested "user_email")

  # Read module activation
  local idx
  for idx in "${!MODULE_KEYS[@]}"; do
    local mod_val
    mod_val=$(yaml_nested "${MODULE_KEYS[$idx]}")
    if [[ "$mod_val" == "true" ]]; then
      MODULE_ACTIVE[$idx]="Y"
    else
      MODULE_ACTIVE[$idx]="N"
    fi
  done

  MEMORY_DIR=$(derive_memory_dir "$VAULT_PATH")
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --preset)  PRESET="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --yes|-y)  AUTO_YES=true; shift ;;
    --list)    LIST_MODULES=true; shift ;;
    --update)  UPDATE_MODE=true; shift ;;
    --help|-h)
      echo ""
      echo -e "${BOLD}Open Arcana Setup${RESET} v${VERSION}"
      echo ""
      echo "  Usage: ./setup.sh [options]"
      echo ""
      echo "  Options:"
      echo "    --preset <name>    Use preset (minimal, writer, full)"
      echo "    --yes, -y          Accept all defaults"
      echo "    --dry-run          Show what would be installed"
      echo "    --list             Show available modules"
      echo "    --update           Update existing installation (skip wizard)"
      echo "    --help, -h         Show this help"
      echo ""
      exit 0
      ;;
    *) error "Unknown option: $1"; exit 1 ;;
  esac
done

# ── List mode ────────────────────────────────────────────

if $LIST_MODULES; then
  echo ""
  echo -e "${BOLD}Open Arcana Modules${RESET}"
  echo ""
  for idx in "${!MODULE_KEYS[@]}"; do
    echo -e "  ${MAGENTA}◈${RESET} ${BOLD}${MODULE_KEYS[$idx]}${RESET}: ${MODULE_NAMES[$idx]}"
  done
  echo ""
  exit 0
fi

# ── Main flow ────────────────────────────────────────────

# Update mode: read existing config, git pull, reinstall, done
if $UPDATE_MODE; then
  # Find existing config: check common locations
  UPDATE_CONFIG=""
  for candidate in \
    "$VAULT_PATH/.claude/arcana.config.yaml" \
    "$HOME/Documents/Obsidian/Personal/.claude/arcana.config.yaml" \
    "$HOME/obsidian/.claude/arcana.config.yaml"; do
    if [[ -f "$candidate" ]]; then
      UPDATE_CONFIG="$candidate"
      break
    fi
  done

  # If not found by default, try to find it
  if [[ -z "$UPDATE_CONFIG" ]]; then
    UPDATE_CONFIG=$(find "$HOME" -maxdepth 6 -name "arcana.config.yaml" -path "*/.claude/*" 2>/dev/null | head -1)
  fi

  if [[ -z "$UPDATE_CONFIG" ]]; then
    error "No Open Arcana installation found. Run ./setup.sh first."
    exit 1
  fi

  echo ""
  echo -e "  ${MAGENTA}◈${RESET} ${BOLD}Open Arcana Update${RESET} v${VERSION}"
  echo ""

  # Read existing config
  read_existing_config "$UPDATE_CONFIG"
  local_version=$(grep "^version:" "$UPDATE_CONFIG" | sed 's/^version:[[:space:]]*//' | sed 's/^"//;s/"$//')
  echo -e "  ${DIM}Installed:${RESET} v${local_version:-unknown}"
  echo -e "  ${DIM}Available:${RESET} v${VERSION}"
  echo -e "  ${DIM}Vault:${RESET}     ${VAULT_PATH}"
  echo ""

  if [[ "$local_version" == "$VERSION" ]]; then
    echo -e "  ${GREEN}Already up to date.${RESET}"
    echo ""
    exit 0
  fi

  # Git pull if we're in a git repo
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    echo -e "  ${DIM}Pulling latest changes...${RESET}"
    git pull --ff-only 2>/dev/null && echo -e "  ${GREEN}Updated repo.${RESET}" || echo -e "  ${YELLOW}Git pull skipped (not on a tracking branch or conflicts).${RESET}"
    echo ""
  fi

  # Reinstall
  echo -e "  ${DIM}Reinstalling...${RESET}"
  echo ""

  install_core
  for idx in "${!MODULE_KEYS[@]}"; do
    if [[ "${MODULE_ACTIVE[$idx]}" == "Y" ]]; then
      install_module "${MODULE_KEYS[$idx]}"
    fi
  done
  generate_config

  echo ""
  echo -e "  ${GREEN}Updated to v${VERSION}.${RESET}"
  echo -e "  ${DIM}${INSTALLED_FILES} files  ·  ${INSTALLED_HOOKS} hooks  ·  ${INSTALLED_COMMANDS} commands${RESET}"
  echo ""
  exit 0
fi

splash

if [[ -n "$PRESET" ]]; then
  apply_preset "$PRESET"
fi

# Step 1: Profile
mini_header 1 4
echo -e "  ${BOLD}Your Profile${RESET}"
echo ""
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
ray_separator

mini_header 2 4
echo -e "  ${BOLD}Integrations${RESET} ${DIM}(optional)${RESET}"
echo ""
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
  ray_separator

  mini_header 3 4
  echo -e "  ${BOLD}Modules${RESET}"
  echo ""
  print_progress 3 4

  echo -e "  ${DIM}Select which modules to activate.${RESET}"
  echo -e "  ${DIM}Press y/n for each, Enter = default.${RESET}"
  echo ""

  for cat_idx in 0 1 2 3; do
    echo -e "  ┌─ ${CYAN}${CAT_NAMES[$cat_idx]}${RESET} $(printf '─%.0s' $(seq 1 $(( 44 - ${#CAT_NAMES[$cat_idx]} )) ))┐"
    echo -e "  │$(printf '%*s' 50 '')│"

    for mod_idx in $(get_cat_indices $cat_idx); do
      echo -e "  │  ${MAGENTA}◈${RESET} ${BOLD}${MODULE_NAMES[$mod_idx]}${RESET}"
      echo -e "  │    ${DIM}${MODULE_DESCS[$mod_idx]}${RESET}"
      echo -e "  │    ${DIM}${MODULE_DESCS2[$mod_idx]}${RESET}"
      yn=""
      ask_yn "${MODULE_NAMES[$mod_idx]}" "Y" yn
      MODULE_ACTIVE[$mod_idx]="$yn"
      echo -e "  │"
    done

    echo -e "  └$(printf '─%.0s' $(seq 1 51))┘"
    echo ""
  done
fi

# Dry run
if $DRY_RUN; then
  ray_separator
  echo ""
  echo -e "  ${BOLD}Dry Run${RESET} ${DIM}(no files will be created)${RESET}"
  echo ""
  echo -e "  Would install to: ${BOLD}$VAULT_PATH${RESET}"
  echo ""
  echo -e "  ${DIM}Core: always installed${RESET}"
  for idx in "${!MODULE_KEYS[@]}"; do
    if [[ "${MODULE_ACTIVE[$idx]}" == "Y" ]]; then
      echo -e "  ${GREEN}◈${RESET} ${MODULE_NAMES[$idx]}"
    else
      echo -e "  ${DIM}· ${MODULE_NAMES[$idx]}${RESET}"
    fi
  done
  echo ""
  echo -e "  ${YELLOW}Dry run complete. Run without --dry-run to install.${RESET}"
  exit 0
fi

# Step 4: Install
ray_separator

mini_header 4 4
echo -e "  ${BOLD}Installing${RESET}"
echo ""
print_progress 4 4

if [[ -f "$VAULT_PATH/.claude/arcana.config.yaml" ]]; then
  echo -e "  ${YELLOW}Existing Open Arcana installation detected.${RESET}"
  overwrite_val=""
  ask "Overwrite? (existing settings.local.json will be backed up)" "Y" overwrite_val
  if [[ "$overwrite_val" != "Y" && "$overwrite_val" != "y" ]]; then
    echo -e "  ${YELLOW}Cancelled.${RESET}"
    exit 0
  fi
  echo ""
fi

install_core

for idx in "${!MODULE_KEYS[@]}"; do
  if [[ "${MODULE_ACTIVE[$idx]}" == "Y" ]]; then
    install_module "${MODULE_KEYS[$idx]}"
  fi
done

generate_config

ray_separator

print_summary
