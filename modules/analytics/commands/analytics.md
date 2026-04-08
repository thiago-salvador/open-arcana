---
name: analytics
description: "Generate analytics dashboard from session data and open in browser."
allowed-tools: "Bash,Read"
---

# /analytics -- Session Analytics Dashboard

Generate behavioral metrics from Claude Code session data and open the interactive dashboard.

## Procedure

1. **Run the analytics engine** (default: last 7 days):
```bash
SINCE_DAYS=${ARGUMENTS:-7} VAULT_PATH={{VAULT_PATH}} python3 {{VAULT_PATH}}/.claude/tools/analytics_engine.py
```

2. **Open the dashboard** in default browser:
```bash
open {{VAULT_PATH}}/00-Dashboard/dashboard.html
```

3. **Report inline summary** from the engine stdout output:
   - Total sessions analyzed
   - Total estimated cost
   - Average HIR, Frustration Index, Tool Precision
   - Top 3 most-used commands

## Constraints

- Engine runs in <10s for typical usage (7 days, <100 sessions)
- Dashboard loads data.json via fetch(), no server needed
- If no sessions found, report "No sessions found for the given range"
