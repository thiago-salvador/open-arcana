---
description: "Monitors context cost and suggests new sessions before auto-compact. Goal: avoid compaction ($150-300 each in wasted tokens)."
---

# Session Discipline (token economy)

## Main rule

**Never let the context reach auto-compact.** Compaction wastes tokens re-reading everything. Shorter sessions = less re-reading = lower cost.

## When to suggest a new session

Monitor these signals and warn the user:

### 1. Tool call count (proxy for context size)

After **30 tool calls** in the session (reads, writes, greps, bash), warn:

> "This session is getting heavy (~30 tool calls). Want to continue or start a new session? History is preserved."

After **50 tool calls**, warn urgently:

> "Session at 50+ tool calls, approaching auto-compact. Recommend starting a new session now."

### 2. Task boundary (more important than counting)

After completing a **logical task** (feature implemented, bug fixed, note processed, command created), proactively suggest:

> "Task complete. Good time for a new session if you have more to do."

Never suggest mid-task. Only at natural boundaries.

### 3. Subagent accumulation

If the session has accumulated **6+ subagents**, warn:

> "We've dispatched N subagents in this session. The next dispatch will inherit all accumulated context. New session?"

### 4. File re-read 3+ times

If the same file has been read 3+ times in the session (sign of context decay / imminent compaction), warn.

## New session vs /clear

**Prefer new session (quit + reopen) over /clear.**

- New session: history preserved, context clean, fresh boot payload
- /clear: history lost, context clean, fresh boot payload

The only reason for /clear is if the session accumulated incorrect state (reasoning bug, context confusion).

## What to log before suggesting a new session

Before suggesting, ensure:
1. Daily Note is updated with work done
2. Any decisions are recorded
3. If there's pending work, it's clear in the log what remains

## Exceptions (don't suggest new session)

- During SDD pipeline execution (has inter-phase state)
- During /weekly, /start, /end (commands that need a longer session)
- If the user explicitly said "I want everything in one session"
