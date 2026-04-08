# Commands Module

Slash commands for Claude Code that turn your Obsidian vault into an operational system. Each command is a `.md` file placed in `.claude/commands/` and invoked via `/command-name`.

These commands assume you have a working vault with the structure defined in the vault-structure module, plus connected MCPs for calendar, team chat, meeting transcripts, and task management.

## Commands

| Command | What it does | Interactive? |
|---------|-------------|:------------:|
| `/start` | Morning briefing. Collects meeting transcripts, team chat, calendar, tasks, and file changes in parallel. Cross-references everything and generates prioritized focus for the day. | No |
| `/end` | End-of-day wrap-up. Captures decisions, records current state (mandatory), processes unprocessed meetings, prepares tomorrow's agenda. | Yes |
| `/weekly` | Weekly review. Reads 7 days of Daily Notes, collects task metrics, GitHub stats, memory health, anti-sycophancy metrics. Generates `00-Dashboard/Weekly Review.md`. | Yes |
| `/recap` | Lightweight day summary. Read-only, no vault writes. Shows meetings, chats, emails, tasks, and sessions so far today. | No |
| `/health` | Vault health audit. Checks frontmatter completeness, index.md coverage, MOC link integrity, orphan notes, Daily Note existence. Outputs score /10. | Yes |
| `/dump` | Brain dump with auto-routing. Accepts free text, classifies it (decision, bug, concept, meeting, person, content, action, project, partnership, event), routes to the correct folder, creates the note. | Minimal |
| `/capture` | Post-session knowledge capture. Asks what to save (decision, bug fix, pattern, concept), creates an atomic note in the right location. | Yes |
| `/process` | Turns raw material (transcripts, research, conversations) into atomic vault notes. Extracts decisions, action items, people, concepts. | Yes |
| `/scan` | Scans recently modified files outside the vault. Groups by project, cross-references with existing vault notes, suggests documentation actions. | Yes |
| `/sync-all` | Full sync: file scan + external project syncs + health check + connection discovery. Best for start of the week or returning after time away. | Yes |
| `/connections` | Discovers cross-domain connections via semantic search. Finds non-obvious links between domains and categorizes them as actions, context enrichment, or productive tensions. | Yes |
| `/link-check` | Cross-linker. Scans recent notes and inserts missing wikilinks by exact match against vault note names, aliases, and people. Supports dry-run mode. | No |
| `/contrarian` | Anti-sycophancy analysis. Searches for excessive agreement, unverified facts, stale memories, and missing divergences. Produces a structured report with metrics. | No |
| `/audit-gaps` | Detects vault gaps: uncatalogued people, projects without notes, action items without tasks, decisions without records. Scans external sources and compares. | Yes |
| `/post-meeting` | Processes meeting transcripts into vault notes. Creates decision records, extracts action items as tasks, updates person notes and indexes. | No |
| `/person` | Person briefing. Pulls complete context from vault, team chat, meeting transcripts, calendar, task manager, and LinkedIn. Offers to create a person note if missing. | Yes |
| `/distill` | Extracts reusable workflows from the current session. Identifies 5+ step sequences with coherent outcomes, classifies as command/rule/template candidates, asks before creating. | Yes |
| `/recall` | Cross-session search. Searches previous sessions by keyword or prompt content using the session index. Requires `tools/session_index.py`. | No |
| `/model-review` | Proactive user model review. Detects uncaptured preferences, stale memories, missing project records, and new workflows. Read-only. | No |
| `/doc-release` | Updates project docs after code changes. Scans for drift in README, ARCHITECTURE, CLAUDE.md, etc. Fixes drift and syncs back to vault project notes. | Yes |
| `/ship` | Full release pipeline: tests, review, commit, PR, deploy, doc-release, vault sync. One command from tested code to deployed PR. | Yes |

## Installation

Copy the `commands/` folder into your project's `.claude/commands/` directory:

```bash
cp -r modules/commands/commands/*.md /path/to/your/project/.claude/commands/
```

Then replace the placeholder tokens in each file with your actual values:

| Token | Replace with |
|-------|-------------|
| `{{VAULT_PATH}}` | Absolute path to your Obsidian vault |
| `{{MEMORY_DIR}}` | Absolute path to your Claude Code memory directory |
| `{{MS_GRAPH_PATH}}` | Path to your Microsoft Graph MCP server |
| `{{NOTION_DB_ID}}` | Your Notion tasks database ID |
| `{{TEAMS_CHAT_ID}}` | Your priority Teams chat IDs |
| `{{COMPANY}}` | Your company/org name |

## Dependencies

Most commands work with just vault read/write access. The full experience requires:

- **Microsoft Graph MCP** -- for Teams chat, Outlook, MS Calendar
- **Read.AI MCP** (or similar) -- for meeting transcripts
- **Notion MCP** (or similar) -- for task management
- **Smart Connections MCP** -- for semantic vault search
- **Gmail MCP** -- for email integration
- **LinkedIn MCP** -- for person enrichment
- **GitHub CLI (`gh`)** -- for dev metrics and PR workflows

Commands gracefully degrade when MCPs are unavailable. They report the failure and continue with whatever sources are accessible.

## Design Principles

1. **Parallel collection.** Commands that gather data from multiple sources run collections in parallel, not sequentially.
2. **Graceful degradation.** If a source fails, skip it and continue. Never block the entire command on one failing MCP.
3. **Never fabricate.** If there is no data, say so. Do not invent content to fill gaps.
4. **Append, never overwrite.** Daily Notes and existing vault content are always preserved. New data is merged in.
5. **Ask before creating.** Commands that create notes or tasks ask for confirmation first (with some exceptions for logging).
6. **Vault as source of truth.** External data gets processed into vault notes. The vault is the canonical record.
