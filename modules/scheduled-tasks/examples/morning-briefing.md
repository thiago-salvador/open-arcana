---
name: morning-briefing
description: "Example scheduled task for a morning intelligence briefing. Runs daily before your workday starts. Collects data from all connected sources, generates a Daily Note with priorities."
schedule: "0 7 45 * * 1-5"
model: "opus"
---

# Morning Briefing (Scheduled Task Example)

This is a template for an automated morning briefing that runs before you start your day. It mirrors the `/start` command but runs unattended, so it skips interactive steps and writes everything to the Daily Note directly.

## What it does

1. **Determines the last collection timestamp** from the most recent Daily Note with a log entry
2. **Collects data in parallel** from all configured sources:
   - Meeting transcripts (summaries, action items, key questions)
   - Team chat messages since last collection
   - Calendar events for today and the next 5 days
   - Pending tasks from the task manager
   - Recently modified files outside the vault
   - Tool/platform updates relevant to your workflows
3. **Cross-references** all collected data to identify:
   - New decisions that affect priorities
   - New action items
   - Context shifts (projects gaining or losing urgency)
   - Conflicts (overlapping meetings, deadline collisions)
4. **Generates prioritized focus** for the day (Top 5 actions with justification)
5. **Creates or updates the Daily Note** with the full briefing
6. **Writes an alert** to `00-Dashboard/alerts.md` if anything needs immediate attention

## Configuration

In your Claude Code scheduled task setup:

```
Schedule: Daily, 7:45 AM (adjust to 30-60 min before your typical start)
Model: Opus (recommended for cross-referencing quality)
Permissions: Allow all tool use without prompting
```

## Key differences from interactive /start

- No user prompts or validation steps
- Writes everything directly to the Daily Note
- Uses `00-Dashboard/alerts.md` for urgent items instead of terminal output
- Includes a `[scheduled]` prefix in all log entries
- If ALL external sources fail, writes a minimal Daily Note with vault-only data and a clear warning

## Prompt template

```
You are running as an automated morning briefing. Follow the /start command flow with these modifications:
- Skip all interactive steps (no user prompts)
- Write all output to the Daily Note at {{VAULT_PATH}}/Daily-Notes/YYYY-MM-DD.md
- If the Daily Note already exists, append/merge without overwriting
- Prefix all log entries with [scheduled]
- If urgent items found, also write to {{VAULT_PATH}}/00-Dashboard/alerts.md
- If a source fails, log the failure and continue
- At the end, update last_collection in the Daily Note frontmatter
```

## Source fallback behavior

| Source | If unavailable |
|--------|---------------|
| Meeting transcripts | Skip meetings section, note in log |
| Team chat | Skip chat section, note in log |
| Calendar | Skip meetings-today section, note in log |
| Task manager | Skip tasks section, note in log |
| File scan | Always works (local filesystem) |
| Tool updates | Skip section, note in log |

If all external sources fail, the task still produces a Daily Note with:
- File scan results
- Vault-based pending items from yesterday
- A warning: "All external sources unavailable. Manual briefing recommended."
