#!/usr/bin/env bash
set -euo pipefail

# Open Arcana Setup Wizard
# Compatible with bash 3.2+ (macOS default)
VERSION="1.10.0"

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
MODULE_KEYS=(anti-sycophancy token-efficiency enforcement-hooks security-hooks vault-structure retrieval-system commands connected-sources scheduled-tasks vault-health analytics scripts-offload)

MODULE_NAMES=(
  "Anti-Sycophancy Protocol"
  "Token Efficiency Rules"
  "Enforcement Hooks"
  "Security Hooks"
  "Vault Structure + Templates"
  "Retrieval System (Engram)"
  "Slash Commands (22 commands)"
  "Connected Sources Config"
  "Scheduled Tasks"
  "Vault Health Checks"
  "Analytics Dashboard"
  "Scripts Offload (Python)"
)

MODULE_DESCS=(
  "6 rules that prevent AI from agreeing without evidence."
  "18 rules to minimize context waste and API costs."
  "Validates frontmatter, enforces daily notes, checks writes."
  "Blocks prompt injection in memory files, guards people data."
  "Opinionated folder structure with 18 note templates."
  "4-layer lookup inspired by DeepSeek's Engram paper."
  "/start, /end, /weekly, /health, /dump, /capture, and more."
  "Template for orchestrating 16+ MCP data sources."
  "Templates for morning briefing, end-of-day, weekly review."
  "500+ automated checks for vault consistency."
  "6 behavioral metrics + local HTML dashboard from session data."
  "9 Python scripts that replace ~100 tool calls with ~10."
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
  "HIR, frustration, tool precision, context fill, commands, subagents."
  "Health audit, stats, indexes, links, stale detection, concept index."
)

# Category grouping: indices into MODULE_KEYS
CAT_NAMES=("GUARDRAILS" "ENFORCEMENT" "VAULT MANAGEMENT" "AUTOMATION")
CAT_INDICES_0="0 1"
CAT_INDICES_1="2 3"
CAT_INDICES_2="4 5"
CAT_INDICES_3="6 7 8 9 10 11"

# Module activation state (Y/N), same order as MODULE_KEYS
MODULE_ACTIVE=(Y Y Y Y Y Y Y Y Y Y Y Y)

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

  # Tools
  if [[ -d "$module_dir/tools" ]]; then
    mkdir -p "$target/tools"
    for tool in "$module_dir"/tools/*; do
      [[ -f "$tool" ]] || continue
      local name
      name=$(basename "$tool")
      copy_file "$tool" "$target/tools/$name"
      chmod +x "$target/tools/$name"
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

  # Include installed community packages
  local pkg_base="$VAULT_PATH/.claude/packages"
  if [[ -d "$pkg_base" ]] && [[ -n "$(ls -A "$pkg_base" 2>/dev/null)" ]]; then
    echo "" >> "$config_path"
    echo "packages:" >> "$config_path"
    for pkg_dir in "$pkg_base"/*/; do
      [[ -d "$pkg_dir" ]] || continue
      local manifest="$pkg_dir/package.yaml"
      [[ -f "$manifest" ]] || continue
      local p_name p_version
      p_name=$(grep "^name:" "$manifest" 2>/dev/null | sed 's/^name:[[:space:]]*//' | sed 's/^"//;s/"$//')
      p_version=$(grep "^version:" "$manifest" 2>/dev/null | sed 's/^version:[[:space:]]*//' | sed 's/^"//;s/"$//')
      if [[ -n "$p_name" ]] && [[ -n "$p_version" ]]; then
        echo "  ${p_name}: \"${p_version}\"" >> "$config_path"
      fi
    done
  fi

  success "Generating arcana.config.yaml"
}

# ── Package management ──────────────────────────────────

# Simple semver compare: returns 0 if $1 >= $2
version_gte() {
  local v1="$1" v2="$2"
  local IFS='.'
  local -a a1 a2
  # shellcheck disable=SC2206
  a1=($v1)
  # shellcheck disable=SC2206
  a2=($v2)
  local i
  for i in 0 1 2; do
    local n1=${a1[$i]:-0}
    local n2=${a2[$i]:-0}
    if [[ $n1 -gt $n2 ]]; then return 0; fi
    if [[ $n1 -lt $n2 ]]; then return 1; fi
  done
  return 0
}

# Extract major version number
version_major() {
  echo "$1" | cut -d. -f1
}

# Check version constraint: returns 0 if $VERSION satisfies $constraint
check_version_constraint() {
  local constraint="$1"
  if [[ -z "$constraint" ]]; then return 0; fi

  if [[ "$constraint" == ">="* ]]; then
    local min="${constraint#>=}"
    version_gte "$VERSION" "$min"
    return $?
  elif [[ "$constraint" == "~="* ]]; then
    local compat="${constraint#~=}"
    local compat_major
    compat_major=$(version_major "$compat")
    local cur_major
    cur_major=$(version_major "$VERSION")
    if [[ "$cur_major" != "$compat_major" ]]; then return 1; fi
    # Pad compat to full semver for gte check
    local compat_full="$compat"
    case "$compat" in
      *.*.*) ;;
      *.*) compat_full="${compat}.0" ;;
      *) compat_full="${compat}.0.0" ;;
    esac
    version_gte "$VERSION" "$compat_full"
    return $?
  else
    # Exact match
    if [[ "$VERSION" == "$constraint" ]]; then return 0; else return 1; fi
  fi
}

# Read a top-level value from a YAML file (simple grep-based)
pkg_yaml_val() {
  local file="$1" key="$2"
  grep "^${key}:" "$file" 2>/dev/null | sed "s/^${key}:[[:space:]]*//" | sed 's/^"//;s/"$//'
}

# Read a nested (2-space indent) value from a YAML file
pkg_yaml_nested() {
  local file="$1" key="$2"
  grep "^  ${key}:" "$file" 2>/dev/null | sed "s/^  ${key}:[[:space:]]*//" | sed 's/^"//;s/"$//'
}

# Read a YAML list under a given key (returns items one per line, stripped of "- ")
pkg_yaml_list() {
  local file="$1" key="$2"
  sed -n "/^  ${key}:/,/^  [^ ]/p" "$file" 2>/dev/null | grep '^    - ' 2>/dev/null | sed 's/^    - //' | sed 's/^"//;s/"$//' || true
}

install_package() {
  local source="$1"
  local tmp_clone=""
  local pkg_dir=""

  # Determine if source is a git URL or local path
  if [[ "$source" == http://* ]] || [[ "$source" == https://* ]] || [[ "$source" == git@* ]] || [[ "$source" == *.git ]]; then
    tmp_clone=$(mktemp -d)
    echo -e "  ${DIM}Cloning ${source}...${RESET}"
    if ! git clone --depth 1 "$source" "$tmp_clone/pkg" 2>/dev/null; then
      error "Failed to clone: $source"
      rm -rf "$tmp_clone"
      exit 1
    fi
    pkg_dir="$tmp_clone/pkg"
  else
    # Local path
    source="${source/#\~/$HOME}"
    if [[ ! -d "$source" ]]; then
      error "Directory not found: $source"
      exit 1
    fi
    pkg_dir="$source"
  fi

  # Validate manifest exists
  local manifest="$pkg_dir/arcana-package.yaml"
  if [[ ! -f "$manifest" ]]; then
    error "No arcana-package.yaml found in: $pkg_dir"
    if [[ -n "$tmp_clone" ]]; then rm -rf "$tmp_clone"; fi
    exit 1
  fi

  # Read manifest
  local pkg_name pkg_version pkg_desc pkg_author
  pkg_name=$(pkg_yaml_val "$manifest" "name")
  pkg_version=$(pkg_yaml_val "$manifest" "version")
  pkg_desc=$(pkg_yaml_val "$manifest" "description")
  pkg_author=$(pkg_yaml_val "$manifest" "author")

  if [[ -z "$pkg_name" ]] || [[ -z "$pkg_version" ]] || [[ -z "$pkg_desc" ]] || [[ -z "$pkg_author" ]]; then
    error "Manifest missing required fields (name, version, description, author)"
    if [[ -n "$tmp_clone" ]]; then rm -rf "$tmp_clone"; fi
    exit 1
  fi

  echo -e "  ${MAGENTA}◈${RESET} ${BOLD}Installing package: ${pkg_name}${RESET} v${pkg_version}"
  echo -e "    ${DIM}${pkg_desc}${RESET}"
  echo ""

  # Check version constraint
  local version_req
  version_req=$(pkg_yaml_nested "$manifest" "open-arcana")
  if [[ -n "$version_req" ]]; then
    if ! check_version_constraint "$version_req"; then
      error "Package requires Open Arcana ${version_req}, but you have v${VERSION}"
      if [[ -n "$tmp_clone" ]]; then rm -rf "$tmp_clone"; fi
      exit 1
    fi
  fi

  # Check module dependencies
  local required_modules
  required_modules=$(pkg_yaml_list "$manifest" "modules")
  if [[ -n "$required_modules" ]]; then
    local config_file="$VAULT_PATH/.claude/arcana.config.yaml"
    if [[ -f "$config_file" ]]; then
      while IFS= read -r req_mod; do
        [[ -z "$req_mod" ]] && continue
        local mod_status
        mod_status=$(pkg_yaml_nested "$config_file" "$req_mod")
        if [[ "$mod_status" != "true" ]]; then
          error "Package requires module '${req_mod}' which is not active"
          if [[ -n "$tmp_clone" ]]; then rm -rf "$tmp_clone"; fi
          exit 1
        fi
      done <<< "$required_modules"
    fi
  fi

  # Detect vault path from existing config if not set
  if [[ -z "${VAULT_PATH:-}" ]]; then
    local config_file="$HOME/Documents/Obsidian/Personal/.claude/arcana.config.yaml"
    if [[ -f "$config_file" ]]; then
      VAULT_PATH=$(pkg_yaml_nested "$config_file" "vault_path")
    fi
  fi

  if [[ -z "${VAULT_PATH:-}" ]]; then
    # Try to find existing config
    local found_config
    found_config=$(find "$HOME" -maxdepth 6 -name "arcana.config.yaml" -path "*/.claude/*" 2>/dev/null | head -1)
    if [[ -n "$found_config" ]]; then
      VAULT_PATH=$(pkg_yaml_nested "$found_config" "vault_path")
    fi
  fi

  if [[ -z "${VAULT_PATH:-}" ]]; then
    error "Cannot determine vault path. Run ./setup.sh first or set VAULT_PATH."
    if [[ -n "$tmp_clone" ]]; then rm -rf "$tmp_clone"; fi
    exit 1
  fi

  # Load config values for template processing (if not already loaded)
  if [[ -z "${USER_NAME:-}" ]]; then
    local config_file="$VAULT_PATH/.claude/arcana.config.yaml"
    if [[ -f "$config_file" ]]; then
      USER_NAME=$(pkg_yaml_nested "$config_file" "name")
      USER_ROLE=$(pkg_yaml_nested "$config_file" "role")
      USER_LANG=$(pkg_yaml_nested "$config_file" "language")
      COMPANY=$(pkg_yaml_nested "$config_file" "company")
      PRIMARY_DOMAIN=$(pkg_yaml_nested "$config_file" "primary_domain")
      DOMAINS=$(pkg_yaml_nested "$config_file" "domains")
      NOTION_DB_ID=$(pkg_yaml_nested "$config_file" "notion_db_id")
      USER_EMAIL=$(pkg_yaml_nested "$config_file" "user_email")
      MEMORY_DIR=$(derive_memory_dir "$VAULT_PATH")
    fi
  fi

  # Provide safe defaults for template vars that might be empty
  USER_NAME="${USER_NAME:-}"
  USER_ROLE="${USER_ROLE:-}"
  USER_LANG="${USER_LANG:-en}"
  VAULT_PATH="${VAULT_PATH:-}"
  MEMORY_DIR="${MEMORY_DIR:-}"
  NOTION_DB_ID="${NOTION_DB_ID:-}"
  USER_EMAIL="${USER_EMAIL:-}"
  PRIMARY_DOMAIN="${PRIMARY_DOMAIN:-work}"
  COMPANY="${COMPANY:-}"
  DOMAINS="${DOMAINS:-work,personal}"

  local target="$VAULT_PATH/.claude"
  local pkg_files_installed=0

  # Install rules
  if [[ -d "$pkg_dir/rules" ]]; then
    mkdir -p "$target/rules"
    for rule in "$pkg_dir"/rules/*.md; do
      [[ -f "$rule" ]] || continue
      local fname
      fname=$(basename "$rule")
      if [[ -f "$target/rules/$fname" ]]; then
        echo -e "    ${YELLOW}Overwriting existing rule: ${fname}${RESET}"
      fi
      copy_file "$rule" "$target/rules/$fname"
      pkg_files_installed=$((pkg_files_installed + 1))
    done
    success "Installed rules"
  fi

  # Install hooks
  if [[ -d "$pkg_dir/hooks" ]]; then
    mkdir -p "$target/hooks"
    for hook in "$pkg_dir"/hooks/*.sh; do
      [[ -f "$hook" ]] || continue
      local fname
      fname=$(basename "$hook")
      if [[ -f "$target/hooks/$fname" ]]; then
        echo -e "    ${YELLOW}Overwriting existing hook: ${fname}${RESET}"
      fi
      process_template "$hook" "$target/hooks/$fname"
      chmod +x "$target/hooks/$fname"
      pkg_files_installed=$((pkg_files_installed + 1))
    done
    success "Installed hooks"
  fi

  # Install commands
  if [[ -d "$pkg_dir/commands" ]]; then
    mkdir -p "$target/commands"
    for cmd in "$pkg_dir"/commands/*.md; do
      [[ -f "$cmd" ]] || continue
      local fname
      fname=$(basename "$cmd")
      if [[ -f "$target/commands/$fname" ]]; then
        echo -e "    ${YELLOW}Overwriting existing command: ${fname}${RESET}"
      fi
      process_template "$cmd" "$target/commands/$fname"
      pkg_files_installed=$((pkg_files_installed + 1))
    done
    success "Installed commands"
  fi

  # Install templates
  if [[ -d "$pkg_dir/templates" ]]; then
    mkdir -p "$VAULT_PATH/80-Templates"
    for tmpl in "$pkg_dir"/templates/*.md; do
      [[ -f "$tmpl" ]] || continue
      local fname
      fname=$(basename "$tmpl")
      if [[ -f "$VAULT_PATH/80-Templates/$fname" ]]; then
        echo -e "    ${YELLOW}Overwriting existing template: ${fname}${RESET}"
      fi
      copy_file "$tmpl" "$VAULT_PATH/80-Templates/$fname"
      pkg_files_installed=$((pkg_files_installed + 1))
    done
    success "Installed templates"
  fi

  # Install tools
  if [[ -d "$pkg_dir/tools" ]]; then
    mkdir -p "$target/tools"
    for tool in "$pkg_dir"/tools/*; do
      [[ -f "$tool" ]] || continue
      local fname
      fname=$(basename "$tool")
      if [[ -f "$target/tools/$fname" ]]; then
        echo -e "    ${YELLOW}Overwriting existing tool: ${fname}${RESET}"
      fi
      copy_file "$tool" "$target/tools/$fname"
      chmod +x "$target/tools/$fname"
      pkg_files_installed=$((pkg_files_installed + 1))
    done
    success "Installed tools"
  fi

  # Record installation
  local pkg_registry="$target/packages/$pkg_name"
  mkdir -p "$pkg_registry"
  cp "$manifest" "$pkg_registry/package.yaml"
  echo "installed: \"$(date +%Y-%m-%d)\"" >> "$pkg_registry/package.yaml"

  # Update arcana.config.yaml packages section
  local config_file="$VAULT_PATH/.claude/arcana.config.yaml"
  if [[ -f "$config_file" ]]; then
    if grep -q "^packages:" "$config_file"; then
      # Check if this package is already listed
      if grep -q "^  ${pkg_name}:" "$config_file"; then
        sed -i.bak "s/^  ${pkg_name}:.*$/  ${pkg_name}: \"${pkg_version}\"/" "$config_file"
        rm -f "${config_file}.bak"
      else
        sed -i.bak "/^packages:/a\\
  ${pkg_name}: \"${pkg_version}\"" "$config_file"
        rm -f "${config_file}.bak"
      fi
    else
      printf '\npackages:\n  %s: "%s"\n' "$pkg_name" "$pkg_version" >> "$config_file"
    fi
  fi

  echo ""
  success "Package ${BOLD}${pkg_name}${RESET} v${pkg_version} installed (${pkg_files_installed} files)"

  # Cleanup temp clone
  if [[ -n "$tmp_clone" ]]; then rm -rf "$tmp_clone"; fi
}

uninstall_package() {
  local pkg_name="$1"

  # Find vault path from existing config
  if [[ -z "${VAULT_PATH:-}" ]]; then
    local found_config
    for candidate in \
      "$HOME/Documents/Obsidian/Personal/.claude/arcana.config.yaml" \
      "$HOME/obsidian/.claude/arcana.config.yaml"; do
      if [[ -f "$candidate" ]]; then
        found_config="$candidate"
        break
      fi
    done
    if [[ -z "${found_config:-}" ]]; then
      found_config=$(find "$HOME" -maxdepth 6 -name "arcana.config.yaml" -path "*/.claude/*" 2>/dev/null | head -1)
    fi
    if [[ -n "${found_config:-}" ]]; then
      VAULT_PATH=$(pkg_yaml_nested "$found_config" "vault_path")
    fi
  fi

  if [[ -z "${VAULT_PATH:-}" ]]; then
    error "Cannot determine vault path. Run ./setup.sh first."
    exit 1
  fi

  local target="$VAULT_PATH/.claude"
  local pkg_registry="$target/packages/$pkg_name"
  local pkg_manifest="$pkg_registry/package.yaml"

  if [[ ! -f "$pkg_manifest" ]]; then
    error "Package not found: ${pkg_name}"
    error "No installation record at: ${pkg_registry}"
    exit 1
  fi

  local pkg_version
  pkg_version=$(pkg_yaml_val "$pkg_manifest" "version")

  echo ""
  echo -e "  ${MAGENTA}◈${RESET} ${BOLD}Uninstalling package: ${pkg_name}${RESET} v${pkg_version}"
  echo ""

  local removed=0

  # Read manifest provides lists and remove installed files
  # For rules: check rules/ listing
  local rule_files
  rule_files=$(pkg_yaml_list "$pkg_manifest" "rules")
  if [[ -n "$rule_files" ]]; then
    while IFS= read -r fname; do
      [[ -z "$fname" ]] && continue
      if [[ -f "$target/rules/$fname" ]]; then
        rm -f "$target/rules/$fname"
        removed=$((removed + 1))
      fi
    done <<< "$rule_files"
  fi

  # For hooks
  local hook_files
  hook_files=$(pkg_yaml_list "$pkg_manifest" "hooks")
  if [[ -n "$hook_files" ]]; then
    while IFS= read -r fname; do
      [[ -z "$fname" ]] && continue
      if [[ -f "$target/hooks/$fname" ]]; then
        rm -f "$target/hooks/$fname"
        removed=$((removed + 1))
      fi
    done <<< "$hook_files"
  fi

  # For commands
  local cmd_files
  cmd_files=$(pkg_yaml_list "$pkg_manifest" "commands")
  if [[ -n "$cmd_files" ]]; then
    while IFS= read -r fname; do
      [[ -z "$fname" ]] && continue
      if [[ -f "$target/commands/$fname" ]]; then
        rm -f "$target/commands/$fname"
        removed=$((removed + 1))
      fi
    done <<< "$cmd_files"
  fi

  # For templates
  local tmpl_files
  tmpl_files=$(pkg_yaml_list "$pkg_manifest" "templates")
  if [[ -n "$tmpl_files" ]]; then
    while IFS= read -r fname; do
      [[ -z "$fname" ]] && continue
      if [[ -f "$VAULT_PATH/80-Templates/$fname" ]]; then
        rm -f "$VAULT_PATH/80-Templates/$fname"
        removed=$((removed + 1))
      fi
    done <<< "$tmpl_files"
  fi

  # For tools
  local tool_files
  tool_files=$(pkg_yaml_list "$pkg_manifest" "tools")
  if [[ -n "$tool_files" ]]; then
    while IFS= read -r fname; do
      [[ -z "$fname" ]] && continue
      if [[ -f "$target/tools/$fname" ]]; then
        rm -f "$target/tools/$fname"
        removed=$((removed + 1))
      fi
    done <<< "$tool_files"
  fi

  # If provides lists were empty, scan directories from the package name prefix
  # as a fallback. This handles the case where provides lists are empty but files exist.
  if [[ $removed -eq 0 ]]; then
    # Try to remove files that match common patterns
    for dir in rules hooks commands tools; do
      for f in "$target/$dir"/*; do
        [[ -f "$f" ]] || continue
        # We can't know which files came from this package without tracking,
        # so we only remove files explicitly listed in provides.
      done
    done
  fi

  # Remove package registry
  rm -rf "$pkg_registry"

  # Update arcana.config.yaml
  local config_file="$VAULT_PATH/.claude/arcana.config.yaml"
  if [[ -f "$config_file" ]]; then
    sed -i.bak "/^  ${pkg_name}:/d" "$config_file"
    rm -f "${config_file}.bak"
    # If packages section is now empty, remove it
    local remaining_pkgs
    remaining_pkgs=$(sed -n '/^packages:/,/^[^ ]/p' "$config_file" 2>/dev/null | grep '^  ' 2>/dev/null || true)
    if [[ -z "$remaining_pkgs" ]]; then
      sed -i.bak '/^packages:$/d' "$config_file"
      rm -f "${config_file}.bak"
    fi
  fi

  success "Package ${BOLD}${pkg_name}${RESET} uninstalled (${removed} files removed)"
  echo ""
}

list_packages() {
  # Find vault path from existing config
  if [[ -z "${VAULT_PATH:-}" ]]; then
    local found_config
    for candidate in \
      "$HOME/Documents/Obsidian/Personal/.claude/arcana.config.yaml" \
      "$HOME/obsidian/.claude/arcana.config.yaml"; do
      if [[ -f "$candidate" ]]; then
        found_config="$candidate"
        break
      fi
    done
    if [[ -z "${found_config:-}" ]]; then
      found_config=$(find "$HOME" -maxdepth 6 -name "arcana.config.yaml" -path "*/.claude/*" 2>/dev/null | head -1)
    fi
    if [[ -n "${found_config:-}" ]]; then
      VAULT_PATH=$(pkg_yaml_nested "$found_config" "vault_path")
    fi
  fi

  if [[ -z "${VAULT_PATH:-}" ]]; then
    error "Cannot determine vault path. Run ./setup.sh first."
    exit 1
  fi

  local pkg_base="$VAULT_PATH/.claude/packages"
  if [[ ! -d "$pkg_base" ]] || [[ -z "$(ls -A "$pkg_base" 2>/dev/null)" ]]; then
    echo ""
    echo -e "  ${DIM}No community packages installed.${RESET}"
    echo ""
    exit 0
  fi

  echo ""
  echo -e "${BOLD}Installed Packages${RESET}"
  echo ""

  local count=0
  for pkg_dir in "$pkg_base"/*/; do
    [[ -d "$pkg_dir" ]] || continue
    local manifest="$pkg_dir/package.yaml"
    [[ -f "$manifest" ]] || continue

    local p_name p_version p_desc p_installed
    p_name=$(pkg_yaml_val "$manifest" "name")
    p_version=$(pkg_yaml_val "$manifest" "version")
    p_desc=$(pkg_yaml_val "$manifest" "description")
    p_installed=$(pkg_yaml_val "$manifest" "installed")

    echo -e "  ${MAGENTA}◈${RESET} ${BOLD}${p_name}${RESET} v${p_version}"
    echo -e "    ${DIM}${p_desc}${RESET}"
    if [[ -n "$p_installed" ]]; then
      echo -e "    ${DIM}Installed: ${p_installed}${RESET}"
    fi
    echo ""
    count=$((count + 1))
  done

  echo -e "  ${DIM}${count} package(s) installed.${RESET}"
  echo ""
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
INSTALL_PKG=""
UNINSTALL_PKG=""
LIST_PKGS=false

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
    --install-package)
      INSTALL_PKG="$2"; shift 2 ;;
    --uninstall-package)
      UNINSTALL_PKG="$2"; shift 2 ;;
    --list-packages)
      LIST_PKGS=true; shift ;;
    --help|-h)
      echo ""
      echo -e "${BOLD}Open Arcana Setup${RESET} v${VERSION}"
      echo ""
      echo "  Usage: ./setup.sh [options]"
      echo ""
      echo "  Options:"
      echo "    --preset <name>              Use preset (minimal, writer, full)"
      echo "    --yes, -y                    Accept all defaults"
      echo "    --dry-run                    Show what would be installed"
      echo "    --list                       Show available modules"
      echo "    --update                     Update existing installation (skip wizard)"
      echo "    --install-package <source>   Install a community package (git URL or local path)"
      echo "    --uninstall-package <name>   Uninstall a community package"
      echo "    --list-packages              List installed community packages"
      echo "    --help, -h                   Show this help"
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

# ── Package operations ──────────────────────────────────

if [[ -n "$INSTALL_PKG" ]]; then
  install_package "$INSTALL_PKG"
  exit 0
fi

if [[ -n "$UNINSTALL_PKG" ]]; then
  uninstall_package "$UNINSTALL_PKG"
  exit 0
fi

if $LIST_PKGS; then
  list_packages
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
