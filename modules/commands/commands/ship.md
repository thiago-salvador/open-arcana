---
name: ship
description: "Full release pipeline: tests, review, commit, PR, deploy, doc-release. Use when the user wants the full pipeline from tested code to deployed PR. Integrates with vault: logs to Daily Note, creates release entry in project notes, triggers /doc-release. Accepts optional argument 'prod' for production deploy."
argument-hint: "[prod]"
dependencies: "vault-read, gh CLI"
allowed-tools: "Read,Write,Edit,Glob,Grep,Bash,Agent"
---

# /ship

Full pipeline: from tested code to deployed PR, with vault sync.

## Pre-requisite

Must be inside a git repo with changes to ship.

## Flow

### 0. Detect context

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$REPO_ROOT")
BRANCH=$(git branch --show-current)
BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo "main")
```

If on `main`/`master`: ask "You are on the main branch. Create a feature branch first?"

### 1. Run tests

Detect the project's test runner:
1. Check `package.json` scripts: `test`, `test:unit`, `test:integration`
2. Check `pytest.ini`, `setup.cfg`, `pyproject.toml` for Python
3. If none found: report "No test runner detected. Skip tests?"

If found: run and report result (pass/fail + summary).
If it fails: STOP. Report failures. Ask if the user wants to continue anyway.

### 2. Coverage check (if available)

If the project has coverage configured:
```bash
# Detect and run coverage
npm run test:coverage 2>/dev/null || npx jest --coverage 2>/dev/null || pytest --cov 2>/dev/null
```

Report: lines covered, % total, files with low coverage.

### 3. Quick review

Run an automatic review of the changes:
```bash
git diff $BASE..HEAD --stat
git diff $BASE..HEAD -- "*.ts" "*.tsx" "*.py" "*.js" "*.jsx" | head -500
```

Check:
- Sensitive files modified (.env, credentials, secrets)
- PII or vault data leaking into commits (personal names, Notion IDs, vault paths with real usernames)
- New TODOs or FIXMEs
- Forgotten console.logs or debuggers
- Unused imports

**Never include in a PR or commit:** files from .claude/ with real PII, arcana.config.yaml with filled-in values, or vault notes with personal data.

If critical issues found: report and ask if the user wants to fix before continuing.

### 4. Commit + Push

If there are uncommitted changes:
1. Show summarized diff
2. Create commit with descriptive message (match repo style, check `git log --oneline -5`)
3. Push to remote with `-u` if new branch

If already committed: just push if needed.

### 5. Create PR

Check if a PR already exists for the branch:
```bash
gh pr view --json number,title,url 2>/dev/null
```

If none exists: create PR via `gh pr create` with:
- Title based on commits
- Body with change summary + test results
- Labels if available

If already exists: report URL.

### 6. Doc release (automatic)

After PR is created, check if docs need updating:
- Analyze if doc files (.md in root, docs/) were affected by the changes
- If yes: run /doc-release logic inline (without invoking the separate command)
- If not: skip silently

### 7. Vault sync

Search for the project note in your vault:
```bash
grep -rl "$REPO_NAME" {{VAULT_PATH}}/15-Projects/ --include="*.md"
```

If found: add release entry to the note:
```markdown
### Release YYYY-MM-DD
- Branch: $BRANCH
- PR: [#N](url)
- Changes: [summary in 1-2 lines]
- Tests: pass/fail (N tests, X% coverage)
```

### 8. Deploy (if argument "prod")

If user passed `prod` as argument:
1. Check if project has Vercel: `vercel inspect 2>/dev/null`
2. If yes: `vercel --prod`
3. If not: check other deploy targets (package.json scripts: deploy, deploy:prod)
4. Report production URL

If `prod` not passed: report that PR was created and deploy will be automatic via CI (if configured).

### 9. Log in Daily Note

```
- HH:MM -- [dev] /ship $REPO_NAME: tests OK, PR #N created, vault sync ([[project-note]])
```

### 10. Output

```
/ship -- $REPO_NAME ($BRANCH)

Tests: [PASS/FAIL] (N tests, X% coverage)
Review: [N issues found / clean]
Commit: [hash] "[message]"
PR: github.com/user/repo/pull/N
Docs: [N updated / no drift]
Deploy: [URL / skipped -- pass 'prod' to deploy]
Vault: [[project-note]] updated
```

## Rules
- NEVER force push
- NEVER skip tests without confirmation
- If tests fail: STOP and report, do not create PR with failing tests
- Always log in Daily Note
- Always sync with vault if project note exists
