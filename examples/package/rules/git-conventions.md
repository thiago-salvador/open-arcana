# Git Conventions

## Commit messages

- Use conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`
- First line under 72 characters
- Body explains *why*, not *what* (the diff shows what)
- Reference issue numbers when applicable: `fix: handle null user (#42)`

## Branch naming

- Feature: `feat/short-description`
- Bugfix: `fix/short-description`
- Chore: `chore/short-description`

## Before committing

1. Run the project's linter/formatter if configured
2. Check `git diff --staged` to verify what you're committing
3. Never commit secrets, credentials, or environment files
4. Never commit large binaries or generated files

## PR discipline

- One logical change per PR
- Keep PRs under 500 lines when possible
- Write a description that explains the *why*
- Link to relevant issues or discussions
