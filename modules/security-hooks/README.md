# Security Hooks

Claude Code hooks that protect vault integrity: prompt injection scanning, cascade edit reminders, people-data fabrication guards, and pre-compaction memory nudges.

## Hooks

### memory-injection-scan.sh (PreToolUse)

Scans content being written to memory files for prompt injection patterns. Blocks writes that match known attack vectors:

- Role hijacking ("you are now...")
- Instruction override ("ignore previous instructions")
- Rule bypassing ("pretend no restrictions")
- Secret exfiltration (curl with KEY/TOKEN/SECRET, cat on .env/credentials)
- Invisible unicode characters (used to hide injections)

Only triggers on files inside the memory directory. All other writes pass through instantly.

**Placeholder:** `{{MEMORY_DIR}}` - the project-specific segment of the Claude memory path (the part after `$HOME/.claude/projects/`). For example, if your memory lives at `~/.claude/projects/-my-project/memory`, use `-my-project`.

### cascade-check.sh (PostToolUse)

Fires after editing vault notes in high-risk directories (people, projects, rules). Reminds the agent to grep for the old value and update all cross-references when a fact changes. Prevents the common failure mode where a fact is updated in one place but stale copies persist elsewhere.

**Placeholder:** `{{VAULT_PATH}}`

### guard-pessoas.sh (PreToolUse)

Guards the `70-Pessoas/` directory against data fabrication. When the agent writes or edits a person's note, this hook injects a reminder to trace every fact to a primary source (chat messages, meeting transcripts, LinkedIn, user statements). If a fact cannot be sourced, it should be marked "unconfirmed" or left blank.

Non-blocking: injects a warning but does not prevent the write.

**Placeholder:** `{{VAULT_PATH}}`

### memory-nudge.sh (PreCompact)

Fires before context compaction. Reminds the agent to check for unsaved learnings (user corrections, project discoveries, useful references, decisions) before context is lost. Already generic, no placeholders needed.

## Installation

1. Replace `{{VAULT_PATH}}` and `{{MEMORY_DIR}}` with your actual paths
2. Copy hooks to `.claude/hooks/` in your project
3. Register in `.claude/settings.local.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Write|Edit", "command": ".claude/hooks/memory-injection-scan.sh" },
      { "matcher": "Write|Edit", "command": ".claude/hooks/guard-pessoas.sh" }
    ],
    "PostToolUse": [
      { "matcher": "Edit", "command": ".claude/hooks/cascade-check.sh" }
    ],
    "PreCompact": [
      { "matcher": "", "command": ".claude/hooks/memory-nudge.sh" }
    ]
  }
}
```

## Dependencies

- `python3` (for JSON parsing and unicode detection)
- `jq` (for JSON parsing in cascade-check.sh and guard-pessoas.sh)
- Standard Unix tools: `grep`, `basename`
