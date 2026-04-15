---
name: wiki-lint
description: "Semantic lint for the vault: detects contradictions between notes, concept duplication under different names, stale content, naming drift, and semantic orphans. Complements /health (structural checks) and /audit-gaps (missing coverage). Use when user says 'wiki-lint', 'semantic lint', 'check contradictions', or weekly as part of /sync-all."
dependencies: "vault-read, ob-smart-connections"
allowed-tools: "Read,Write,Edit,Glob,Grep,Bash,mcp__ob-smart-connections__*"
---

# /wiki-lint

Semantic lint. Goes beyond `/health` structural checks: clusters notes semantically, runs each cluster through an adversarial prompt, and identifies factual contradictions, concept duplication under different names, and obviously stale content.

## Principle

`/health` checks form (frontmatter, wikilinks, orphans). `/audit-gaps` checks absences (uncatalogued people, undocumented projects). `/wiki-lint` checks **internal coherence of compiled knowledge**. Without it, the vault drifts over months: the same idea appears under different names, silent contradictions accumulate, old content contradicts the new.

## Input

- No arguments: runs across the entire vault (cap: 300 notes).
- Domain argument: `/wiki-lint research` -- only notes with matching `domain`.
- Folder argument: `/wiki-lint 60-Research/` -- only that folder.

## Flow

### 1. Collect corpus

```bash
# If no argument, entire vault excluding Daily-Notes/, 90-Archive/, 99-Inbox/, .claude/
# If argument provided, filter accordingly
```

Read frontmatter (YAML block only) from each eligible note. Budget: 1 read per note, frontmatter parsing only.

Default filters applied:
- Skip `type: daily | template | moc` (not knowledge)
- Skip folders `90-Archive/`, `Daily-Notes/`, `99-Inbox/`, `.firecrawl/`
- Skip notes with `status: archived | deprecated | superseded`

### 2. Cluster semantically

Use Smart Connections MCP to build clusters:

```
mcp__ob-smart-connections__lookup { query: "<title of each note>", limit: 5 }
```

For each note, get the 5 top neighbors. Build a similarity graph. Notes sharing >=2 mutual neighbors form a cluster.

Budget: max 100 lookup calls (1 per note, capped). If corpus >100 notes, sample randomly prioritizing notes modified in the last 30 days + notes never processed before.

### 3. Adversarial analysis per cluster

For each cluster with 3+ notes, read the full body (max 5 notes per cluster, max 20 clusters per run) and apply the adversarial analysis:

```
Given these N notes on <inferred topic>, identify:

1. FACTUAL CONTRADICTIONS
   - Direct assertions that contradict each other across notes
   - Example: note A says "Tool X supports 1M context", note B says "Tool X supports 200K context"

2. CONCEPT DUPLICATION
   - Same idea written independently in different notes without cross-linking
   - Example: "knowledge layer" and "AI wiki" referring to the same concept with no cross-link

3. NAMING DRIFT
   - Entity/person/tool named differently in different notes
   - Example: "Phyllo" in one note, "InsightIQ" in another, referring to the same API

4. STALE CONTENT
   - Assertions that were true but more recent evidence contradicts
   - Use `created` field and compare against current state (when applicable)

5. SEMANTIC ORPHAN
   - Note that appears to support an idea but no other note references or builds on it
   - Different from structural orphan in /health (which checks links); this checks semantic orphan
```

For each finding, return:
- **Type:** contradiction | duplication | drift | stale | semantic orphan
- **Severity:** high (factual) | medium (naming) | low (stylistic)
- **Notes involved:** list of paths
- **Evidence:** short excerpts (max 2 lines per note)
- **Suggested resolution:** merge, update, cross-link, archive, or flag for human review

### 4. Do not auto-correct

`/wiki-lint` ONLY reports. Never modifies the vault. The decision to resolve belongs to the user, because many "contradictions" are intentional (e.g., notes representing opposing positions for bias-check purposes).

### 5. Generate report

Create `00-Dashboard/lint-report.md` (overwriting the previous one):

```markdown
---
title: "Wiki Lint Report -- YYYY-MM-DD"
summary: "Contradictions, duplications, and semantic drift detected in the vault. Read-only, does not auto-correct."
type: reference
domain: personal
tags: [lint, vault-health, semantic-audit]
status: active
reviewed: false
created: YYYY-MM-DD
---

# Wiki Lint Report -- YYYY-MM-DD

**Corpus analyzed:** N notes (clusters: X, adversarial passes: Y)
**Total findings:** N (high: N, medium: N, low: N)

## Factual contradictions (high)

### [Contradiction N] {short title}
- **Notes:** [[note A]], [[note B]]
- **A says:** "excerpt"
- **B says:** "excerpt"
- **Suggestion:** {resolution}

## Concept duplications (medium)

### [Dup N] {short title}
- **Notes:** [[A]], [[B]], [[C]]
- **Shared concept:** {description}
- **Suggestion:** merge into a new concept note OR add cross-links

## Naming drift (medium)

### [Drift N] {entity}
- **Variants found:** "X" in [[A]], "Y" in [[B]]
- **Suggested canonical:** {which}
- **Action:** rename one + add alias

## Stale content (high)

### [Stale N] {short title}
- **Note:** [[A]] (created: YYYY-MM-DD)
- **Assertion:** "excerpt"
- **Contradicting evidence:** {which newer notes contradict, or what external source suggests update}
- **Suggestion:** update, add erratum, or move to archive folder

## Semantic orphans (low)

### [Orphan N] {concept}
- **Note:** [[A]]
- **Why orphaned:** no other note builds on this or cites the concept
- **Suggestion:** link from relevant MOC, or accept as standalone

## Summary and next steps

- N high-severity issues -- review this week
- N medium-severity issues -- review at next /weekly
- N low-severity issues -- keep on radar
```

### 6. Log to Daily Note

```
HH:MM -- [wiki-lint] **Lint report generated: N findings (X high, Y medium, Z low). Corpus: N notes.** [[00-Dashboard/lint-report]] [confidence: medium, source: smart-connections + analysis]
```

### 7. Output to the user

Short summary in chat with the N high-severity findings + link to the full report.

## Rules

- **Never auto-correct.** Only reports. Resolution is human.
- **Hard budget:** max 300 notes in corpus, max 100 SC lookups, max 20 clusters analyzed. If corpus is larger, sample.
- **Do not flag intentional contradictions.** Notes marked `type: reference` in rules folders may contain opposing positions (bias-check, contrarian analysis): skip adversarial lint for those.
- **Cache-friendly:** lint report is overwritten, not versioned within the same day (only the latest). Previous versions go to `90-Archive/Lint-Reports/YYYY-MM/`.
- **Use as complement, not substitute:** `/health` runs every session, `/wiki-lint` runs weekly or on-demand. Too expensive to run constantly.

## When to use (vs other commands)

- `/health` -- structural form (frontmatter, links, numeric score). Cheap, runs frequently.
- `/audit-gaps` -- absences (who has no note, which project lacks documentation).
- `/wiki-lint` -- semantic coherence between existing notes. Expensive, weekly.
- `/contrarian` -- anti-sycophancy analysis on excessive opinion convergence across the vault (broader scope, different focus).
- `/link-check` -- structural cross-linker via Python script.

`/wiki-lint` is the only command that detects factual contradictions and naming drift.

## Connections

- Inspired by Shann's llm-wikid thread
- Related: anti-sycophancy rules (why silent contradictions erode the vault)
- Complements: `/health`, `/audit-gaps`, `/contrarian`
- Can feed: `/capture` (when lint suggests a merge, the user can invoke capture to create the consolidated note)
