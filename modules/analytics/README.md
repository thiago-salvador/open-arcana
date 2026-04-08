# Analytics Module

Observability dashboard for Claude Code sessions. Computes 6 behavioral metrics from JSONL session data and generates a local-first HTML dashboard.

## What it installs

| Component | Destination |
|-----------|-------------|
| `tools/analytics_engine.py` | `{VAULT_PATH}/.claude/tools/analytics_engine.py` |
| `dashboard/dashboard.html` | `{VAULT_PATH}/00-Dashboard/dashboard.html` |
| `commands/analytics.md` | `{VAULT_PATH}/.claude/commands/analytics.md` |

## Metrics

1. **HIR** (Human Intervention Rate) - intervention prompts / total tool calls
2. **Context Fill Rate** - cumulative input tokens over session lifetime
3. **Frustration Index** - repeated prompts, negative keywords, early abandonment (0-10)
4. **Tool Call Precision** - successful tool calls / total tool calls
5. **Skill/Command Frequency** - `/command` usage counts across sessions
6. **Subagent Efficiency** - subagent cost as ratio of total session cost

## Usage

```
/analytics
```

Or run the engine directly:
```bash
SINCE_DAYS=7 python3 tools/analytics_engine.py
```
