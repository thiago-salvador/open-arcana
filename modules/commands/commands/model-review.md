---
name: model-review
description: "Proactive user model review -- detects uncaptured preferences, stale memories, and gaps in memory files. Standalone version of the /weekly user model check. Use mid-week or when you suspect memory drift."
allowed-tools: "Read,Glob,Grep,Bash"
---

# /model-review

Proactive review of memory files. Looks for memories that SHOULD exist but don't, and memories that may be stale.

## Flow

### 1. Collect data

```bash
MEMORY_DIR="{{MEMORY_DIR}}"
VAULT="{{VAULT_PATH}}"

# List current memory files
ls "$MEMORY_DIR"/*.md | grep -v MEMORY.md

# Last 7 Daily Notes
ls "$VAULT/Daily-Notes/" | sort -r | head -7
```

Read the Daily Notes and memory files.

### 2. Preference detection

Scan Daily Notes for repeated choices:
- Same tools used 3+ times (grep for tool/command names in logs)
- Same domains prioritized (count mentions by domain)
- Same output formats requested
- Same corrections made by the user

Compare with existing feedback memory files. If a pattern is NOT captured: suggest a new feedback memory.

### 3. Workflow evolution

Compare tool usage for the week with workflows described in memories:
- If a memory describes a workflow that did NOT appear at all during the week: flag as potentially stale
- If a NEW workflow emerged (same 3+ step sequence in 2+ distinct sessions): suggest capture via `/distill`

### 4. Context drift

Check project memories against actual activity:
- Read project_*.md files
- If a project memory says "active" but 0 activity in 14+ days in Daily Notes: flag for review
- If user worked significantly in a domain without a project memory: suggest creation

### 5. Output

```markdown
## User Model Review

| Type | Finding | Suggested Action |
|------|---------|-----------------|
| New preference | [description] | Create feedback_[name].md |
| Stale memory | [file] | Review/archive |
| Missing project | [domain] | Create project_[name].md |
| New workflow | [description] | Run /distill |
```

**NEVER auto-create memories.** Present to the user for decision.
If no findings: report "No suggestions. Memory files appear aligned with recent activity."

## Rules

- Read-only: this command does not modify anything
- Max 3 full reads of memory files (retrieval budget)
- If Daily Notes for the last 7 days don't exist: report and exit
