# Completion Tracking Module — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a completion-tracking module to Open Arcana that closes the loop between data ingestion and action item tracking, so fulfillments in one source automatically resolve open items in another.

**Architecture:** A new module (`modules/completion-tracking/`) with 2 rule files and patches to 2 existing commands. The agent IS the reconciler — no external scripts. Rules define when and how to match new data against open action items, with safety guardrails. Task manager references use generic placeholders (not Notion-specific).

**Tech Stack:** Vault rules, Obsidian commands, grep, optional Smart Connections MCP, optional task manager MCP

**Design doc:** `docs/plans/2026-04-10-completion-tracking-design.md` (this file doubles as design)

---

## Dependencies

- Task 1 and Task 2 are independent (can be parallelized)
- Task 3 and Task 4 are independent (can be parallelized, depend on Task 1)
- Task 5 depends on Tasks 1-4
- Task 6 depends on Task 5

---

### Task 1: Create completion-tracking rule file

**Files:**
- Create: `modules/completion-tracking/rules/completion-tracking.md`

**Step 1: Write the rule file**

```markdown
# Completion Tracking (3 rules)

## CT-1. Mark action items in meeting notes

When a task originated from a meeting is completed during a session:
1. Edit the meeting note: change `- [ ]` to `- [x]` on the corresponding item
2. If the meeting note is older than 30 days, do not edit (it is historical)

This prevents meeting notes with open checkboxes from being treated as a source of pending items.

## CT-2. Record deliverables in memory

When completing significant work for any project with delivery tracking:
1. Update the project's deliverables memory file (`project_*_deliverables.md` or equivalent)
2. Move the item from "Pending" to "Delivered" with the date
3. If the item was discarded, move it to "Discarded" with the reason

Without completion records, future sessions re-list work that was already done. This wastes time and erodes trust.

## CT-3. End-of-session warning if deliverables not updated

If the Daily Note has entries for significant work (grep for `**` bold entries with project/domain tags) but no `[auto-reconciled]` or `[user-declared]` entry appears, AND the deliverables memory was not edited in the session, the agent should warn before closing:

> "There was significant work in this session but no deliverable was updated. Want me to update the tracking?"
```

**Step 2: Verify**

Run: `grep -c "^## CT-" modules/completion-tracking/rules/completion-tracking.md`
Expected: 3

**Step 3: Commit**

```bash
git add modules/completion-tracking/rules/completion-tracking.md
git commit -m "feat(completion-tracking): add CT-1 to CT-3 rules"
```

---

### Task 2: Create cross-source reconciler rule file

**Files:**
- Create: `modules/completion-tracking/rules/cross-source-reconciler.md`

**Step 1: Write the rule file**

```markdown
# Cross-Source Reconciler (3 rules)

## CSR-1. Reconciliation at ingestion time

After processing new data from any source (chat messages, emails, meeting transcripts, work sessions), execute the reconciliation step:

1. **EXTRACT** entities from the new data: names of people, projects, tools, key terms. Detect fulfillment signals: links, attachments, "here's", "done", "attached", "sent", "completed".
2. **LOAD** open action items (max 3 reads):
   - Recent meeting notes: `grep -rl "\- \[ \]" {domain}/Meetings/` (last 30 days)
   - Deliverables memory: "Pending" section in `project_*_deliverables.md`
   - Task manager: pending tasks (if a task manager MCP is available)
3. **MATCH** (hybrid):
   - 3a. Keyword: extracted entities vs action item text. Exact match = confidence HIGH.
   - 3b. If keyword = 0 matches AND fulfillment signals are present: semantic search via Smart Connections (max 3 results). Semantic match = confidence MEDIUM.
4. **ACT** based on confidence:
   - **HIGH:** auto-resolve. Mark `[x]` in the meeting note (if <30 days, per CT-1). Move to "Delivered" in deliverables memory (per CT-2). If a task manager MCP is available, update task status to done. Log in DN: `[auto-reconciled] "item" <- source (confidence: high)`
   - **MEDIUM/LOW:** flag for review. Add entry to `00-Dashboard/alerts.md`. Log in DN: `[reconcile-candidate] "item" <- source (confidence: medium)`. Do not change anything until the user confirms.
5. **LOG** results. If zero matches: silence (do not pollute the DN).

## CSR-2. Safety guardrails

- Never auto-resolve without concrete evidence (link, file, explicit declaration)
- Never edit a meeting note older than 30 days
- Max 5 auto-resolves per run. If more: flag everything, something is wrong
- If the user corrects an auto-resolve: log in DN and report for adjustment

## CSR-3. Direct user declaration

When the user declares an item as done ("already did it", "done", "completed", "finished"):
1. Identify which open action item corresponds
2. Execute the full resolve cycle (meeting note + deliverables memory + task manager if available)
3. Log: `[user-declared] "item" (confidence: high, source: direct)`

Direct declaration is the most reliable signal. No matching needed.
```

**Step 2: Verify**

Run: `grep -c "^## CSR-" modules/completion-tracking/rules/cross-source-reconciler.md`
Expected: 3

**Step 3: Commit**

```bash
git add modules/completion-tracking/rules/cross-source-reconciler.md
git commit -m "feat(completion-tracking): add CSR-1 to CSR-3 rules"
```

---

### Task 3: Patch /end command (step 3.6)

**Files:**
- Modify: `modules/commands/commands/end.md`

**Step 1: Insert reconciler step between step 3.5 (WIP) and step 4 (validation)**

Find the line `### 4. Ask for validation (if interactive)` and insert before it:

```markdown

### 3.6. Reconciler: cross-reference session work against open action items

Execute the reconciliation step defined in `completion-tracking/rules/cross-source-reconciler.md` (CSR-1):
1. Read today's DN log (the work done in this session)
2. Extract entities and fulfillment signals
3. Load open action items (recent meeting notes + deliverables memory + task manager)
4. Hybrid match (keyword first, semantic if needed)
5. Auto-resolve HIGH, flag MEDIUM
6. If no matches but significant work was done: apply CT-3 (warn user)

```

**Step 2: Verify**

Run: `grep -c "3.6" modules/commands/commands/end.md`
Expected: 1

Run: `grep "Reconciler\|reconcil" modules/commands/commands/end.md`
Expected: 2+ matches

**Step 3: Commit**

```bash
git add modules/commands/commands/end.md
git commit -m "feat(completion-tracking): add reconciler step 3.6 to /end"
```

---

### Task 4: Patch /post-meeting command (step 3f)

**Files:**
- Modify: `modules/commands/commands/post-meeting.md`

**Step 1: Insert reconciler step between step 3e (Daily Note) and step 4 (indexes)**

Find the line `### 4. Update indexes` and insert before it:

```markdown

#### 3f. Reconciler: cross-reference meeting content against open action items

Execute CSR-1 (`completion-tracking/rules/cross-source-reconciler.md`):
- The meeting content may resolve action items from PREVIOUS meetings (e.g., "we deployed the profile feature" resolves "QA and deploy public profiles")
- Extract entities from the summary and topics
- Match against open action items from other meeting notes
- Auto-resolve HIGH, flag MEDIUM

```

**Step 2: Verify**

Run: `grep "3f\|CSR-1\|Reconciler" modules/commands/commands/post-meeting.md`
Expected: 3+ matches

**Step 3: Commit**

```bash
git add modules/commands/commands/post-meeting.md
git commit -m "feat(completion-tracking): add reconciler step 3f to /post-meeting"
```

---

### Task 5: Create module README

**Files:**
- Create: `modules/completion-tracking/README.md`

**Step 1: Write the README**

```markdown
# Completion Tracking

Closes the loop between data ingestion and action item tracking. When new information arrives (meeting transcripts, chat messages, emails, work sessions), the agent automatically checks if any open action items have been fulfilled.

## How it works

1. **During ingestion** (CSR-1): new data is scanned for fulfillment signals. Open action items are loaded from meeting notes and deliverables memory. Matches are auto-resolved (high confidence) or flagged for review (medium confidence).

2. **During sessions** (CT-1, CT-2): when the user completes work related to a meeting action item, the meeting note checkbox is marked and the deliverables memory is updated.

3. **At end of day** (CT-3, /end step 3.6): if significant work happened but no deliverables were updated, the agent warns before closing.

4. **After meetings** (/post-meeting step 3f): meeting content is cross-referenced against action items from previous meetings. If a topic was resolved, the original item is marked done.

## Rules

### completion-tracking.md (3 rules)

| Rule | What it does |
|------|-------------|
| CT-1 | Mark `[x]` on meeting note checkboxes when items are completed |
| CT-2 | Update deliverables memory files when work is delivered |
| CT-3 | Warn if significant work happened but no deliverable was updated |

### cross-source-reconciler.md (3 rules)

| Rule | What it does |
|------|-------------|
| CSR-1 | Hybrid keyword+semantic matching at ingestion time |
| CSR-2 | Safety guardrails (max 5 auto-resolves, 30-day limit, evidence required) |
| CSR-3 | Direct user declaration ("done", "already did it") triggers full resolve |

## Installation

1. Copy `rules/` contents to your `.claude/rules/` directory
2. The /end and /post-meeting command patches are already included in the commands module

## Optional dependencies

- **Smart Connections MCP**: enables semantic fallback matching (CSR-1 step 3b). Without it, only keyword matching is used.
- **Task manager MCP** (Notion, Linear, Todoist, etc.): enables updating task status on auto-resolve. Without it, only vault-side tracking (meeting notes + memory files) is used.

## Log format

Entries added to the Daily Note by the reconciler:

```
[auto-reconciled] "action item text" <- source (confidence: high)
[reconcile-candidate] "action item text" <- source (confidence: medium)
[user-declared] "action item text" (confidence: high, source: direct)
```
```

**Step 2: Verify**

Run: `wc -l modules/completion-tracking/README.md`
Expected: ~65 lines

**Step 3: Commit**

```bash
git add modules/completion-tracking/README.md
git commit -m "docs(completion-tracking): add module README"
```

---

### Task 6: Update CHANGELOG and verify

**Files:**
- Modify: `CHANGELOG.md`

**Step 1: Add 1.3.0 entry at the top (after the header line)**

Insert after `All notable changes to Open Arcana are documented here.` and before the `## [1.2.0]` entry:

```markdown

## [1.3.0] - 2026-04-10 -- Completion Tracking

Closes the gap between data ingestion and action item tracking. When new information arrives, open items that were fulfilled are automatically resolved or flagged for review.

### Added
- **Completion tracking module** (`modules/completion-tracking/`): 2 rule files with 6 rules total (CT-1 to CT-3, CSR-1 to CSR-3)
- **CT-1**: auto-mark `[x]` on meeting note checkboxes when items are completed
- **CT-2**: update deliverables memory files when work is delivered
- **CT-3**: end-of-session warning if significant work happened but no deliverable was updated
- **CSR-1**: hybrid keyword+semantic reconciliation at data ingestion time
- **CSR-2**: safety guardrails (max 5 auto-resolves, 30-day edit limit, evidence required)
- **CSR-3**: direct user declaration triggers full resolve cycle

### Changed
- `/end`: added step 3.6 (reconciler: cross-reference session work against open action items)
- `/post-meeting`: added step 3f (reconciler: cross-reference meeting content against previous action items)

```

**Step 2: Run full verification checklist**

```bash
# Rule files exist with correct rule counts
grep -c "^## CT-" modules/completion-tracking/rules/completion-tracking.md    # Expected: 3
grep -c "^## CSR-" modules/completion-tracking/rules/cross-source-reconciler.md  # Expected: 3

# Commands patched
grep -c "3.6" modules/commands/commands/end.md                                # Expected: 1
grep "3f" modules/commands/commands/post-meeting.md | wc -l                   # Expected: 1+

# README exists
test -f modules/completion-tracking/README.md && echo "OK"                     # Expected: OK

# CHANGELOG updated
grep "1.3.0" CHANGELOG.md                                                     # Expected: match
```

**Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: bump to v1.3.0 -- Completion Tracking"
```

---

## Verification Checklist (run after all tasks)

| Check | Command | Expected |
|-------|---------|----------|
| CT rule file exists | `head -1 modules/completion-tracking/rules/completion-tracking.md` | `# Completion Tracking (3 rules)` |
| 3 CT rules | `grep -c "^## CT-" modules/completion-tracking/rules/completion-tracking.md` | 3 |
| CSR rule file exists | `head -1 modules/completion-tracking/rules/cross-source-reconciler.md` | `# Cross-Source Reconciler (3 rules)` |
| 3 CSR rules | `grep -c "^## CSR-" modules/completion-tracking/rules/cross-source-reconciler.md` | 3 |
| /end has step 3.6 | `grep "3.6" modules/commands/commands/end.md` | 1 match |
| /post-meeting has 3f | `grep "3f" modules/commands/commands/post-meeting.md` | 1 match |
| README exists | `test -f modules/completion-tracking/README.md && echo OK` | OK |
| CHANGELOG has 1.3.0 | `grep "1.3.0" CHANGELOG.md` | match |
| No Notion references | `grep -ri "notion" modules/completion-tracking/` | 0 matches |
| Generic task manager | `grep -i "task manager" modules/completion-tracking/rules/cross-source-reconciler.md` | 2+ matches |
