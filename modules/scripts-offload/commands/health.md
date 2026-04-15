---
name: health
description: "Vault health audit via Python scripts. Runs vault_health.py + vault_stats.py for instant JSON results, then presents a score 0-100 with breakdown and classification."
dependencies: "vault-read"
allowed-tools: "Bash,Read"
---

# /health

Checks vault health using offload scripts (fast, single-pass).

## Flow

### 1. Run health audit script

```bash
VAULT_PATH="{{VAULT_PATH}}" python3 "{{VAULT_PATH}}/.claude/tools/vault_health.py" --verbose
```

Parse the JSON output. This gives you:
- `health_score` (0-100)
- `total_notes`
- `notes_by_folder`
- `issues` (missing frontmatter, fields, orphans, isolated, missing indexes)
- `score_breakdown` (penalty per category)
- `details` (file-level issues, limited to 30 per category)

### 2. Run stats script (optional context)

```bash
VAULT_PATH="{{VAULT_PATH}}" python3 "{{VAULT_PATH}}/.claude/tools/vault_stats.py"
```

Parse JSON for activity overview (modified 24h/7d, top tags, type/domain/status distribution).

### 3. Check Daily Notes + WIP

- Does today's Daily Note exist? (`{{VAULT_PATH}}/Daily-Notes/YYYY-MM-DD.md`)
- Do the last 3 Daily Notes have a `## Log` section?
- Was `00-Dashboard/wip.md` edited in the last 3 days?

Add/subtract from the script's base score:
- +5 pts if today's DN exists
- +5 pts if last 3 DNs have `## Log`
- +5 pts if WIP is fresh (edited in 3 days)

Cap total at 100.

### 4. Output

Classification:
- 90-100: Excellent
- 75-89: Good
- 60-74: Needs attention
- <60: Critical

```
Vault Health Report -- YYYY-MM-DD

## Score: [N/100] -- [Classification]

| Component | Score | Details |
|---|---|---|
| Frontmatter | -N | N notes missing, N fields missing |
| Orphan notes | -N | N notes with no incoming links |
| Isolated notes | -N | N notes with no outgoing links |
| Index coverage | -N | N folders missing index.md |
| Daily Notes | +N | Today: yes/no, Recent log: yes/no |
| WIP | +N | Updated: yes/no |

## Validation Gate (reviewed field)
Eligible notes (type=concept|knowledge|reference): N
- reviewed: true -> N (X%)
- reviewed: false -> N (X%)
- missing -> N (X%, legacy)

Interpretation: % reviewed measures how much of the knowledge layer is human-verified vs auto-generated. Missing = legacy (pre-gate). New notes without the field trigger a hook warning.

## Activity (last 7 days)
N notes modified, N in last 24h

## Top issues (up to 10)
[from details.frontmatter_issues + details.orphans]
```

### 5. Offer corrections

"Want me to fix the problems found? I can:
- Run `fix_frontmatter.py --apply` to add missing fields
- Run `rebuild_indexes.py --apply` to regenerate indexes
- Run `auto_linker.py --apply` to add links to isolated notes
- Create today's Daily Note"

## Rules
- NEVER auto-correct without asking
- Use script JSON output directly, do not re-scan files manually
- If scripts are not installed, fall back to the manual /health flow
