# Template Variables

Variables used in `.template` files. The setup wizard collects values and replaces `{{VARIABLE}}` placeholders at install time via sed.

## All variables

| Variable | Collected in | Default | Required |
|----------|-------------|---------|----------|
| `{{USER_NAME}}` | Step 1: Profile | git config user.name | Yes |
| `{{USER_ROLE}}` | Step 1: Profile | (none) | Yes |
| `{{USER_LANG}}` | Step 1: Profile | `en` | Yes |
| `{{VAULT_PATH}}` | Step 1: Profile | `~/Documents/Obsidian/Personal` | Yes |
| `{{MEMORY_DIR}}` | Auto-derived | (from VAULT_PATH) | Auto |
| `{{NOTION_DB_ID}}` | Step 2: Integrations | (skip) | No |
| `{{USER_EMAIL}}` | Step 2: Integrations | git config user.email | No |
| `{{COMPANY}}` | Step 2: Integrations | (skip) | No |
| `{{PRIMARY_DOMAIN}}` | Step 2: Integrations | `work` | Yes |
| `{{DOMAINS}}` | Step 2: Integrations | `work,personal` | Yes |

## How MEMORY_DIR is derived

Claude Code stores project memory in a directory named after the vault path with slashes replaced by dashes:

```
~/.claude/projects/-Users-yourname-Documents-Obsidian-YourVault/memory/
```

The setup wizard computes this automatically from `{{VAULT_PATH}}`.

## Where variables appear

### CLAUDE.md
Uses: USER_NAME, USER_ROLE, USER_LANG, VAULT_PATH, COMPANY, PRIMARY_DOMAIN, DOMAINS

### Hooks (.sh files)
Uses: VAULT_PATH, MEMORY_DIR

### Commands (.md files)
Uses: VAULT_PATH, MEMORY_DIR, NOTION_DB_ID, USER_LANG, PRIMARY_DOMAIN, DOMAINS

### Settings (settings.template.json)
Uses: VAULT_PATH

## Changing values after install

Option 1: Re-run `./setup.sh` (will back up and overwrite).

Option 2: Edit files directly. Search for the current value and replace it. The `arcana.config.yaml` file records what values were used during setup.

Option 3: For a single variable, use sed:
```bash
# Example: change vault path
find /path/to/vault/.claude -type f -exec sed -i '' 's|/old/path|/new/path|g' {} +
```
