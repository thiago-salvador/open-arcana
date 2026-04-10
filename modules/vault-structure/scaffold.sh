#!/usr/bin/env bash
# scaffold.sh -- Creates the Open Arcana vault folder structure
# Usage: ./scaffold.sh /path/to/vault

set -euo pipefail

VAULT_PATH="${1:-}"

if [ -z "$VAULT_PATH" ]; then
  echo "Usage: $0 <vault-path>"
  echo "Example: $0 ~/Documents/Obsidian/MyVault"
  exit 1
fi

# Resolve to absolute path
VAULT_PATH="$(cd "$(dirname "$VAULT_PATH")" 2>/dev/null && pwd)/$(basename "$VAULT_PATH")" || VAULT_PATH="$1"

echo "Creating vault structure at: $VAULT_PATH"

# Core folders
folders=(
  "00-Dashboard"
  "10-Work"
  "30-Content"
  "40-Partnerships"
  "50-Events"
  "60-Research"
  "70-People"
  "80-Templates"
  "85-Rules"
  "90-Archive"
  "99-Inbox"
  "Daily-Notes"
  "MOCs"
)

for folder in "${folders[@]}"; do
  mkdir -p "$VAULT_PATH/$folder"
  echo "  Created $folder/"
done

# Create placeholder index.md in each folder (skip Daily-Notes and MOCs)
for folder in "${folders[@]}"; do
  index_file="$VAULT_PATH/$folder/index.md"
  if [ "$folder" = "Daily-Notes" ] || [ "$folder" = "MOCs" ]; then
    continue
  fi
  if [ ! -f "$index_file" ]; then
    cat > "$index_file" <<EOF
---
title: "$folder Index"
type: hub
status: active
created: $(date +%Y-%m-%d)
---

# $folder

> Index of notes in this folder. Keep updated when adding or removing files.
EOF
    echo "  Created $folder/index.md"
  fi
done

# Create wip.md in 00-Dashboard if it doesn't exist
if [ ! -f "$VAULT_PATH/00-Dashboard/wip.md" ]; then
  sed "s/{{TODAY}}/$(date +%Y-%m-%d)/g" \
    "$(dirname "$0")/templates/WIP.md" > "$VAULT_PATH/00-Dashboard/wip.md"
  echo "  Created 00-Dashboard/wip.md"
fi

echo ""
echo "Done. $((${#folders[@]})) folders created."
echo "Next steps:"
echo "  1. Copy templates from modules/vault-structure/templates/ into $VAULT_PATH/80-Templates/"
echo "  2. Copy rules from modules/vault-structure/rules/ into your .claude/rules/ directory"
echo "  3. Customize domain-example.md for your own projects"
