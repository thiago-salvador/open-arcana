---
name: dump
description: "Brain dump with auto-routing. Accepts free text, classifies automatically (decision, bug, concept, meeting, person, content, action item, project, partnership, event), routes to correct folder, creates note with template and frontmatter. Use when user says 'dump', 'brain dump', or passes freeform text to capture quickly. Different from /capture (interactive) and /process (external material)."
dependencies: "notion MCP, vault-read"
allowed-tools: "Read,Write,Edit,Glob,Grep,Bash,AskUserQuestion,mcp__notion__*"
---

# /dump

Quick brain dump with auto-routing. Takes free text, classifies it, creates a vault note (or a task in your task manager).

## Input

`$ARGUMENTS` contains the dump text. If empty, ask ONCE: "What's on your mind?"

## Classification

Analyze the text and classify using these signals (first strong match wins):

| Signals | Type | Base template | Default route |
|---------|------|---------------|---------------|
| "we decided", "go with", "approved", "we chose", choice between options | `decision` | Decision Record | `{domain}/` or project folder |
| "error", "bug", "fix", stack trace, error code, "resolved" | `error-solution` | Error Solution | `{domain}/Errors/` or project folder |
| "concept", "pattern", "I learned", "works like this", explanatory tone | `knowledge` | Knowledge Note | `{domain}/` |
| "meeting with", list of participants, "we discussed", "call" | `meeting` | Meeting Template | `{domain}/Meetings/` |
| Name of existing person in `70-People/` + new info about them | `person` | Person Template | `70-People/` |
| "post about", "article", "video", "reel", "content", "idea for" | `content` | Social Post or Article Draft | `30-Content/{subfolder}/` |
| "I need to", "do", "TODO", "task", imperative, deadline | `action` | N/A (task manager) | Task database |
| Name of existing project + "sprint", "release", "milestone" | `project` | Project Template | `15-Projects/{project}/` |
| "partnership", "partner", "deal", "agreement", "proposal" | `partnership` | Partnership Template | `40-Partnerships/` |
| "talk", "event", "conference", "submission" | `event` | Event Template | `50-Talks/` |

### Domain detection

Analyze the text to determine the domain:
- Mentions your company, product, analytics, dashboards -> `company`
- Mentions your studio, partner, clients -> `studio`
- Mentions post, article, video, reel -> `content`
- Mentions partnership, partner, deal -> `partnerships`
- Mentions talk, event, conference -> `speaking`
- Mentions research, paper, trend, AI trends -> `research`
- No clear match -> `personal`

### Content subfolders

Map content types to subfolders based on your vault structure (e.g., social media, articles, professional posts, courses, etc.).

## Execution flow

### 1. Classify
Apply the table above. If low confidence or ambiguous, choose the most likely and mention the alternative in the output.

### 2. Check existence
- Glob in the destination folder to see if a note on the topic already exists
- If it exists: ask whether to update the existing one or create new

### 3. Create note (or task)

**If type = `action`:**
- DO NOT create a vault note
- Create a task in your task manager with a clear, actionable title
- If a deadline was mentioned, add it
- Log in Daily Note: `- HH:MM -- /dump: task created: [title]`

**For all other types:**
- Generate a descriptive title based on the content (format: `YYYY-MM-DD Descriptive Title`)
- Create note with complete frontmatter:

```yaml
---
title: "[generated title]"
summary: "[one sentence summarizing the dump]"
type: [classified type]
domain: [detected domain]
tags: [relevant tags]
status: draft
created: YYYY-MM-DD
---
```

- Fill the body using the corresponding template structure
- Distribute the dump content into the correct template sections
- Add wikilinks for people, projects, and concepts mentioned that exist in the vault
- DO NOT invent content beyond what was said in the dump

### 4. Update context
- Read the destination folder's `index.md` and add entry for the new note
- Add log to Daily Note: `- HH:MM -- /dump: created [[title]] at [path] (type: [type])`

### 5. Detect secondary types
If the dump contains MORE than one type (e.g., "meeting where we decided to migrate and found a bug"):
- Create note for the PRIMARY type
- Mention in output: "Also detected: [secondary type]. Want me to create a separate note?"

### 6. Output

```
Created: [note title]
Type: [type] | Domain: [domain] | Location: [relative path]
Links: [wikilinks inserted]
Wrong? Say "move to X" and I'll reposition.
```

For action items:
```
Task created in task manager: [title]
(No vault note -- action items go straight to task manager)
```

## Rules

- NEVER invent fabricated content. Only use what the user said.
- If classification confidence is low, ask ONCE: "Is this more [type A] or [type B]?"
- If the dump mentions a person not in `70-People/`, mention: "Person [name] is not in the vault. Want to create?"
- Maximum 1 note per dump. If the user wants multiple, run /dump multiple times.
- If any MCP fails: report the error and continue with what works (vault note without task manager, or vice-versa).
