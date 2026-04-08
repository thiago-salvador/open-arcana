# Definition of Done (mandatory, ALL projects)

NEVER declare "done", "complete", "implemented", "finished" or any variation without passing through ALL phases below. If 1 criterion fails, it is NOT done.

## Phase 1: BEFORE implementing (DoD Upfront)

Before writing the first line of code or making the first edit:

1. **Define explicit acceptance criteria** for the task. What needs to work? What must not break?
2. **For each criterion, define the test** that will validate it. Test = command, check, or automated verification. Not "I'll look and see if it's ok."
3. **Present the DoD table to the user** in the format below. Get confirmation or adjustments BEFORE implementing.
4. **If any criterion is ambiguous:** ASK. Do not assume. Do not invent.

### DoD table format

```
### DoD: [task name]

| # | Criterion | Test | Status |
|---|-----------|------|--------|
| 1 | [what needs to work] | [how I will test] | - |
| 2 | ... | ... | - |

**Threshold: 100% PASS required**
```

## Phase 2: DURING implementation

1. Implement the changes
2. Stay aware of which criteria are being affected
3. If during implementation you realize a criterion is missing from the table, ADD it (do not ignore)

## Phase 3: BEFORE declaring Done (Validation)

1. **Run EACH test** from the DoD table, one by one
2. **Record actual result:** PASS or FAIL with evidence (command output, file content, build result)
3. **If FAIL:** fix, re-test, record new result. Loop until PASS.
4. **If a test could not be automated:** explain why and request explicit user confirmation
5. **Present final table** with all results
6. **Only declare Done when:** 100% PASS, no exceptions

### Final table format

```
### DoD: [task name] — Validation

| # | Criterion | Test | Status | Evidence |
|---|-----------|------|--------|----------|
| 1 | ... | ... | PASS | [output/grep/read that proves it] |
| 2 | ... | ... | PASS | [same] |

**Result: X/X PASS (100%)** → Done
```

## Test matrix by change type

| Type | Minimum tests |
|------|--------------|
| **New/edited code** | Build passes (`tsc --noEmit` or equiv), lint clean, unit tests pass, functionality verified |
| **UI/Frontend** | Renders without error, responsive (mobile/desktop), basic contrast/accessibility, visual match with reference |
| **API/Backend** | Endpoint responds, status codes correct, error handling works, returned data correct |
| **Config/Env** | Config loads without error, behavior changes as expected (execute, don't just read) |
| **Bug fix** | Original bug reproduced, fix applied, bug no longer reproduces, regression tested |
| **Refactor** | Identical behavior before/after, existing tests pass, no broken imports |
| **File created/edited** | Exists, correct content (grep/read), valid formatting |
| **Vault ops** | Valid frontmatter, wikilinks work, index updated, did not break existing notes |
| **Scheduled task** | Correct paths, tools exist, coherent prompt, fallbacks defined |
| **Command/Skill** | Correct description, functional content, valid paths, accessible dependencies |

## When to ASK (do not assume)

- Ambiguous acceptance criteria ("should look good" = ask what that means)
- Trade-off between criteria (performance vs readability, for example)
- Test impossible to automate (requires visual input, for example)
- Feature that changes existing behavior (confirm impact is acceptable)
- Uncertain whether an edge case matters
- Scope creep detected (implementation grew larger than planned)

## Anti-patterns (PROHIBITED)

- **"Tool said success"** is NOT validation. Verify the actual result with read/grep/exec.
- **"It's done, I'll test later"** does NOT exist. Test before declaring.
- **"It's simple, doesn't need DoD"** EVERY change needs it. Simple = table with 2-3 items. Not overhead.
- **"Works for me"** is NOT enough. Test the base case AND at least 1 edge case.
- **"I only changed one line"** Grep for what changed across all consumers. Cascade check.
- **Testing only happy path.** Include at least 1 error/edge case.
- **Declaring 90% done.** Either it's 100% or it's not done. No "almost ready."
- **Copying success response without evidence.** Show the actual output.
