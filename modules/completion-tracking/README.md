# Completion Tracking

Closes the loop between data ingestion and action item tracking. When new information arrives (meeting transcripts, chat messages, emails, work sessions), the agent automatically checks if any open action items have been fulfilled.

## How it works

1. **During ingestion** (CSR-1): new data is scanned for fulfillment signals. Open action items are loaded from meeting notes and deliverables memory. Matches are auto-resolved (high confidence) or flagged for review (medium confidence).

2. **During sessions** (CT-1, CT-2): when the user completes work related to a meeting action item, the meeting note checkbox is marked and the deliverables memory is updated.

3. **At end of day** (CT-3, /end step 3.6): if significant work happened but no deliverables were updated, the agent warns before closing.

4. **After meetings** (/post-meeting step 3f): meeting content is cross-referenced against action items from previous meetings. If a topic was resolved, the original item is marked done.

## Rules

### completion-tracking.md (3 rules)

| Rule | What it does |
|------|-------------|
| CT-1 | Mark `[x]` on meeting note checkboxes when items are completed |
| CT-2 | Update deliverables memory files when work is delivered |
| CT-3 | Warn if significant work happened but no deliverable was updated |

### cross-source-reconciler.md (3 rules)

| Rule | What it does |
|------|-------------|
| CSR-1 | Hybrid keyword+semantic matching at ingestion time |
| CSR-2 | Safety guardrails (max 5 auto-resolves, 30-day limit, evidence required) |
| CSR-3 | Direct user declaration ("done", "already did it") triggers full resolve |

## Installation

1. Copy `rules/` contents to your `.claude/rules/` directory
2. The /end and /post-meeting command patches are already included in the commands module

## Optional dependencies

- **Smart Connections MCP**: enables semantic fallback matching (CSR-1 step 3b). Without it, only keyword matching is used.
- **Task manager MCP** (Notion, Linear, Todoist, etc.): enables updating task status on auto-resolve. Without it, only vault-side tracking (meeting notes + memory files) is used.

## Log format

Entries added to the Daily Note by the reconciler:

```
[auto-reconciled] "action item text" <- source (confidence: high)
[reconcile-candidate] "action item text" <- source (confidence: medium)
[user-declared] "action item text" (confidence: high, source: direct)
```
