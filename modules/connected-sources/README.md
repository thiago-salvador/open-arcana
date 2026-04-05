# Connected Sources Module

Template for configuring external data sources that feed into your vault. Defines which MCPs and CLIs are available, how to cross-reference between them, and known gotchas.

## Purpose

A Claude Code agent operating on a vault needs to know:
1. **What sources exist** (Notion, Teams, Gmail, Calendar, etc.)
2. **When to use each** (which source for which type of query)
3. **How to cross-reference** (combining multiple sources for richer context)
4. **What breaks** (token expiration, MCP scoping issues, database ID mismatches)

This module provides a template that captures all four.

## Files

```
connected-sources/
  rules/
    connected-sources.md.template   # Source registry with cross-referencing rules
  README.md                         # This file
```

## Setup

1. Copy `rules/connected-sources.md.template` to your vault's `.claude/rules/connected-sources.md`
2. Replace placeholders:
   - `{{NOTION_DB_ID}}` - Your Notion task database ID
   - `{{MS_GRAPH_MCP_PATH}}` - Path to your Microsoft Graph MCP server
3. Remove sources you don't use (e.g., if you don't use Teams, remove that row)
4. Add sources specific to your setup (e.g., Slack, Discord, Jira)
5. Update the cross-referencing rules to match your vault folder names

## Placeholders

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{{NOTION_DB_ID}}` | Notion database ID for tasks | `abc123def456...` |
| `{{MS_GRAPH_MCP_PATH}}` | Path to MS Graph MCP server | `$HOME/tools/ms-graph-mcp/index.js` |

## Cross-referencing Patterns

The template defines four cross-referencing contexts:

- **Work**: combines internal comms (Teams, Outlook) with task tracking (Notion) and vault notes
- **People**: combines vault person notes with messaging (iMessages, Gmail, Teams) and professional profiles (LinkedIn)
- **Meetings**: combines transcriptions (Read.AI) with calendars and vault meeting notes
- **Content**: combines vault drafts with idea tracking (Notion), email threads, social media, and video sources

Customize these patterns based on your actual workflow. The goal is that when the agent needs context about a topic, it knows which combination of sources to check.
