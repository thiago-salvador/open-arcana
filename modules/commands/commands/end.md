---
name: end
description: "End-of-day -- summarizes work, captures decisions, current state, tomorrow's agenda. Use when ending the day, before logging off. Captures decisions, updates Current State block (mandatory), processes unprocessed meetings, and prepares tomorrow's agenda."
dependencies: "read-ai MCP, microsoft-graph MCP, notion MCP, vault-read"
allowed-tools: "Read,Write,Edit,Glob,Grep,Bash,Agent,mcp__read-ai__*,mcp__microsoft-graph__*,mcp__notion__*"
---

# /end

End of day wrap-up. Captures everything that happened, records decisions, prepares tomorrow.

## Flow

### 1. Automatic collection (BEFORE asking the user)

Run in parallel:
- Read today's Daily Note in full (all logs)
- Scan files modified today (find -mtime -1)
- Task manager: tasks that changed status today
- Meeting transcripts: today's meetings not yet processed -> process them (use /post-meeting flow)

### 2. Capture decisions from the day

Review the full day's log and identify:
- **Decisions made in Claude sessions** -- when the user said "go with X", "cancel Y", "approve Z"
- **Meeting decisions** -- already captured by /post-meeting, but verify none were missed
- **Implicit decisions** -- priority changes, abandoned tasks, redirections

For each decision NOT recorded as a decision record:
```markdown
> [!decision] {Decision title}
> **When:** YYYY-MM-DD
> **Context:** {why it came up}
> **Decision:** {what was decided}
> **Impact:** {what changes}
```

Create in vault (appropriate domain folder) and link from Daily Note.

### 3. Current state (MANDATORY)

Add to Daily Note:
```markdown
## Current State (end of day)
**Working on:** {what was being done in the last session}
**Where stopped:** {exact point -- file, function, step in the plan}
**Next step:** {what should be resumed tomorrow}
**Blockers:** {anything stuck}
**Critical context:** {info that tomorrow's session NEEDS to know}
```

This block is read by tomorrow's /start to ensure continuity.

### 3.5. Update WIP (MANDATORY)

Update `00-Dashboard/wip.md` with workstream state:
- Workstreams that progressed today: update state and next step
- New workstreams started: add to "Active workstreams"
- Completed workstreams: move to "Recently archived"
- Ideas/threads that emerged but were not started: add to "Parking lot"

Format for each workstream:
```markdown
### [Workstream name] | domain | since YYYY-MM-DD
**State:** {what was done, where it stopped}
**Blocker:** {if any}
**Next:** {concrete action to resume}
```

### 3.6. Reconciler: cross-reference session work against open action items

Execute the reconciliation step defined in `completion-tracking/rules/cross-source-reconciler.md` (CSR-1):
1. Read today's DN log (the work done in this session)
2. Extract entities and fulfillment signals
3. Load open action items (recent meeting notes + deliverables memory + task manager)
4. Hybrid match (keyword first, semantic if needed)
5. Auto-resolve HIGH, flag MEDIUM
6. If no matches but significant work was done: apply CT-3 (warn user)

### 4. Ask for validation (if interactive)

If the user is present (not automated execution):
- Show the day summary and ask: "Did I miss anything? Any decision I didn't capture?"
- If the user adds something: incorporate it

If automated execution (scheduled task): skip this step.

### 5. Sync and health

- Check index.md for folders modified today
- Check relevant MOCs
- If outdated: update silently
- If new files appeared in external project folders: record as pending for tomorrow

### 6. Build tomorrow

- Google Calendar + Microsoft Calendar: tomorrow's meetings
- Task manager: top 5 pending tasks by priority
- Vault: pending items from today's log + Current State
- Populate `## Tomorrow` in the Daily Note grouped by domain
- If task manager does not connect and interactive: ask the user

### 7. Output

```
YYYY-MM-DD -- Day closed

Today:
- [summary by domain in 1-2 lines each]

Decisions captured: N
- [short list]

State:
- Working on: [...]
- Next step: [...]

Tomorrow:
1. [task 1]
2. [task 2]
3. [task 3]

Meetings tomorrow:
- HH:MM -- [meeting]
```

## Source fallback

If an MCP fails (timeout >15s, 401/403, network error, empty response):
1. Log in output: `[!] Source unavailable: [name]`
2. Skip the category, do not block the entire command
3. Continue with remaining sources
4. If ALL sources fail, report and suggest retry

## When to use (vs other commands)

Full end-of-day wrap-up. Different from /capture (point-in-time capture of one session item) and /recap (read-only, does not write to vault or prepare tomorrow).

## Rules
- Never fabricated content
- Never overwrite -- always append
- The "Current State" block is MANDATORY -- never skip it
- Decisions must be extracted from logs, never invented
