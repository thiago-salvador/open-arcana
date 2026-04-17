# Open Arcana Architecture

**Canonical source of truth for Open Arcana's architecture.** This document describes every module, hook, rule, command, script, template, and configuration primitive that Open Arcana ships. If anything in the repository contradicts this document, this document wins, or this document is stale and must be updated immediately (see Governance below).

Companion docs (scoped, non-canonical): `README.md` (product overview), `docs/modules.md` (per-module summaries), `docs/getting-started.md` (install walkthrough), `docs/packages.md` (community package spec), `docs/customization.md` (config recipes), `docs/variables.md` (template variable reference), `CHANGELOG.md` (release history).

---

## Governance

### Versioning

Open Arcana uses [Semantic Versioning](https://semver.org/):

- **MAJOR**: breaking change to hook wiring, rule semantics, or module contracts (packages built against the old version will not work)
- **MINOR**: new module, new rule set, new commands, new hooks. Backwards compatible.
- **PATCH**: bug fixes, doc fixes, metadata drift corrections. Backwards compatible.

Current: see `setup.sh` `VERSION` variable and the latest `## [X.Y.Z]` heading in `CHANGELOG.md`. The two must match. A stale `VERSION` in `setup.sh` is a v1.7.0 regression; the integrity check verifies parity.

### Changelog protocol

Every release updates `CHANGELOG.md` following [Keep a Changelog](https://keepachangelog.com/) format:

- Heading: `## [X.Y.Z] - YYYY-MM-DD -- <Short title>`
- Sections (omit empty ones): `### Added`, `### Changed`, `### Fixed`, `### Removed`, `### Architecture notes`
- Each entry names the file it touches in backticks: `` `modules/<name>/rules/foo.md` ``
- No silent edits. If a rule count, hook count, or command count changes, the change is listed.

Every MINOR/MAJOR release also gets a git tag matching the version (`v1.9.0`). The integrity check compares `CHANGELOG.md` entries against `git tag` and flags missing tags.

### Master doc maintenance

This document lists every hook, rule, command, module, and script that ships with Open Arcana. Two classes of change trigger an update to this document:

1. **Inventory change**: file added, removed, or renamed under `core/`, `modules/`, or `tools/`. The integrity check (`tools/arcana-integrity.py`) compares the filesystem against this document and flags drift.
2. **Semantic change**: a rule's meaning changes, a hook's event changes, a command's effect changes, or the dependency graph changes. These do not always produce a filesystem diff, so they require a conscious edit here.

When in doubt: if a release is MINOR or MAJOR, this document should change. If a release is PATCH and nothing structural moved, only `## Changelog` below gets a new entry.

### Drift prevention (3 layers)

1. **Mechanical (code)**: `tools/arcana-integrity.py` walks the repository and compares reality against this document. It runs locally and in CI on every push (see `.github/workflows/integrity.yml`). Output: a list of drift findings with severity (ERROR blocks merge, WARN flags review, INFO is informational).
2. **Disciplinary (process)**: `CONTRIBUTING.md` lists the checklist every PR author runs before opening a PR. The checklist includes running the integrity check, updating this document if inventory moved, and appending a CHANGELOG entry.
3. **Documental (history)**: this document's `## Changelog` section (at the bottom) records every structural edit with date and diff summary. A doc that changes silently is a doc that is drifting.

### When to update this doc

- A new module lands under `modules/<name>/`: add a row to the module table, add module details to `## Modules`, add its hooks/rules/commands to the respective inventory tables.
- A hook file is added, removed, or renamed: update `## Hooks` table and the relevant module's hook count.
- A rule file gains or loses a numbered rule (AS-N, TE-N, CT-N, CSR-N): update the count in `## Rules` and in the module's README.
- A command is added or removed from `modules/commands/commands/`: update `## Slash commands` table.
- A template is added or removed from `modules/vault-structure/templates/`: update the count in `## Note templates`.
- A top-level tool (`tools/*.py`) is added or removed: update `## Tools`.
- A git tag is cut: verify this doc matches the new release before tagging.

---

## Repository layout

```
open-arcana/
├── ARCHITECTURE.md         # ← This file (master doc)
├── README.md               # Product overview
├── CHANGELOG.md            # Release history (Keep a Changelog)
├── CLAUDE.md               # Claude Code instructions for this repo
├── LICENSE                 # MIT
├── Spec.md                 # Spec for the analytics module (legacy path)
├── setup.sh                # Install/update wizard (50KB)
├── uninstall.sh            # Uninstall script
├── core/                   # Always installed
│   ├── CLAUDE.md.template  # Master config generated into user's vault
│   ├── MEMORY.md.template  # (under memory/)
│   ├── settings.template.json  # Hook wiring template
│   ├── rules/              # 4 operational rules
│   ├── hooks/              # 5 shell hooks
│   └── memory/             # Memory system template
├── modules/                # 13 optional modules (see § Modules)
├── tools/                  # 2 Python tools (session_index, token_analysis)
├── docs/                   # Scoped docs (non-canonical)
├── examples/               # 4 preset configurations (minimal, writer, full, package)
└── Logo/                   # Brand assets
```

File counts (verified against filesystem; regenerate with `tools/arcana-integrity.py --inventory`):

| Location | Count | Notes |
|---|---|---|
| `core/rules/*.md` | 4 | auto-capture, auto-parallel, core-rules, definition-of-done |
| `core/hooks/*.sh` | 5 | alert, read-alerts, session-scan, session-title, update-check |
| `modules/` subdirectories | 13 | See § Modules |
| `modules/commands/commands/*.md` | 26 | All shipped slash commands |
| `modules/enforcement-hooks/hooks/*.sh` | 6 | Enforcement-class hooks |
| `modules/security-hooks/hooks/*.sh` | 4 | Security-class hooks |
| `modules/retrieval-system/hooks/*.sh` | 1 | `prefetch-context.sh` |
| `modules/vault-structure/templates/*.md` | 19 | Note templates |
| `modules/scripts-offload/tools/*.py` | 9 | 8 operational + `_common.py` helper |
| `tools/*.py` | 2 | `session_index.py`, `token_analysis.py` |
| `docs/*.md` | 7 | architecture, customization, getting-started, modules, packages, variables, PRD-arcana-analytics |
| `examples/` directories | 4 | full, minimal, writer, package |

Total hooks installable if all modules are active: **16** (5 core + 6 enforcement + 4 security + 1 retrieval).

---

## Core

Always installed. Ships the rule layer, the session lifecycle hooks, the Claude Code config template, and the memory scaffold.

### Core rules (`core/rules/`)

| File | Purpose | Key numbered items |
|---|---|---|
| `core-rules.md` | 11 operational rules for the agent | Rules 1-11 + 4b (timestamp placeholder prohibition) |
| `auto-capture.md` | Proactive vault capture for substantial analysis | No numbered rules; trigger criteria + format |
| `auto-parallel.md` | Dispatch parallel subagents for independent work | Agent type table + soft cap (8 subagents) |
| `definition-of-done.md` | DoD discipline for all projects | Phase 1/2/3 gates + test matrix |

`core-rules.md` deliberately does NOT duplicate anti-sycophancy text. When the anti-sycophancy module is active, `anti-sycophancy.md` loads separately. If anti-sycophancy is inactive, the user has chosen to skip that guardrail; core-rules still loads.

### Core hooks (`core/hooks/`)

| Hook | Event | What it does | Notes |
|---|---|---|---|
| `session-scan.sh` | SessionStart (`startup|resume`) | Reports recently modified files; loads hot-cache/concept-index stats | Does NOT auto-inject content (token discipline, TE-4) |
| `read-alerts.sh` | SessionStart | Reads `00-Dashboard/alerts.md` and surfaces unread alerts grouped by domain | No-op if file absent |
| `update-check.sh` | SessionStart | Daily check for new Open Arcana releases via `git` | Opt out by removing from `settings.local.json` |
| `session-title.sh` | UserPromptSubmit | Captures the first prompt as the session title for later indexing | Fires once per session (first turn) |
| `alert.sh` | Not wired automatically; invoked by commands/tasks | Writes a structured alert to `00-Dashboard/alerts.md` | Utility, not a lifecycle hook |

Wiring is declared in `core/settings.template.json`. At install time, `setup.sh` substitutes `{{VAULT_PATH}}` and other template variables (see § Template variables).

### Core memory (`core/memory/`)

| File | Purpose |
|---|---|
| `MEMORY.md.template` | Scaffold for the user's `MEMORY.md` index, generated at install into `~/.claude/projects/<slug>/memory/` |

### Core CLAUDE.md template (`core/CLAUDE.md.template`)

Generated into the vault root at install. Includes: retrieval rules, frontmatter schema, vault structure tree, maintenance rules, command index. Uses template variables: `{{USER_NAME}}`, `{{USER_ROLE}}`, `{{USER_LANG}}`, `{{VAULT_PATH}}`, `{{MEMORY_DIR}}`, `{{NOTION_DB_ID}}`, `{{USER_EMAIL}}`, `{{COMPANY}}`, `{{PRIMARY_DOMAIN}}`, `{{DOMAINS}}`.

---

## Modules

13 modules, each optional. Users activate them during `./setup.sh` or add with `./setup.sh --add <module>`. Each module directory contains a `README.md` documenting its own scope.

| # | Module | Category | Ships | Key outputs |
|---|---|---|---|---|
| 1 | `anti-sycophancy` | Guardrail | 1 rule file (6 AS rules), 1 template (ConflictReport) | Grounded disagreement, confidence tags |
| 2 | `token-efficiency` | Guardrail | 2 rule files (18 TE rules + session-discipline) | Cost control, session management |
| 3 | `enforcement-hooks` | Enforcement | 6 hooks | Daily Note gate, frontmatter validation, iteration counting |
| 4 | `security-hooks` | Enforcement | 4 hooks | Injection scan, cascade reminders, people-data guard |
| 5 | `vault-structure` | Vault | 19 templates, 3 rules, `scaffold.sh` | Folder tree + note templates |
| 6 | `retrieval-system` | Vault | 1 rule (boot-protocol), 1 hook (prefetch-context), 3 dashboard templates | 4-layer Engram-style retrieval |
| 7 | `commands` | Automation | 26 slash commands | Daily workflows (see § Slash commands) |
| 8 | `connected-sources` | Automation | 1 rule template (connected-sources) | MCP registry + cross-referencing rules |
| 9 | `scheduled-tasks` | Automation | 3 example templates (morning, end-of-day, weekly) | Patterns for unattended agents |
| 10 | `vault-health` | Automation | `vault-test.sh` | 5-test composite score |
| 11 | `scripts-offload` | Automation | 9 Python scripts + 2 commands (health, link-check) | Compute-heavy ops as scripts |
| 12 | `completion-tracking` | Automation | 2 rule files (CT-1 to CT-3, CSR-1 to CSR-3) | Action-item fulfillment loop |
| 13 | `analytics` | Automation | 1 engine, 1 dashboard template, 1 command | 6 behavioral metrics dashboard |

### Dependency graph

```
Core (always)
│
├── Guardrails (standalone, no dependencies)
│   ├── anti-sycophancy
│   └── token-efficiency
│
├── Enforcement (needs core hook infrastructure)
│   ├── enforcement-hooks
│   └── security-hooks
│
├── Vault layer
│   ├── vault-structure (creates folders + templates)
│   └── retrieval-system (works best with vault-structure folders)
│
├── Automation layer
│   ├── commands (some commands use retrieval-system; all work standalone)
│   ├── connected-sources (standalone config)
│   ├── scheduled-tasks (standalone patterns)
│   ├── vault-health (works best with vault-structure)
│   ├── scripts-offload (overrides /health and /link-check from commands)
│   ├── completion-tracking (works best with commands + connected-sources)
│   └── analytics (reads JSONL from ~/.claude/projects; standalone)
```

No module has a hard dependency on another. Presets in `examples/` document tested combinations.

### Module install mechanics

`setup.sh` function `install_module()` (lines 414-533) walks the module directory and copies:

| Source inside module | Destination in user's vault |
|---|---|
| `rules/*.md` (or `.md.template`) | `.claude/rules/` |
| `hooks/*.sh` | `.claude/hooks/` (executable, template-processed) |
| `commands/*.md` (or `.md.template`) | `.claude/commands/` (template-processed) |
| `templates/*.md` | `80-Templates/` |
| `dashboard/*.md.template` | `00-Dashboard/` (template-processed) |
| `examples/*.md` | `.claude/scheduled-tasks/` |
| `tools/*` | `.claude/tools/` (executable) |
| `scaffold.sh` (vault-structure only) | Runs on install, creates vault folder tree |
| `vault-test.sh` (vault-health only) | Copied to `$VAULT_PATH/.vault-test.sh` |

The generated `.claude/arcana.config.yaml` records which modules are active, for later `--add`/`--remove` operations and community package dependency resolution.

---

## Rules

The term "rule" has two overlapping uses in this repo:

- **Rule file** (`.claude/rules/*.md` in the user's installed vault, or `rules/*.md` inside a module): loaded into Claude Code context on every session via the Claude Code rule-loading mechanism.
- **Numbered rule** (AS-1, TE-1, CT-1, CSR-1, etc.): a specific guidance item inside a rule file. Counted for drift detection.

### Rule files installed when each module is active

| From | File | Count of numbered rules |
|---|---|---|
| `core/rules/` | `auto-capture.md` | (trigger-criteria style, no numbered items) |
| `core/rules/` | `auto-parallel.md` | (checklist style, no numbered items) |
| `core/rules/` | `core-rules.md` | 11 (numbered 1-11, with 4b as timestamp sub-rule) |
| `core/rules/` | `definition-of-done.md` | (phase-based, no numbered items) |
| `modules/anti-sycophancy/rules/` | `anti-sycophancy.md` | **6** (AS-1 through AS-6) + intra-session extension |
| `modules/token-efficiency/rules/` | `token-efficiency.md` | **18** (TE-1 through TE-18) |
| `modules/token-efficiency/rules/` | `session-discipline.md` | (decision-tree style, no numbered items) |
| `modules/retrieval-system/rules/` | `boot-protocol.md` | (layer-based, no numbered items) |
| `modules/completion-tracking/rules/` | `completion-tracking.md` | **3** (CT-1, CT-2, CT-3) |
| `modules/completion-tracking/rules/` | `cross-source-reconciler.md` | **3** (CSR-1, CSR-2, CSR-3) |
| `modules/connected-sources/rules/` | `connected-sources.md.template` | (registry style, no numbered items) |
| `modules/vault-structure/rules/` | `people.md`, `content.md`, `domain-example.md` | (domain-scoped style) |

Total numbered rules across all modules: **11 (core) + 6 (AS) + 18 (TE) + 3 (CT) + 3 (CSR) = 41**.

### Numbered rule drift check

The integrity validator reads the filename convention `<name>.md` and extracts headings matching `^(AS|TE|CT|CSR)-\d+`. Any mismatch between the count claimed in `modules/<name>/README.md` and the count in the rule file is flagged.

---

## Hooks

Shell scripts fired by Claude Code on specific events: `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PreCompact`, `Stop`.

### Full hook inventory (all modules installed)

| Hook | Event | Source module | Purpose | Blocks? |
|---|---|---|---|---|
| `session-scan.sh` | SessionStart | core | Report recent file activity | No |
| `read-alerts.sh` | SessionStart | core | Surface unread alerts | No |
| `update-check.sh` | SessionStart | core | Check for new Arcana release | No |
| `session-title.sh` | UserPromptSubmit | core | Capture session title | No |
| `turn-boundary-check.sh` | UserPromptSubmit | enforcement-hooks | Evaluate iteration thresholds, emit review flag | No |
| `enforce-daily-note.sh` | PreToolUse | enforcement-hooks | Block tool use if DN missing | Yes (approve/block) |
| `validate-frontmatter.sh` | PreToolUse (Write) | enforcement-hooks | Warn if missing YAML frontmatter | No |
| `memory-injection-scan.sh` | PreToolUse (Write, Edit) | security-hooks | Block injection patterns in memory files | Yes (block) |
| `guard-people.sh` | PreToolUse (Write, Edit) | security-hooks | Remind to source people data | No |
| `prefetch-context.sh` | PreToolUse | retrieval-system | Inject domain context, concept-index stats | No |
| `iteration-counter.sh` | PostToolUse (wildcard) | enforcement-hooks | Track iteration + struggle signals | No |
| `validate-write.sh` | PostToolUse (Write, Edit) | enforcement-hooks | Validate frontmatter, wikilinks, dashes, domain tags | No (warn only) |
| `cascade-check.sh` | PostToolUse (Edit) | security-hooks | Remind to update cross-references | No |
| `stop-check-dn.sh` | Stop | enforcement-hooks | Warn if DN lacks timestamped logs | No |
| `memory-nudge.sh` | PreCompact | security-hooks | Remind to persist learnings before compact | No |
| `alert.sh` | (utility, not wired) | core | Write alert to `00-Dashboard/alerts.md` | - |

### Hook categories

- **Session lifecycle** (4): session-scan, read-alerts, update-check, session-title. Boot-time orientation.
- **Enforcement** (6): enforce-daily-note, validate-frontmatter, validate-write, stop-check-dn, iteration-counter, turn-boundary-check. Vault discipline.
- **Security** (4): memory-injection-scan, cascade-check, guard-people, memory-nudge. Safety and integrity.
- **Retrieval** (1): prefetch-context. Domain inference.
- **Utility** (1): alert. Invoked on demand by other code.

### Blocking vs non-blocking

Only two hooks actually block tool execution:

- `enforce-daily-note.sh` emits `{"decision":"approve"}` when the DN exists and `{"decision":"block","reason":...}` when it does not. The agent retries after creating the DN.
- `memory-injection-scan.sh` emits a block when prompt injection patterns are detected in memory writes.

All other hooks inject warnings via `additionalContext`, which the agent sees but can choose how to handle. This is deliberate: blocking hooks are expensive and the failure mode (agent loops) is worse than missing warnings.

### Hook wiring

Each module's README documents the exact JSON block to add to `.claude/settings.local.json`. `setup.sh` merges these blocks automatically during install. The generated wiring matches the contract declared in each module README; the integrity check verifies this.

---

## Slash commands

All in `modules/commands/commands/*.md` (26 files) plus `modules/scripts-offload/commands/` (2 files that override `health.md` and `link-check.md`) and `modules/analytics/commands/` (1 file).

Each `.md` file is a prompt template. When the user types `/<name>`, Claude Code loads the file contents as the next turn's system prompt.

### Commands by category

| Category | Commands |
|---|---|
| Daily workflow | `/start`, `/end`, `/recap`, `/distill` |
| Weekly/periodic | `/weekly`, `/contrarian`, `/model-review` |
| Health and audit | `/health`, `/audit-gaps`, `/scan` |
| Capture | `/capture`, `/dump`, `/process`, `/post-meeting` |
| Knowledge | `/wiki-query`, `/wiki-lint`, `/recall`, `/connections`, `/link-check` |
| People | `/person` |
| Content validation | `/bias-check` |
| Release | `/ship`, `/doc-release` |
| Sync | `/sync-all` |
| Session debugging | `/tree` |
| Observability | `/analytics` |

Total: 26 commands in `modules/commands/commands/` + 1 in `modules/analytics/commands/` = **27** unique commands when all modules are active.

(`scripts-offload` does not add commands; it overrides the behavior of `/health` and `/link-check` by replacing the markdown prompt with a script-backed variant.)

### Command inventory table

| Command | File | Source module | Interactive? |
|---|---|---|---|
| `/audit-gaps` | `audit-gaps.md` | commands | Yes |
| `/background-review` | `background-review.md` | commands | No |
| `/bias-check` | `bias-check.md` | commands | Minimal |
| `/capture` | `capture.md` | commands | Yes |
| `/connections` | `connections.md` | commands | Yes |
| `/contrarian` | `contrarian.md` | commands | No |
| `/distill` | `distill.md` | commands | Yes |
| `/doc-release` | `doc-release.md` | commands | Yes |
| `/dump` | `dump.md` | commands | Minimal |
| `/end` | `end.md` | commands | Yes |
| `/health` | `health.md` | commands (or scripts-offload override) | Yes |
| `/link-check` | `link-check.md` | commands (or scripts-offload override) | No |
| `/model-review` | `model-review.md` | commands | No |
| `/person` | `person.md` | commands | Yes |
| `/post-meeting` | `post-meeting.md` | commands | No |
| `/process` | `process.md` | commands | Yes |
| `/recall` | `recall.md` | commands | No |
| `/recap` | `recap.md` | commands | No |
| `/scan` | `scan.md` | commands | Yes |
| `/ship` | `ship.md` | commands | Yes |
| `/start` | `start.md` | commands | No |
| `/sync-all` | `sync-all.md` | commands | Yes |
| `/tree` | `tree.md` | commands | No |
| `/weekly` | `weekly.md` | commands | Yes |
| `/wiki-lint` | `wiki-lint.md` | commands | No |
| `/wiki-query` | `wiki-query.md` | commands | Yes |
| `/analytics` | `analytics.md` | analytics | No |

---

## Tools

Python scripts living outside modules that are used by the framework directly.

| Path | Purpose | Used by |
|---|---|---|
| `tools/session_index.py` | Indexes `~/.claude/projects/**/*.jsonl` into SQLite FTS5 for cross-session search | `/recall` command |
| `tools/token_analysis.py` | Analyzes token usage across recent sessions, generates cost report | `/weekly` (Token Economy section) |
| `tools/arcana-integrity.py` | Drift detector: compares filesystem against this document, flags inventory/count/path/version mismatches | CI (`.github/workflows/integrity.yml`), release checklist, local pre-PR |

Plus the 9 scripts inside `modules/scripts-offload/tools/` (see § Modules, `scripts-offload`).

---

## Note templates

19 Templater-compatible templates in `modules/vault-structure/templates/`:

| Template | Use case |
|---|---|
| `Daily.md` | Daily journal with log format |
| `Meeting.md` | Meeting notes with action items |
| `Project.md` | Project note |
| `Person.md` | Contact/person note |
| `Partnership.md` | Partnership CRM note |
| `Event.md` | Speaking events and conferences |
| `Article-Draft.md` | Long-form article drafts |
| `Social-Post.md` | Social media post drafts |
| `Decision-Record.md` | Decision records |
| `Dev-Log.md` | Development session logs |
| `Error-Solution.md` | Bug/error solutions |
| `Hub-Note.md` | Hub pages with Dataview queries |
| `Knowledge-Note.md` | Technical concept notes |
| `MOC.md` | Map of Content |
| `Project-Index.md` | Project index with Dataview |
| `Toolbox-Note.md` | Tool/library reference notes |
| `ConflictReport.md` | Divergence tracking (used by anti-sycophancy) |
| `Inbox-Item.md` | Raw staging |
| `WIP.md` | Session-continuity WIP hub |

All templates declare frontmatter with `type`, `domain`, `tags`, `status`, `created`, and `summary`. `Knowledge-Note.md` also carries `reviewed: false` (validation gate, added in v1.8.0).

---

## Event chains

How the pieces fit together at runtime. Only chains that involve multiple components are listed; trivial single-hook events are omitted.

### A. Session start

```
SessionStart (startup|resume)
├── session-scan.sh (core): report recent activity
├── read-alerts.sh (core): surface alerts from 00-Dashboard/alerts.md
└── update-check.sh (core): compare installed version vs latest Arcana release
```

None of the three emit content by default. They exit with stdout if there is something to report (fresh files, unread alerts, pending update). Boot-time cost: low, in line with TE-4.

### B. First user turn (session title capture)

```
UserPromptSubmit (first prompt of session)
└── session-title.sh (core): extract first N chars, write to session metadata
```

Also: `turn-boundary-check.sh` (enforcement-hooks) fires on every UserPromptSubmit (not just the first) and checks the iteration state file to decide whether to emit a `/background-review` nudge.

### C. Agent edits a vault note

```
PreToolUse (Write|Edit on .md in vault)
├── enforce-daily-note.sh: block if today's DN missing
├── validate-frontmatter.sh: warn if YAML frontmatter missing (Write only)
├── memory-injection-scan.sh: block injection patterns (memory files only)
├── guard-people.sh: warn to source claims (70-People/ only)
└── prefetch-context.sh: inject domain context (if path matches domain mapping)

<tool executes>

PostToolUse (Write|Edit)
├── iteration-counter.sh: increment state counter (wildcard matcher)
├── validate-write.sh: check frontmatter, wikilinks, domain tags, dashes
└── cascade-check.sh: remind to grep for old values (Edit on high-risk folders)
```

Stop event (end of turn):

```
Stop
└── stop-check-dn.sh: warn if DN has no timestamped log entries today
```

### D. Pre-compaction memory sweep

```
PreCompact (context about to compress)
└── memory-nudge.sh: remind to persist key learnings before context is lost
```

### E. Scheduled task run (morning-briefing example)

```
Cron-triggered scheduled task (via mcp__scheduled-tasks__create_scheduled_task)
├── Task prompt loaded from modules/scheduled-tasks/examples/morning-briefing.md
├── Reads: connected sources (Teams, Gmail, Calendar, Read.AI, Notion)
├── Writes: Daily Note with priorities, alerts.md if urgent
└── Logs: [scheduled] prefix on each entry
```

### F. `/end` command flow

```
User types /end
└── Load end.md prompt as next-turn system context
    ├── Step 1: collect today's work from Daily Note
    ├── Step 2: capture decisions (decision-records in domain folders)
    ├── Step 3: process unprocessed meetings (calls /post-meeting logic)
    ├── Step 4: update Estado Atual (mandatory)
    ├── Step 5: prepare tomorrow's tasks (Notion)
    └── Exit: stop-check-dn.sh validates DN was updated
```

### G. `/recall` cross-session search

```
User types /recall <keyword>
└── recall.md prompt loaded
    ├── Calls tools/session_index.py --search <keyword>
    ├── SQLite FTS5 index searched, returns ranked session matches
    ├── For each match, reads relevant JSONL slice via offset
    └── Synthesizes findings
```

---

## File ownership

Who writes where. `setup.sh` creates these, `uninstall.sh` removes these, the user owns everything else.

### Installed by Open Arcana

| Location | What lives here | Owned by |
|---|---|---|
| `.claude/rules/` | Rule markdown files | Modules + core |
| `.claude/hooks/` | Shell hook scripts | Modules + core |
| `.claude/commands/` | Slash command prompts | Modules + core |
| `.claude/tools/` | Python/shell tools | Modules (scripts-offload mostly) |
| `.claude/scheduled-tasks/` | Scheduled task example templates | `scheduled-tasks` module |
| `.claude/settings.local.json` | Hook wiring JSON | `setup.sh` (merged) |
| `.claude/arcana.config.yaml` | Active module list + profile | `setup.sh` (generated) |
| `.claude/packages/*/package.yaml` | Community package manifests | `setup.sh --install-package` |
| `CLAUDE.md` | Master config, vault root | `core/CLAUDE.md.template` |
| `00-Dashboard/concept-index.md` | Layer 1 retrieval index | `retrieval-system` dashboard templates |
| `00-Dashboard/aliases.md` | Alias normalization | Same |
| `00-Dashboard/hot-cache.md` | Boot cache | Same |
| `00-Dashboard/dashboard.html` | Analytics dashboard | `analytics` module |
| `80-Templates/*.md` | Note templates | `vault-structure` module |
| `.vault-test.sh` | Vault health test suite | `vault-health` module |

### Not touched by Open Arcana

- User's notes in any folder outside `80-Templates/` and `00-Dashboard/`
- Daily Notes (the enforce-daily-note hook CHECKS them but does not create or edit)
- Memory files under `~/.claude/projects/<slug>/memory/` (only scaffold is installed once; user content is untouched)
- Anything outside the user's vault

### Writer conflicts

Files with multiple potential writers (risk of race conditions):

- `.claude/settings.local.json`: `setup.sh` on install/update, user manually, some hooks (NONE currently). Safe.
- `00-Dashboard/alerts.md`: `read-alerts.sh` (reads only), `alert.sh` utility (writes), scheduled tasks (write), user (edit/archive). Convention: append-only writes, alerts go to "Unread" section, user moves to "Archive" manually.
- Daily Notes: user, agent (logs), scheduled tasks (log with `[scheduled]` prefix), commands (append). Convention: everyone appends with a timestamp and domain tag; nobody overwrites prior content.

---

## Template variables

Installed file paths and hooks are templated at install time. `setup.sh` runs `process_template` on each file, replacing `{{VARIABLE}}` with the user's configured value.

| Variable | Example | Source |
|---|---|---|
| `{{USER_NAME}}` | `Jane Smith` | Setup wizard (profile step) |
| `{{USER_ROLE}}` | `Senior Engineer` | Setup wizard |
| `{{USER_LANG}}` | `en` | Setup wizard |
| `{{VAULT_PATH}}` | `/Users/jane/Obsidian/Vault` | Setup wizard |
| `{{MEMORY_DIR}}` | `-Users-jane-Obsidian-Vault` | Derived from vault path slug |
| `{{NOTION_DB_ID}}` | `abc123def456` | Setup wizard (integrations step, optional) |
| `{{USER_EMAIL}}` | `jane@example.com` | Setup wizard (optional) |
| `{{COMPANY}}` | `Acme Corp` | Setup wizard (optional) |
| `{{PRIMARY_DOMAIN}}` | `work` | Setup wizard |
| `{{DOMAINS}}` | `work,personal,research` | Setup wizard |
| `{{MS_GRAPH_PATH}}` | `/path/to/ms-graph-mcp` | Setup wizard (optional) |
| `{{TEAMS_CHAT_ID}}` | `team-xyz` | Setup wizard (optional) |
| `{{TODAY}}` | `2026-04-17` | Runtime substitution in `modules/vault-structure/scaffold.sh` (not install-time) |

All values are persisted to `.claude/arcana.config.yaml`. The `--update` flag reads this file and reinstalls without re-prompting.

Community packages have access to the same variable set at install time (see `docs/packages.md`).

---

## Integrity checks (drift detection)

The `tools/arcana-integrity.py` script walks the repository and compares filesystem reality against this document. It is run:

- Locally: `python3 tools/arcana-integrity.py` (human output) or `--json` (CI output)
- In CI: `.github/workflows/integrity.yml` on every push and PR
- Before every release: part of the release checklist in `CONTRIBUTING.md`

### What it checks

1. **Inventory drift**: file counts in § Repository layout match the filesystem
2. **Hook inventory**: every `*.sh` under `core/hooks/` and `modules/*/hooks/` appears in § Hooks
3. **Command inventory**: every `*.md` under `modules/commands/commands/` appears in § Slash commands
4. **Rule count drift**: headings matching `^(AS|TE|CT|CSR)-\d+` in each rule file match the counts claimed in this document and in the module README
5. **Orphan files**: any hook, rule, command, or tool not listed here is flagged
6. **Broken references**: any path referenced in this document that does not exist is flagged
7. **Version parity**: `setup.sh`'s `VERSION=` matches the latest `## [X.Y.Z]` heading in `CHANGELOG.md`
8. **Git tag drift**: every minor/major version in `CHANGELOG.md` has a matching `git tag`
9. **Template variable usage**: `{{VAR}}` tokens in hooks/commands correspond to variables listed in § Template variables
10. **Module dependency**: `examples/<preset>/` module lists reference modules that exist

Severity levels: `ERROR` (blocks merge in CI), `WARN` (flagged but not blocking), `INFO` (advisory).

### Running locally

```bash
# Human-readable output (default)
python3 tools/arcana-integrity.py

# Machine-readable output (for CI or scripts)
python3 tools/arcana-integrity.py --json

# Regenerate just the inventory counts (no drift check)
python3 tools/arcana-integrity.py --inventory
```

Exit code: `0` if no ERRORs, `1` if any ERROR, `2` if only WARNs.

---

## Examples and presets

`examples/` ships 4 preset configurations:

| Preset | Directory | Modules activated |
|---|---|---|
| `minimal` | `examples/minimal/` | Core only |
| `writer` | `examples/writer/` | Core + vault-structure + commands + retrieval-system |
| `full` | `examples/full/` | Core + all 13 modules |
| `package` | `examples/package/` | Template skeleton for a community package |

Used by `./setup.sh --preset <name>` to skip the interactive wizard. Each preset directory contains a pre-filled `arcana.config.yaml` template.

---

## Community packages

Third-party extensions install from git repos or local directories via `./setup.sh --install-package`. Full spec in `docs/packages.md`. Packages ship an `arcana-package.yaml` manifest that declares name, version, provides (rules/hooks/commands/templates/tools), and requires (Open Arcana version + module dependencies).

Packages are tracked in `.claude/packages/<name>/package.yaml` and listed in `arcana.config.yaml` under the `packages:` key. `./setup.sh --list-packages` and `--uninstall-package <name>` provide the management surface.

Community packages have the same template variable access as built-in modules.

---

## Release process

1. Implement the change on a feature branch. Update `CHANGELOG.md` under `## [Unreleased]`.
2. Run `python3 tools/arcana-integrity.py` locally. Fix any ERRORs.
3. Update this document if any inventory count changed, any hook was added/removed, any rule count changed, or any semantic behavior changed.
4. Open a PR. The CI integrity check runs automatically (`.github/workflows/integrity.yml`).
5. Merge to `main` after review. 
6. Bump `VERSION=` in `setup.sh` to match the planned release.
7. Move `## [Unreleased]` in `CHANGELOG.md` to `## [X.Y.Z] - YYYY-MM-DD -- <title>`.
8. `git tag vX.Y.Z && git push --tags`
9. Create a GitHub release pointing at the tag.

`CONTRIBUTING.md` (at repo root) documents the PR checklist that enforces steps 1-4 for every contributor.

---

## Changelog (of this document)

Every structural edit to `ARCHITECTURE.md` records a line here. Format: `YYYY-MM-DD — <summary> (commit `<short-sha>`)`.

- 2026-04-17 — Initial master doc. Migrated from `docs/architecture.md` (high-level) to root-level canonical ARCHITECTURE.md with full inventory, governance, drift prevention, and integrity check spec.
