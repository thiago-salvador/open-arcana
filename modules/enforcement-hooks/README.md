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
    "PostToolUse": [
      { "matcher": "Write|Edit", "command": ".claude/hooks/validate-write.sh" }
    ],
    "Stop": [
      { "matcher": "", "command": ".claude/hooks/stop-check-dn.sh" }
    ]
  }
}
```

## Dependencies

- `python3` (for JSON parsing in enforce-daily-note.sh and validate-write.sh)
- `jq` (for JSON parsing in validate-frontmatter.sh)
- Standard Unix tools: `grep`, `awk`, `head`, `sed`
