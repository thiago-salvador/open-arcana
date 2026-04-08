# Modules

Open Arcana is modular. Core is always installed; everything else is optional. Activate modules during setup or add them later with `./setup.sh --add <module>`.

## Core (always installed)

**CLAUDE.md template**: Master configuration file that tells Claude Code how to work with your vault. Includes retrieval rules, frontmatter schema, vault structure, and maintenance rules.

**Core Rules** (`core-rules.md`): 12 operational rules covering logging discipline, data validation, file handling, cross-referencing, and pre-delivery checks.

**Session Scan Hook**: Runs on session start. Reports recently modified files, loads the daily note, and injects retrieval context.

**Memory System**: MEMORY.md scaffold for persistent memory across sessions. Organized by type (user, feedback, project, reference).

## Guardrails

### anti-sycophancy
**6 rules that change how the AI reasons.**

| Rule | What it does |
|------|-------------|
| AS-1 | Confidence tags on every logged action (high/medium/low + source) |
| AS-2 | Challenge-previous: question output from prior sessions before accepting |
| AS-3 | Unanimity check: flag when multiple sources agree too perfectly |
| AS-4 | Conflict reports: document disagreements, don't overwrite silently |
| AS-5 | Independent analysis before reading prior output |
| AS-6 | Memory decay: re-verify memories older than 7 days |

Also includes a ConflictReport template for documenting disagreements.

### token-efficiency
**14 rules for context window management and cost control.**

Covers: MicroCompact scope awareness, post-compact file restoration, prompt cache management, boot payload minimization, cross-agent scratchpads, web search cost tracking, fast mode awareness, context window math, output discipline, targeted reads, tool call consolidation, graduated response length, agent prompt efficiency, and anti-speculative exploration.

## Enforcement

### enforcement-hooks
**4 hooks that run automatically on Edit/Write operations.**

- `enforce-daily-note.sh`: Blocks tool use if today's daily note doesn't exist
- `validate-frontmatter.sh`: Checks frontmatter structure before writes
- `validate-write.sh`: Validates note content after writes (required fields, domain tags)
- `stop-check-dn.sh`: Warns if daily note has no log entries

### security-hooks
**4 hooks for memory safety and data integrity.**

- `memory-injection-scan.sh`: Blocks prompt injection patterns in memory files
- `cascade-check.sh`: Reminds about cross-reference updates after editing facts
- `guard-people.sh`: Guards against fabricating data about people
- `memory-nudge.sh`: Reminds to persist learnings before context compaction

## Vault Management

### vault-structure
**Opinionated folder structure with 18 note templates.**

Creates a complete vault directory tree:
```
00-Dashboard/    10-Work/       30-Content/     50-Events/
70-People/       80-Templates/  85-Rules/       90-Archive/
99-Inbox/        Daily-Notes/   MOCs/
```

Includes templates for: Daily Notes, Meetings, Projects, People, Partnerships, Events, Articles, Social Posts, Decision Records, Dev Logs, Error Solutions, Hub Notes, Knowledge Notes, MOCs, Project Indexes, Toolbox Notes, Conflict Reports, and Inbox Items.

### retrieval-system
**4-layer lookup inspired by DeepSeek's Engram paper.**

1. **Deterministic** (O(1)): concept-index hash table, aliases
2. **Filtered search**: grep scoped by domain/type, max 5 results
3. **Semantic search**: Smart Connections MCP, max 3 results
4. **Fallback**: list recent files or ask the user

Budget: max 20% of context window for retrieval, 80% for reasoning.

Includes: boot-protocol rules, prefetch-context hook, and dashboard templates (concept-index, aliases, hot-cache).

## Automation

### commands
**18 slash commands for daily workflows.**

| Command | What it does |
|---------|-------------|
| `/start` | Morning briefing + daily note creation |
| `/end` | End-of-day summary + tomorrow's priorities |
| `/weekly` | 7-day review with metrics |
| `/recap` | Quick summary of today so far |
| `/health` | Vault health audit |
| `/dump` | Brain dump with auto-routing by type |
| `/capture` | Guided session capture to vault |
| `/process` | Process raw material into atomic notes |
| `/scan` | Detect recently modified files outside vault |
| `/sync-all` | Full sync orchestrator |
| `/connections` | Cross-domain semantic search |
| `/link-check` | Insert missing wikilinks in recent notes |
| `/contrarian` | Anti-sycophancy weekly analysis |
| `/audit-gaps` | Detect missing people, projects, tasks |
| `/post-meeting` | Process meeting transcripts |
| `/person` | Full briefing on a person |
| `/doc-release` | Update docs after code changes |
| `/ship` | Release pipeline (test, review, commit, PR) |

### connected-sources
**Template for orchestrating MCP data sources.**

Pre-configured templates for: Teams, Outlook, Calendar (MS + Google), Read.AI, Notion, Gmail, iMessages, GitHub, Apple Notes, YouTube, RSS, Twitter/X, LinkedIn, and more.

Includes cross-referencing rules (which sources to combine for which contexts).

### scheduled-tasks
**Templates for autonomous recurring agents.**

Example configurations for: morning briefing, end-of-day closure, and weekly review. Patterns you can adapt for your own recurring automation.

### vault-health
**500+ automated checks for vault consistency.**

Checks: frontmatter completeness, required fields, orphan detection, broken wikilinks, index.md sync, template compliance, domain tag validity, and more.

Run with: `bash .vault-test.sh`
