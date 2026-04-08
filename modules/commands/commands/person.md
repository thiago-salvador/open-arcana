---
name: person
description: "Pulls complete context about a person -- vault, team chat, meeting transcripts, calendar, tasks. Use before meetings with someone. Cross-references ALL sources in parallel: vault people folder, team chats, meeting transcripts, calendar events, task manager. Offers to create person note if missing."
arguments:
  - name: name
    description: "Person's name (ex: Jane, Bob, Alice)"
    required: true
dependencies: "microsoft-graph MCP, read-ai MCP, notion MCP, linkedin MCP, WebSearch, vault-read"
allowed-tools: "Read,Write,Edit,Glob,Grep,Bash,WebFetch,WebSearch,mcp__read-ai__*,mcp__microsoft-graph__*,mcp__notion__*,mcp__linkedin__*"
---

# /person $ARGUMENTS

Complete briefing about a person. Cross-references ALL sources.

## Flow

### 1. Identify the person

Use the provided name (`$ARGUMENTS`) to search all sources. If ambiguous, ask the user.

### 2. Parallel collection (RUN IN PARALLEL)

#### 2a. Public enrichment (LinkedIn + company)

Before everything else, search for public data to enrich the briefing:

1. **LinkedIn** (via linkedin MCP):
   - Search for the person's profile
   - Extract: current role, company, headline, location, summary
   - If multiple results: filter by known company or ask

2. **Company** (if identifiable):
   - Get the company profile
   - Extract: description, size, sector, location, recent posts
   - If the person works at your company: skip (already known)

3. **Web** (fallback if LinkedIn returns nothing):
   - WebSearch for the name + company/context
   - Extract: public bio, articles, talks, GitHub

**Enrichment rules:**
- LinkedIn data is "public source", mark as such
- NEVER confuse with confirmed vault data (vault takes priority)
- If vault already has info and LinkedIn contradicts: keep vault, report discrepancy
- If LinkedIn returns a profile but you're not sure it's the same person: ask

#### 2b. Vault (People folder)

1. Grep in vault for the name: `70-People/` first, then entire vault
   <!-- LIMIT: max 5 results, filter by domain first (boot-protocol rule) -->
2. If a person note is found: read summary + full content
3. If not found: register as "no vault note" (offer to create at the end)
4. Search for mentions in other notes (meetings, decisions, projects) via grep
   <!-- LIMIT: max 5 results, filter by domain first (boot-protocol rule) -->

#### 2c. Team chat

Using Microsoft Graph (or your team chat MCP):
```bash
cd {{MS_GRAPH_PATH}} && node -e "
require('dotenv').config();
const graph = require('./graph');
(async () => {
  const chats = await graph.getChats({ top: 50 });
  // Filter chats where the person participates (by name or email)
  // For each relevant chat, pull last 15 messages
  for (const chat of chats.value || []) {
    const members = (chat.members || []).map(m => m.displayName || '').join(', ');
    if (members.toLowerCase().includes('NAME_LOWER')) {
      const msgs = await graph.getChatMessages({ chatId: chat.id, top: 15 });
      // Filter messages from the last 14 days
      // Output: chat topic, recent messages
    }
  }
})();
"
```

If token expires (401/403): report to the user.

#### 2d. Meeting transcripts

Use your transcript MCP to list recent meetings.
Filter meetings where the person appears as participant (by name or email).
Get the 3 most recent.

#### 2e. Calendar

**Google Calendar:** search events with the person's name, next 30 days
**Microsoft Calendar:**
```bash
cd {{MS_GRAPH_PATH}} && node -e "
require('dotenv').config();
const graph = require('./graph');
(async () => {
  const events = await graph.getCalendarEvents({ top: 20 });
  // Filter events where the person is an attendee
})();
"
```

#### 2f. Task manager

Search your task database for mentions of the person's name.

### 3. Compile briefing

Generate a structured briefing:

```markdown
## Briefing: [Full Name]

**Role/Context:** [role, company, relationship]
**Last interaction:** [date and type -- meeting, chat, email]
**Next interaction:** [date and type, if scheduled]

### Recent history (last 14 days)
- [list of interactions: meetings, messages, decisions]

### Open action items
- [pending items involving this person]

### Recent decisions
- [decisions made together]

### Vault context
- [summary from person note, if it exists]
- [mentions in other notes]
```

### 4. Output

Show the briefing in the terminal. If the person does not have a note in `70-People/`, ask:
"[Name] does not have a vault note. Want me to create one based on this briefing?"

If the user says yes: create note in `70-People/` with complete frontmatter:
```yaml
---
title: "[Full Name]"
summary: "[role, company, relationship context]"
type: person
domain: [detected domain]
tags: [relevant-tags]
status: active
created: YYYY-MM-DD
---
```

## Source fallback

If an MCP fails (timeout >15s, 401/403, network error, empty response):
1. Log in output: `[!] Source unavailable: [name]`
2. Skip the category, do not block the entire command
3. Continue with remaining sources
4. If ALL sources fail, report and suggest retry

## Rules
- Never invent information about the person -- only use real data from sources
- If the name is too common and returns multiple results: ask the user which one
- If no source returns data: say "No information found about [name] in connected sources"
