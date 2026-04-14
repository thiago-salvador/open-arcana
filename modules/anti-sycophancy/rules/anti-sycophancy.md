---
description: "Anti-sycophancy protocol for interactive sessions and autonomous agents. Prevents false consensus, disagreement collapse, and agreement without evidence."
---

# Anti-Sycophancy Protocol

## Core principle

**Agreement without evidence is a failure, not a success.** The goal is not harmony between sessions/agents, it's precision. Grounded disagreement is more valuable than automatic consensus.

## 6 Anti-Sycophancy Rules

### AS-1. Mandatory confidence tags in logs

Every Daily Note log entry must include a confidence qualifier:

```
- HH:MM [action] Description [confidence: high|medium|low, source: api|log|inferred|memory|prior-agent]
```

- `high` + `api/doc`: fact verified against primary source
- `medium` + `log/memory`: information from a prior session or memory file, not re-verified
- `low` + `inferred/prior-agent`: own conclusion or inherited from another agent without validation

**If confidence = low:** add `[!needs-verification]` so future sessions know it needs checking.

### AS-2. Mandatory challenge-previous

When consuming output from a prior session/agent (yesterday's Daily Note, scheduled task output, memory file):

1. **Read the output**
2. **Before accepting, ask:** "What evidence supports this? Has anything changed since it was written?"
3. **Identify at least 1 questionable point** (it can be minor, but the exercise is mandatory)
4. **If nothing questionable found:** log explicitly `[challenge-previous: reviewed, no divergences found]`

This isn't about disagreeing for its own sake. It's about never accepting without examining.

### AS-3. Suspicious unanimity

When processing multiple sources (Teams + Outlook + Read.AI, or daily-news + morning-briefing, or grep + Smart Connections) and all agree perfectly:

- **Flag as** `[unanimity-check: N sources agree]`
- **Ask:** "Could these sources share the same bias or the same original source?"
- If all derive from the same upstream source, the "agreement" is not independent evidence

### AS-4. Conflict documentation

When a current session disagrees with a prior session (different fact, opposite conclusion, changed context):

1. **Do NOT silently overwrite.** Create a ConflictReport (see template in 80-Templates/ConflictReport.md)
2. Save in the relevant domain folder
3. Link from the Daily Note
4. Resolve with evidence, not with "the most recent session wins"

### AS-5. Independent analysis before chaining

For any task that involves reading output from another agent/session and producing new output:

1. **Phase 1 (independent):** Form your own assessment based on primary sources (APIs, files, docs)
2. **Phase 2 (comparison):** Only then read the prior output and compare
3. **Phase 3 (synthesis):** If you diverge, document the divergence. If you agree, record that the agreement was independently verified.

This prevents cascading conformity where each agent merely reinforces the previous one.

### AS-6. Memory decay and re-verification

- Memories **>7 days** about transient states: verify against primary source before acting (already existed as core-rule 8, now enforced)
- Memories **>30 days**: treat as `[confidence: low]` automatically, regardless of content
- On re-verification, if the memory is still valid: update the `created` field or add `[re-verified: YYYY-MM-DD]`
- On re-verification, if divergence found: create ConflictReport, update or archive the memory

## Metrics (for /weekly and /contrarian)

| Metric | What it measures | Red flag |
|--------|-----------------|----------|
| Challenge rate | % of times challenge-previous found something | 0% for 7 days = suspicious |
| Conflict reports created | Number of documented divergences in the week | 0 in an active week = suspicious |
| Confidence distribution | Distribution of high/medium/low in logs | >90% high = probably inflated |
| Source diversity | How many independent sources per conclusion | 1 source = not validated |

## Application

- **Interactive sessions**: follow AS-1 through AS-6 fully
- **Scheduled tasks**: follow AS-2 (challenge-previous) and AS-5 (independent analysis) in the prompt
- **Weekly review**: calculate metrics and report in the weekly review
- **Contrarian review**: `/contrarian` runs a dedicated analysis (see skill)

## Intra-session extension

The 6 rules above target the **inter-session** sycophancy vector: one session, agent, or memory file getting accepted without challenge by the next session. That is half the problem.

The **intra-session** vector lives inside a single turn: an LLM adopting whatever framing the user argued for in the same message. The llm-bias-bench benchmark (Maritaca AI, April 2026) tested nine frontier models across 38 charged topics in two interaction modes:

- **Direct mode** (user asks for an opinion): sycophancy around 20 to 40% across models
- **Indirect mode** (user argues a position, then asks): 70 to 94% across most models

Llama 4 Maverick jumped from 32% to 94%. Qwen 3.5 from 71% to 91%. Gemini 3.1 Pro from 24% to 85%. Only Kimi K2 Thinking and Claude Haiku 4.5 resisted the pattern in indirect mode. AS-1 through AS-6 above do not catch this because the user and the agent share a turn, there is no prior agent output to challenge.

### Coverage

| Vector | Where it operates | Protection |
|---|---|---|
| Inter-session | Across turns, sessions, agents, memory files | AS-1 through AS-6 |
| Intra-session | Inside a single turn, inside a single draft | `/bias-check` for drafts, model selection, composer prompt hardening |

### Model selection implications

The benchmark identifies two lower-sycophancy composers under argumentative pressure: **Kimi K2 Thinking** and **Claude Haiku 4.5**. When an agent pipeline uses an LLM to compose the final user-facing response and the typical user framing is argumentative (asking "should I do X?" while already arguing for X), the composer model choice matters. Factual accuracy is not the only axis. Measure pipelines against adversarial framings, not only happy-path unit tests.

### /bias-check command

For drafts of opinion content (op-eds, political posts, manifestos, directional commentary), the `/bias-check` command runs a lightweight adaptation of the benchmark methodology against the draft file: three simulated readers, six latent-sycophancy patterns, one stress test against hypothetical counter-argument. See `modules/commands/commands/bias-check.md`.

### Composer prompt hardening (for agent builders)

If you are building an agent whose LLM composer responds to user-argued framings, structural mitigations matter more than prompt pleading:

1. **Adversarial step**: require at least two concrete risks the user did NOT mention, stated plainly, even when the user framing seems committed
2. **Rule-based gates before the LLM**: precompute objective red flags and pass them to the composer as mandatory-surface items the composer cannot soften or omit
3. **Assertive output language**: when the correct answer is a specific number or recommendation, ban softening phrases ("you could consider", "somewhere around") in the system prompt
4. **Sycophancy regression test**: build an eval set of framings in both directions (bad cases framed positively by the user, fair cases framed negatively), run before launch, block launch on any sycophantic output

The regression test pattern applies at launch, not only at build time. The benchmark shows sycophancy compounds across turns: the more pressure, the more agreement. An eval set of single-turn cases is the floor, not the ceiling.

Benchmark source: github.com/maritaca-ai/llm-bias-bench. Methodology: 38 charged topics, 3 personas, 5-turn argumentative pressure, 4-judge validation (70% unanimous, 91% majority agreement).
