---
name: weekly
description: "Weekly review -- summarizes 7 days, pending items, priorities. Use on Mondays or when the user asks for a weekly review. Reads last 7 Daily Notes, collects tasks, identifies cross-domain connections, generates 00-Dashboard/Weekly Review.md. Interactive -- asks user for perspective before generating."
dependencies: "notion MCP, smart-connections MCP, gh CLI, vault-read"
allowed-tools: "Read,Write,Edit,Glob,Grep,Bash,mcp__notion__*,mcp__ob-smart-connections__*"
---

# /weekly

Weekly review. INTERACTIVE model -- ask the user questions when you need data.

## Flow

### 1. Ask for the user's perspective
Ask:
- "How was the week? What stood out?"
- "Did any priority shift or something unexpected come up?"

### 2. Collect data
- Read the last 7 Daily Notes from `Daily-Notes/`
- If no Daily Notes found: ask "I didn't find Daily Notes for the week. Can you give me a summary?"
- Try task manager MCP -> tasks completed during the week
- If task manager does not connect: ask "Which tasks did you complete this week?"

### 3. GitHub metrics (quantitative)

Collect dev activity for the week via `gh`:

```bash
# Repos with activity in the last 7 days
gh repo list YOUR_USERNAME --limit 20 --json name,pushedAt --jq '.[] | select(.pushedAt > "YYYY-MM-DD") | .name'
```

For each repo with activity:
```bash
# Commits this week
gh api repos/YOUR_USERNAME/$REPO/commits --jq '.[].commit.message' -q "since=YYYY-MM-DDT00:00:00Z&until=YYYY-MM-DDT23:59:59Z" 2>/dev/null | wc -l

# PRs merged this week
gh pr list --repo YOUR_USERNAME/$REPO --state merged --json mergedAt,title --jq '.[] | select(.mergedAt > "YYYY-MM-DD")'

# LOC added/removed (approximate)
cd ~/Documents/Apps/*/$REPO 2>/dev/null && git log --since="7 days ago" --shortstat --oneline | tail -20
```

Compile into table:

```markdown
### Dev Metrics (week)

| Repo | Commits | PRs Merged | +Lines | -Lines |
|------|---------|------------|--------|--------|
| project-a | N | N | +N | -N |
| project-b | N | N | +N | -N |
| **Total** | **N** | **N** | **+N** | **-N** |
```

If no repo has activity: skip this section silently.

### 3.5 Session Index + Token Economy Report

Update the session index (incremental, fast):

```bash
VAULT_PATH={{VAULT_PATH}} python3 {{VAULT_PATH}}/../tools/session_index.py --incremental
```

Generate a token consumption report for the week:

```bash
SINCE_DAYS=7 python3 {{VAULT_PATH}}/../tools/token_analysis.py
# Or if installed globally:
# SINCE_DAYS=7 VAULT_PATH={{VAULT_PATH}} python3 token_analysis.py
```

If the script is not available, skip this section with a note.

Read the generated report at `00-Dashboard/token-report.md` and extract:
- Grand totals (tokens, estimated cost)
- Top 3 projects by cost
- Top 3 costliest sessions (with first prompt)
- Daily trend for the week
- % of tokens in subagents vs main sessions

Compile:

```markdown
### Token Economy

| Metric | Value |
|--------|-------|
| Total tokens (7d) | N |
| Estimated cost (fast mode) | $N |
| Sessions | N |
| Subagent % | N% |

**Top projects:** Project1 ($N), Project2 ($N), Project3 ($N)

**Costliest session:** $N -- "first prompt..." (N subagents)

**Daily trend:** increasing / stable / decreasing
```

If average daily cost is >$5K: flag as alert with optimization recommendation.
If subagent % is >60%: suggest reviewing parallel agent dispatch.

### 3.6 Memory Health Check (consolidation)

Run a maintenance pass on memory files:

```bash
MEMORY_DIR="{{MEMORY_DIR}}"
VAULT="{{VAULT_PATH}}"

# 1. List all memory files
ls "$MEMORY_DIR"/*.md | grep -v MEMORY.md

# 2. Count lines of MEMORY.md (alert if >150)
wc -l "$MEMORY_DIR/MEMORY.md"
```

For each memory file:

**a) Stale references** -- extract paths and wikilinks, check if they exist:
```bash
# Absolute paths
grep -oE '/[^ "]+\.md' "$MEMORY_DIR/$FILE" | while read p; do
  [ ! -f "$p" ] && echo "STALE: $FILE references $p (not found)"
done

# Wikilinks
grep -oE '\[\[[^\]]+\]\]' "$MEMORY_DIR/$FILE" | sed 's/\[\[//;s/\]\]//' | while read link; do
  found=$(find "$VAULT" -name "$(basename "$link").md" 2>/dev/null | head -1)
  [ -z "$found" ] && echo "STALE WIKILINK: $FILE references [[$link]] (not found)"
done
```

**b) Stale transient memories** -- memories >30 days about temporary states (bugs, workarounds, status):
- Read `created` or `description` from frontmatter
- If >30 days AND description mentions "bug", "workaround", "status", "pending", "blocked": flag for review

**c) Duplicates** -- compare descriptions of all files. If 2+ have >80% overlap in description: flag.

**d) MEMORY.md index check** -- each file in `$MEMORY_DIR` should have an entry in MEMORY.md. List orphans (file without index entry) and ghosts (index entry without file).

Compile result:

```markdown
### Memory Health

| Check | Result |
|-------|--------|
| MEMORY.md | N lines (ok / warning >150) |
| Stale references | N found |
| Transient >30d | N for review |
| Duplicates | N suspected |
| Orphans/Ghosts | N |
```

If issues found: list each with suggested action (remove, update, or keep). DO NOT auto-correct. Present to user for decision.

### 3.7 Contrarian Analysis (anti-sycophancy)

Run the weekly contrarian analysis (integrated version of `/contrarian`):

**a) Confidence tag distribution:**
```bash
VAULT="{{VAULT_PATH}}"
grep -h "\[confidence:" $VAULT/Daily-Notes/*.md 2>/dev/null | grep -oE "confidence: (high|medium|low)" | sort | uniq -c | sort -rn
```

**b) Challenge-previous rate:**
```bash
grep -h "\[challenge-previous:" $VAULT/Daily-Notes/*.md 2>/dev/null | wc -l
```

**c) ConflictReports created:**
```bash
find $VAULT -name "ConflictReport*" -newer $VAULT/Daily-Notes/$(date -v-7d +%Y-%m-%d).md 2>/dev/null | wc -l
```

Compile:

```markdown
### Anti-Sycophancy Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Confidence: % high | N% | ok / red-flag (>90%) |
| Challenges executed | N | ok / red-flag (0) |
| ConflictReports | N | ok / red-flag (0 in active week) |
```

If any metric is red-flag: list specific recommendation.

### 3.8 User Model Review

Run a lightweight version of `/model-review`:

1. List memory files and Daily Notes from the last 7 days
2. Scan for repeated preferences not captured in feedback memories
3. Check project memories against actual activity (flag stale if 0 activity in 14+ days)
4. If new workflow patterns detected: suggest `/distill`

Compile:

```markdown
### User Model

| Type | Finding | Suggested Action |
|------|---------|-----------------|
| New preference | [description] | Create feedback memory |
| Stale memory | [file] | Review/archive |
| Missing project | [domain] | Create project memory |
```

If no findings: skip this section silently.

### 4. Search vault for connections
- Use Smart Connections or grep to identify recurring themes
  <!-- LIMIT: Smart Connections max 3 results (boot-protocol rule) -->
  <!-- LIMIT: grep max 5 results, filter by domain first (boot-protocol rule) -->
- Search for notes created/modified during the week

### 5. Generate Weekly Review
- Path: `00-Dashboard/Weekly Review.md` (overwrite with new week)
- Sections:
  - `## Week of YYYY-MM-DD to YYYY-MM-DD`
  - `### Done` (by domain)
  - `### Dev Metrics` (GitHub table if there was activity)
  - `### Pending` (what was not completed)
  - `### Connections` (cross-domain patterns identified)
  - `### Vault Health Score` (run /health and report score 0-100 with component breakdown)
  - `### WIP Status` (read `00-Dashboard/wip.md`, list active, stale, and completed workstreams)
  - `### Token Economy` (result from check 3.5 -- tokens, cost, top projects, trend)
  - `### Memory Health` (result from check 3.6)
  - `### Anti-Sycophancy Metrics` (result from check 3.7)
  - `### User Model` (result from check 3.8, if findings exist)
  - `### Next week` (priority suggestions)

### 6. Ask for validation
- Show the summary and ask: "Does this reflect the week well? Want to adjust anything?"

### 7. Output
```
Weekly Review updated (YYYY-MM-DD to YYYY-MM-DD)
Done: N items by domain
Pending: N items
Connections identified: [short list]
```

## Source fallback

If an MCP fails (timeout >15s, 401/403, network error, empty response):
1. Log in output: `[!] Source unavailable: [name]`
2. Skip the category, do not block the entire command
3. Continue with remaining sources
4. If ALL sources fail, report and suggest retry

## Rules
- Never fabricated content
- Ask for validation before finalizing
