---
name: start
description: "Morning kickoff -- Intelligence briefing + Daily Note + task manager. Use when starting the day. Collects meeting transcripts, team chats, calendar events, tasks, file scan, and tool updates in parallel, cross-references all sources, and generates prioritized focus for the day."
dependencies: "read-ai MCP, microsoft-graph MCP, notion MCP, gmail MCP, smart-connections MCP, WebSearch, vault-read"
allowed-tools: "Read,Write,Edit,Glob,Grep,Bash,Agent,WebSearch,WebFetch,mcp__read-ai__*,mcp__microsoft-graph__*,mcp__notion__*,mcp__ob-smart-connections__*"
---

# /start

Intelligence briefing for the morning. Collects ALL sources, cross-references data, generates priorities.

## Flow

### 0. Boot (handled by SessionStart hook -- skip if already loaded)

If Daily Note exists with content, treat it as priority context for prioritization.

**Rules Manifest:** Check if the Daily Note has the `## Rules Manifest` block (callout listing all rule files). If missing, add at the top (after frontmatter, before `## Today's Meetings`). The block is defined in `.claude/rules/boot-protocol.md` section "Rules Manifest". Only needs to be added once per day.

### 1. Determine last_collection

Find the date/time of the last data collection:
1. Read the most recent Daily Note that has `## Log` with "Claude Session" (could be today or days ago)
2. Extract the timestamp of the last logged session (format: YYYY-MM-DDT HH:MM)
3. If no Daily Note with log found, use 7 days ago as fallback
4. Store this timestamp as `LAST_COLLECTION` -- all collections below use it as cutoff

### 2. Parallel source collection (RUN IN PARALLEL)

Launch all collections simultaneously. If any MCP fails, report but continue with the others.

#### 2a. Meeting transcripts (Read.AI or equivalent)

Using your meeting transcript MCP:
1. Fetch meetings with `start_datetime_gte` = LAST_COLLECTION, expand summaries and action items
2. Paginate until done (max 10 per page)
3. For each meeting collected, record:
   - Title, date/time, participants
   - Summary (auto-generated)
   - Action items (extracted tasks)
   - Key questions (open issues)
4. If a meeting has critical action items or decisions, mark as HIGH_SIGNAL

#### 2b. Team chat -- Conversations

Using Microsoft Graph (or your team chat MCP):

```bash
cd {{MS_GRAPH_PATH}} && node -e "
require('dotenv').config();
const graph = require('./graph');
(async () => {
  // 1. List all updated chats
  const chats = await graph.getChats({ top: 50 });

  // 2. For each chat with recent activity after LAST_COLLECTION,
  //    pull recent messages
  const results = {};
  for (const chat of chats.value || []) {
    const topic = chat.topic || chat.chatType || 'DM';
    try {
      const msgs = await graph.getChatMessages({ chatId: chat.id, top: 30 });
      const recent = (msgs.value || []).filter(m =>
        new Date(m.createdDateTime) > new Date('LAST_COLLECTION_ISO')
      );
      if (recent.length > 0) {
        results[topic] = {
          chatId: chat.id,
          chatType: chat.chatType,
          members: (chat.members || []).map(m => m.displayName).join(', '),
          messageCount: recent.length,
          messages: recent.map(m => ({
            from: m.from?.user?.displayName || 'unknown',
            date: m.createdDateTime,
            preview: (m.body?.content || '').replace(/<[^>]*>/g, '').substring(0, 200)
          }))
        };
      }
    } catch(e) { /* skip inaccessible chats */ }
  }
  console.log(JSON.stringify(results, null, 2));
})();
"
```

**Priority chats** (always pull even if lastUpdated seems old):
Configure your priority chat IDs in your local `.claude/settings.local.json` or environment variables. Example:
- `{{TEAMS_CHAT_ID}}` -- Manager 1:1
- `{{TEAMS_CHAT_ID}}` -- Daily standup
- `{{TEAMS_CHAT_ID}}` -- Dev team

For these chats, ALWAYS pull the last 30 messages regardless of date filter.

#### 2c. Calendar -- Scheduled meetings

**Personal calendar (Google):**
Use `gcal_list_events` with:
- `timeMin`: today 00:00
- `timeMax`: 5 days ahead 23:59
- `timeZone`: your timezone
- `condenseEventDetails`: false (we want attendees)

**Work calendar (Microsoft):**
```bash
cd {{MS_GRAPH_PATH}} && node -e "
require('dotenv').config();
const graph = require('./graph');
(async () => {
  const events = await graph.getCalendarEvents({
    top: 30,
    filter: \"start/dateTime ge 'TODAY_ISO' and start/dateTime le 'FIVE_DAYS_ISO'\"
  });
  console.log(JSON.stringify(events, null, 2));
})();
"
```

#### 2d. Task manager -- Pending tasks

1. Fetch your task database via Notion MCP (or your preferred task manager)
2. Filter for tasks with status != Done
3. If task manager does not connect: ask the user

#### 2e. File scan (silent)

```bash
find ~/Documents -type f -mtime -2 \
  -not -path "*/node_modules/*" -not -path "*/.git/*" \
  -not -path "*/Obsidian*" -not -path "*/.next/*" \
  -not -path "*/.svelte-kit/*" -not -path "*/dist/*" \
  -not -path "*/.turbo/*" -not -path "*/.cache/*" \
  -not -path "*/build/*" -not -path "*/out/*" \
  -not -path "*/__pycache__/*" -not -path "*/venv/*" \
  -not -name "*.lock" -not -name "package-lock.json" \
  -not -name ".DS_Store" -not -name "*.log" \
  -not -name "*.png" -not -name "*.jpg" -not -name "*.svg" \
  -not -name "*.mp4" -not -name "*.ttf" -not -name "*.woff*" \
  | sort
```
Group by project.

#### 2f. Tool updates -- Feature scan

**Goal:** Identify updates to your AI tools that could improve workflows (vault, MCPs, hooks, scheduled tasks, commands, agents).

1. **Blog/changelog:** WebSearch for your tool vendor's recent updates (last 48h)
2. **Social/community:** Search community channels for tips and changelogs
3. **For each relevant update found:**
   - Evaluate if it impacts your setup
   - If yes: describe what changed + suggested concrete action
   - If no: omit
4. **Create/update** research note with:
   - Release notes summary
   - Table: Feature | Already have? | Verdict (AUDIT against existing setup before recommending)
   - Only recommend "APPLY" if clearly superior to current setup
5. **Format in briefing:**
   ```
   ### Tool Updates
   - [feature] -- impact: [how it affects your projects/vault]
   - Action: [what to do]
   ```
   If no relevant updates: omit section entirely.

### 3. Cross-analysis and prioritization

With ALL data collected, perform the analysis:

#### 3a. Delta report (what changed since LAST_COLLECTION)

Compare new data with what was in the previous Daily Note:
- **New decisions** -- decisions made in meetings or chats that affect priorities
- **New action items** -- from transcripts or team messages
- **Context shifts** -- projects that gained or lost urgency
- **Conflicts** -- overlapping meetings, conflicting deadlines, duplicate tasks

#### 3b. Intelligent prioritization

Calculate priorities based on:
1. **Time urgency** -- overdue or upcoming deadlines (< 3 days)
2. **Stakeholder signal** -- Did your manager ask? Meeting today on the topic?
3. **Dependencies** -- blocking other people?
4. **Accumulation** -- how many days without progress?

Generate a ranking of **Top 5 actions for today** with short justification.

#### 3c. Today's meetings

For each meeting today:
- Context: what was discussed in the last meeting of this type?
- Preparation: is there something pending that should be resolved before?
- Expected decisions: based on open action items

### 4. Create/update Daily Note

- Path: `Daily-Notes/YYYY-MM-DD.md`
- If it already exists: DO NOT overwrite. Add/update sections preserving existing content.
- If it does not exist, create with frontmatter:
  ```yaml
  ---
  title: "YYYY-MM-DD"
  type: daily
  created: YYYY-MM-DD
  last_collection: "YYYY-MM-DDTHH:MM"
  ---
  ```

Daily Note structure:

```markdown
## Today's Meetings
| Time | Meeting | Prep needed |
|------|---------|-------------|
(table with today's meetings and preparation status)

## Intelligence Briefing (since LAST_COLLECTION)

### Decisions and changes
- [list of new decisions from meetings/chats]

### New action items
- [list of action items extracted from transcripts and chats]

### Important signals
- [messages or events that deserve attention]

### Tool Updates
- [feature] -- impact: [how it affects projects/vault]
- Action: [what to do]
(omit if no relevant updates)

## Focus for Today

### [Domain] (priority)
- [ ] Task 1 -- short justification
- [ ] Task 2

(grouped by domain)

## Log

### Claude Session -- HH:MM
- Intelligence briefing: X meetings collected, Y team messages, Z calendar events
- Sources: Transcripts (ok/failed), Chat (ok/failed), Google Cal (ok/failed), MS Cal (ok/failed), Tasks (ok/failed)
- Delta since LAST_COLLECTION: [1-line summary]

## Tomorrow
```

### 5. Terminal output

```
YYYY-MM-DD -- Intelligence Briefing

DELTA (since LAST_COLLECTION):
- X meetings (transcripts) | Y team messages | Z calendar events
- New decisions: [short list or "none"]
- New action items: [N items]

TODAY'S MEETINGS:
- HH:MM -- [name] (prep: ok/pending)

TOP 5 FOCUS:
1. [task] -- [short justification]
2. ...

SCAN (48h): N files outside vault
HEALTH: vault ok / X issues

Daily Note created/updated.
```

## Rules

- If any MCP fails: report which one failed, continue with the others. NEVER block the flow
- For team chat: if token expired (401/403), instruct the user to re-authenticate
- For meeting transcripts: if auth error, advise re-authentication may be needed
- Never fabricated content -- if no data, say "no data since LAST_COLLECTION"
- Never overwrite existing Daily Note -- always append/merge
- Validate timestamps -- never assume dates, always verify
- Collections 2a-2e should run in parallel when possible (use parallel agents)
- The `last_collection` field in the Daily Note frontmatter is updated at the end with the current timestamp
- If LAST_COLLECTION is > 3 days ago, warn the user: "Gap of X days. Collection may be large."

## Interactive fallback

If NO external source connects (transcripts + chat + calendar all failed):
1. Report which failed and why
2. Ask: "Want to tell me what happened since [LAST_COLLECTION]? I can build the briefing manually."
3. Continue with tasks + scan + vault (which work offline)
