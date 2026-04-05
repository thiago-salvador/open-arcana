---
name: audit-gaps
description: "Detects gaps in the vault: uncatalogued people, projects without notes, missing tasks. Scans sources from the last N days and compares with vault. Use when checking what's missing or as part of /sync-all or /weekly."
arguments:
  - name: period
    description: "Period in days to scan (default: 7)"
    required: false
dependencies: "read-ai MCP, microsoft-graph MCP, notion MCP, smart-connections MCP, vault-read"
allowed-tools: "Read,Write,Edit,Glob,Grep,Bash,mcp__read-ai__*,mcp__microsoft-graph__*,mcp__notion__*,mcp__ob-smart-connections__*"
---

# /audit-gaps $ARGUMENTS

Systematically detects what is missing from the vault. Scans external sources and compares with what already exists.

## Parameters

- `$ARGUMENTS` = period in days (default: 7)

## Flow

### 1. Define time window

```
PERIOD = $ARGUMENTS or 7
START_DATE = today - PERIOD days
```

### 2. Collect names and terms (RUN IN PARALLEL)

The goal is to extract ALL names of people, projects, and topics mentioned in sources during the period.

#### 2a. Meeting transcripts (recent meetings)

Use your transcript MCP to list recent meetings within the period.
For each meeting: extract participants, discussed topics, action items.

#### 2b. Team chat (recent chats)

```bash
cd {{MS_GRAPH_PATH}} && node -e "
require('dotenv').config();
const graph = require('./graph');
(async () => {
  const chats = await graph.getChats({ top: 30 });
  for (const chat of (chats.value || []).slice(0, 15)) {
    const msgs = await graph.getChatMessages({ chatId: chat.id, top: 20 });
    // Extract sender names and mentioned people
    // Extract mentioned topics/projects
    console.log(JSON.stringify({ chatId: chat.id, topic: chat.topic, messages: msgs.value?.slice(0,10) }));
  }
})();
"
```

#### 2c. Email (recent)

```bash
cd {{MS_GRAPH_PATH}} && node -e "
require('dotenv').config();
const graph = require('./graph');
(async () => {
  const emails = await graph.getEmails({ top: 30, filter: 'receivedDateTime ge START_DATE' });
  // Extract senders, recipients, subjects
  // SKIP spam/sales (unknown sender + generic subject)
  console.log(JSON.stringify(emails.value?.map(e => ({ from: e.from, subject: e.subject, date: e.receivedDateTime }))));
})();
"
```

#### 2d. Daily Notes from the period

Read the Daily Notes for the last PERIOD days.
Extract: mentioned people, projects worked on, decisions made.

#### 2e. Task manager

Search for tasks created/modified during the period.

### 3. Cross-reference with vault

For each name/term found in sources:

#### 3a. People without a note

```
For each person mentioned:
  1. Grep "70-People/" for the name
  2. If no note found -> add to "People without a note" list
  3. Count mention frequency (how many times across how many sources)
```

#### 3b. Projects/topics without a note

```
For each recurring project/topic (mentioned 2+ times):
  1. Grep the entire vault for the name
  2. If no dedicated note found -> add to "Projects without a note" list
  3. Count frequency
```

#### 3c. Action items without a task

```
For each action item extracted (transcripts, chats, Daily Notes):
  1. Search the task manager for a similar task (by title/description)
  2. If not found -> add to "Missing tasks" list
```

#### 3d. Decisions without a decision record

```
For each decision identified (in meetings, chats, Daily Notes):
  1. Grep vault for the decision's key terms
  2. If no note with type:decision found -> add to "Unregistered decisions" list
```

### 4. Generate report

Present to the user in structured format. NEVER auto-create anything, always ask for confirmation.

```markdown
## Gap Audit -- last PERIOD days

### People without a vault note (COUNT)
| Name | Mentions | Sources | Context |
|------|----------|---------|---------|
| [name] | [N times] | [Chat, Transcripts, ...] | [role/relationship if identifiable] |

### Projects/topics without a dedicated note (COUNT)
| Topic | Mentions | Sources | Where it appears |
|-------|----------|---------|------------------|
| [topic] | [N times] | [...] | [notes where it appears] |

### Action items without a task (COUNT)
| Action item | Origin | Date | Owner |
|-------------|--------|------|-------|
| [item] | [meeting/chat] | [date] | [who] |

### Decisions without a decision record (COUNT)
| Decision | Context | Date | Participants |
|----------|---------|------|-------------|
| [decision] | [meeting/chat] | [date] | [who] |

### Cleanup suggestions
- [stale notes, completed tasks not marked, etc.]
```

### 5. Actions (with confirmation)

Ask the user:
1. "Want me to create notes for the [N] people listed?"
2. "Want me to create notes for the [N] projects/topics?"
3. "Want me to create tasks for the [N] action items?"
4. "Want me to create decision records for the [N] decisions?"

Execute ONLY what the user confirms. Each item created follows normal vault rules (frontmatter, wikilinks, index.md update, etc.).

### 6. Log

Log in Daily Note:
```
- HH:MM -- [vault/audit] /audit-gaps PERIOD days: X people without note, Y projects without note, Z missing tasks, W unregistered decisions. [Actions taken: ...]
```

## Rules

- NEVER create anything automatically. Always ask for confirmation.
- If an MCP fails: report and continue with other sources.
- Prioritize by frequency: people/topics with more mentions appear first.
- Skip spam/sales from email (existing rule).
- If the scan returns >30 items in any category: show top 10 by frequency and ask if user wants to see the rest.
- Data about people: NEVER infer role/relationship. Mark as "unconfirmed" if it does not come directly from the source.
