# Cross-Source Reconciler (3 rules)

## CSR-1. Reconciliation at ingestion time

After processing new data from any source (chat messages, emails, meeting transcripts, work sessions), execute the reconciliation step:

1. **EXTRACT** entities from the new data: names of people, projects, tools, key terms. Detect fulfillment signals: links, attachments, "here's", "done", "attached", "sent", "completed".
2. **LOAD** open action items (max 3 reads):
   - Recent meeting notes: `grep -rl "\- \[ \]" {domain}/Meetings/` (last 30 days)
   - Deliverables memory: "Pending" section in `project_*_deliverables.md`
   - Task manager: pending tasks (if a task manager MCP is available)
3. **MATCH** (hybrid):
   - 3a. Keyword: extracted entities vs action item text. Exact match = confidence HIGH.
   - 3b. If keyword = 0 matches AND fulfillment signals are present: semantic search via Smart Connections (max 3 results). Semantic match = confidence MEDIUM.
4. **ACT** based on confidence:
   - **HIGH:** auto-resolve. Mark `[x]` in the meeting note (if <30 days, per CT-1). Move to "Delivered" in deliverables memory (per CT-2). If a task manager MCP is available, update task status to done. Log in DN: `[auto-reconciled] "item" <- source (confidence: high)`
   - **MEDIUM/LOW:** flag for review. Add entry to `00-Dashboard/alerts.md` section `## Reconciler Candidates`, with domain tag. Format: `- 🔄 **[reconcile-candidate]** \`<domain>\` YYYY-MM-DD — "action item" <- source [confidence: medium, source: log]`. Domain: determine from the action item's origin (meeting note folder, project context, etc.). Do not change anything until the user confirms.
5. **LOG** results. If zero matches: silence (do not pollute the DN).

## CSR-2. Safety guardrails

- Never auto-resolve without concrete evidence (link, file, explicit declaration)
- Never edit a meeting note older than 30 days
- Max 5 auto-resolves per run. If more: flag everything, something is wrong
- If the user corrects an auto-resolve: log in DN and report for adjustment

## CSR-3. Direct user declaration

When the user declares an item as done ("already did it", "done", "completed", "finished"):
1. Identify which open action item corresponds
2. Execute the full resolve cycle (meeting note + deliverables memory + task manager if available)
3. Log: `[user-declared] "item" (confidence: high, source: direct)`

Direct declaration is the most reliable signal. No matching needed.
