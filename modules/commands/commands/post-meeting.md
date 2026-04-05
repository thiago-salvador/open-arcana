---
name: post-meeting
description: "Processes meeting transcripts -- decisions, action items, vault notes, task manager entries. Use after meetings or via scheduled task. Fetches unprocessed meetings, creates vault notes with decision records, extracts action items as tasks, updates person notes and indexes."
dependencies: "read-ai MCP, notion MCP, vault-read"
allowed-tools: "Read,Write,Edit,Glob,Grep,Bash,mcp__read-ai__*,mcp__notion__*"
---

# /post-meeting

Processes meetings from your transcript service that have not yet been documented in the vault.

## Flow

### 1. Identify unprocessed meetings (boot handled by SessionStart hook)

1. Use your transcript MCP to list recent meetings with expanded summaries, action items, key questions, and topics
2. For each meeting returned, check if a corresponding note already exists in the vault:
   - Grep in your meetings folders by the title or date of the meeting
   - If a note with the same title and date is found: mark as "already processed", skip
3. If no new meetings: report "No new meetings to process" and exit
4. If new meetings exist: list and process each one

### 3. Process each meeting

For each unprocessed meeting:

#### 3a. Create meeting note in the vault

Path: `{domain}/Meetings/YYYY-MM-DD {Meeting Title}.md`
Route to the appropriate domain folder based on meeting participants and topic.

Frontmatter:
```yaml
---
title: "YYYY-MM-DD {Title}"
summary: "{transcript summary in 1 sentence}"
type: meeting
domain: [detected domain]
tags: [meeting, participant-names]
status: active
created: YYYY-MM-DD
participants: [list of names]
transcript_id: "{meeting ID}"
---
```

Content:
```markdown
## Participants
- Name (role/context if known from vault)

## Summary
{transcript summary}

## Decisions
> [!decision] {Decision title}
> **When:** YYYY-MM-DD, {meeting name}
> **Who decided:** {relevant participants}
> **Context:** {why it was discussed}
> **Decision:** {what was decided}
> **Impact:** {who needs to act, what changes}

(repeat for each identified decision)

## Action Items
- [ ] {action item} -- **{owner}** (deadline: {if mentioned})

## Key Questions (open)
- {question 1}
- {question 2}

## Topics
- {topic 1}
- {topic 2}
```

#### 3b. Create separate decision records (if decision is significant)

For decisions that affect product, strategy, or architecture:
- Create a separate note in the domain folder with type: decision
- Link from the meeting note via wikilink

#### 3c. Create tasks in task manager

For each action item:
1. Identify if it is for you or for follow-up
2. If for you: create task in your task database
   - Task: action item text
   - Project: relevant domain
   - Priority: infer from context
   - Status: To Do
3. If for someone else: record in the meeting note as a follow-up item

#### 3d. Update person notes

For each meeting participant:
- If they have a note in `70-People/`: add reference to this meeting
- If they do not have a note: create a basic note with frontmatter

#### 3e. Update Daily Note

Add log entry:
```markdown
- HH:MM -- [domain] Processed meeting: {title} ([[link]])
  - {N} decisions, {N} action items, {N} tasks created
```

### 4. Update indexes

- `index.md` for each folder where notes were created
- Relevant MOCs if there are cross-domain connections

### 5. Output

```
Meetings processed: N

For each meeting:
- {Title} ({date})
  - Decisions: {N} ({short list})
  - Action items: {N} ({N} for you, {N} for follow-up)
  - Tasks created: {N}
  - Note created: [[path]]
```

## Source fallback

If an MCP fails (timeout >15s, 401/403, network error, empty response):
1. Log in output: `[!] Source unavailable: [name]`
2. Skip the category, do not block the entire command
3. Continue with remaining sources
4. If transcript service fails: report and suggest processing manually
5. If task manager fails: create tasks as checkboxes in the vault note, warn user

## Rules
- Never invent content -- use only data from the transcript service
- Decisions must be extracted from summary + action items, never fabricated
- If not sure something is a decision: record as "possible decision" and ask the user
