# Changelog

All notable changes to Open Arcana are documented here. Format based on [Keep a Changelog](https://keepachangelog.com/).

## [1.2.0] - 2026-04-10 -- Knowledge Compounding

Inspired by analysis of Karpathy's LLM Wiki pattern (gist 442a6bf5) and production experience showing that research outputs were being lost between sessions.

### Added
- **Auto-capture rule** (`core/rules/auto-capture.md`): after delivering substantial analysis (3+ sources, comparative tables, 500+ word synthesis), the agent proactively offers to save it as a vault note. Routes to correct domain folder automatically.
- **WIP hub** (`00-Dashboard/wip.md`): persistent work-in-progress state between sessions. Tracks active workstreams, blockers, next steps, and parking lot ideas. Different from Daily Notes (chronological log) and tasks (execution).
- **WIP template** (`modules/vault-structure/templates/WIP.md`): scaffold creates wip.md automatically in 00-Dashboard/

### Changed
- **Health score**: expanded from qualitative "X/10" to **weighted 0-100 score** with 7 components: Frontmatter (25), Index (20), MOC (15), Connections (15), Daily Notes (10), WIP (5), Memory (10). Classification: Excellent/Good/Needs attention/Critical.
- `/health`: updated output format with component breakdown table
- `/end`: added mandatory step 3.5 (update WIP with workstream state)
- `/start`: added step 3a (WIP check for session continuity, flag stale/blocked workstreams)
- `/weekly`: added Vault Health Score section (0-100 with breakdown) and WIP Status section; fixed duplicate step 5 numbering (now 5/6/7)
- `/sync-all`: health output updated from "score/10" to "N/100 -- classification"
- `vault-structure`: 18 -> 19 templates, scaffold.sh creates wip.md

## [1.1.1] - 2026-04-09 -- Project Hygiene

### Added
- **Project CLAUDE.md**: stack context (Python 3.11+, no frontend), dev workflow commands, and overrides that suppress irrelevant global rules (design-protocol, Notion workflows) during dev sessions
- `.gitignore` hardening: `Spec.md`, `docs/PRD-*.md`, `__pycache__/`, `*.pyc`, `.claude/`, `.playwright-mcp/`

### Fixed
- Internal artifacts (PRDs, Specs) were untracked but unprotected by `.gitignore`, one `git add .` away from accidental commit. Now explicitly ignored.

### Meta (not shipped in repo)
- Removed 2 broken global hooks (`validate-frontmatter.sh`, `memory-nudge.sh`) pointing to nonexistent scripts
- Wired `validate-write.sh` as PostToolUse hook for vault `.md` files (was on disk but disconnected)
- Wired `session-title.sh` as UserPromptSubmit hook (auto-names sessions by slash command or domain)
- Wired `prefetch-context.sh` as PreToolUse hook scoped to vault paths (surfaces concept-index per domain)
- Scoped `log-nudge.sh` and `index-check.sh` hooks to vault paths only (no longer fire on Python file saves)
- Archived `session-scan.sh` (replaced by `/scan` skill)
- Moved `design-protocol.md` from global auto-loaded rules to `~/.claude/references/` (saves ~801 tokens/session on non-frontend projects)
- Fixed `definition-of-done.md` false claim about `validate-write.sh` auto-enforcement
- Removed stale `reference_connected_sources.md` pointer from global CLAUDE.md

## [1.1.0] - 2026-04-08 -- Analytics Dashboard

### Added
- **New module: `analytics`** with 6 behavioral metrics computed from session JSONL data
- **Metrics:** HIR (Human Intervention Rate), Context Fill Rate, Frustration Index, Tool Call Precision, Skill/Command Frequency, Subagent Efficiency
- **Dashboard:** Single-file HTML with Tailwind + Alpine.js + Chart.js, dark/light theme, 5 tabs (Overview, Sessions, Cost, Commands, Context)
- **Command:** `/analytics` runs the engine and opens the dashboard
- **Zero new dependencies:** Pure Python engine, CDN-only frontend

### Changed
- setup.sh: added `analytics` to MODULE_KEYS, added `tools/` handler to `install_module()`
- README.md: added Analytics Dashboard row to modules table

## [1.0.6] - 2026-04-07

### Added
- **Session branching**: `session_index.py` now builds a message tree from `uuid`/`parentUuid` fields in Claude Code JSONL sessions. Detects branch points (multiple children for the same parent), computes tree depth, and labels each branch with the nearest human prompt. New fields in the index: `branch_count`, `max_depth`, `branch_points`. Markdown table now includes a "Branches" column.
- **`/tree` command**: Visualize any session's decision tree with ASCII art. Shows branch points, alternative paths, and conversation flow. Supports keyword search, session selection, and both branching (tree) and linear (timeline) display modes. Token budget: 2-5K per visualization.
- **Community packages**: Third-party modules can now be installed from git repos or local directories. New CLI flags: `--install-package <source>`, `--uninstall-package <name>`, `--list-packages`. Packages use an `arcana-package.yaml` manifest with version constraints, module dependencies, and file declarations. Full spec in `docs/packages.md`.
- **Steering messages documentation**: README now explains Claude Code's mid-execution steering (Shift+Tab) and how it interacts with Open Arcana's session tree, anti-sycophancy protocol, and session titles.
- Example community package: `examples/package/` with a "git-workflow" package (git conventions rule + `/git-review` command).

### Changed
- `core/rules/definition-of-done.md`: expanded from skeleton (3 rules + test table) to full 3-phase DoD process. Now requires: (1) DoD table upfront before implementation with explicit criteria + tests, presented to user for approval; (2) tracking during implementation; (3) validation with 100% PASS threshold, evidence per criterion, and structured final table. Added test matrix covering 10 change types (code, UI, API, config, bug fix, refactor, files, vault, scheduled tasks, commands). Added "when to ask" guidelines and 8 prohibited anti-patterns. Automatically distributed via `setup.sh --update` (glob copy since v1.0.4).
- setup.sh: ~1033 -> ~1609 lines. Added `install_package()`, `uninstall_package()`, `list_packages()` functions plus `version_gte()`, `check_version_constraint()` helpers. 3 new CLI flags, updated help text. `generate_config()` now includes installed packages.
- session_index.py: Added `build_message_tree()` and `_find_branch_label()` functions. Markdown output includes Branches column.
- README.md: 3 new sections (Session Branching, Steering Messages, Community Packages), updated command count (21 -> 22), updated flags list, updated Contributing section.
- Commands module: 22 commands (was 21)

## [1.0.5] - 2026-04-07

### Added
- **Session title hook**: `session-title.sh` (UserPromptSubmit hook) auto-sets descriptive session titles based on slash commands or domain keywords. Makes `--resume` show names like "Morning Kickoff", "Weekly Review", "Vault Ops" instead of generic session IDs. Requires Claude Code >= 2.1.94.
- TE-16: Effort level awareness. Default changed from medium to high in Claude Code 2.1.94. Documents when to suggest `/effort medium` (routine ops) vs keep high (complex reasoning).
- TE-17: MCP result size override awareness. Documents `_meta["anthropic/maxResultSizeChars"]` annotation (up to 500K) from Claude Code 2.1.91 and its context cost implications.

### Changed
- token-efficiency.md: expanded from 15 to 17 rules
- token-efficiency README: updated rule count and added TE-16, TE-17 descriptions
- settings.template.json: added UserPromptSubmit hook section with session-title.sh
- customization.md: documented UserPromptSubmit hooks, plugin skill hooks fix, `bin/` executables, `disableSkillShellExecution`, `keep-coding-instructions` frontmatter, and stable skill names via frontmatter `name` field
- README.md: updated token efficiency rule count from 14 to 17

## [1.0.4] - 2026-04-06

### Added
- **Auto-update system**: `update-check.sh` hook checks for updates once per day on session start (notification only, never auto-updates). `setup.sh --update` reinstalls from latest code while preserving user config (profile, modules, integrations). `arcana.config.yaml` now stores `source_dir` for the check.
- `/distill` command: extracts reusable workflows from the current session (5+ step sequences with coherent outcomes), classifies as command/rule/template candidates
- `/recall` command + `tools/session_index.py`: cross-session full-text search. Indexes all JSONL sessions into a grepable index, supports incremental updates. Zero dependencies beyond Python 3.
- `/model-review` command: proactive user model review that detects uncaptured preferences, stale memories, missing project records, and emerging workflow patterns
- `core/rules/auto-parallel.md`: automatic decomposition of multi-step requests into parallel agents. Includes agent type selection guide, token efficiency tips, anti-patterns, and soft cap of 8 subagents per session.
- `core/rules/definition-of-done.md`: mandatory validation before marking any task as Done. Minimum test matrix by change type, anti-patterns for false completion.
- User Model Review step (3.8) in `/weekly` command

### Changed
- setup.sh: core rules now copied via glob (picks up new rules automatically instead of hardcoding filenames)
- setup.sh: added `--update` flag and `read_existing_config()` function
- settings.template.json: wired `update-check.sh` into SessionStart hooks
- arcana.config.yaml: added `source_dir` field
- weekly.md: session index update wired into step 3.5 (runs before token analysis)
- weekly.md: added step 3.8 (User Model Review) and corresponding output section
- Commands README: updated to document 3 new commands (21 total)
- Main README: updated command count from 18 to 21

## [1.0.3] - 2026-04-06

### Added
- TE-15: Subagent budget per session (soft cap of 8 subagents, evaluate before exceeding)
- Session discipline rule: monitors tool call count, subagent accumulation, and task boundaries to suggest new sessions before auto-compact triggers
- Token Economy section in /weekly command: runs token_analysis.py and reports cost, top projects, daily trend, and optimization flags
- tools/token_analysis.py: standalone script that parses ~/.claude/projects/ JSONL files and generates a markdown cost report with per-project breakdown, costliest sessions, subagent analysis, and daily trends

### Changed
- token-efficiency.md: expanded from 14 to 15 rules
- weekly.md: section numbering updated (3.5 Token Economy, 3.6 Memory Health, 3.7 Contrarian)
- README.md for token-efficiency module: updated to document TE-15, session discipline, and token analysis script

## [1.0.2] - 2026-04-06

### Changed
- All remaining Portuguese content translated to English (anti-sycophancy.md, boot-protocol.md, token-efficiency.md, pessoas.md)
- Every user-facing file in the repo is now fully English

## [1.0.1] - 2026-04-06

### Changed
- core-rules.md: 12 rules reduced to 11 (personal context rules moved to memory files where they belong)
- core-rules.md: added rule 4b requiring real timestamps (no XX:XX placeholders)
- core-rules.md: added callout explaining that personal operational rules belong in memory files, not in agent rules
- CLAUDE.md.template: retrieval system section compacted to a single line referencing boot-protocol.md (was duplicating the full 4-layer system)
- CLAUDE.md.template: static commands table replaced with grouped categories (easier to maintain, less likely to go stale)
- CLAUDE.md.template: added "Rules" section with note to not duplicate rule content in CLAUDE.md

### Fixed
- setup.sh: replaced `eval` with `printf -v` in ask() and ask_yn() to prevent shell injection from user input
- setup.sh: added escape_sed() helper for safe handling of / | & \ characters in paths during template processing
- setup.sh: sanitize input by stripping backticks, $, quotes, and backslashes
- setup.sh: full bash 3.2 compatibility (removed associative arrays, removed local outside functions)
- memory-injection-scan.sh: fixed double-nesting of {{MEMORY_DIR}} variable
- ship.md: added explicit PII warning to review checklist

## [1.0.0] - 2026-04-05

### Added
- Initial release
- Interactive setup wizard with splash screen, progress bars, smart defaults, and presets (minimal, writer, full)
- 11 modules: anti-sycophancy, token-efficiency, enforcement-hooks, security-hooks, vault-structure, retrieval-system, commands, connected-sources, scheduled-tasks, vault-health
- Anti-Sycophancy Protocol (6 rules: confidence tags, challenge-previous, unanimity check, conflict reports, independent analysis, memory decay)
- Token Efficiency Rules (14 rules for context window management and cost control)
- 4 enforcement hooks (daily note, frontmatter validation, write validation, stop check)
- 4 security hooks (prompt injection scanner, cascade check, people data guard, memory nudge)
- Vault structure scaffold with 18 note templates
- Engram-inspired 4-layer retrieval system (concept index, filtered grep, semantic search, fallback)
- 18 slash commands for daily workflows
- Connected sources configuration templates for 16+ MCP data sources
- Scheduled tasks templates (morning briefing, end-of-day, weekly review)
- Vault health checks (500+ automated consistency tests)
- Uninstall script with backup restoration
- Full wiki documentation (20 pages)
- 3 example configurations (minimal, writer, full)
