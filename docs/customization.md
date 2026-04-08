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
| UserPromptSubmit | User sends a prompt | Set session title, validate input |
| PreToolUse | Before a tool runs | Validate inputs, inject context |
| PostToolUse | After a tool runs | Validate outputs, trigger side effects |
| PreCompact | Before context compaction | Save state, persist learnings |
| Stop | Session ending | Validate work was logged |

Hooks receive context via environment variables and stdin (JSON with tool details).

**UserPromptSubmit hooks** (Claude Code >= 2.1.94) can set the session title via `hookSpecificOutput.sessionTitle` in their JSON output. This makes `--resume` show descriptive names instead of generic ones.

**Plugin skill hooks** defined in YAML frontmatter now work correctly (fixed in 2.1.94). You can define hooks directly in command/skill frontmatter instead of wiring them in settings.json.

### Commands

Commands are Markdown prompt templates. The filename becomes the slash command name. `/health` maps to `commands/health.md`.

**Important (Claude Code >= 2.1.94):** If your commands are part of a plugin using `"skills": ["./"]`, the invocation name comes from the frontmatter `name` field, not the filename. Always include a `name` field in command frontmatter to ensure stable invocation names across install methods.

Use `{{VAULT_PATH}}` and other template variables in commands. They're replaced at install time.

### Executables (Claude Code >= 2.1.91)

Plugins can ship executables under a `bin/` directory. These become available as bare commands in the Bash tool without needing full paths. Useful for shipping CLI tools (indexers, analyzers, formatters) alongside your module.

```
modules/your-module/
├── bin/
│   └── my-analyzer     # Available as: my-analyzer (no path needed)
├── rules/
└── README.md
```

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

## Security settings

### Disabling shell execution in skills (Claude Code >= 2.1.91)

If you want to prevent skills and slash commands from running arbitrary shell commands, add to your `settings.json`:

```json
{
  "disableSkillShellExecution": true
}
```

This blocks inline shell execution in skills, custom slash commands, and plugin commands. Useful for shared environments or when onboarding new team members.

### Command frontmatter: keep-coding-instructions (Claude Code >= 2.1.94)

Commands can include `keep-coding-instructions: true` in their YAML frontmatter to preserve the project's coding instructions in the output context. Useful for commands that generate code and need to follow project conventions.

## Modifying existing modules

Edit the files in your vault's `.claude/` directory directly. Changes take effect on the next Claude Code session.

To persist changes across re-installs, fork the Open Arcana repo and modify the source modules.

## Sharing modules

If you build something useful, consider contributing it back:

1. Create your module under `modules/`
2. Add a README.md with clear documentation
3. Register it in `setup.sh` (add to MODULE_NAMES, MODULE_DESCRIPTIONS, MODULE_CATEGORIES)
4. Open a PR
