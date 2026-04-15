---
name: wiki-query
description: "Queries the vault and materializes the answer as a permanent atomic note in 60-Research/Outputs/. Runs Engram 4-layer retrieval across the vault and files the synthesized response as a citable knowledge note. Use when user asks 'what do I have on X', 'answer X based on the vault', 'query: X', or any analytical question worth preserving."
dependencies: "vault-read, ob-smart-connections"
allowed-tools: "Read,Write,Edit,Glob,Grep,Bash,mcp__ob-smart-connections__*"
---

# /wiki-query

Query the vault with mandatory file-back. Every substantial answer becomes a permanent atomic note in `60-Research/Outputs/`, citable and grep-able in future sessions.

## Principle

Without file-back, every deep analysis evaporates with the session. The vault already holds raw knowledge; what's missing is a layer of **synthesized answers** that compound over time. Each filed query enriches the next.

## Input

Argument: a natural-language question. Examples:
- `/wiki-query what patterns appear in my published posts?`
- `/wiki-query what do I have on [person] aligned with the product roadmap?`
- `/wiki-query how does the Engram protocol compare to llm-wikid?`

No argument: ask the user what they want to query.

## Flow

### 1. Detect domain and query type

Read the question and classify:
- **Domain:** one of your configured domains (match against `domain` values in the vault), or `multi` if it spans several
- **Type:** factual (information lookup), analytical (synthesis across sources), comparative (X vs Y), exploratory (what do I have on X)

This determines which folders to target during retrieval and the format of the filed answer.

### 2. Retrieval (Engram 4-layer)

Follow the Engram retrieval protocol exactly:

**Layer 1: concept-index**
```bash
grep -i "<concept>" 00-Dashboard/concept-index.md
grep -i "<concept>" 00-Dashboard/aliases.md
```
If found: read the notes referenced.

**Layer 2: filtered grep**
```bash
grep -rl "<term>" <domain-folder>/  # max 5 results
```

**Layer 3: Smart Connections** (only if layers 1 and 2 return empty)
```
mcp__ob-smart-connections__lookup { query: "<original question>", limit: 5 }
```

**Layer 4: fallback**
`ls -t <folder>/` or ask the user for clarification.

**Budget:** max 3 full reads. Prefer reading `summary` from frontmatter before reading the body. If you need more than 3 reads, consolidate before continuing.

### 3. Synthesize the answer

Generate a 200-500 word response with:
- **TLDR** (1 line)
- **Answer** structured with `[[wikilinks]]` to every cited note
- **Sources** bulleted (the notes supporting the answer)
- **Confidence** (high/medium/low) with justification

### 4. Mandatory file-back

Create `60-Research/Outputs/YYYY-MM-DD {descriptive title}.md` with frontmatter:

```yaml
---
title: "{descriptive title based on the query}"
summary: "{TLDR in 1 sentence}"
type: knowledge
domain: {detected domain}
tags: [query-output, auto-captured, {relevant-tags}]
status: draft
reviewed: false
created: YYYY-MM-DD
source_session: "YYYY-MM-DD HH:MM"
query: "{original question verbatim}"
confidence: high | medium | low
---
```

Body:

```markdown
# {title}

> Query: {original question}

## TLDR
{1 line}

## Answer
{200-400 words, with wikilinks}

## Sources
- [[note1]]
- [[note2]]

## Counter-arguments & gaps
{what the vault does NOT have on the subject, or what counter-evidence appears in the sources}

## Confidence
`{level}` -- {justification, 1 sentence}
```

**File-back rules:**
- Filename must be descriptive, never generic. `2026-04-15 Sycophancy Patterns in LinkedIn Posts.md`, not `query-1.md`.
- Always link bidirectionally: in the filed note body, link to sources. In the sources, do NOT add automatic back-links (avoids Write churn).
- Always include a `Counter-arguments & gaps` section. If empty, write `No strong counter-argument emerged from vault sources. Possible gap: {what's missing}.`
- Confidence default: `medium` if retrieval found 2+ corroborating sources, `low` if only 1, `high` only when multiple independent sources converge.
- `reviewed: false` always (anti-sycophancy gate).

### 5. Update Outputs index

After creating the note, update `60-Research/Outputs/index.md` adding the entry in the chronological table. If the index does not exist, create it.

### 6. Log to Daily Note

```
HH:MM -- [wiki-query] **{short query title}.** Filed at [[60-Research/Outputs/YYYY-MM-DD title]]. Confidence: {X}. {N} sources cited. [confidence: {X}, source: vault]
```

### 7. Output to the user

```
Query: {question}

TLDR: {1 line}

Answer: {full answer, exactly as written in the note}

Filed at: [[60-Research/Outputs/YYYY-MM-DD title]]
Sources: {N notes}
Confidence: {X}
Reviewed: false (flip manually once you've reviewed)
```

## Rules

- **Never skip file-back.** Even if the user doesn't explicitly ask for it. The value is in compounding, not in any single answer.
- **Never fabricate sources.** If retrieval returns empty, say `The vault has no material on this yet` and offer to research externally (WebFetch/firecrawl). In that case the filed note is marked `confidence: low` with a large `Gap` section.
- **Respect domain-scoping.** If the query is about one domain, do not pull material from unrelated domains even if semantically close.
- **Budget:** max 3 reads, 1 Smart Connections call, 1 Write. If you need more, consolidate and decide.
- **Do not overwrite existing Outputs.** If a filed note with a similar title already exists, add a `(v2)` suffix or point it out to the user.

## When to use (vs other commands)

- `/recall` -- searches past sessions in the FTS5 index (read-only, returns old snippets).
- `/wiki-query` -- queries the CURRENT vault, synthesizes, FILES the answer as a knowledge note.
- `/capture` -- saves something from the current session, interactive, not necessarily a query.
- `/process` -- transforms raw external material into atomic notes, not a query.
- `/bias-check` -- evaluates opinionated drafts, does not answer questions.

`/wiki-query` is the bridge between analysis (session) and permanent knowledge (vault).

## Connections

- Inspired by Shann's AI Knowledge Layer thread (llm-wikid)
- Complements: Engram 4-layer retrieval (boot-protocol / retrieval strategy rules)
- Successor to: `/recall` (which is read-only on session index, does not create knowledge)
