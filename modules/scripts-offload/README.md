# Scripts Offload

Replaces ~100 tool calls per session with ~10 by offloading computation to Python scripts. The principle: **scripts for computation, Claude for cognition**.

## What's included

| Script | What it does | Flags |
|--------|-------------|-------|
| `_common.py` | Shared utilities (BOM, atomic write, vault validation, FM parsing) | -- |
| `vault_health.py` | Audit score 0-100 with penalty breakdown | `--verbose`, `--vault` |
| `vault_stats.py` | Stats by type/domain/status/tags + activity | `--vault` |
| `rebuild_indexes.py` | Regenerate index.md for all folders | `--apply`, `--vault` |
| `fix_frontmatter.py` | Add missing required FM fields | `--apply`, `--vault` |
| `auto_linker.py` | Add wikilinks to isolated notes | `--apply`, `--vault` |
| `broken_links.py` | Find [[links]] pointing to nonexistent notes | `--verbose`, `--vault` |
| `concept_index.py` | Generate concept-index.md grouped by domain | `--apply`, `--vault` |
| `stale_detector.py` | Find active notes unedited for N days | `--days N`, `--apply`, `--vault` |

## Commands

- `/health` -- Uses `vault_health.py` + `vault_stats.py` for instant health audit
- `/link-check` -- Uses `broken_links.py` + `auto_linker.py` for link analysis

## Configuration

All scripts auto-detect the vault path. Override with:

```bash
# Environment variable (highest priority)
VAULT_PATH=/path/to/vault python3 vault_health.py

# CLI argument
python3 vault_health.py --vault /path/to/vault
```

### Customization via env vars

| Variable | Purpose | Example |
|----------|---------|---------|
| `VAULT_PATH` | Vault root directory | `/Users/me/Obsidian/Vault` |
| `ARCANA_SKIP_DIRS` | Extra dirs to skip (comma-separated) | `Archive,Drafts` |
| `ARCANA_DOMAIN_MAP` | Folder-to-domain mapping | `10-Work=work,20-Research=research` |
| `ARCANA_MOC_MAP` | Folder-to-MOC mapping | `10-Work=Work MOC,60-Research=Research MOC` |

## Safety

- All `--apply` scripts use atomic writes (temp file + rename) to prevent data loss
- Dry-run is the default for every script that modifies files
- Read-only scripts (`vault_health`, `vault_stats`, `broken_links`) never write files
- BOM-safe: handles UTF-8 BOM in frontmatter without corruption
- Encoding-safe: uses `errors="replace"` for mixed-encoding files

## Token savings

Before scripts-offload, a typical `/health` run required:
- 8-12 Glob calls to find notes
- 15-25 Read calls for frontmatter checks
- 5-10 Grep calls for link detection
- Total: ~40-50 tool calls, ~15K tokens

After scripts-offload:
- 1 Bash call to run `vault_health.py`
- 1 Bash call to run `vault_stats.py`
- Total: 2 tool calls, ~2K tokens

~90% reduction in tool calls and ~85% reduction in retrieval tokens.
