---
name: connections
description: "Discovers cross-domain connections in the vault via semantic search. Use when looking for non-obvious links between domains (e.g., research that feeds content, partnerships that become clients). Categorizes into actions, context enrichment, and productive tensions. Accepts optional topic argument."
dependencies: "smart-connections MCP, vault-read"
allowed-tools: "Read,Write,Edit,Glob,Grep,Bash,mcp__ob-smart-connections__*"
---

# /connections

Uses semantic search (Smart Connections MCP) to discover non-obvious connections between vault domains.

## Argument

- `$ARGUMENTS` -- specific topic or note to search connections for (optional)

## Flow

### 1. Identify recent notes

If no argument, search for notes created/modified in the last 7 days:
```bash
find {{VAULT_PATH}} -name "*.md" -mtime -7 \
  -not -path "*/Daily-Notes/*" -not -path "*/.agents/*" -not -path "*/80-Templates/*" \
  | head -10
```

### 2. For each recent note (or provided topic)

Use Smart Connections MCP (tool: `lookup`) to search for semantically related notes.
<!-- LIMIT: max 3 results per lookup (boot-protocol rule) -->

### 3. Filter cross-domain connections

Focus on connections that cross different domains:
- Company work <-> Content (features that become posts)
- Research <-> Talks (research that becomes a talk)
- Partnerships <-> Studio (partners that become clients)
- Research <-> Content (trends that become articles)

Same-domain connections are less interesting.

### 4. Evaluate value

For each connection found, evaluate:
- **Action:** generates a task? (article, pitch, outreach)
- **Context:** enriches an existing note?
- **Tension:** reveals a productive contradiction?

### 5. Output

```
Connections Discovered

## Actions (generate tasks)
- [[note A]] <-> [[note B]]: [why they connect] -> Suggestion: [task]

## Context (enrich notes)
- [[note A]] <-> [[note B]]: [why they connect] -> Add wikilink in [note]

## Productive tensions (content hooks)
- [[note A]] <-> [[note B]]: [description of tension] -> Potential post/article about [topic]
```

### 6. Offer

"Want me to:
- Add the suggested wikilinks?
- Create tasks in the task manager for the actions?
- Create a content idea note for the tensions?"

## Rules
- Maximum 5 notes to search connections per execution
- Smart Connections first, grep as fallback
- NEVER create forced connections -- if there is no genuine relationship, do not invent one
- Prioritize cross-domain over intra-domain connections
