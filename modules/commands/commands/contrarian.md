---
name: contrarian
description: "Weekly contrarian analysis -- searches for excessive agreement patterns, unverified facts, stale memories, and absence of divergences. Use as part of /weekly, or standalone when the user wants to challenge assumptions. Reads last 7 Daily Notes + memory files + scheduled task outputs."
dependencies: "smart-connections MCP, vault-read"
allowed-tools: "Read,Write,Edit,Glob,Grep,Bash,mcp__ob-smart-connections__lookup"
---

# /contrarian

Contrarian agent. Deliberately searches for flaws in consensus, suspicious agreements, and facts accepted without questioning.

## Principle

**Disagreement grounded in evidence is more valuable than automatic consensus.** This command exists to compensate for the natural bias of AI agents toward agreement.

## Flow

### 1. Collect material from the week

```bash
VAULT="{{VAULT_PATH}}"

# Daily Notes from the last 7 days
for i in $(seq 0 6); do
  DATE=$(date -v-${i}d +%Y-%m-%d)
  FILE="$VAULT/Daily-Notes/$DATE.md"
  [ -f "$FILE" ] && echo "$FILE"
done
```

Read all Daily Notes found. If <3 Daily Notes: warn that the sample is small.

### 2. Confidence tag analysis

Extract all logs with confidence tags:

```bash
grep -h "\[confidence:" $VAULT/Daily-Notes/*.md 2>/dev/null | tail -100
```

Calculate distribution:
- % high vs medium vs low
- **Red flag:** >90% high = probably inflated
- **Red flag:** 0% low = agents never admit uncertainty

### 3. Challenge-previous analysis

```bash
grep -h "\[challenge-previous:" $VAULT/Daily-Notes/*.md 2>/dev/null | tail -50
```

- How many times was challenge-previous executed?
- How many times did it find something questionable?
- **Red flag:** 0 challenges in 7 days = nobody is questioning anything
- **Red flag:** 100% "no divergences" = challenge is being done pro forma

### 4. ConflictReport analysis

```bash
find $VAULT -name "ConflictReport*" -newer $VAULT/Daily-Notes/$(date -v-7d +%Y-%m-%d).md 2>/dev/null
```

- How many ConflictReports this week?
- **Red flag:** 0 in an active week = divergences are being ignored
- If any exist: check if they were resolved with evidence

### 5. Repeated facts without re-verification

Identify claims that appear in 3+ Daily Notes without a new source:

```bash
# Repetition patterns
grep -h "confirmed\|decided\|approved\|defined" $VAULT/Daily-Notes/*.md 2>/dev/null | sort | uniq -c | sort -rn | head -10
```

For each fact repeated 3+ times: verify if the original source is still valid.

### 6. Stale memories

```bash
MEMORY_DIR="{{MEMORY_DIR}}"
```

For each memory file:
- Read `created` from frontmatter
- If >30 days AND content mentions transient states: flag
- Verify if central claims are still true (spot check: pick 2-3 claims, verify against current sources)

### 7. Active counter-evidence search

For the 3 most important facts/conclusions of the week (extract from logs):
1. Actively search for evidence AGAINST the conclusion
2. Use Smart Connections to find contradicting notes
3. Grep for opposite/alternative terms

### 8. Generate report

Format:

```markdown
## Contrarian Report -- Week of YYYY-MM-DD to YYYY-MM-DD

### Anti-Sycophancy Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Confidence: % high | N% | ok / red-flag |
| Confidence: % low | N% | ok / red-flag |
| Challenges executed | N | ok / red-flag |
| Challenges with divergence | N | ok / red-flag |
| ConflictReports created | N | ok / red-flag |
| Facts repeated without re-verification | N | ok / red-flag |
| Stale memories (>30d transient) | N | ok / red-flag |

### Facts Questioned

For each fact questioned:
> [!question] {Fact}
> **Original source:** {where it came from}
> **Counter-evidence found:** {yes/no}
> **Recommendation:** keep | re-verify | correct | create ConflictReport

### Suspicious Agreement Patterns

List patterns where multiple sessions/sources agreed without independent evidence.

### Recommendations

List of concrete actions prioritized by impact.
```

### 9. Save and integrate

- Save report as a section of the Weekly Review (if running as part of /weekly)
- OR save as a separate note in `00-Dashboard/Contrarian Report YYYY-MM-DD.md` (if standalone)
- Link from Daily Note

## Rules

- This command is NOT neutral. It has a bias AGAINST consensus. This is intentional.
- Never conclude "all good, no problems found" without having checked each metric.
- If no real problems found: say "no problems found this week, but the absence of divergences itself can be a signal"
- Present findings to the user for decision. DO NOT auto-correct.
