# Customization

## Creating your own modules

A module is just a directory under `modules/` with a specific structure:

```
modules/your-module/
├── README.md           # Required: what it does, how to use it
├── rules/              # Optional: .md files copied to .claude/rules/
├── hooks/              # Optional: .sh files copied to .claude/hooks/
├── commands/           # Optional: .md files copied to .claude/commands/
├── templates/          # Optional: .md files copied to 80-Templates/
├── dashboard/          # Optional: .md files copied to 00-Dashboard/
├── examples/           # Optional: example configs
└── scaffold.sh         # Optional: script run during install
```

### Rules

Rule files are Markdown documents auto-loaded into Claude Code's context on every session. They shape AI behavior without any wiring needed.

Good rules are:
- Specific (concrete examples, not abstract principles)
- Testable (you can tell whether the AI followed the rule)
- Scoped (use conditional loading via `.claude/rules/` filename conventions)

### Hooks

Hooks are bash scripts triggered by Claude Code events:

| Event | When it fires | Use case |
|-------|--------------|----------|
| SessionStart | New session begins | Load context, check state |
| PreToolUse | Before a tool runs | Validate inputs, inject context |
| PostToolUse | After a tool runs | Validate outputs, trigger side effects |
| PreCompact | Before context compaction | Save state, persist learnings |

Hooks receive context via environment variables and stdin (JSON with tool details).

### Commands

Commands are Markdown prompt templates. The filename becomes the slash command name. `/health` maps to `commands/health.md`.

Use `{{VAULT_PATH}}` and other template variables in commands. They're replaced at install time.

### Template variables

Available in any file with `.template` extension (processed by setup.sh):

| Variable | Description |
|----------|-------------|
| `{{USER_NAME}}` | User's full name |
| `{{USER_ROLE}}` | User's role/title |
| `{{USER_LANG}}` | Primary language |
| `{{VAULT_PATH}}` | Absolute vault path |
| `{{MEMORY_DIR}}` | Claude Code memory directory |
| `{{NOTION_DB_ID}}` | Notion database ID |
| `{{USER_EMAIL}}` | Notification email |
| `{{PRIMARY_DOMAIN}}` | Main work domain |
| `{{COMPANY}}` | Company name |
| `{{DOMAINS}}` | Comma-separated domain list |

## Modifying existing modules

Edit the files in your vault's `.claude/` directory directly. Changes take effect on the next Claude Code session.

To persist changes across re-installs, fork the Open Arcana repo and modify the source modules.

## Sharing modules

If you build something useful, consider contributing it back:

1. Create your module under `modules/`
2. Add a README.md with clear documentation
3. Register it in `setup.sh` (add to MODULE_NAMES, MODULE_DESCRIPTIONS, MODULE_CATEGORIES)
4. Open a PR
