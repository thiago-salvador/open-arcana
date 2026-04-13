#!/bin/bash
# vault-test.sh - Automated vault health test suite v2
# Inspired by autoresearch (Karpathy): fixed metric, reproducible, scriptable
# Usage: bash vault-test.sh [test1|test2|test3|test4|test5|all]
# v2: Expanded from 285 to 500+ checks
#
# CONFIGURATION:
# Set VAULT environment variable or edit the path below.

VAULT="${VAULT:-{{VAULT_PATH}}}"
CONCEPT_INDEX="$VAULT/00-Dashboard/concept-index.md"
ALIASES="$VAULT/00-Dashboard/aliases.md"
HOT_CACHE="$VAULT/00-Dashboard/hot-cache.md"
PESSOAS="$VAULT/70-People"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================
# TEST 1: RETRIEVAL ACCURACY
# Does the concept-index + aliases resolve known queries?
# ============================================================
test1_retrieval() {
    echo -e "${BLUE}=== Test 1: Retrieval Accuracy ===${NC}"
    local pass=0
    local fail=0
    local total=0

    # Format: "search_term|expected_file_fragment|layer"
    # Layer: ci=concept-index, al=aliases, hc=hot-cache
    #
    # CUSTOMIZE: Replace these with your actual vault entries.
    # Each query tests that a search term resolves to the expected note.
    #
    # Example entries (replace with your own):
    #   "project-alpha|Project Alpha Roadmap|ci"
    #   "john|John Smith|ci"
    #   "meeting notes|Weekly Standup|ci"

    local queries=(
        # === ADD YOUR QUERIES HERE ===
        # Format: "search_term|expected_file_fragment|ci"
        # "your-concept|Expected Note Name|ci"
        # "person-name|Full Name|ci"
        # "project|Project Note|ci"
    )

    # Test concept-index lookups
    for q in "${queries[@]}"; do
        IFS='|' read -r term expected layer <<< "$q"
        total=$((total + 1))
        if grep -qi "$term" "$CONCEPT_INDEX" 2>/dev/null; then
            local found=0
            while IFS= read -r line; do
                if echo "$line" | grep -qi "$expected"; then
                    found=1
                    break
                fi
            done < <(grep -i "$term" "$CONCEPT_INDEX")
            if [ "$found" -eq 1 ]; then
                pass=$((pass + 1))
            else
                echo -e "  ${YELLOW}PARTIAL${NC}: '$term' found in index but not linked to '$expected'"
                fail=$((fail + 1))
            fi
        else
            echo -e "  ${RED}MISS${NC}: '$term' not in concept-index"
            fail=$((fail + 1))
        fi
    done

    # === ALIAS RESOLUTION ===
    # CUSTOMIZE: Replace with your actual aliases.
    # Format: "alias_term|expected_canonical|al"
    #
    # Example entries:
    #   "JD|John Doe|al"
    #   "the app|Main Product|al"

    local alias_queries=(
        # === ADD YOUR ALIAS QUERIES HERE ===
        # "alias|Expected Canonical|al"
    )

    for q in "${alias_queries[@]}"; do
        IFS='|' read -r term expected layer <<< "$q"
        total=$((total + 1))
        if grep -qi "$term" "$ALIASES" 2>/dev/null; then
            local line=$(grep -i "$term" "$ALIASES" | head -1)
            if echo "$line" | grep -qi "$expected" || grep -B5 -i "$term" "$ALIASES" | grep -qi "$expected"; then
                pass=$((pass + 1))
            else
                echo -e "  ${YELLOW}PARTIAL${NC}: '$term' found in aliases but canonical != '$expected'"
                fail=$((fail + 1))
            fi
        else
            echo -e "  ${RED}MISS${NC}: '$term' not in aliases"
            fail=$((fail + 1))
        fi
    done

    # === NEGATIVE TESTS: concepts that should NOT be in the index ===
    # Add terms that are irrelevant to your vault to catch false positives.
    local negative_queries=(
        "kubernetes"
        "blockchain"
        "web3"
        "metaverse"
        "nft"
        "solana"
        "cryptocurrency"
    )
    for term in "${negative_queries[@]}"; do
        total=$((total + 1))
        if grep -qi "$term" "$CONCEPT_INDEX" 2>/dev/null; then
            echo -e "  ${RED}FALSE POSITIVE${NC}: '$term' should NOT be in concept-index"
            fail=$((fail + 1))
        else
            pass=$((pass + 1))
        fi
    done

    local score=0
    if [ $total -gt 0 ]; then
        score=$(echo "scale=1; $pass * 100 / $total" | bc)
    fi
    echo -e "  ${GREEN}Result${NC}: $pass/$total passed (${score}%)"
    echo "$score"
}

# ============================================================
# TEST 2: DATA INTEGRITY (People Notes)
# Frontmatter completeness + no fabricated data + quality
# ============================================================
test2_integrity() {
    echo -e "${BLUE}=== Test 2: Data Integrity (People) ===${NC}"
    local pass=0
    local fail=0
    local total=0
    local required_fields=("title" "summary" "type" "domain" "tags" "status" "created")

    for f in "$PESSOAS"/*.md; do
        [ "$(basename "$f")" = "index.md" ] && continue
        [ ! -f "$f" ] && continue
        local name=$(basename "$f" .md)

        # Check required frontmatter fields
        for field in "${required_fields[@]}"; do
            total=$((total + 1))
            if head -15 "$f" | grep -q "^${field}:" 2>/dev/null; then
                pass=$((pass + 1))
            else
                echo -e "  ${RED}MISSING${NC}: $name -- field '$field'"
                fail=$((fail + 1))
            fi
        done

        # Check last_interaction exists and is not placeholder
        total=$((total + 1))
        if head -15 "$f" | grep -q "^last_interaction:" 2>/dev/null; then
            local li=$(head -15 "$f" | grep "^last_interaction:" | head -1)
            if echo "$li" | grep -q "2026-01-01"; then
                echo -e "  ${RED}PLACEHOLDER${NC}: $name -- last_interaction is placeholder date"
                fail=$((fail + 1))
            else
                pass=$((pass + 1))
            fi
        else
            echo -e "  ${YELLOW}MISSING${NC}: $name -- no last_interaction"
            fail=$((fail + 1))
        fi

        # Check summary is not too generic (>15 chars)
        total=$((total + 1))
        local summary=$(head -15 "$f" | grep "^summary:" | sed 's/^summary: *//' | tr -d '"')
        if [ ${#summary} -gt 15 ]; then
            pass=$((pass + 1))
        else
            echo -e "  ${YELLOW}WEAK${NC}: $name -- summary too short: '$summary'"
            fail=$((fail + 1))
        fi

        # Check for wikilinks (bidirectional connections)
        total=$((total + 1))
        local links=$(grep -c '\[\[' "$f" 2>/dev/null || echo 0)
        if [ "$links" -gt 0 ]; then
            pass=$((pass + 1))
        else
            echo -e "  ${YELLOW}NO LINKS${NC}: $name -- no wikilinks found"
            fail=$((fail + 1))
        fi

        # Summary quality - must mention a role or relationship
        # CUSTOMIZE: Add role keywords relevant to your vault
        total=$((total + 1))
        local summary_lower=$(echo "$summary" | tr '[:upper:]' '[:lower:]')
        if echo "$summary_lower" | grep -qiE "(developer|designer|founder|ceo|cto|cfo|director|manager|engineer|investor|partner|lead|head|vp|president|advisor|consultant|friend|colleague)"; then
            pass=$((pass + 1))
        else
            echo -e "  ${YELLOW}WEAK SUMMARY${NC}: $name -- summary doesn't mention role/relationship"
            fail=$((fail + 1))
        fi

        # Must have at least one H2 section
        total=$((total + 1))
        local h2_count=$(grep -c "^## " "$f" 2>/dev/null || echo "0")
        h2_count=$(echo "$h2_count" | tr -d '[:space:]')
        if [ "$h2_count" -ge 1 ]; then
            pass=$((pass + 1))
        else
            echo -e "  ${YELLOW}NO SECTIONS${NC}: $name -- no ## sections found"
            fail=$((fail + 1))
        fi

        # "not confirmed" / "unconfirmed" count - max 2 per note
        total=$((total + 1))
        local unconfirmed=$(grep -ci "not confirmed\|unconfirmed" "$f" 2>/dev/null || echo "0")
        unconfirmed=$(echo "$unconfirmed" | tr -d '[:space:]')
        if [ "$unconfirmed" -le 2 ]; then
            pass=$((pass + 1))
        else
            echo -e "  ${YELLOW}LOW QUALITY${NC}: $name -- $unconfirmed unconfirmed entries (max 2)"
            fail=$((fail + 1))
        fi
    done

    local score=0
    if [ $total -gt 0 ]; then
        score=$(echo "scale=1; $pass * 100 / $total" | bc)
    fi
    echo -e "  ${GREEN}Result${NC}: $pass/$total checks passed (${score}%)"
    echo "$score"
}

# ============================================================
# TEST 3: INDEX CONSISTENCY
# Every folder + subfolder has index.md, every note is listed, no phantoms
# ============================================================
test3_consistency() {
    echo -e "${BLUE}=== Test 3: Index Consistency ===${NC}"
    local pass=0
    local fail=0
    local total=0

    # CUSTOMIZE: List your top-level vault folders that should have index.md
    local folders=("10-Work" "15-Projects" "20-Studio" "25-Agency" "30-Content" "40-Partnerships" "50-Speaking" "60-Research" "70-People" "90-Archive")

    for folder in "${folders[@]}"; do
        local dir="$VAULT/$folder"
        [ ! -d "$dir" ] && continue
        total=$((total + 1))

        # Check index.md exists
        if [ -f "$dir/index.md" ]; then
            pass=$((pass + 1))
        else
            echo -e "  ${RED}MISSING INDEX${NC}: $folder/index.md"
            fail=$((fail + 1))
            continue
        fi

        # Check for orphan notes (in folder but not in index)
        for note in "$dir"/*.md; do
            [ "$(basename "$note")" = "index.md" ] && continue
            [ ! -f "$note" ] && continue
            local notename=$(basename "$note" .md)
            total=$((total + 1))
            if grep -qi "$notename" "$dir/index.md" 2>/dev/null; then
                pass=$((pass + 1))
            else
                echo -e "  ${YELLOW}ORPHAN${NC}: $folder/$(basename "$note") -- not in index"
                fail=$((fail + 1))
            fi
        done

        # Check for phantom links (in index but file doesn't exist) - macOS compatible
        local phantoms=$(grep -oE '\[\[[^]|]+' "$dir/index.md" 2>/dev/null | sed 's/\[\[//;s/\\$//' | sort -u | while read link; do
            if echo "$link" | grep -q '/$'; then
                local target="$VAULT/${link}index.md"
                if [ ! -f "$target" ]; then
                    echo "PHANTOM: $link"
                fi
            else
                local target="$VAULT/${link}.md"
                if [ ! -f "$target" ]; then
                    echo "PHANTOM: $link"
                fi
            fi
        done | wc -l | tr -d ' ')

        if [ "$phantoms" -gt 0 ]; then
            total=$((total + 1))
            echo -e "  ${RED}PHANTOMS${NC}: $folder/index.md has $phantoms broken links"
            fail=$((fail + 1))
        fi
    done

    # CUSTOMIZE: List subdirectories that should also have index.md
    local subdirs=(
        # "10-Work/Product"
        # "10-Work/Growth"
        # "30-Content/Social"
        # "30-Content/Articles"
        # "60-Research/Trends"
    )

    for sub in "${subdirs[@]}"; do
        local dir="$VAULT/$sub"
        [ ! -d "$dir" ] && continue
        total=$((total + 1))
        if [ -f "$dir/index.md" ]; then
            pass=$((pass + 1))
        else
            echo -e "  ${RED}MISSING SUBINDEX${NC}: $sub/index.md"
            fail=$((fail + 1))
            continue
        fi

        # Check orphan notes in subdirectory
        for note in "$dir"/*.md; do
            [ "$(basename "$note")" = "index.md" ] && continue
            [ ! -f "$note" ] && continue
            local notename=$(basename "$note" .md)
            total=$((total + 1))
            if grep -qi "$notename" "$dir/index.md" 2>/dev/null; then
                pass=$((pass + 1))
            else
                echo -e "  ${YELLOW}ORPHAN${NC}: $sub/$(basename "$note") -- not in subindex"
                fail=$((fail + 1))
            fi
        done
    done

    # MOC wikilinks resolve
    if [ -d "$VAULT/MOCs" ]; then
        local moc_broken=0
        for f in "$VAULT"/MOCs/*.md; do
            [ "$(basename "$f")" = "index.md" ] && continue
            [ ! -f "$f" ] && continue
            while IFS= read -r link; do
                echo "$link" | grep -q '/$' && continue
                [ -z "$link" ] && continue
                local target="$VAULT/${link}.md"
                if [ ! -f "$target" ]; then
                    total=$((total + 1))
                    echo -e "  ${RED}BROKEN MOC${NC}: $(basename "$f" .md) -> [[$link]]"
                    fail=$((fail + 1))
                    moc_broken=$((moc_broken + 1))
                else
                    total=$((total + 1))
                    pass=$((pass + 1))
                fi
            done < <(grep -oE '\[\[[^]|]+' "$f" 2>/dev/null | sed 's/\[\[//' | sort -u)
        done
    fi

    local score=0
    if [ $total -gt 0 ]; then
        score=$(echo "scale=1; $pass * 100 / $total" | bc)
    fi
    echo -e "  ${GREEN}Result${NC}: $pass/$total checks passed (${score}%)"
    echo "$score"
}

# ============================================================
# TEST 4: FRESHNESS
# Hot-cache valid, concept-index entries resolve, coverage checks
# ============================================================
test4_freshness() {
    echo -e "${BLUE}=== Test 4: Freshness ===${NC}"
    local pass=0
    local fail=0
    local total=0

    # Check hot-cache notes exist (macOS compatible)
    if [ -f "$HOT_CACHE" ]; then
        while IFS= read -r link; do
            [ -z "$link" ] && continue
            total=$((total + 1))
            local target="$VAULT/${link}.md"
            if [ -f "$target" ]; then
                pass=$((pass + 1))
            else
                echo -e "  ${RED}BROKEN HOT-CACHE${NC}: [[$link]] doesn't exist"
                fail=$((fail + 1))
            fi
        done < <(grep -oE '\[\[[^]|]+' "$HOT_CACHE" 2>/dev/null | sed 's/\[\[//' | sort -u)
    fi

    # Check ALL concept-index links resolve
    if [ -f "$CONCEPT_INDEX" ]; then
        while IFS= read -r link; do
            [ -z "$link" ] && continue
            total=$((total + 1))
            local target="$VAULT/${link}.md"
            if [ -f "$target" ]; then
                pass=$((pass + 1))
            else
                echo -e "  ${RED}BROKEN CI${NC}: [[$link]] doesn't exist"
                fail=$((fail + 1))
            fi
        done < <(grep -oE '\[\[[^]|]+' "$CONCEPT_INDEX" 2>/dev/null | sed 's/\[\[//' | sort -u)
    fi

    # Check aliases file is valid (no empty canonical)
    if [ -f "$ALIASES" ]; then
        total=$((total + 1))
        local empty_canonical=$(grep "canonical:" "$ALIASES" 2>/dev/null | grep '""' | wc -l | tr -d ' ')
        if [ "$empty_canonical" -eq 0 ]; then
            pass=$((pass + 1))
        else
            echo -e "  ${RED}EMPTY CANONICAL${NC}: $empty_canonical aliases have empty canonical"
            fail=$((fail + 1))
        fi
    fi

    # Check daily note exists for today
    total=$((total + 1))
    local today=$(date +%Y-%m-%d)
    if [ -f "$VAULT/Daily-Notes/${today}.md" ]; then
        pass=$((pass + 1))
    else
        echo -e "  ${RED}NO DAILY NOTE${NC}: $today"
        fail=$((fail + 1))
    fi

    # Concept-index covers ALL person notes
    if [ -d "$PESSOAS" ] && [ -f "$CONCEPT_INDEX" ]; then
        for f in "$PESSOAS"/*.md; do
            [ "$(basename "$f")" = "index.md" ] && continue
            [ ! -f "$f" ] && continue
            local name=$(basename "$f" .md)
            total=$((total + 1))
            if grep -q "$name" "$CONCEPT_INDEX" 2>/dev/null; then
                pass=$((pass + 1))
            else
                echo -e "  ${RED}UNCOVERED PERSON${NC}: $name not in concept-index"
                fail=$((fail + 1))
            fi
        done
    fi

    # Concept-index covers ALL project notes
    if [ -d "$VAULT/15-Projects" ] && [ -f "$CONCEPT_INDEX" ]; then
        for f in "$VAULT/15-Projects"/*.md; do
            [ "$(basename "$f")" = "index.md" ] && continue
            [ ! -f "$f" ] && continue
            local name=$(basename "$f" .md)
            total=$((total + 1))
            if grep -q "$name" "$CONCEPT_INDEX" 2>/dev/null; then
                pass=$((pass + 1))
            else
                echo -e "  ${RED}UNCOVERED PROJECT${NC}: $name not in concept-index"
                fail=$((fail + 1))
            fi
        done
    fi

    # CUSTOMIZE: Add hot-cache Tier 1 expected entries
    # These are terms you expect to always be in your hot-cache.
    local tier1_expected=(
        "Daily-Notes"
        # "Your Priority Note"
        # "Your Active Project"
    )
    for term in "${tier1_expected[@]}"; do
        total=$((total + 1))
        if [ -f "$HOT_CACHE" ] && grep -qi "$term" "$HOT_CACHE" 2>/dev/null; then
            pass=$((pass + 1))
        else
            echo -e "  ${YELLOW}MISSING T1${NC}: '$term' not in hot-cache Tier 1"
            fail=$((fail + 1))
        fi
    done

    local score=0
    if [ $total -gt 0 ]; then
        score=$(echo "scale=1; $pass * 100 / $total" | bc)
    fi
    echo -e "  ${GREEN}Result${NC}: $pass/$total checks passed (${score}%)"
    echo "$score"
}

# ============================================================
# TEST 5: TASKS HEALTH
# Scheduled tasks have evidence of running in daily notes
# ============================================================
test5_tasks() {
    echo -e "${BLUE}=== Test 5: Tasks Health ===${NC}"
    local pass=0
    local fail=0
    local total=0

    local today=$(date +%Y-%m-%d)
    local yesterday=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d 2>/dev/null)
    local daily_today="$VAULT/Daily-Notes/${today}.md"
    local daily_yesterday="$VAULT/Daily-Notes/${yesterday}.md"

    # Check if tasks have evidence in recent daily notes
    # CUSTOMIZE: Add markers for your scheduled tasks
    local task_markers=(
        "morning-briefing|Intelligence Briefing|Briefing ran today"
        "news|News digest|News digest ran"
        "session-logging|## Log|Session log exists in daily note"
    )

    for t in "${task_markers[@]}"; do
        IFS='|' read -r task marker desc <<< "$t"
        total=$((total + 1))
        if grep -qi "$marker" "$daily_today" 2>/dev/null; then
            pass=$((pass + 1))
        elif grep -qi "$marker" "$daily_yesterday" 2>/dev/null; then
            pass=$((pass + 1))
        else
            echo -e "  ${YELLOW}NO EVIDENCE${NC}: $task -- '$marker' not found in recent daily notes"
            fail=$((fail + 1))
        fi
    done

    # Check scheduled tasks config exists
    total=$((total + 1))
    local tasks_config="$VAULT/.claude/settings.local.json"
    if [ -f "$tasks_config" ]; then
        pass=$((pass + 1))
    else
        echo -e "  ${YELLOW}NO CONFIG${NC}: settings.local.json not found at $tasks_config"
        fail=$((fail + 1))
    fi

    # Check hooks exist
    total=$((total + 1))
    if grep -rq "PreToolUse\|PostToolUse\|SessionStart" "$VAULT/.claude/" 2>/dev/null; then
        pass=$((pass + 1))
    else
        echo -e "  ${YELLOW}NO HOOKS${NC}: No hook configuration found"
        fail=$((fail + 1))
    fi

    local score=0
    if [ $total -gt 0 ]; then
        score=$(echo "scale=1; $pass * 100 / $total" | bc)
    fi
    echo -e "  ${GREEN}Result${NC}: $pass/$total checks passed (${score}%)"
    echo "$score"
}

# ============================================================
# TEST 6: SCRIPTS OFFLOAD
# Python scripts installed, produce valid JSON, consistent scores
# ============================================================
test6_scripts() {
    echo -e "${BLUE}=== Test 6: Scripts Offload ===${NC}"
    local pass=0
    local fail=0
    local total=0

    local tools_dir="$VAULT/.claude/tools"

    # Check scripts are installed
    local required_scripts=("_common.py" "vault_health.py" "vault_stats.py" "rebuild_indexes.py" "fix_frontmatter.py" "auto_linker.py" "broken_links.py" "concept_index.py" "stale_detector.py")
    for s in "${required_scripts[@]}"; do
        total=$((total + 1))
        if [ -f "$tools_dir/$s" ]; then
            pass=$((pass + 1))
        else
            echo -e "  ${RED}MISSING${NC}: $s not installed in .claude/tools/"
            fail=$((fail + 1))
        fi
    done

    # Check Python is available
    total=$((total + 1))
    if command -v python3 &>/dev/null; then
        pass=$((pass + 1))
    else
        echo -e "  ${RED}NO PYTHON${NC}: python3 not found in PATH"
        fail=$((fail + 1))
        local score=0
        if [ $total -gt 0 ]; then
            score=$(echo "scale=1; $pass * 100 / $total" | bc)
        fi
        echo -e "  ${GREEN}Result${NC}: $pass/$total checks passed (${score}%)"
        echo "$score"
        return
    fi

    # Check each script produces valid JSON (dry-run)
    local json_scripts=("vault_health.py" "vault_stats.py" "rebuild_indexes.py" "fix_frontmatter.py" "auto_linker.py" "broken_links.py" "concept_index.py" "stale_detector.py")
    for s in "${json_scripts[@]}"; do
        [ ! -f "$tools_dir/$s" ] && continue
        total=$((total + 1))
        local out
        out=$(VAULT_PATH="$VAULT" python3 "$tools_dir/$s" 2>&1)
        if echo "$out" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
            pass=$((pass + 1))
        else
            echo -e "  ${RED}INVALID JSON${NC}: $s"
            fail=$((fail + 1))
        fi
    done

    # Check vault_health score is reasonable (0-100)
    if [ -f "$tools_dir/vault_health.py" ]; then
        total=$((total + 1))
        local health_out
        health_out=$(VAULT_PATH="$VAULT" python3 "$tools_dir/vault_health.py" 2>&1)
        local health_score
        health_score=$(echo "$health_out" | python3 -c "import sys,json; print(json.load(sys.stdin).get('health_score', -1))" 2>/dev/null || echo "-1")
        if [ "$health_score" -ge 0 ] && [ "$health_score" -le 100 ] 2>/dev/null; then
            pass=$((pass + 1))
        else
            echo -e "  ${RED}BAD SCORE${NC}: vault_health returned $health_score (expected 0-100)"
            fail=$((fail + 1))
        fi
    fi

    local score=0
    if [ $total -gt 0 ]; then
        score=$(echo "scale=1; $pass * 100 / $total" | bc)
    fi
    echo -e "  ${GREEN}Result${NC}: $pass/$total checks passed (${score}%)"
    echo "$score"
}

# ============================================================
# COMPOSITE SCORE
# ============================================================
composite() {
    local t1=$1 t2=$2 t3=$3 t4=$4 t5=$5 t6=${6:-0}
    local score=$(echo "scale=1; ($t1 * 0.25) + ($t2 * 0.20) + ($t3 * 0.20) + ($t4 * 0.15) + ($t5 * 0.10) + ($t6 * 0.10)" | bc)
    echo "$score"
}

# ============================================================
# MAIN
# ============================================================
if [ "$1" = "all" ] || [ -z "$1" ]; then
    echo ""
    echo "=================================="
    echo "  VAULT TEST SUITE v2"
    echo "  $(date +%Y-%m-%d\ %H:%M)"
    echo "=================================="
    echo ""

    t1_output=$(test1_retrieval)
    t1_score=$(echo "$t1_output" | tail -1)
    echo "$t1_output" | sed '$d'
    echo ""

    t2_output=$(test2_integrity)
    t2_score=$(echo "$t2_output" | tail -1)
    echo "$t2_output" | sed '$d'
    echo ""

    t3_output=$(test3_consistency)
    t3_score=$(echo "$t3_output" | tail -1)
    echo "$t3_output" | sed '$d'
    echo ""

    t4_output=$(test4_freshness)
    t4_score=$(echo "$t4_output" | tail -1)
    echo "$t4_output" | sed '$d'
    echo ""

    t5_output=$(test5_tasks)
    t5_score=$(echo "$t5_output" | tail -1)
    echo "$t5_output" | sed '$d'
    echo ""

    t6_output=$(test6_scripts)
    t6_score=$(echo "$t6_output" | tail -1)
    echo "$t6_output" | sed '$d'
    echo ""

    echo "=================================="
    printf "  Test 1 (Retrieval):    %s%%\n" "$t1_score"
    printf "  Test 2 (Integrity):    %s%%\n" "$t2_score"
    printf "  Test 3 (Consistency):  %s%%\n" "$t3_score"
    printf "  Test 4 (Freshness):    %s%%\n" "$t4_score"
    printf "  Test 5 (Tasks):        %s%%\n" "$t5_score"
    printf "  Test 6 (Scripts):      %s%%\n" "$t6_score"
    echo "=================================="
    composite=$(echo "scale=1; ($t1_score * 0.25) + ($t2_score * 0.20) + ($t3_score * 0.20) + ($t4_score * 0.15) + ($t5_score * 0.10) + ($t6_score * 0.10)" | bc)
    printf "  VAULT SCORE: %s\n" "$composite"
    echo "=================================="
    echo ""
    echo "vault_score: $composite"
else
    # Run individual test
    case "$1" in
        test1) test1_retrieval ;;
        test2) test2_integrity ;;
        test3) test3_consistency ;;
        test4) test4_freshness ;;
        test5) test5_tasks ;;
        test6) test6_scripts ;;
        *) echo "Usage: bash vault-test.sh [test1|test2|test3|test4|test5|test6|all]" ;;
    esac
fi
