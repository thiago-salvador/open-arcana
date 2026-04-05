# Getting Started

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed (CLI or IDE extension)
- An [Obsidian](https://obsidian.md/) vault (existing or new)
- bash (macOS/Linux, or WSL on Windows)

## Installation

1. Clone the repo:
```bash
git clone https://github.com/thiago-salvador/open-arcana.git
cd open-arcana
```

2. Run the setup wizard:
```bash
./setup.sh
```

3. Follow the prompts. The wizard has 4 steps:
   - **Your Profile**: name, role, language, vault path
   - **Integrations**: Notion DB ID, email, company (all optional)
   - **Modules**: pick which modules to activate
   - **Install**: files are copied, templates processed, hooks wired

4. Open a Claude Code session in your vault:
```bash
cd /path/to/your/vault
claude
```

5. Verify the installation:
```
/health
```

## What gets installed

Open Arcana creates files inside your vault's `.claude/` directory:

```
your-vault/
├── .claude/
│   ├── rules/              # AI behavior rules
│   ├── hooks/              # Shell hooks for tool events
│   ├── commands/           # Slash commands
│   ├── settings.local.json # Hook wiring
│   └── arcana.config.yaml  # Module state
├── CLAUDE.md               # Master config
└── (module-specific files)
```

Rules in `.claude/rules/` are auto-loaded by Claude Code on every session. No manual configuration needed.

## Quick presets

If you don't want to go through the wizard:

```bash
./setup.sh --preset minimal   # Core rules + memory system only
./setup.sh --preset writer    # Core + vault + commands + retrieval
./setup.sh --preset full      # Everything
```

## Adding or removing modules later

```bash
./setup.sh --add retrieval-system
./setup.sh --remove scheduled-tasks
./setup.sh --list
```

## Uninstalling

```bash
./uninstall.sh /path/to/your/vault
```

This removes all Open Arcana files and restores your original settings.local.json from backup. Your notes, daily notes, and templates are left untouched.

## Next steps

- Read [modules.md](modules.md) for details on each module
- Read [architecture.md](architecture.md) to understand how components connect
- Read [customization.md](customization.md) to create your own modules
