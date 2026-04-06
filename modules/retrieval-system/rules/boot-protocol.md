---
description: "Boot sequence and retrieval layers (Engram-inspired). Hot-cache on boot, rest on demand."
---

# Boot Protocol

## On startup (auto-loaded by SessionStart hook)

1. **MEMORY.md** - memory file index (auto-loaded by Claude Code memory system)
2. **Today's Daily Note** - create if missing (with frontmatter + Rules Manifest). Check current state and pending items.
3. **Hot cache** - Tier 1+2 notes injected automatically by `session-scan.sh`

Concept-index and aliases are NOT loaded on boot (only counts). Read on demand.

## On-demand retrieval (Engram layers)

Use ONLY when the task requires it:

| Layer | When to use | How |
|-------|-------------|-----|
| 1. Concept index / aliases | Task mentions a specific concept | Lookup in `00-Dashboard/concept-index.md` or `aliases.md` |
| 2. Filtered grep | Layer 1 didn't resolve | `grep -rl "term" <filtered-folder>/` max 5 results |
| 3. Smart Connections | Grep returns empty AND concept isn't in the index | `ob-smart-connections` MCP, max 3 results |
| 4. Fallback | All layers returned empty | List recent files in active domain (`ls -t <folder>/`) or ask the user for clarification |

**Context-Aware Gating:** Before searching (layers 3-4), define the active domain (work, studio, content, research, personal) to filter irrelevant results.

**Budget:** max 3 full file reads per query. If you need more, read summaries from frontmatter first.

## Rules Manifest (add to Daily Note if absent)

```markdown
## Rules Manifest
> [!info] Active rules
> - `core-rules.md` - 11 operational rules + pre-delivery (5 checks); anti-sycophancy in `anti-sycophancy.md`; personal rules in memory files
> - `anti-sycophancy.md` - 6 AS rules: confidence tags, challenge-previous, unanimity, conflicts, independent analysis, memory decay
> - `boot-protocol.md` - Boot + retrieval layers
> - `connected-sources.md` - MCP sources + known issues
> - `content.md` - Editorial identity (scope: 30-Content/)
> - `pessoas.md` - People note format (scope: 70-People/)
> - `memory/MEMORY.md` - Memory files (feedback, project, reference)
```

## Memory System

```
~/.claude/projects/.../memory/
├── MEMORY.md           - Index
├── feedback_*.md       - Learned rules
├── project_*.md        - Project context
└── reference_*.md      - Reference data
```
