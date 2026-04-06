# Changelog

All notable changes to Open Arcana are documented here. Format based on [Keep a Changelog](https://keepachangelog.com/).

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
