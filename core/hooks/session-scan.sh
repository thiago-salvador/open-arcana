#!/bin/bash
# Auto-scan: reports recently modified files and loads retrieval context
# Runs on SessionStart to give Claude context about what changed

VAULT_PATH="{{VAULT_PATH}}"
DOCS="$(dirname "$(dirname "$VAULT_PATH")")"

# Find files modified in last 2 days, excluding noise
MODIFIED=$(find "$DOCS" -type f -mtime -2 \
  -not -path "*/node_modules/*" \
  -not -path "*/.git/*" \
  -not -path "*/Obsidian*" \
  -not -path "*/.next/*" \
  -not -path "*/.svelte-kit/*" \
  -not -path "*/dist/*" \
  -not -path "*/.turbo/*" \
  -not -path "*/.cache/*" \
  -not -path "*/build/*" \
  -not -path "*/out/*" \
  -not -path "*/__pycache__/*" \
  -not -path "*/venv/*" \
  -not -name "*.lock" \
  -not -name "package-lock.json" \
  -not -name ".DS_Store" \
  -not -name "*.log" \
  -not -name "*.png" -not -name "*.jpg" -not -name "*.svg" \
  -not -name "*.mp4" -not -name "*.ttf" -not -name "*.woff*" \
  2>/dev/null | sort)

TOTAL=0
if [ -n "$MODIFIED" ]; then
  TOTAL=$(echo "$MODIFIED" | wc -l | tr -d ' ')
fi

echo "Vault Auto-Scan (last 48h)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total: $TOTAL files modified outside vault"
echo ""

if [ "$TOTAL" -gt 0 ]; then
  echo "$MODIFIED" | head -10 | sed "s|$DOCS/||" | sed 's/^/  - /'
  [ "$TOTAL" -gt 10 ] && echo "  ... and $((TOTAL - 10)) more"
  echo ""
fi

# Check Daily Note exists
TODAY=$(date +%Y-%m-%d)
DAILY="$VAULT_PATH/Daily-Notes/$TODAY.md"
if [ -f "$DAILY" ]; then
  echo "Daily Note: exists"
else
  echo "Daily Note: MISSING (run /start to create)"
fi

echo ""

# Engram Retrieval System context
HOT_CACHE="$VAULT_PATH/00-Dashboard/hot-cache.md"
CONCEPT_IDX="$VAULT_PATH/00-Dashboard/concept-index.md"
ALIASES="$VAULT_PATH/00-Dashboard/aliases.md"

echo "Engram Retrieval System (auto-loaded)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "$HOT_CACHE" ]; then
  ENTRY_COUNT_HC=$(grep -c '\[\[' "$HOT_CACHE" 2>/dev/null || echo "0")
  echo ""
  echo "## HOT CACHE (Tier 1+2 notes)"
  echo ""
  echo "Available at: 00-Dashboard/hot-cache.md ($ENTRY_COUNT_HC entries)"
  echo "   Read on demand when task requires Tier 1+2 context"
fi

if [ -f "$CONCEPT_IDX" ]; then
  ENTRY_COUNT=$(grep -c '\[\[' "$CONCEPT_IDX" 2>/dev/null || echo "0")
  echo ""
  echo "Concept Index: $ENTRY_COUNT entries loaded (00-Dashboard/concept-index.md)"
  echo "   Use for O(1) lookup before grep/Smart Connections"
fi

if [ -f "$ALIASES" ]; then
  ALIAS_COUNT=$(grep -c 'canonical:' "$ALIASES" 2>/dev/null || echo "0")
  echo "Aliases: $ALIAS_COUNT term groups loaded (00-Dashboard/aliases.md)"
  echo "   Expand queries with synonyms before searching"
fi

echo ""
echo "Retrieval budget: max 20% context for retrieval, 80% for reasoning"

# Vault health quick check
if [ -f "$VAULT_PATH/00-Dashboard/vault-experiments.md" ]; then
  LAST_SCORE=$(grep -o '\*\*[0-9.]*\*\*' "$VAULT_PATH/00-Dashboard/vault-experiments.md" | tail -1 | tr -d '*')
  if [ -n "$LAST_SCORE" ]; then
    echo "Last vault_score: $LAST_SCORE (run 'bash .vault-test.sh' to re-test)"
  fi
fi

echo ""

# Boot payload measurement (~4 chars per token)
HOT_CHARS=0; IDX_CHARS=0; RULES_CHARS=0
[ -f "$HOT_CACHE" ] && HOT_CHARS=$(wc -c < "$HOT_CACHE" | tr -d ' ')
[ -f "$CONCEPT_IDX" ] && IDX_CHARS=$(wc -c < "$CONCEPT_IDX" | tr -d ' ')
for rf in "$VAULT_PATH/.claude/rules/"*.md; do
  [ -f "$rf" ] && RULES_CHARS=$((RULES_CHARS + $(wc -c < "$rf" | tr -d ' ')))
done
TOTAL_BOOT_CHARS=$((HOT_CHARS + IDX_CHARS + RULES_CHARS))
EST_TOKENS=$((TOTAL_BOOT_CHARS / 4))
PCT_1M=$((EST_TOKENS * 100 / 1000000))
echo "Boot payload: ~${EST_TOKENS} tokens (${PCT_1M}% of 1M context)"
if [ "$EST_TOKENS" -gt 80000 ]; then
  echo "   Warning: Above 8% threshold. Consider trimming hot-cache or lazy-loading concept-index."
fi

# Operating rules pointer
MEMORY_DIR="{{MEMORY_DIR}}"
FEEDBACK_COUNT=$(ls "$MEMORY_DIR"/feedback_*.md 2>/dev/null | wc -l | tr -d ' ')
echo ""
echo "Operating Rules: loaded via .claude/rules/ (core-rules.md + anti-sycophancy.md + feedback_*.md ($FEEDBACK_COUNT files))"
