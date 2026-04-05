---
description: "Example: domain-specific context rules for a work project folder"
paths: ["10-Work/**"]
---

# Domain Context: [Your Company/Project]

This is an **example** of how to create domain-specific rules for a work folder.
Copy this file, rename it (e.g. `acme-corp.md`), and fill in your own details.

## What it is
<!-- One-liner describing the company/project -->
Example: SaaS startup in the analytics space. Series A, 12 people.

## Team
<!-- List key people the AI agent should know about -->
- **Name** -- Role, relevant context
- **Name** -- Role, relevant context

## Current status
<!-- Snapshot of where things stand. Update periodically. -->
- Phase: (pre-launch, growth, maintenance, etc.)
- Key milestone: (next launch, fundraise, etc.)
- Blockers: (if any)

## Data sources
<!-- Which MCP sources or local folders feed this domain? -->
- Teams / Slack for communication
- Local docs folder: `/path/to/docs/`
- Task manager DB for tasks

## Rules specific to this domain
<!-- Any special handling the AI should know -->
1. Always cross-reference meeting notes with task board
2. Financial data is confidential, never include in public-facing content
3. When processing meeting notes, extract action items with owner and deadline
