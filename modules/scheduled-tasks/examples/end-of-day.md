---
name: end-of-day
description: "Example scheduled task for end-of-day wrap-up. Runs daily near the end of your workday. Captures decisions, records current state, processes unprocessed meetings, and prepares tomorrow."
schedule: "0 18 30 * * 1-5"
model: "opus"
---

# End of Day (Scheduled Task Example)

This is a template for an automated end-of-day task that wraps up the workday. It mirrors the `/end` command but runs unattended, so it skips validation prompts and writes directly to the Daily Note.

## What it does

1. **Reads today's Daily Note** in full to understand what happened
2. **Scans for unprocessed meetings** via the transcript service and processes any that were missed during the day
3. **Extracts decisions** from the day's logs:
   - Explicit decisions from Claude sessions
   - Meeting decisions from transcripts
   - Implicit decisions (priority changes, abandoned tasks)
4. **Creates decision records** in the vault for any unrecorded decisions
5. **Writes the Current State block** (mandatory):
   - What was being worked on
   - Where it stopped
   - Next step for tomorrow
   - Any blockers
   - Critical context for the next session
6. **Builds tomorrow's agenda** from calendar events and pending tasks
7. **Updates indexes and MOCs** for folders modified today
8. **Logs everything** to the Daily Note

## Configuration

```
Schedule: Daily, 6:30 PM (adjust to your typical end of day)
Model: Opus (recommended for decision extraction quality)
Permissions: Allow all tool use without prompting
```

## Key differences from interactive /end

- No user validation ("Did I miss anything?")
- Writes the Current State block based on the last Claude session log of the day
- If no Claude sessions today, the Current State block says "No active sessions today" with blank fields
- Processes unprocessed meetings automatically (no confirmation)
- Decision records are created directly (interactive /end would ask first)

## Prompt template

```
You are running as an automated end-of-day wrap-up. Follow the /end command flow with these modifications:
- Skip all interactive validation steps
- Write all output directly to today's Daily Note at {{VAULT_PATH}}/Daily-Notes/YYYY-MM-DD.md
- The Current State block is MANDATORY even in automated mode
- Create decision records without asking for confirmation
- Process unprocessed meetings without asking
- Prefix all log entries with [scheduled]
- If a source fails, log the failure and continue
```

## Current State block format

```markdown
## Current State (end of day)
**Working on:** {extracted from last Claude session log, or "No active sessions today"}
**Where stopped:** {extracted from last session context, or "N/A"}
**Next step:** {inferred from pending tasks and today's activity}
**Blockers:** {extracted from logs, or "None identified"}
**Critical context:** {anything the next session needs to know}
```

This block is consumed by the morning briefing to maintain continuity across days.

## Failure modes

| Scenario | Behavior |
|----------|----------|
| No Daily Note exists | Create one with minimal content + Current State |
| No Claude sessions today | Current State with "No active sessions today" |
| Meeting transcript service down | Skip meeting processing, note in log |
| Task manager down | Skip tomorrow's task list, note in log |
| Calendar down | Skip tomorrow's meetings, note in log |
