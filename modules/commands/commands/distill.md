---
name: distill
description: "Extract reusable workflows/processes from the current session. Analyzes tool calls, identifies sequences of 5+ steps with coherent outcomes, suggests creating a command, rule, or template. Use after productive sessions."
allowed-tools: "Read,Write,Edit,Glob,Grep,Bash"
---

# /distill

Extracts process patterns (not knowledge) from the current session. Complements `/capture` (which captures facts/decisions).

## Flow

### 1. Analyze the session

Review tool calls and actions from the current session (already in context, no file read needed). Identify:

- **Sequences of 5+ steps** with a coherent outcome (e.g., "grep > read > edit > test > commit")
- **Multi-tool workflows** that solved a specific problem
- **Repeated patterns** that appeared 2+ times in the session

### 2. Classify each pattern

For each candidate, classify:

| Type | Criteria | Destination |
|------|----------|-------------|
| **Command candidate** | Parameterizable workflow, useful in future sessions | `.claude/commands/` |
| **Rule candidate** | Constraint or convention that should persist | Rules folder or memory file |
| **Template candidate** | Note structure created manually that could become a template | Templates folder |
| **Skip** | One-off workflow, not reusable | None |

### 3. Present to the user

For each relevant candidate, show:

```
Pattern detected: [1-line description]
Sequence: [step1 > step2 > step3 > ...]
Suggested type: [command/rule/template]
Options: (a) create as /command  (b) save as rule  (c) save as template  (d) skip
```

**NEVER create automatically.** Always ask first.

### 4. Create the artifact

**If command:**
1. Scaffold `.claude/commands/{name}.md` with standard frontmatter (name, description, allowed-tools)
2. Describe the flow in numbered steps
3. Add a "When to use" section differentiating from similar commands

**If rule:**
1. Check if a similar rule already exists
2. If not: create a rule file or feedback memory
3. If yes: suggest merging with the existing one

**If template:**
1. Create in the templates folder with `{{field}}` placeholders
2. Add to the template index

### 5. Output

```
Distilled: [N] patterns analyzed, [M] created
- [type]: [name] -> [path]
```

## Rules

- Analysis based ONLY on what's in the session context. Do not read session JSONL files.
- Do not suggest trivial patterns (e.g., "read file and edit" is not a workflow)
- Minimum threshold: 5 tool calls in sequence with a coherent objective
- If the session was short (<10 tool calls total): respond "Short session, no complex patterns detected."

## When to use (vs other commands)

`/distill` captures **processes** (how to do things). `/capture` captures **knowledge** (what was decided/learned). `/dump` captures **thoughts** (free text). They complement each other, not substitute.
