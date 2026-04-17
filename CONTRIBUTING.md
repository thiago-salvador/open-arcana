# Contributing to Open Arcana

Thanks for considering a contribution. This document covers the contribution process, coding standards, and the governance protocol that keeps the repository and `ARCHITECTURE.md` in sync.

## Table of contents

- [Before you start](#before-you-start)
- [Development setup](#development-setup)
- [Making a change](#making-a-change)
- [PR checklist](#pr-checklist)
- [Architecture discipline](#architecture-discipline)
- [CHANGELOG protocol](#changelog-protocol)
- [Release process](#release-process)
- [Community packages](#community-packages)
- [Code style](#code-style)

---

## Before you start

- Read [`ARCHITECTURE.md`](./ARCHITECTURE.md) at the repo root. It is the canonical description of every module, hook, rule, command, template, and tool that Open Arcana ships. If you are adding, removing, or changing any of those, the doc will need an update.
- Skim [`CHANGELOG.md`](./CHANGELOG.md) to get a sense of how past changes were documented. Follow the same format.
- For bug reports or feature requests, open a GitHub issue first. For small fixes (typos, one-line bug fixes), a PR without an issue is fine.

## Development setup

```bash
git clone https://github.com/thiago-salvador/open-arcana.git
cd open-arcana

# Verify you can run the integrity check locally
python3 tools/arcana-integrity.py

# Test install into a scratch vault
mkdir -p /tmp/arcana-test-vault
./setup.sh --yes --preset minimal
# follow prompts, pointing at /tmp/arcana-test-vault
```

Requirements: Python 3.9+, bash 3.2+, `git`, optionally `jq` for some hooks.

## Making a change

1. Fork the repo and branch from `main` (`git checkout -b feature/my-change`).
2. Make your edit. Keep the change focused. If you find yourself touching files in unrelated modules, split the PR.
3. Run the integrity check: `python3 tools/arcana-integrity.py`. Fix any `ERROR`s before opening the PR.
4. Update `ARCHITECTURE.md` if your change moved any item tracked by the integrity check (see [Architecture discipline](#architecture-discipline) below).
5. Add an entry to `CHANGELOG.md` under `## [Unreleased]` (create the section if missing). Follow the format used for past entries.
6. Commit with a clear message. Conventional commits are appreciated but not required: `feat:`, `fix:`, `docs:`, `chore:`.
7. Push and open a PR against `main`. The CI integrity check runs automatically.

## PR checklist

Before requesting review, verify every item:

- [ ] `python3 tools/arcana-integrity.py` returns `All checks passed.` (or only expected WARNs)
- [ ] `ARCHITECTURE.md` reflects any file added, removed, or renamed under `core/`, `modules/`, or `tools/`
- [ ] `ARCHITECTURE.md` reflects any new rule added to an AS, TE, CT, or CSR numbered set
- [ ] `ARCHITECTURE.md` hook table updated if a hook's event or file changed
- [ ] `ARCHITECTURE.md` command table updated if a slash command was added or removed
- [ ] `ARCHITECTURE.md § Changelog` at the bottom records the structural edit with today's date
- [ ] `CHANGELOG.md` has an `## [Unreleased]` entry describing the user-facing change
- [ ] Any new file includes a brief header comment explaining its purpose
- [ ] Template variables (`{{VAR}}`) introduced are documented in `ARCHITECTURE.md § Template variables`
- [ ] If you added a hook: documented the wiring snippet in the module's `README.md`
- [ ] If you added a command: added a row to `modules/commands/README.md` and to `ARCHITECTURE.md § Slash commands`
- [ ] The integrity CI job passes (`.github/workflows/integrity.yml`)

---

## Architecture discipline

`ARCHITECTURE.md` is the single source of truth for how Open Arcana is wired together. Keeping it current is not optional. The drift-prevention system has three layers:

1. **Mechanical**: `tools/arcana-integrity.py` runs in CI on every push and PR. Drift that it can detect (missing files, count mismatches, broken path references, version parity) is caught automatically.
2. **Disciplinary**: this PR checklist. The mechanical layer cannot catch semantic drift (a rule's meaning changing without its count changing, a hook's behavior shifting without its filename changing). The checklist is how contributors and reviewers catch what the validator cannot.
3. **Documental**: `ARCHITECTURE.md § Changelog` records every structural edit with date and summary. A doc that changes silently is a doc that is drifting.

### When `ARCHITECTURE.md` must be updated

Any of these triggers an update:

- New or removed file under `core/rules/`, `core/hooks/`, `tools/`, `modules/*/hooks/`, `modules/*/rules/`, `modules/commands/commands/`, `modules/vault-structure/templates/`
- New or removed numbered rule (AS-N, TE-N, CT-N, CSR-N)
- Change to a hook's event binding (e.g., moving a hook from `PostToolUse` to `PreToolUse`)
- New module or removed module (directory under `modules/`)
- New top-level file (README, CHANGELOG, new doc)
- New template variable introduced (`{{VAR}}`)
- Change to the file ownership map (new destination under `.claude/` or the vault)
- Change to the module dependency graph

### When `ARCHITECTURE.md` does NOT need to be updated

- Fix typo in prose inside an existing rule or module README
- Add a test case or example to an existing script
- Update the wording of a warning message in a hook, without changing its trigger
- Bump a Python script's internal helper function name

If you are unsure, run the integrity check. If it does not complain, your edit probably does not need a doc update. If it complains about counts, paths, or version parity, the doc needs updating.

## CHANGELOG protocol

- Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
- Headings: `## [MAJOR.MINOR.PATCH] - YYYY-MM-DD -- <short title>`
- Section order inside each release: `### Added`, `### Changed`, `### Fixed`, `### Removed`, `### Architecture notes`
- Each entry should name the file it touches in backticks: `` `modules/anti-sycophancy/rules/anti-sycophancy.md` ``
- Write entries at the time of the change, not at release time. `## [Unreleased]` is the staging area.

## Release process

Maintainers follow this sequence for each release:

1. Verify `main` is green (CI passes, integrity check clean).
2. Review `## [Unreleased]` entries in `CHANGELOG.md`. Promote to `## [X.Y.Z] - YYYY-MM-DD -- <title>`.
3. Bump `VERSION=` in `setup.sh` to match. `tools/arcana-integrity.py` catches parity drift.
4. Update the module dependency count or module descriptions in `README.md` if they drifted.
5. Update `ARCHITECTURE.md § Changelog` at the bottom with a single line for this release.
6. Commit: `chore: release vX.Y.Z`. Tag: `git tag vX.Y.Z && git push --tags`.
7. Create a GitHub release pointing at the tag. Paste the CHANGELOG section as the release notes.

## Community packages

If you are building a package that extends Open Arcana, read [`docs/packages.md`](./docs/packages.md). Package PRs are welcome as examples in the `examples/package/` skeleton, but the package itself should live in its own repository.

## Code style

### Shell scripts

- Bash 3.2 compatible (macOS ships with 3.2). No associative arrays. No `[[` extensions unless you also test on 3.2.
- `set -e` at the top, plus `set -u` if the script has zero dynamic variable creation.
- Use `"${VAR:-default}"` for optional env vars with defaults.
- Quote all path expansions: `"$VAULT_PATH"`, never `$VAULT_PATH`.
- Hooks should exit with `{"decision":"approve"}` / `{"decision":"block","reason":"..."}` JSON when blocking, plain stdout otherwise.

### Python

- Stdlib only, unless a clear reason requires a dependency. None of the shipped tools import third-party packages.
- `python3` shebang: `#!/usr/bin/env python3`.
- Type hints on function signatures, especially for scripts that process user data.
- Prefer `pathlib.Path` over `os.path`.
- For scripts that modify files: atomic write (temp + rename), default to dry-run, expose `--apply` to commit.

### Markdown

- `.md` files in `modules/*/rules/` are loaded as system prompts by Claude Code. Treat them as code, not documentation: wording changes change behavior.
- Tables everywhere. Claude parses tables well and reads them efficiently.
- Avoid em-dashes (`—`) and en-dashes (`–`) in body text. The `validate-write.sh` hook (enforcement-hooks module) enforces this opinion in installed vaults; we follow the same convention in the repo itself for consistency.
- Headings in rule files should follow the numbered convention: `### AS-1: Confidence tags` so the integrity check can count them.

### Commit messages

Conventional commit prefixes are welcome but not required:

- `feat:` new feature
- `fix:` bug fix
- `docs:` documentation only
- `chore:` tooling, CI, repo hygiene
- `refactor:` code structure, no behavior change
- `test:` test additions or fixes

Keep the subject line under 72 chars. Put the details in the body.

---

## Questions

Open a GitHub discussion or issue. If the answer applies to future contributors, consider submitting a PR to this file so the answer is durable.
