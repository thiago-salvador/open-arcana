---
name: weekly-review
description: "Example scheduled task for a weekly review. Runs Monday mornings. Collects 7 days of data, generates a Weekly Review note, checks memory health, and runs anti-sycophancy metrics."
schedule: "0 8 0 * * 1"
model: "opus"
---

# Weekly Review (Scheduled Task Example)

This is a template for an automated weekly review that runs every Monday morning. It mirrors the `/weekly` command but runs unattended, generating a complete review without user interaction.

## What it does

1. **Reads all Daily Notes** from the past 7 days
2. **Collects completed and pending tasks** from the task manager
3. **Gathers GitHub metrics** (commits, PRs merged, lines changed per repo)
4. **Runs memory health check:**
   - Stale references (paths/wikilinks that no longer exist)
   - Transient memories older than 30 days
   - Duplicate memory files
   - MEMORY.md index consistency
5. **Runs anti-sycophancy metrics:**
   - Confidence tag distribution (red flag if >90% high)
   - Challenge-previous execution rate (red flag if 0)
   - ConflictReport count (red flag if 0 in an active week)
6. **Identifies cross-domain connections** via semantic search
7. **Generates `00-Dashboard/Weekly Review.md`** with all sections
8. **Writes an alert** if any metric is a red flag

## Configuration

```
Schedule: Monday, 8:00 AM
Model: Opus (required for synthesis quality across 7 days of data)
Permissions: Allow all tool use without prompting
```

## Key differences from interactive /weekly

- No user perspective question ("How was the week?")
- No validation prompt at the end
- The "Done" section is built purely from Daily Note logs and task manager data
- The "Next week" section is generated from pending tasks and calendar, without user input
- Memory health issues are listed but NOT auto-corrected (presented in the review for manual decision)

## Prompt template

```
You are running as an automated weekly review. Follow the /weekly command flow with these modifications:
- Skip all interactive questions and validation
- Generate the full Weekly Review at {{VAULT_PATH}}/00-Dashboard/Weekly Review.md
- Include all sections: Done (by domain), Dev Metrics, Pending, Connections, Memory Health, Anti-Sycophancy Metrics, Next Week
- If any anti-sycophancy metric is a red flag, also write to {{VAULT_PATH}}/00-Dashboard/alerts.md
- If fewer than 3 Daily Notes exist for the week, include a warning about incomplete data
- Prefix all log entries with [scheduled]
```

## Generated sections

### Done (by domain)
Groups accomplishments by domain (company, studio, content, research, personal). Extracted from Daily Note logs and completed tasks.

### Dev Metrics
Table of GitHub activity per repo: commits, PRs merged, lines added/removed. Skipped if no repos had activity.

### Pending
Tasks and items that were planned but not completed. Includes how many days each has been pending.

### Connections
Cross-domain connections discovered via semantic search. Categorized as actions, context enrichment, or productive tensions.

### Memory Health
Results of the memory file audit: stale references, old transient memories, duplicates, orphans/ghosts.

### Anti-Sycophancy Metrics
Confidence tag distribution, challenge-previous rate, ConflictReport count. Each with ok/red-flag status.

### Next Week
Suggested priorities based on pending items, upcoming calendar, and identified gaps.

## Failure modes

| Scenario | Behavior |
|----------|----------|
| No Daily Notes for the week | Generate minimal review with warning |
| Task manager down | Skip task sections, note in log |
| GitHub CLI not configured | Skip dev metrics silently |
| Smart Connections unavailable | Skip connections section, use grep fallback |
| Memory directory not found | Skip memory health section |
