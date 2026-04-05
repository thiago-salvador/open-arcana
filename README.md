# Open Arcana

**AI Agent Orchestration Framework for Obsidian + Claude Code**

Open Arcana turns your Obsidian vault into an AI-operated knowledge system. It gives Claude Code the rules, hooks, retrieval strategies, and automation commands it needs to actually work well with a vault, not just read and write files.

Built from a production system running 16 hooks, 24 commands, and 500+ automated health checks daily.

## What's in the box

| Module | What it does |
|--------|-------------|
| **Anti-Sycophancy Protocol** | 6 rules that prevent AI from agreeing without evidence. Confidence tags, challenge-previous, conflict reports. |
| **Token Efficiency** | 14 rules for context window management and cost control. Cache awareness, retrieval budgets, output discipline. |
| **Enforcement Hooks** | Auto-validates frontmatter, enforces daily notes, checks writes before they happen. |
| **Security Hooks** | Blocks prompt injection in memory files, guards against fabricated people data. |
| **Vault Structure** | Opinionated folder system with 18 note templates. One command creates the full tree. |
| **Retrieval System** | 4-layer lookup inspired by DeepSeek's Engram paper. Concept index, filtered grep, semantic search, fallback. |
| **Slash Commands** | 18 commands: /start, /end, /weekly, /health, /dump, /capture, and more. |
| **Connected Sources** | Templates for orchestrating 16+ MCP data sources (Teams, Notion, Calendar, Read.AI, etc). |
| **Scheduled Tasks** | Patterns for autonomous recurring agents: morning briefing, end-of-day, weekly review. |
| **Vault Health** | 500+ automated checks for frontmatter, orphans, broken links, and index consistency. |

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
./setup.sh --dry-run           # Preview what would be installed
./setup.sh --yes               # Accept all defaults (scripting mode)
./setup.sh --add <module>      # Add a module to existing install
./setup.sh --remove <module>   # Remove a module
./setup.sh --list              # Show installed modules
```

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

- New modules (git workflow hooks, citation management, spaced repetition)
- Adapters for other AI tools (Cursor, Windsurf, Copilot)
- Windows native support (no WSL)
- Translations for non-English rule sets

## License

MIT. See [LICENSE](LICENSE).

## Credits

Created by [Thiago Salvador](https://github.com/thiago-salvador). Built on top of [Claude Code](https://docs.anthropic.com/en/docs/claude-code) by Anthropic and [Obsidian](https://obsidian.md/) by Obsidian.

The retrieval system is inspired by ["Conditional Memory via Scalable Lookup"](https://arxiv.org/abs/2025.xxxxx) (DeepSeek Engram, 2025).
