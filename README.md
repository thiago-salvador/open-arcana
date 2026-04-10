# Open Arcana

**AI Agent Orchestration Framework for Obsidian + Claude Code**

Open Arcana turns your Obsidian vault into an AI-operated knowledge system. It gives Claude Code the rules, hooks, retrieval strategies, and automation commands it needs to actually work well with a vault, not just read and write files.

Built from a production system running 16 hooks, 27 commands, 500+ automated health checks, and a 0-100 vault health score daily.

## What's in the box

| Module | What it does |
|--------|-------------|
| **Anti-Sycophancy Protocol** | 6 rules that prevent AI from agreeing without evidence. Confidence tags, challenge-previous, conflict reports. |
| **Token Efficiency** | 17 rules for context window management and cost control. Cache awareness, retrieval budgets, output discipline. |
| **Enforcement Hooks** | Auto-validates frontmatter, enforces daily notes, checks writes before they happen. |
| **Security Hooks** | Blocks prompt injection in memory files, guards against fabricated people data. |
| **Vault Structure** | Opinionated folder system with 19 note templates + WIP hub for session continuity. One command creates the full tree. |
| **Retrieval System** | 4-layer lookup inspired by DeepSeek's Engram paper. Concept index, filtered grep, semantic search, fallback. |
| **Slash Commands** | 22 commands: /start, /end, /weekly, /health, /dump, /capture, /distill, /recall, /tree, /model-review, and more. |
| **Connected Sources** | Templates for orchestrating 16+ MCP data sources (Teams, Notion, Calendar, Read.AI, etc). |
| **Scheduled Tasks** | Patterns for autonomous recurring agents: morning briefing, end-of-day, weekly review. |
| **Vault Health** | 7-component weighted health score (0-100) for frontmatter, index, MOCs, connections, daily notes, WIP, and memory. |
| **Analytics Dashboard** | 6 behavioral metrics (HIR, frustration, tool precision, context fill, command frequency, subagent efficiency) + interactive HTML dashboard. |

Every module is optional. Install what you need, skip what you don't.

## Quick start

```bash
git clone https://github.com/thiago-salvador/open-arcana.git
cd open-arcana
./setup.sh
```

The setup wizard walks you through everything:

1. **Your profile** (name, role, language, vault path)
2. **Integrations** (Notion, email, company name, all optional)
3. **Module selection** (pick which modules to activate)
4. **Installation** (copies files, processes templates, wires hooks)

Takes about 2 minutes. No dependencies beyond bash and Claude Code.

### Presets

Skip the wizard with a preset:

```bash
./setup.sh --preset minimal   # Core rules + memory only
./setup.sh --preset writer    # Core + vault structure + commands + retrieval
./setup.sh --preset full      # Everything activated
```

### Other flags

```bash
./setup.sh --update                    # Update existing install (preserves config)
./setup.sh --dry-run                   # Preview what would be installed
./setup.sh --yes                       # Accept all defaults (scripting mode)
./setup.sh --add <module>              # Add a module to existing install
./setup.sh --remove <module>           # Remove a module
./setup.sh --list                      # Show installed modules
./setup.sh --install-package <source>  # Install a community package
./setup.sh --uninstall-package <name>  # Uninstall a community package
./setup.sh --list-packages             # List installed community packages
```

## Auto-update

Open Arcana checks for updates once per day on session start. If a newer version is available, you'll see a notification:

```
Open Arcana update available: v1.0.3 -> v1.0.4
  Run: cd /path/to/open-arcana && git pull && ./setup.sh --update
```

The `--update` flag reads your existing config (profile, modules, integrations), pulls the latest code, and reinstalls without re-running the wizard. Your settings are preserved.

To disable the check, remove the `update-check.sh` hook from your `.claude/settings.local.json`.

## How it works

Open Arcana installs into your vault's `.claude/` directory:

```
your-vault/
├── .claude/
│   ├── rules/          # AI behavior rules (auto-loaded by Claude Code)
│   ├── hooks/          # Shell scripts triggered on tool use
│   ├── commands/       # Slash commands (/start, /health, etc.)
│   ├── settings.local.json  # Hook wiring
│   └── arcana.config.yaml   # Which modules are active
├── CLAUDE.md           # Master config (generated from template)
├── 00-Dashboard/       # Concept index, hot-cache, alerts
├── 80-Templates/       # Note templates
└── Daily-Notes/        # Daily notes (if vault-structure module active)
```

Rules are loaded automatically by Claude Code on every session. Hooks fire on specific events (Write, Edit, SessionStart). Commands are available as `/command-name`.

## The Anti-Sycophancy Protocol

The headline feature. Six rules (AS-1 through AS-6) that change how Claude Code reasons:

- **AS-1: Confidence tags.** Every logged action includes `[confidence: high|medium|low, source: api|log|inferred|memory]`
- **AS-2: Challenge-previous.** Before accepting output from a prior session, the agent must identify at least one questionable point.
- **AS-3: Unanimity check.** When multiple sources agree perfectly, flag it. They might share the same upstream bias.
- **AS-4: Conflict reports.** Disagreements between sessions are documented, not silently overwritten.
- **AS-5: Independent analysis.** Form your own assessment from primary sources before reading prior output.
- **AS-6: Memory decay.** Memories older than 7 days about transient states must be re-verified.

## The Retrieval System

Four layers, inspired by DeepSeek's Engram paper on conditional memory lookup:

1. **Deterministic lookup** (O(1)): concept-index hash table, aliases for term normalization
2. **Filtered search**: grep scoped by domain/type, max 5 results
3. **Semantic search**: Smart Connections MCP, max 3 results (only when layers 1-2 return empty)
4. **Fallback**: list recent files in active domain, or ask the user

Budget: max 20% of context window for retrieval, 80% for reasoning.

## Session Branching

Claude Code sessions are stored as JSONL with a tree structure (each message has `uuid` and `parentUuid`). When you steer a conversation, retry, or branch off, the session file records the full tree, not just a linear chat.

Open Arcana detects these branches automatically. The session index (`tools/session_index.py`) builds a tree from each session, counts branch points, and tracks tree depth. The index includes `branch_count`, `max_depth`, and `branch_points` fields for every session.

Use `/tree <keyword>` to visualize any session's decision tree:

```
## Session Tree: 2026-04-07 (3 branches, depth 12)

◈ "Implement auth system"
├── ◇ (assistant response)
│   ├── ◈ "Use Google OAuth"          ← branch point (2 children)
│   │   └── ◇ (assistant response)
│   └── ◈ "Use GitHub OAuth"          ← alternative branch
│       └── ◇ (assistant response)
└── ◈ "Add rate limiting"
```

This makes it easy to audit past decisions, revisit abandoned approaches, and understand how a session evolved.

## Steering Messages

Claude Code supports mid-execution steering: you can send messages while the agent is working, without interrupting its current tool call.

**How it works:** press `Shift+Tab` (or `Esc` in some terminals) while the agent is executing to queue a message. The message is delivered after the current tool call completes, letting you course-correct without losing work in progress.

**When to use steering:**
- The agent is heading in the wrong direction and you want to redirect it
- You want to add a constraint ("don't modify that file") mid-task
- You want to provide new context that just became available

**How this interacts with Open Arcana:**
- Steered messages create branch points in the session tree (visible in `/tree`)
- The anti-sycophancy protocol applies to steered prompts too: the agent must still validate, not just comply
- Session titles (via `session-title.sh`) are set from the first prompt, not from steering messages

## Community Packages

Beyond the 10 built-in modules, Open Arcana supports community packages: third-party extensions you can install from git repos or local directories.

### Installing a package

```bash
# From a git repository
./setup.sh --install-package https://github.com/author/arcana-git-workflow.git

# From a local directory
./setup.sh --install-package /path/to/my-package
```

The installer validates the manifest, checks version compatibility, installs files to the right locations, and records the package in your config.

### Creating a package

A package is any directory (or git repo) with an `arcana-package.yaml` manifest:

```yaml
name: "git-workflow"
version: "1.0.0"
description: "Git conventions and a /git-review command"
author: "Your Name"

requires:
  open-arcana: ">=1.0.0"

provides:
  rules:
    - git-conventions.md
  commands:
    - git-review.md
```

Packages follow the same directory convention as built-in modules: `rules/`, `hooks/`, `commands/`, `templates/`, `tools/`. Template variables (`{{VAULT_PATH}}`, etc.) work in package files.

### Managing packages

```bash
./setup.sh --list-packages              # See what's installed
./setup.sh --uninstall-package my-pkg   # Remove a package and its files
```

See [docs/packages.md](docs/packages.md) for the full specification, including version constraints, conflict resolution, and publishing guidelines.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (CLI or IDE extension)
- [Obsidian](https://obsidian.md/) vault (existing or new)
- bash (macOS/Linux, or WSL on Windows)
- Optional: Smart Connections MCP (for semantic search layer)

## Uninstall

```bash
./uninstall.sh /path/to/your/vault
```

Removes all Open Arcana files and restores your original settings.local.json from backup.

## Contributing

Contributions welcome. Some ideas:

- **Community packages** (git workflow, citation management, spaced repetition, journaling). See [docs/packages.md](docs/packages.md) and the [example package](examples/package/).
- Adapters for other AI tools (Cursor, Windsurf, Copilot)
- Windows native support (no WSL)
- Translations for non-English rule sets

## License

MIT. See [LICENSE](LICENSE).

## Credits

Created by [Thiago Salvador](https://github.com/thiago-salvador). Built on top of [Claude Code](https://docs.anthropic.com/en/docs/claude-code) by Anthropic and [Obsidian](https://obsidian.md/) by Obsidian.

The retrieval system is inspired by ["Conditional Memory via Scalable Lookup"](https://arxiv.org/abs/2025.xxxxx) (DeepSeek Engram, 2025).
