#!/bin/bash
# Memory Nudge: PreCompact hook
# Fires before context compaction to remind agent to persist learnings
# Inspired by Hermes Agent's nudge_interval system

cat <<'NUDGE'
{"additionalContext": "MEMORY NUDGE (PreCompact): Context is about to be compacted. Before losing this context, check if there are unsaved learnings:\n\n1. Did the user correct you or express a preference? → feedback memory file\n2. Did you discover something about a project? → project memory file\n3. Did you find a useful reference (IDs, configs, URLs)? → reference memory file\n4. Were there significant decisions? → decision record in vault + Daily Note\n5. Did you do something complex that worked well? → consider /capture\n\nOnly save genuinely NEW information not already in memory. Skip if nothing worth persisting. Do NOT create duplicate memories."}
NUDGE
