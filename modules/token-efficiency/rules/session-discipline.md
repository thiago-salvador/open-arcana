---
description: "Monitors context cost and suggests new sessions before auto-compact. Decision tree, rewind guidance, proactive compaction."
---

# Session Discipline (token economy)

## Main rule

**Never let the context reach auto-compact.** Context rot degrades performance as context grows: attention spreads across more tokens and old, irrelevant content distracts from the current task. The model is at its LEAST intelligent exactly when it needs to compact, and it can't predict the future direction of your work. Result: automatic compacts lose critical information. Shorter sessions = less re-reading = lower cost.

## Post-turn decision tree

After every completed turn, there are 5 options. The agent should evaluate which to suggest when relevant:

| Option | When to use | Context cost |
|---|---|---|
| **Continue** | Next step depends on what just happened | Context grows |
| **Rewind** (esc esc) | Approach failed, want to try different without polluting context | Context shrinks |
| **Compact** (`/compact`) | Session is heavy but task isn't done, want to continue with less weight | Context resets (lossy) |
| **Clear** (`/clear`) | Accumulated incorrect state (reasoning bug, confusion) | Context resets (manual) |
| **New session** (quit + reopen) | Task complete, starting a different one | Clean context + history preserved |

### Subagents as an implicit option

Before any of the 5, consider: "Will I need this tool output again, or just the conclusion?" If just the conclusion, delegate to a subagent instead of executing in the main context.

## Rewind: the primary correction tool

**Rewind is the #1 habit for good context management.** When Claude tries an approach and it fails:

- **Wrong instinct:** type "that didn't work, try X instead" (pollutes context with the failed attempt + the correction)
- **Better move:** rewind to just after the file reads, and re-prompt with what you learned: "Don't use approach A, the foo module doesn't expose that. Go straight to B."

The agent should suggest rewind to the user when it detects:
1. An attempted approach resulted in an error or unsatisfactory result
2. The context accumulated tool outputs from an investigation that won't be reused
3. The user says "that's not it" or "try a different way"

**"Summarize from here":** before rewinding, the user can ask Claude to summarize what it learned. This works as a handoff message from "future self that tried something and it didn't work" to "past self that will try differently." The summary becomes the new prompt after rewind.

## Proactive compaction with steering

When the session is heavy but the task isn't done, `/compact` is preferable to a new session. With 1M context, there's time to compact BEFORE auto-compact fires.

**Steer the compact:** `/compact focus on the auth refactor, drop the test debugging`. The model uses the instruction to decide what to preserve and what to discard. Without instructions, it guesses (and with context rot active, it guesses poorly).

**When to suggest compact instead of new session:**
- Task in progress that would lose state if interrupted
- Context has clearly disposable blocks (finished debugging, exploration that led nowhere)
- The user can describe what matters in 1-2 sentences

## Signals to suggest context management

Monitor these signals and warn the user:

### 1. Tool call count (proxy for context size)

After **30 tool calls** in the session (reads, writes, greps, bash), warn:

> "This session is getting heavy (~30 tool calls). Want to continue, compact, or start a new session?"

After **50 tool calls**, warn urgently:

> "Session at 50+ tool calls, approaching auto-compact. Recommend a new session or a steered /compact now."

### 2. Task boundary (more important than counting)

After completing a **logical task** (feature implemented, bug fixed, note processed, command created), proactively suggest:

> "Task complete. Good time for a new session if you have more to do."

Never suggest mid-task. Only at natural boundaries.

### 3. Subagent accumulation

If the session has accumulated **6+ subagents**, warn:

> "We've dispatched N subagents in this session. The next dispatch will inherit all accumulated context. New session?"

### 4. File re-read 3+ times

If the same file has been read 3+ times in the session (sign of context decay / imminent compaction), warn.

### 5. Failed approach

If an approach was attempted and failed, suggest rewind before correcting inline:

> "That approach didn't work. Want to rewind (esc esc) and re-prompt clean, or correct from here?"

## New session vs /clear vs /compact

| Action | History | Context | When |
|---|---|---|---|
| New session | Preserved | Clean + fresh boot | Task complete, starting a new one |
| /clear | Lost | Clean + fresh boot | Accumulated incorrect state |
| /compact | N/A | Summarized (lossy) | Task in progress, context is heavy |

## What to log before suggesting a new session

Before suggesting, ensure:
1. Daily Note is updated with work done
2. Any decisions are recorded
3. If there's pending work, it's clear in the log what remains

## Exceptions (don't suggest new session)

- During SDD pipeline execution (has inter-phase state)
- During /weekly, /start, /end (commands that need a longer session)
- If the user explicitly said "I want everything in one session"
