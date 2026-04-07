#!/bin/bash
# Checks if a newer version of Open Arcana is available.
# Runs on SessionStart, rate-limited to once per day.
# Notification only — never auto-updates.

CONFIG="{{VAULT_PATH}}/.claude/arcana.config.yaml"
STAMP="/tmp/arcana-update-check-$(id -u).stamp"

# Rate limit: once per day
if [[ -f "$STAMP" ]]; then
  stamp_age=$(( $(date +%s) - $(stat -f %m "$STAMP" 2>/dev/null || stat -c %Y "$STAMP" 2>/dev/null || echo 0) ))
  if [[ $stamp_age -lt 86400 ]]; then
    exit 0
  fi
fi

# Touch stamp early to avoid repeated checks on failure
touch "$STAMP" 2>/dev/null

# Read installed version and source dir from config
if [[ ! -f "$CONFIG" ]]; then
  exit 0
fi

installed_version=$(grep "^version:" "$CONFIG" 2>/dev/null | sed 's/^version:[[:space:]]*//' | sed 's/^"//;s/"$//')
source_dir=$(grep "^source_dir:" "$CONFIG" 2>/dev/null | sed 's/^source_dir:[[:space:]]*//' | sed 's/^"//;s/"$//')

if [[ -z "$installed_version" ]] || [[ -z "$source_dir" ]] || [[ ! -d "$source_dir" ]]; then
  exit 0
fi

# Read available version from repo's setup.sh
available_version=$(grep "^VERSION=" "$source_dir/setup.sh" 2>/dev/null | head -1 | sed 's/VERSION="//' | sed 's/"$//')

if [[ -z "$available_version" ]]; then
  exit 0
fi

# Compare versions
if [[ "$installed_version" != "$available_version" ]]; then
  echo ""
  echo "Open Arcana update available: v${installed_version} -> v${available_version}"
  echo "  Run: cd ${source_dir} && git pull && ./setup.sh --update"
  echo ""
fi

# Also check remote for newer commits (lightweight, fetch only)
if command -v git &>/dev/null && [[ -d "$source_dir/.git" ]]; then
  cd "$source_dir" 2>/dev/null || exit 0
  # Fetch silently, compare HEAD vs remote
  git fetch --quiet 2>/dev/null || exit 0
  local_head=$(git rev-parse HEAD 2>/dev/null)
  remote_head=$(git rev-parse @{u} 2>/dev/null || echo "")
  if [[ -n "$remote_head" ]] && [[ "$local_head" != "$remote_head" ]]; then
    behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "?")
    echo "Open Arcana repo is ${behind} commit(s) behind remote."
    echo "  Run: cd ${source_dir} && git pull && ./setup.sh --update"
    echo ""
  fi
fi
