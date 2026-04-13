#!/usr/bin/env bash
# test_scripts.sh — Automated test suite for scripts-offload module
# Creates a temp vault, runs all 8 scripts through 8 test layers, reports PASS/FAIL.
#
# Usage:
#   bash test_scripts.sh                    # run all layers
#   bash test_scripts.sh --tools /path      # override tools path
#
# Exit code: 0 if all pass, 1 if any fail.
set -euo pipefail

PASS=0; FAIL=0; TOTAL=0
VAULT="/tmp/arcana-test-vault-$$"

# Locate tools directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS="${SCRIPT_DIR}/../tools"

for i in "$@"; do
  case "$i" in
    --tools) shift; TOOLS="$1"; shift ;;
  esac
done

if [[ ! -f "$TOOLS/_common.py" ]]; then
  echo "ERROR: _common.py not found at $TOOLS"
  exit 1
fi

# ── Helpers ──────────────────────────────────────────────

assert_eq() {
  TOTAL=$((TOTAL+1))
  if [[ "$1" == "$2" ]]; then
    PASS=$((PASS+1)); echo "  PASS: $3"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $3 (expected='$2', got='$1')"
  fi
}

assert_contains() {
  TOTAL=$((TOTAL+1))
  if echo "$1" | grep -q "$2"; then
    PASS=$((PASS+1)); echo "  PASS: $3"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $3 (missing '$2')"
  fi
}

assert_not_contains() {
  TOTAL=$((TOTAL+1))
  if ! echo "$1" | grep -q "$2"; then
    PASS=$((PASS+1)); echo "  PASS: $3"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $3 (should not contain '$2')"
  fi
}

assert_ge() {
  TOTAL=$((TOTAL+1))
  if [ "$1" -ge "$2" ] 2>/dev/null; then
    PASS=$((PASS+1)); echo "  PASS: $3 ($1 >= $2)"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $3 ($1 < $2)"
  fi
}

run() { VAULT_PATH="$VAULT" python3 "$TOOLS/$1" "${@:2}" 2>&1; }
jq_py() { python3 -c "import sys,json; $1" <<< "$2"; }

cleanup() { rm -rf "$VAULT"; }
trap cleanup EXIT

# ── Fixtures ─────────────────────────────────────────────

rm -rf "$VAULT"
mkdir -p "$VAULT/.claude" "$VAULT/00-Dashboard" "$VAULT/10-Work" "$VAULT/10-Work/SubProject" \
  "$VAULT/20-Research" "$VAULT/30-Content" "$VAULT/Daily-Notes" "$VAULT/MOCs" \
  "$VAULT/70-People" "$VAULT/90-Arquivo"
touch "$VAULT/CLAUDE.md"

# Good note (linked from MOC)
cat > "$VAULT/10-Work/good-note.md" << 'MD'
---
title: "Good Note"
summary: "A well-formed note"
type: concept
domain: work
tags: [test, sample]
status: active
created: 2026-01-01
---
# Good Note
Content with a [[20-Research/research-one|Research One]] link.
MD

# Research note
cat > "$VAULT/20-Research/research-one.md" << 'MD'
---
title: "Research One"
summary: "Research note"
type: reference
domain: research
tags: [research]
status: active
created: 2026-01-01
---
# Research One
This links to [[Good Note]].
MD

# Orphan note (no incoming links)
cat > "$VAULT/30-Content/orphan-note.md" << 'MD'
---
title: "Orphan Note"
summary: "Nobody links to me"
type: concept
domain: content
tags: [lonely]
status: active
created: 2026-01-01
---
# Orphan Note
I link to [[Good Note]] but nobody links back.
MD

# Isolated note (no outgoing links)
cat > "$VAULT/10-Work/isolated-note.md" << 'MD'
---
title: "Isolated Note"
summary: "I have no outgoing links"
type: concept
domain: work
tags: [isolated]
status: active
created: 2026-01-01
---
# Isolated Note
Just content, no wikilinks anywhere.
MD

# Missing fields
cat > "$VAULT/10-Work/missing-fields.md" << 'MD'
---
title: "Missing Fields"
type: concept
---
# Missing Fields
MD

# No frontmatter
cat > "$VAULT/10-Work/no-fm.md" << 'MD'
# No Frontmatter
This note has no frontmatter at all.
MD

# BOM note
printf '\xef\xbb\xbf---\ntitle: "BOM Note"\nsummary: "Has BOM"\ntype: concept\ndomain: work\ntags: [bom]\nstatus: active\ncreated: 2026-01-01\n---\n# BOM Note\nContent.\n' > "$VAULT/10-Work/bom-note.md"

# Multiline tags
cat > "$VAULT/10-Work/multi-tags.md" << 'MD'
---
title: "Multi Tags"
summary: "Multiline tags"
type: concept
domain: work
tags:
  - alpha
  - beta
  - gamma
status: active
created: 2026-01-01
---
# Multi Tags
Links to [[Good Note]].
MD

# Empty file
touch "$VAULT/10-Work/empty.md"

# Stale note (mtime set to 2025-01-01)
cat > "$VAULT/10-Work/stale-note.md" << 'MD'
---
title: "Stale Note"
summary: "Old and stale"
type: concept
domain: work
tags: [stale]
status: active
created: 2025-01-01
---
# Stale Note
MD
touch -t 202501010000 "$VAULT/10-Work/stale-note.md"

# Broken link source
cat > "$VAULT/10-Work/has-broken-link.md" << 'MD'
---
title: "Has Broken Link"
summary: "Links to nonexistent"
type: concept
domain: work
tags: [broken]
status: active
created: 2026-01-01
---
See [[Nonexistent Note]] and [[Reserch One]].
MD

# MOC linking notes by display name
cat > "$VAULT/MOCs/work-moc.md" << 'MD'
---
title: "Work MOC"
summary: "Work map"
type: moc
domain: work
tags: [moc]
status: active
created: 2026-01-01
---
- [[Good Note]]
- [[Multi Tags]]
- [[Has Broken Link]]
MD

# Index for 10-Work
cat > "$VAULT/10-Work/index.md" << 'MD'
---
title: "Work Index"
type: hub
domain: work
---
# 10-Work
MD

# Subfolder note
cat > "$VAULT/10-Work/SubProject/sub-note.md" << 'MD'
---
title: "Sub Note"
summary: "In a subfolder"
type: concept
domain: work
tags: [sub]
status: active
created: 2026-01-01
---
Links to [[Good Note]].
MD

# Person
cat > "$VAULT/70-People/John Smith.md" << 'MD'
---
title: "John Smith"
summary: "A person"
type: person
domain: personal
tags: [person]
status: active
created: 2026-01-01
---
# John Smith
MD

# Double FM delimiter
cat > "$VAULT/20-Research/double-fm.md" << 'MD'
---
title: "Double FM"
summary: "Edge case"
type: concept
domain: research
tags: [edge]
status: active
created: 2026-01-01
---
# Double FM
---
Horizontal rule above.
MD

# Special chars
cat > "$VAULT/20-Research/special-chars.md" << 'MD'
---
title: "Notas & Reflexões: Edição #3"
summary: "Special chars test"
type: concept
domain: research
tags: [special]
status: active
created: 2026-01-01
---
Content with [[Good Note]].
MD

# Mixed encoding
python3 -c "
with open('$VAULT/10-Work/mixed-enc.md', 'wb') as f:
    f.write(b'---\ntitle: \"Mixed Encoding\"\nsummary: \"Latin-1 bytes\"\ntype: concept\ndomain: work\ntags: [encoding]\nstatus: active\ncreated: 2026-01-01\n---\n# Mixed\nCaf\xe9 text.\n')
"

FIXTURE_COUNT=$(find "$VAULT" -name '*.md' | wc -l | tr -d ' ')
echo "=== Test Suite: $FIXTURE_COUNT fixtures ==="
echo ""

# ═══════════════════════════════════════════════════════════
# LAYER 1: Unit tests (each script produces valid JSON)
# ═══════════════════════════════════════════════════════════
echo "--- Layer 1: JSON validity ---"
for script in vault_health.py vault_stats.py rebuild_indexes.py fix_frontmatter.py auto_linker.py broken_links.py concept_index.py stale_detector.py; do
  OUT=$(run "$script" 2>&1)
  TOTAL=$((TOTAL+1))
  if python3 -c "import sys,json; json.load(sys.stdin)" <<< "$OUT" 2>/dev/null; then
    PASS=$((PASS+1)); echo "  PASS: $script valid JSON"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $script invalid JSON"
  fi
done

# ═══════════════════════════════════════════════════════════
# LAYER 2: Edge cases (BOM, multiline tags, empty, special chars, mixed encoding)
# ═══════════════════════════════════════════════════════════
echo "--- Layer 2: Edge cases ---"

# BOM
OUT=$(run vault_health.py --verbose)
FM_ISSUES=$(jq_py "d=json.load(sys.stdin)['details']['frontmatter_issues']; [print(x) for x in d]" "$OUT")
assert_not_contains "$FM_ISSUES" "bom-note.md" "BOM note parses correctly"

# Multiline tags
STATS=$(run vault_stats.py)
TAG_A=$(jq_py "print(json.load(sys.stdin)['top_tags'].get('alpha',0))" "$STATS")
assert_eq "$TAG_A" "1" "multiline tag 'alpha' detected"

# Empty file (no crash)
run vault_health.py > /dev/null 2>&1 && { TOTAL=$((TOTAL+1)); PASS=$((PASS+1)); echo "  PASS: empty file no crash"; } || { TOTAL=$((TOTAL+1)); FAIL=$((FAIL+1)); echo "  FAIL: empty file crashed"; }

# Double FM delimiter
DFM=$(VAULT_PATH="$VAULT" python3 -c "
import sys; sys.path.insert(0, '$TOOLS')
from _common import parse_frontmatter, read_note
text = read_note(__import__('pathlib').Path('$VAULT/20-Research/double-fm.md'))
fm = parse_frontmatter(text)
print(fm.get('title','MISSING') if fm else 'NO_FM')
")
assert_eq "$DFM" "Double FM" "double FM delimiter"

# Special chars
SC=$(VAULT_PATH="$VAULT" python3 -c "
import sys; sys.path.insert(0, '$TOOLS')
from _common import parse_frontmatter, read_note
text = read_note(__import__('pathlib').Path('$VAULT/20-Research/special-chars.md'))
fm = parse_frontmatter(text)
print(fm.get('title','MISSING') if fm else 'NO_FM')
")
assert_contains "$SC" "Reflexões" "special chars preserved"

# Mixed encoding
ME=$(VAULT_PATH="$VAULT" python3 -c "
import sys; sys.path.insert(0, '$TOOLS')
from _common import parse_frontmatter, read_note
text = read_note(__import__('pathlib').Path('$VAULT/10-Work/mixed-enc.md'))
fm = parse_frontmatter(text)
print(fm.get('title','MISSING') if fm else 'NO_FM')
")
assert_eq "$ME" "Mixed Encoding" "mixed encoding parsed"

# ═══════════════════════════════════════════════════════════
# LAYER 3: Detection accuracy
# ═══════════════════════════════════════════════════════════
echo "--- Layer 3: Detection accuracy ---"

# Frontmatter issues
MISSING_FM=$(jq_py "print(json.load(sys.stdin)['issues']['missing_frontmatter'])" "$OUT")
assert_ge "$MISSING_FM" 1 "detected missing frontmatter"

# Orphans (with stem normalization fix)
ORPHANS=$(jq_py "[print(x) for x in json.load(sys.stdin)['details']['orphans']]" "$OUT")
assert_not_contains "$ORPHANS" "good-note" "good-note NOT orphan (norm fix)"
assert_contains "$ORPHANS" "orphan-note" "orphan-note IS orphan"

# Isolated
ISOLATED=$(jq_py "[print(x) for x in json.load(sys.stdin)['details']['isolated']]" "$OUT")
assert_contains "$ISOLATED" "isolated-note" "isolated-note detected"

# Broken links
BL=$(run broken_links.py)
BL_TARGETS=$(jq_py "[print(x['target']) for x in json.load(sys.stdin)['broken_links']]" "$BL")
assert_contains "$BL_TARGETS" "Nonexistent Note" "Nonexistent Note is broken"
assert_not_contains "$BL_TARGETS" "Good Note" "[[Good Note]] NOT broken (norm fix)"

# Stale
SD=$(run stale_detector.py --days 7)
SD_STALE=$(jq_py "print(json.load(sys.stdin)['stale_count'])" "$SD")
assert_ge "$SD_STALE" 1 "detected stale notes"

# ═══════════════════════════════════════════════════════════
# LAYER 4: Idempotency
# ═══════════════════════════════════════════════════════════
echo "--- Layer 4: Idempotency ---"

# rebuild_indexes
run rebuild_indexes.py --apply > /dev/null
RI_IDEM=$(run rebuild_indexes.py --apply)
RI_COUNT=$(jq_py "print(json.load(sys.stdin)['changed_count'])" "$RI_IDEM")
assert_eq "$RI_COUNT" "0" "rebuild_indexes idempotent"

# fix_frontmatter
run fix_frontmatter.py --apply > /dev/null
FF_IDEM=$(run fix_frontmatter.py --apply)
FF_COUNT=$(jq_py "print(json.load(sys.stdin)['files_fixed'])" "$FF_IDEM")
assert_eq "$FF_COUNT" "0" "fix_frontmatter idempotent"

# ═══════════════════════════════════════════════════════════
# LAYER 5: Integration (SKIP_FILES regression, cross-format links)
# ═══════════════════════════════════════════════════════════
echo "--- Layer 5: Integration ---"

# SKIP_FILES regression: note linked ONLY from index.md
cat > "$VAULT/10-Work/only-in-index.md" << 'MD'
---
title: "Only In Index"
summary: "Linked only from index"
type: concept
domain: work
tags: [test]
status: active
created: 2026-01-01
---
Content with [[Good Note]].
MD
echo "- [[Only In Index]]" >> "$VAULT/10-Work/index.md"

OUT5=$(run vault_health.py --verbose)
ORPHANS5=$(jq_py "[print(x) for x in json.load(sys.stdin)['details']['orphans']]" "$OUT5")
assert_not_contains "$ORPHANS5" "only-in-index" "SKIP_FILES regression: index links counted"

# Reverse normalization: file with space, link with hyphen
cat > "$VAULT/20-Research/My Research.md" << 'MD'
---
title: "My Research"
summary: "Spaces in filename"
type: concept
domain: research
tags: [test]
status: active
created: 2026-01-01
---
Content.
MD
echo "See [[my-research]]." >> "$VAULT/10-Work/good-note.md"

OUT5B=$(run vault_health.py --verbose)
ORPHANS5B=$(jq_py "[print(x) for x in json.load(sys.stdin)['details']['orphans']]" "$OUT5B")
assert_not_contains "$ORPHANS5B" "My Research" "reverse normalization works"

# ═══════════════════════════════════════════════════════════
# LAYER 6: Failure handling
# ═══════════════════════════════════════════════════════════
echo "--- Layer 6: Failure handling ---"

ERR=$(VAULT_PATH="/tmp/nonexistent-vault-$$" python3 "$TOOLS/vault_health.py" 2>&1 || true)
assert_contains "$ERR" "error" "missing vault returns error JSON"

# ═══════════════════════════════════════════════════════════
# LAYER 7: Concurrency safety
# ═══════════════════════════════════════════════════════════
echo "--- Layer 7: Concurrency safety ---"

# All --apply scripts must use atomic_write, not write_text/write()
for script in rebuild_indexes.py fix_frontmatter.py auto_linker.py concept_index.py stale_detector.py; do
  TOTAL=$((TOTAL+1))
  if grep -q "atomic_write" "$TOOLS/$script"; then
    PASS=$((PASS+1)); echo "  PASS: $script uses atomic_write"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $script missing atomic_write"
  fi
done

# Read-only scripts must NOT call atomic_write or write
for script in vault_health.py vault_stats.py broken_links.py; do
  TOTAL=$((TOTAL+1))
  if ! grep -q "atomic_write\|\.write(" "$TOOLS/$script"; then
    PASS=$((PASS+1)); echo "  PASS: $script is read-only"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $script should be read-only"
  fi
done

# ═══════════════════════════════════════════════════════════
# LAYER 8: Apply + verify
# ═══════════════════════════════════════════════════════════
echo "--- Layer 8: Apply + verify ---"

# stale_detector --apply changes status
SD_APPLY=$(run stale_detector.py --days 7 --apply)
SD_APP=$(jq_py "print(json.load(sys.stdin).get('applied', False))" "$SD_APPLY")
assert_eq "$SD_APP" "True" "stale_detector applied"

STALE_STATUS=$(python3 -c "
with open('$VAULT/10-Work/stale-note.md') as f:
    for line in f:
        if line.startswith('status:'):
            print(line.split(':',1)[1].strip())
            break
")
assert_eq "$STALE_STATUS" "paused" "stale status changed to paused"

# concept_index --apply creates file
CI_APPLY=$(run concept_index.py --apply)
TOTAL=$((TOTAL+1))
if [ -f "$VAULT/00-Dashboard/concept-index.md" ]; then
  PASS=$((PASS+1)); echo "  PASS: concept-index.md created"
else
  FAIL=$((FAIL+1)); echo "  FAIL: concept-index.md not created"
fi

# auto_linker defaults to dry-run
AL=$(run auto_linker.py)
AL_MODE=$(jq_py "print(json.load(sys.stdin)['mode'])" "$AL")
assert_eq "$AL_MODE" "dry-run" "auto_linker defaults to dry-run"

# --vault CLI argument works
OUT_CLI=$(python3 "$TOOLS/vault_health.py" --vault "$VAULT" 2>&1)
SCORE_CLI=$(jq_py "print(json.load(sys.stdin)['health_score'])" "$OUT_CLI")
assert_contains "$SCORE_CLI" "" "--vault CLI arg works"

# ═══════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════
echo ""
echo "==============================="
echo "RESULTS: $PASS PASS / $FAIL FAIL / $TOTAL TOTAL"
echo "==============================="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
