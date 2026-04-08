# Community Packages

Open Arcana supports community packages: third-party modules that extend your vault with rules, hooks, commands, templates, and tools. Packages can be installed from git repositories or local directories.

## Package Manifest

Every package requires an `arcana-package.yaml` file at its root. This is the manifest that tells Open Arcana what the package provides and what it needs.

```yaml
name: "my-module"
version: "1.0.0"
description: "What this module does"
author: "Author Name"
homepage: "https://github.com/author/repo"
license: "MIT"

# What Open Arcana version is required
requires:
  open-arcana: ">=1.0.0"
  # Optional: built-in modules this depends on
  modules: []

# What this package provides (all optional)
provides:
  rules: []       # .md files -> .claude/rules/
  hooks: []       # .sh files -> .claude/hooks/
  commands: []    # .md files -> .claude/commands/
  templates: []   # .md files -> 80-Templates/
  tools: []       # .py/.sh scripts -> .claude/tools/
```

### Required fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Unique package identifier. Lowercase, hyphens allowed. No spaces. |
| `version` | string | Semantic version (MAJOR.MINOR.PATCH) |
| `description` | string | One-line summary of what the package does |
| `author` | string | Author name or handle |

### Optional fields

| Field | Type | Description |
|-------|------|-------------|
| `homepage` | string | URL to the package source or docs |
| `license` | string | SPDX license identifier |
| `requires.open-arcana` | string | Version constraint (see below) |
| `requires.modules` | list | Built-in modules that must be active |
| `provides.*` | list | Files the package installs (see below) |

## Directory Convention

```
my-package/
├── arcana-package.yaml   # Required manifest
├── rules/                # Optional: .md files
├── hooks/                # Optional: .sh files
├── commands/             # Optional: .md files
├── templates/            # Optional: .md files
└── tools/                # Optional: .py or .sh scripts
```

Only directories listed in `provides` are installed. If a directory exists but is not listed in the manifest, it is ignored.

If `provides` lists are empty or omitted, all files in the corresponding directories are installed. For example, if `provides.rules` is `[]` (empty list) and a `rules/` directory exists, all `.md` files in `rules/` are installed.

## Installation

### From a git repository

```bash
./setup.sh --install-package https://github.com/author/arcana-git-workflow.git
```

The installer clones the repo to a temporary directory, validates the manifest, installs files, and cleans up the clone.

### From a local directory

```bash
./setup.sh --install-package /path/to/my-package
```

Useful for developing packages locally before publishing.

### What happens during install

1. **Validation**: Checks that `arcana-package.yaml` exists and contains the required fields (name, version, description, author).
2. **Version check**: Compares `requires.open-arcana` against the running Open Arcana version. Rejects if incompatible.
3. **Module dependency check**: If `requires.modules` is specified, verifies that each listed module is active in `arcana.config.yaml`.
4. **File installation**: Copies files to their target locations:
   - `rules/*.md` to `.claude/rules/`
   - `hooks/*.sh` to `.claude/hooks/` (made executable, template-processed)
   - `commands/*.md` to `.claude/commands/` (template-processed)
   - `templates/*.md` to `80-Templates/`
   - `tools/*` to `.claude/tools/` (made executable)
5. **Registry**: Copies the manifest to `.claude/packages/<name>/package.yaml` with the install date appended.
6. **Config update**: Adds the package to the `packages:` section of `arcana.config.yaml`.

### Template variables in packages

Package files (hooks, commands) are processed through the same template engine as built-in modules. These variables are available:

| Variable | Example value |
|----------|--------------|
| `{{VAULT_PATH}}` | `/Users/you/Documents/Obsidian/Personal` |
| `{{MEMORY_DIR}}` | `/Users/you/.claude/projects/-Users-you-Documents-Obsidian-Personal/memory` |
| `{{USER_NAME}}` | `Jane Smith` |
| `{{USER_ROLE}}` | `Senior Engineer` |
| `{{USER_LANG}}` | `en` |
| `{{USER_EMAIL}}` | `jane@example.com` |
| `{{NOTION_DB_ID}}` | `abc123def456` |
| `{{PRIMARY_DOMAIN}}` | `work` |
| `{{COMPANY}}` | `Acme Corp` |
| `{{DOMAINS}}` | `work,personal,research` |

Use `{{VARIABLE}}` in your `.sh` or `.md` files and they will be replaced at install time.

## Uninstallation

```bash
./setup.sh --uninstall-package my-module
```

The uninstaller:

1. Reads `.claude/packages/<name>/package.yaml` to find which files were installed.
2. Removes each installed file from its target location.
3. Deletes `.claude/packages/<name>/`.
4. Removes the package entry from `arcana.config.yaml`.

Files that were modified after installation are still removed. Open Arcana does not track file checksums.

## Listing installed packages

```bash
./setup.sh --list-packages
```

Shows name, version, and description for each installed package.

## Conflict Resolution

If a package file conflicts with an existing file (same filename already exists in the target directory):

- **Rules, templates, tools**: The package file **overwrites** the existing file. A warning is printed.
- **Hooks, commands**: The package file **overwrites** the existing file. A warning is printed.

To avoid conflicts, package authors should use distinctive file names. Prefix your files with the package name: `git-workflow-pre-commit.sh` rather than `pre-commit.sh`.

If a package conflicts with a built-in module file, the package file takes precedence. Uninstalling the package restores the original only if you re-run `./setup.sh --update`.

## Version Constraints

The `requires.open-arcana` field supports three constraint formats:

| Format | Example | Meaning |
|--------|---------|---------|
| Exact | `"1.0.0"` | Must be exactly version 1.0.0 |
| Minimum | `">=1.0.0"` | Must be 1.0.0 or higher |
| Compatible | `"~=1.0"` | Must be >=1.0.0 and <2.0.0 (same major) |

Version comparison uses semantic versioning. Only the numeric parts (MAJOR.MINOR.PATCH) are compared. Pre-release tags are not supported.

If `requires.open-arcana` is omitted, the package is treated as compatible with any version.

## Publishing a Package

Publishing is simple: push your package directory to a git repository.

1. Create your package directory following the convention above.
2. Write your `arcana-package.yaml` with accurate metadata.
3. Push to GitHub, GitLab, or any git host.
4. Share the clone URL. Users install with:
   ```bash
   ./setup.sh --install-package https://github.com/you/arcana-my-package.git
   ```

There is no central registry. Discovery happens through GitHub topics, READMEs, and community sharing. Consider tagging your repo with `open-arcana-package` for discoverability.

### Checklist for package authors

- [ ] `arcana-package.yaml` has all required fields
- [ ] `requires.open-arcana` is set to the minimum version you tested with
- [ ] File names are prefixed to avoid conflicts (e.g., `mypackage-myrule.md`)
- [ ] Template variables (`{{VAULT_PATH}}` etc.) are used instead of hardcoded paths
- [ ] Hooks are written for bash 3.2 compatibility (no associative arrays, no `[[` extensions)
- [ ] A README.md explains what the package does and how to configure it

## Internal Storage

Installed packages are tracked in:

```
.claude/
├── packages/
│   ├── my-package/
│   │   └── package.yaml    # Copy of manifest + install metadata
│   └── another-package/
│       └── package.yaml
└── arcana.config.yaml      # packages: section lists all installed packages
```

The `arcana.config.yaml` packages section looks like:

```yaml
packages:
  my-package: "1.0.0"
  another-package: "2.1.0"
```
