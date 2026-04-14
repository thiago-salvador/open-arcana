# Enforcement Hooks

Claude Code hooks that enforce vault discipline: Daily Note existence, frontmatter validation, and logging compliance.

## Hooks

### enforce-daily-note.sh (PreToolUse)

Blocks all tool use until today's Daily Note exists. Prevents the agent from doing work without a logging target. Includes a deadlock-prevention exception: Write and Bash commands targeting the Daily Note itself are allowed through.

**Placeholder:** `{{VAULT_PATH}}` - absolute path to your Obsidian vault.

### validate-frontmatter.sh (PreToolUse)

Checks that any `.md` file being written to the vault starts with YAML frontmatter (`---`). Fires before the write happens and injects a warning if frontmatter is missing. Does not block the write.

**Placeholder:** `{{VAULT_PATH}}`

### validate-write.sh (PostToolUse)

Runs after Write/Edit on vault notes. Validates:
- Frontmatter exists and has required fields (title, summary, type, domain, tags, status, created)
- `type` and `domain` values match allowed enums
- At least one wikilink exists (to prevent orphan notes)
- Filename is descriptive (rejects generic names like "note", "untitled", "temp")

Non-blocking: injects warnings via `additionalContext`.

**Placeholders:**
- `{{VAULT_PATH}}` - absolute path to your Obsidian vault
- `{{DOMAINS}}` (env var `DOMAINS`) - space-separated list of valid domain values. Defaults to `zaaz mode content partnerships speaking research personal` if not set.

### stop-check-dn.sh (Stop)

Fires when the agent is about to stop. Checks if the Daily Note has any timestamped log entries (`- HH:MM` format). Warns if logging is missing but never blocks (always approves).

**Placeholder:** `{{VAULT_PATH}}`

### iteration-counter.sh (PostToolUse, wildcard)

Tracks iteration counts for the adaptive background-review trigger. Fires on every tool call. Maintains three counters:

- **per_turn**: iterations in current turn (reset at turn boundary)
- **cumulative**: total iterations since session start
- **struggle_signals**: count of error patterns detected in tool output (error, fail, traceback, denied, test failed, refused)

State file: `/tmp/claude-iter-state-YYYYMMDD.json`

Uses `fcntl.flock(LOCK_EX)` for atomic read-modify-write under concurrent hook firings. POSIX-compatible (macOS + Linux). Inspired by NousResearch/hermes-agent's nudge counter.

### turn-boundary-check.sh (UserPromptSubmit)

Reads iteration state, evaluates adaptive thresholds, and emits a flag file when thresholds are crossed. Next-turn system-reminder prompts the agent to invoke `/background-review`.

**Adaptive thresholds** read from `~/.claude/review-history.json`:
- Last 5 reviews all "nothing" → raise thresholds (`+2` distill, `+1` struggle, `+5` cumulative), up to ceiling 14/9/25
- Last 5 all "acted" → lower thresholds (`-1` / `-1` / `-3`), down to floor 4/3/10
- Mixed or fewer than 5 outcomes → defaults (8 / 5 / 15)

On emission, `last_review_iter` advances to `cumulative` (prevents re-fire spam). Stale flag files from previous turns are cleaned at start.

## Installation

1. Replace `{{VAULT_PATH}}` in all scripts with your vault's absolute path
2. For `validate-write.sh`, optionally set the `DOMAINS` env var or replace the default list
3. Copy hooks to `.claude/hooks/` in your project
4. Register in `.claude/settings.local.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "", "command": ".claude/hooks/enforce-daily-note.sh" },
      { "matcher": "Write", "command": ".claude/hooks/validate-frontmatter.sh" }
    ],
    "UserPromptSubmit": [
      { "matcher": "", "command": ".claude/hooks/turn-boundary-check.sh" }
    ],
    "PostToolUse": [
      { "matcher": "", "command": ".claude/hooks/iteration-counter.sh" },
      { "matcher": "Write|Edit", "command": ".claude/hooks/validate-write.sh" }
    ],
    "Stop": [
      { "matcher": "", "command": ".claude/hooks/stop-check-dn.sh" }
    ]
  }
}
```

The `iteration-counter.sh` entry MUST use `matcher: ""` (wildcard) so it fires on every tool call, not just Write/Edit.

## Dependencies

- `python3` with stdlib `fcntl` (for atomic state updates)
- `jq` (for JSON parsing in validate-frontmatter.sh)
- Standard Unix tools: `grep`, `awk`, `head`, `sed`

## Related

- `/background-review` command (in `modules/commands/`) consumes the flag file
- `tools/session_index.py` v3 with FTS5 + entity extraction for `/recall`
