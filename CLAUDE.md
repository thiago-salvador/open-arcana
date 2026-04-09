# open-arcana

Python analytics module for AI session data.

## Project-specific overrides

- `design-protocol.md` global rule is NOT relevant here (no frontend). Ignore it.
- Notion/vault workflow sections in global CLAUDE.md are not needed during dev sessions. Focus on code.
- `reference_connected_sources.md` lives in the Obsidian Personal project memory, not here.

## Stack

- Python 3.11+
- No frontend

## Dev workflow

- Build check: `python -m py_compile` on changed files
- Lint: `ruff check` if available
- Tests: `pytest` if test files exist
