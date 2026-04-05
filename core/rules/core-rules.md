---
description: "12 operational rules for the agent. Anti-sycophancy (AS-1 to AS-6): see anti-sycophancy.md (not duplicated here)."
---

# Core Rules (12)

1. **Log before responding.** Action -> Daily Note -> response. Never accumulate.
2. **Daily Note is an index.** Permanent info goes to specific notes (person, project, meeting). DN gets the link.
3. **Never infer data about people.** If you don't know, leave blank or mark "not confirmed."
4. **Validate timestamps.** Never guess the day of the week. Calculate. >24:00 = next day.
5. **Large files: 3 passes.** Grep headers (inventory) -> read all -> synthesize. Never "here's everything" without confirming.
6. **Cascade check after editing facts.** Grep for the old value, update ALL locations.
7. **Qualify uncertainty.** "Confirmed" vs "from log" vs "inferred" vs "unknown."
8. **Memories >7 days about transient states: verify before acting.**
9. **Cross-reference sources.** Never say "not found" based on a single source.
10. **Installing a tool = vault work.** Trigger the 7-item routing checklist.
11. **When modifying the system (hooks, rules, MCPs): reconcile the whole system, not just the items touched.**

## Anti-sycophancy

Not repeated here (avoids token duplication when `anti-sycophancy.md` is loaded). Full text: **`anti-sycophancy.md`** (AS-1 to AS-6).

## Decision Records (compact format)

When the user makes a decision ("go with X", "cancel Y", "approve Z"):
```
> [!decision] {Title}
> **When:** YYYY-MM-DD | **Who:** {participants}
> **Decision:** {what} | **Impact:** {who acts, what changes}
> **Outcome:** pending | success | partial | failed | revised
```
Save in the domain folder, link from Daily Note. Update `outcome` when result is known.

## Pre-Delivery (5 checks before ANY output)

1. No em-dashes/en-dashes, no AI filler words?
2. Data about people confirmed (not inferred)?
3. Frontmatter YAML complete + wikilinks?
4. Daily Note logged?
5. Output matches the user's requested format and language?
