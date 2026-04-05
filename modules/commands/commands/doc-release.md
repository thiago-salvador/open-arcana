---
name: doc-release
description: "Auto-updates project docs after code changes. Use after shipping code or when docs need updating. Scans project docs (README, ARCHITECTURE, CONTRIBUTING, CLAUDE.md) for drift against recent changes, fixes them, and syncs back to vault project notes. Accepts optional repo path argument."
argument-hint: "[repo-path]"
dependencies: "vault-read, gh CLI"
allowed-tools: "Read,Write,Edit,Glob,Grep,Bash"
---

# /doc-release

Updates project documentation after code changes. Syncs back to the vault.

## Flow

### 1. Detect context

If argument passed: use as repo path.
If not: detect automatically:
1. Check if `pwd` is a git repo (`git rev-parse --show-toplevel`)
2. If not, ask: "Which project do you want to update? List recent GitHub repos?"

Store:
- `REPO_ROOT`: absolute path of the repo
- `REPO_NAME`: repo name (basename or remote origin)
- `BASE_BRANCH`: main branch (`git symbolic-ref refs/remotes/origin/HEAD | sed 's|refs/remotes/origin/||'` or fallback main/master)

### 2. Identify recent changes

```bash
cd $REPO_ROOT
# Commits since last tag or last 7 days (whichever is fewer)
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null)
if [ -n "$LAST_TAG" ]; then
  DIFF_REF="$LAST_TAG"
else
  DIFF_REF="$(git log --since='7 days ago' --format='%H' | tail -1)"
fi
git diff --stat $DIFF_REF..HEAD
git log --oneline $DIFF_REF..HEAD
```

Analyze: which modules changed, which features were added/removed, which APIs changed.

### 3. Scan project docs

Search for all .md files in root and common folders:
- `README.md`
- `ARCHITECTURE.md`
- `CONTRIBUTING.md`
- `CLAUDE.md`
- `CHANGELOG.md`
- `docs/*.md`
- `.claude/commands/*.md` (if they exist)

For each doc found:
1. Read the content
2. Compare with the changes identified in step 2
3. Identify **drift**: mentions of functions/files/APIs that changed, outdated instructions, missing sections

### 4. Fix drift

For each doc with drift:
1. List the inconsistencies found
2. Make corrections (Edit, not Write, to preserve unchanged content)
3. If an entire section needs rewriting: show before/after and ask for confirmation

Rule: corrections must be **minimal and precise**. Do not rewrite the entire doc, only fix what diverged.

### 5. Sync with vault

Check if a corresponding note exists in your projects folder:

```bash
# Map repo -> vault note
grep -rl "$REPO_NAME" {{VAULT_PATH}}/15-Projects/ --include="*.md" | head -3
```

If a project note is found in the vault:
1. Check if the note reflects the current state (stack, features, status)
2. Update outdated fields in frontmatter or body
3. Add changelog entry if there were significant changes

If NOT found:
- Ask: "Project $REPO_NAME does not have a vault note. Create one?"
- If yes: create with standard template (frontmatter + stack + status + links)

### 6. Log in Daily Note

```
- HH:MM -- [dev] /doc-release $REPO_NAME: N docs updated, vault sync ([[project-note]])
```

### 7. Output

```
/doc-release -- $REPO_NAME

Changes analyzed: N commits since $DIFF_REF
Docs scanned: N
Drift found: N docs
  - README.md: [short description of what changed]
  - CLAUDE.md: [short description]
Vault sync: [[project-note]] updated

No action needed: [docs without drift]
```

## Rules
- Never rewrite entire docs, only fix drift
- Preserve the original author's voice and style
- If you find a large change requiring a decision: ask
- Always log in Daily Note
- Always sync with vault
