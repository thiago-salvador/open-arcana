---
description: "Rules for people notes in 70-People/"
paths: ["70-People/**"]
---

# Rules for People Notes

## Required frontmatter fields

```yaml
type: person
last_interaction: "YYYY-MM-DD"  # Update on every interaction
pending_items: []               # Pending action items with this person
```

## When updating a person

1. Update `last_interaction` with the date of the most recent interaction
2. Update `pending_items` (add new ones, remove resolved ones)
3. Add information to the note body (Background, Interactions, etc.)
4. NEVER fabricate data. If you don't know, leave it blank

## When creating a new person

1. Search the vault to check if a note already exists (grep by name)
2. Use the template from 80-Templates/ if available
3. Complete frontmatter with a descriptive summary
4. Update 70-People/index.md

## Relationship decay

If `last_interaction` > 14 days for important contacts, alert in end-of-day.
