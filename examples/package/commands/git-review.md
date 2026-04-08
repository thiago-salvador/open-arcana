---
name: git-review
description: Review the current branch against main, checking for common issues
---

# Git Review

Review the current git branch against `main`. Check for:

1. **Commit hygiene**: Are commit messages descriptive? Are there WIP or fixup commits that should be squashed?
2. **Diff size**: Is this PR reasonably scoped? Flag if >500 lines changed.
3. **File patterns**: Any accidental commits (.env, node_modules, .DS_Store)?
4. **Breaking changes**: Any changes to public APIs, shared types, or config files?

## Steps

1. Run `git log main..HEAD --oneline` to see all commits on this branch.
2. Run `git diff main...HEAD --stat` to see the overall diff size.
3. Run `git diff main...HEAD` to read the actual changes.
4. Report findings in this format:

```
## Git Review: [branch-name]

**Commits**: N commits
**Files changed**: N files, +X/-Y lines

### Issues found
- [ ] Issue description

### Suggestions
- Suggestion description

### Verdict
LGTM / Needs work
```

Log the review in the Daily Note:
`- HH:MM — [git-review] **Reviewed branch [name].** N commits, N files. Verdict: X. [confidence: high, source: git]`
