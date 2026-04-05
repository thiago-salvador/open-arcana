# Scheduled Tasks Module

Templates for automated Claude Code tasks that run on a schedule. These tasks execute the same logic as interactive slash commands but run unattended, writing results directly to the vault.

## How Scheduled Tasks Work

Claude Code supports scheduled tasks (also called "triggers") that run at specified times. Each task:
- Executes a prompt with full tool access
- Runs without user interaction
- Writes output to vault notes and alerts
- Logs its execution with a `[scheduled]` prefix

## Examples

| Template | Schedule | What it does |
|----------|----------|-------------|
| `morning-briefing.md` | Weekdays, 7:45 AM | Collects all sources, generates Daily Note with priorities |
| `end-of-day.md` | Weekdays, 6:30 PM | Wraps up the day, captures decisions, records current state, prepares tomorrow |
| `weekly-review.md` | Monday, 8:00 AM | 7-day review with metrics, memory health, anti-sycophancy analysis |

## Setting Up a Scheduled Task

1. Choose a template from `examples/`
2. Replace placeholder tokens (`{{VAULT_PATH}}`, `{{MEMORY_DIR}}`, etc.) with your values
3. Create the scheduled task using Claude Code's scheduling system:

```bash
# Using the schedule skill
# /schedule create --name "morning-briefing" --cron "45 7 * * 1-5" --prompt "..."
```

Or use the MCP directly if available:
```bash
# Via scheduled-tasks MCP
mcp__scheduled-tasks__create_scheduled_task
```

## Design Principles

1. **Same logic, no interaction.** Scheduled tasks follow the same flow as their interactive counterparts but skip all user prompts and validation steps.
2. **Always write to vault.** Since there is no terminal to display results, all output goes to Daily Notes and `00-Dashboard/alerts.md`.
3. **Graceful degradation.** If an external source is unavailable, the task logs the failure and continues with available data. A partial result is better than no result.
4. **Idempotent when possible.** Running a task twice should not create duplicate content. Tasks check for existing data before writing.
5. **Alerts for urgency.** If something needs immediate attention, the task writes to `00-Dashboard/alerts.md` in addition to the regular output location.

## Model Recommendations

- **Morning briefing:** Opus recommended. Cross-referencing multiple sources and generating priorities benefits from stronger reasoning.
- **End of day:** Opus recommended. Decision extraction from logs requires nuanced understanding.
- **Weekly review:** Opus required. Synthesizing 7 days of data across domains is the kind of task where model quality makes a real difference.

For lighter tasks (file scan, link check, simple sync), Sonnet is sufficient and more cost-effective.

## Common Tokens to Replace

| Token | Description |
|-------|------------|
| `{{VAULT_PATH}}` | Absolute path to your Obsidian vault |
| `{{MEMORY_DIR}}` | Absolute path to Claude Code memory directory |
| `{{MS_GRAPH_PATH}}` | Path to Microsoft Graph MCP server |
| `{{NOTION_DB_ID}}` | Your Notion tasks database ID |

## Adding Your Own

To create a new scheduled task:

1. Start from the closest example template
2. Adjust the schedule, sources, and output format
3. Test interactively first (run the prompt manually and verify the output)
4. Then schedule it for unattended execution
5. Monitor the first few runs by checking Daily Notes and alerts

Good candidates for scheduled tasks:
- Anything you run daily at roughly the same time
- Data collection that benefits from consistency (same time each day = clean deltas)
- Health checks and audits that should run whether you remember or not
