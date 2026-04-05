---
name: recap
description: "Day recap -- summarizes what happened today so far. Activities, meetings, emails, chats, tasks, research. Lightweight, can run anytime. Use when user says 'recap', 'day summary', 'what happened today'."
dependencies: "read-ai MCP, microsoft-graph MCP, notion MCP, gmail MCP, vault-read"
allowed-tools: "Read,Write,Edit,Glob,Grep,Bash,Agent,mcp__read-ai__*,mcp__microsoft-graph__*,mcp__notion__*,mcp__gmail__*"
---

# /recap

Lightweight day recap. Can run anytime, as many times as you want. Does not write to the vault (unlike /end).

## Flow

### 1. Parallel collection (silent, no logs)

Run in parallel:

#### 1a. Today's Daily Note
Read `Daily-Notes/YYYY-MM-DD.md` in full. Extract:
- All logs (Claude sessions, registered actions)
- Listed meetings
- Focus of the day / planned tasks
- Registered decisions

#### 1b. Meetings (transcript service)
Using your meeting transcript MCP:
- Filter: today 00:00 onwards
- Expand summaries and action items
- For each meeting: title, time, participants, short summary, action items

#### 1c. Team chat (recent messages)
```bash
cd {{MS_GRAPH_PATH}} && node -e "
require('dotenv').config();
const graph = require('./graph');
(async () => {
  const today = new Date(); today.setHours(0,0,0,0);
  const chats = await graph.getChats({ top: 30 });
  const chatList = Array.isArray(chats) ? chats : (chats.value || []);
  const results = {};
  for (const chat of chatList) {
    try {
      const msgs = await graph.getChatMessages({ chatId: chat.id, top: 20 });
      const msgList = Array.isArray(msgs) ? msgs : (msgs.value || []);
      const recent = msgList.filter(m =>
        new Date(m.createdDateTime) >= today
      );
      if (recent.length > 0) {
        const topic = chat.topic || chat.chatType || 'DM';
        results[topic] = {
          count: recent.length,
          highlights: recent.slice(0, 3).map(m => ({
            from: m.from?.user?.displayName || 'unknown',
            time: m.createdDateTime,
            preview: (m.body?.content || '').replace(/<[^>]*>/g, '').substring(0, 150)
          }))
        };
      }
    } catch(e) {}
  }
  console.log(JSON.stringify(results, null, 2));
})();
"
```

#### 1d. Emails today
Try Gmail MCP (search for today's emails).
If it fails, try Outlook via Microsoft Graph.
Filter: skip spam/sales/newsletters. Only emails from known contacts or existing threads.

#### 1e. Tasks
Query your task database for ongoing tasks and tasks edited today.

#### 1f. Claude sessions (vault grep)
```bash
grep -n "Claude Session" {{VAULT_PATH}}/Daily-Notes/YYYY-MM-DD.md
```
Identify how many Claude sessions occurred today and what was done in each.

#### 1g. News and AI updates (from Daily Note)
Read the auto-generated news/monitoring blocks from today's Daily Note.
Extract:
- Top stories (max 5, only those with real work impact)
- Monitored videos/content
- Tool-specific updates (if any)

### 2. Synthesize

Organize the output into clear categories. Do not repeat information across categories.

### 3. Output (TERMINAL ONLY, do not write to vault)

```
YYYY-MM-DD -- Recap (as of HH:MM)

CLAUDE SESSIONS: N sessions
- HH:MM -- [summary of what was done]
- HH:MM -- [summary]

MEETINGS: N
- HH:MM -- [title] with [participants]
  Summary: [1-2 sentences]
  Action items: [N items, highlights]

COMMUNICATIONS:
Team chat: N active conversations
- [chat/person]: [preview of main topic]
Emails: N relevant
- [sender]: [subject]

TASKS:
- Created today: N
- Completed today: N
- In progress: [short list]

NEWS/UPDATES:
- [top story 1 -- 1 sentence]
- [top story 2 -- 1 sentence]
(max 5; omit if daily news did not run today)

Tool updates: [specific update, if any; omit if nothing relevant]

RESEARCH/CONTENT:
- [notes created or research done today, if any]

PENDING (from day plan):
- [ ] [tasks from Focus of the Day not yet done]
```

If a category has no data, omit it entirely (do not show "Emails: 0").
If an MCP fails, omit the category and add at the end:
```
[!] Unavailable sources: [list]
```

## Rules

- **Read-only.** Does not write to the vault. Does not create logs. Does not update Daily Note.
- If the user wants to record something, suggest `/end` or `/capture`.
- Can run multiple times per day with no side effects.
- Prioritize speed. If a source takes >15s, skip and report.
- Never fabricated content. If no data, omit.
- Filter spam/sales from emails.
