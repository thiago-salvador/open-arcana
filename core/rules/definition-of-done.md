# Definition of Done (mandatory)

NEVER mark a task as Done without validation. Applies to EVERY task, in ANY project.

## Process

1. **Before starting:** define explicit DoD criteria for the task
2. **Before marking Done:** run automated tests that validate each criterion
3. **If a test fails:** fix and re-test. Do not mark as Done.

## Minimum required tests

| Change type | Test |
|-------------|------|
| File created/edited | Verify existence + expected content (grep/read) |
| Config change | Test that the config works (execute, don't just read) |
| Daily Note | Log entry present, current state correct, day of week correct |
| Scheduled task | Prompt contains correct paths, doesn't use nonexistent tools |
| Data displayed to user | Verify timezone, format, real values |
| Command/skill | Verify description, content, paths, dependencies |

## Anti-patterns

- "The tool said success" is NOT validation. Verify the actual result.
- Marking a phase as Done and "later" updating the Daily Note. DN first.
- Assuming data is in the right timezone. Verify explicitly.
- Copying files without checking if content needs adjustments (e.g., hardcoded paths).
