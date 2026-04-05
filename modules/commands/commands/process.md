---
name: process
description: "Processes raw material into atomic vault notes. Use when the user has meetings, transcripts, research, or conversations to turn into structured notes. Creates atomic notes (300-500 words) with frontmatter, extracts decisions/action items/people, updates indexes and MOCs. Accepts optional file/folder path argument."
dependencies: "notion MCP, smart-connections MCP, vault-read"
allowed-tools: "Read,Write,Edit,Glob,Grep,Bash,Agent,mcp__notion__*,mcp__ob-smart-connections__*"
---

# /process

Processes material (meetings, transcripts, research, conversations) into atomic vault notes.

**Optional argument:** file or folder path to process. Ex: `/process /path/to/transcripts`

## Flow

### 1. Identify material
Ask the user:
- "What do you want to process? (meeting, transcript, research, conversation, other)"
- "Do you have a specific file/folder or want me to search in the task manager?"
- If the user passed an argument: use as source

### 2. Check what already exists
- Grep/glob in the vault to check if notes on the topic already exist
- Ask whether to update existing ones or create new

### 3. Process
For each material item:
- Extract: decisions, action items, technical topics, people, insights, connections
- Create atomic notes (300-500 words) with complete frontmatter
- Use parallel agents to process multiple items simultaneously

### 4. Create concept notes
- If the material reveals cross-cutting concepts (feature, strategy, pattern): create a separate concept note synthesizing across sources
- Link bidirectionally

### 5. Create person notes
- If new people appear: create in `70-People/`
- If they already exist: ask whether to update

### 6. Ask the user
- "I created N notes. Want me to generate tasks in the task manager for the action items?"
- "I identified these cross-domain connections: [list]. Want me to update the MOCs?"

### 7. Update indexes
- Update `index.md` for all modified folders
- Update relevant MOCs

## Rules
- If any MCP fails: ask the user, do not block
- Never fabricated content -- only process what was actually said/written
- Maximum 10 files per operation without user confirmation
- Ask before creating person notes (may have duplicates)

## When to use (vs other commands)

Transforms raw material (research, meetings, links, transcripts) into atomic vault notes. Different from /capture (capture from current session, not external material) and /post-meeting (specific to meeting transcript processing).
