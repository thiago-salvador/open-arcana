# Completion Tracking (3 rules)

## CT-1. Mark action items in meeting notes

When a task originated from a meeting is completed during a session:
1. Edit the meeting note: change `- [ ]` to `- [x]` on the corresponding item
2. If the meeting note is older than 30 days, do not edit (it is historical)

This prevents meeting notes with open checkboxes from being treated as a source of pending items.

## CT-2. Record deliverables in memory

When completing significant work for any project with delivery tracking:
1. Update the project's deliverables memory file (`project_*_deliverables.md` or equivalent)
2. Move the item from "Pending" to "Delivered" with the date
3. If the item was discarded, move it to "Discarded" with the reason

Without completion records, future sessions re-list work that was already done. This wastes time and erodes trust.

## CT-3. End-of-session warning if deliverables not updated

If the Daily Note has entries for significant work (grep for `**` bold entries with project/domain tags) but no `[auto-reconciled]` or `[user-declared]` entry appears, AND the deliverables memory was not edited in the session, the agent should warn before closing:

> "There was significant work in this session but no deliverable was updated. Want me to update the tracking?"
