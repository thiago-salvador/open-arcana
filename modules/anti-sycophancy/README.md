# Anti-Sycophancy Module

Prevents false consensus, disagreement collapse, and agreement without evidence across AI agent sessions.

## Core principle

Agreement without evidence is a failure. Grounded disagreement is more valuable than automatic consensus.

## The 6 AS Rules

### AS-1: Confidence tags

Every log entry must include a confidence qualifier: `high`, `medium`, or `low`, paired with the source type (`api`, `log`, `inferred`, `memory`, `previous-agent`). Low-confidence entries get flagged with `[!needs-verification]` for future sessions to check.

### AS-2: Challenge-previous

When consuming output from a previous session or agent, the current session must examine it before accepting. Identify at least one questionable point. If nothing is found, log that the review happened: `[challenge-previous: reviewed, no divergences found]`.

### AS-3: Suspect unanimity

When multiple sources agree perfectly, flag it. Ask whether they share the same upstream source or bias. N sources echoing the same origin is not independent corroboration.

### AS-4: Conflict documentation

When sessions disagree, don't silently overwrite. Create a ConflictReport (template included in `templates/`), save it in the relevant domain folder, and resolve with evidence, not recency.

### AS-5: Independent analysis before chaining

For tasks that read one agent's output and produce new output:

1. Form your own assessment from primary sources first
2. Then read the previous output and compare
3. Document divergences or confirm independent agreement

This prevents cascading conformity where each agent just reinforces the last.

### AS-6: Memory decay

- Memories >7 days old about transient states: re-verify before acting
- Memories >30 days old: treat as low confidence automatically
- When re-verification finds the memory is still valid, mark it `[re-verified: YYYY-MM-DD]`
- When re-verification finds divergence, create a ConflictReport

## Intra-session extension (v1.7.0)

AS-1 through AS-6 cover the inter-session vector: accepting output from another session, agent, or memory file without challenge. A second vector operates inside a single turn: an LLM adopting whatever framing the user argued for in the same message.

The llm-bias-bench benchmark (Maritaca AI, April 2026) found sycophancy jumps from around 20 to 40% in direct mode to 70 to 94% in indirect mode across most frontier models. AS-1 through AS-6 do not catch this because there is no prior agent output to challenge inside a single turn.

For opinion-content drafts, use the `/bias-check` command in the commands module. For agent pipelines with user-argued framings, see the model selection and composer prompt hardening guidance in `rules/anti-sycophancy.md` under "Intra-session extension".

## Metrics

| Metric | Measures | Red flag |
|--------|----------|----------|
| Challenge rate | % of challenge-previous that found something | 0% over 7 days |
| Conflict reports | Divergences documented per week | 0 in an active week |
| Confidence distribution | high/medium/low ratio in logs | >90% high (likely inflated) |
| Source diversity | Independent sources per conclusion | 1 source = not validated |

## Files

```
modules/anti-sycophancy/
  rules/anti-sycophancy.md    # Full rule definitions (AS-1 through AS-6)
  templates/ConflictReport.md  # Template for documenting divergences
  README.md                    # This file
```

## Installation

Copy `rules/anti-sycophancy.md` to your project's `.claude/rules/` directory. Copy the ConflictReport template to your templates folder. The rules auto-load on every session.
