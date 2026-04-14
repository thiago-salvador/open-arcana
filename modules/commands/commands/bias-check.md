---
name: bias-check
description: "Bias and latent-sycophancy check for opinion-content drafts before publishing. Lightweight adaptation of the llm-bias-bench methodology (direct vs indirect sycophancy). Runs a draft against three simulated readers (neutral, agrees, disagrees) and identifies where the text would cave under argumentative pressure, even before any real pushback is applied. Use before publishing opinion posts, op-eds, manifestos, or any directional content."
dependencies: "vault-read"
allowed-tools: "Read,Write,Edit,Glob,Grep"
---

# /bias-check

Bias and latent-sycophancy check for opinion drafts. A lightweight adaptation of the llm-bias-bench methodology to catch text that would cave under argumentative pressure, even before any pressure is applied.

## Principle

An honest opinion piece should be **consistent between readers who agree and readers who disagree**. If the text would soften its position under hypothetical pushback, it is already latently sycophantic, even without any real interaction.

Based on the llm-bias-bench benchmark (Maritaca AI, April 2026): frontier LLMs flip sycophancy rates from around 20 to 40% in direct mode (user asks for opinion) to 70 to 94% in indirect mode (user argues a position, then asks). The same structural bias applies to any text written with help from an agreement-prone assistant, because the assistant often drafts toward the user's stated frame.

This command complements the 6 inter-session AS rules in the anti-sycophancy module. Those rules protect across sessions. This one protects inside a single draft.

## Input

Path to the draft to evaluate. Accepted arguments:
- File path: `/bias-check path/to/draft.md`
- `latest` or `current`: picks the most recently modified `.md` in your drafts folder (set via `DRAFTS_DIR` env var, defaults to `{{VAULT_PATH}}/drafts/`)

## Flow

### 1. Read the draft and extract directional claims

Read the file. List every claim that takes a stance. Not questions, not neutral factual descriptions. For example, a post about AI policy might contain:

- "Big tech controls frontier AI today" (directional, critical)
- "LLMs are increasingly used" (factual, not directional)
- "This is a problem for democratic oversight" (directional, normative)

If the draft has zero directional claims, the command reports "not applicable, this is a factual or descriptive piece" and exits.

### 2. Generate 3 simulated readers

For each important directional claim (max 5), generate three mental reactions:

- **Neutral reader:** has no prior position on the topic. Does the text give enough evidence to form an opinion? Is the argument balanced, or does it favor one side without justification?
- **Agreeing reader:** already shares the author's position. Does the text reinforce or challenge them? If it only reinforces, it may be preemptive sycophancy (the author wrote to please their own tribe rather than to persuade anyone new).
- **Disagreeing reader:** thinks the opposite. Does the text confront them with direct evidence, or does it avoid them? If it avoids them, the text is less opinionated than it appears.

### 3. Detect latent sycophancy patterns

Mark the draft where you find:

| Pattern | Signal | Action |
|---|---|---|
| **Excessive hedging** | "maybe", "might", "in some cases", "it depends" on central claims | suggest a firmer version |
| **False balance** | "both sides have valid arguments" without specifying which parts | suggest the author take a side |
| **Agreement-tuned tone** | the argument only works for readers who already agree | test with a neutral reader in mind |
| **Missing strong counter-argument** | the text does not mention the best opposing case | suggest incorporating and rebutting |
| **One-sided evidence** | every citation favors the author's position | suggest hunting for counter-evidence |
| **Call-to-action without cost** | "reflect", "share", "I invite you to think" with no real ask | suggest a CTA with a concrete cost (action, subscription, commitment) |

### 4. Stress test the central claim

For the central claim of the draft, simulate: "if a respected critic wrote a serious counter-argument in the comments, could the author defend this exact text without edits?" If the answer is "depends" or "maybe not", the text lacks conviction and needs work before shipping.

### 5. Produce the report

Short, direct format:

```markdown
## Bias Check: {draft title}

**File:** {path}
**Directional claims:** N
**Latent sycophancy patterns detected:** N

### Findings

For each pattern detected:
> [!warning] {Pattern}
> **Where:** {exact passage}
> **Why:** {explanation}
> **Suggestion:** {how to rewrite}

### Stress test

**Central claim:** {what it is}
**Defensible under a serious counter-argument?** yes / partial / no
**Concrete evidence supporting it:** {list}

### Verdict

- Honest: publish as-is
- Latent sycophancy, light: 1 or 2 adjustments recommended
- Latent sycophancy, significant: rewrite before publishing

### Prioritized suggestions

1. {action 1}
2. {action 2}
3. {action 3}
```

### 6. Save and attach

- Append the report to the draft file as a `## Bias check` section at the end
- Log to the Daily Note: `HH:MM [content] Bias check ran on {draft}. Verdict: {X}. {N} adjustments suggested.`

## Rules

- This command does NOT rewrite the draft. It only identifies and suggests. The decision stays with the author.
- If the draft is factual and not opinionated (news brief, tutorial, list, documentation), the command reports "not applicable" and exits without writing.
- Never conclude "no problems found" without having walked through all 6 patterns in step 3.
- If no problems found, say "honest on the 6 dimensions tested, but the method is a heuristic, not proof of neutrality".
- The method has a known blind spot: a draft can pass all 6 patterns and still be intellectually dishonest in ways the method does not detect (factual errors, bad-faith framing of sources, selective omissions). A passing verdict is not a publication certificate.

## When to run

- Before publishing any opinion-content draft (op-ed, manifesto, critique, political post)
- As part of a content pipeline where an opinion series is being produced
- When you suspect a draft was shaped by agreement-prone LLM output and you want a sanity check
- Before a deliberately controversial post, as a pre-mortem against weak defenses

## Related

- `/contrarian`: weekly contrarian analysis across the whole vault (broader scope, weekly cadence, catches cross-session sycophancy)
- `modules/anti-sycophancy/rules/anti-sycophancy.md`: the 6 AS rules protect against inter-session sycophancy. This command complements them by catching intra-draft sycophancy. See the "Intra-session extension" section in that file for the two-vector framework and composer prompt hardening patterns.
- llm-bias-bench: github.com/maritaca-ai/llm-bias-bench, the benchmark this methodology is adapted from. Methodology: 38 charged topics, 3 personas, 5-turn argumentative pressure, 4-judge validation (70% unanimous, 91% majority agreement).
