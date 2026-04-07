---
name: recall
description: "Search previous sessions by keyword or prompt content. Requires tools/session_index.py."
allowed-tools: "Read,Grep,Bash"
---

# /recall -- Cross-Session Search

Search previous sessions that mentioned "$ARGUMENTS".

## Procedure

1. **Update index** (incremental, <5s):
```bash
python3 {{VAULT_PATH}}/../tools/session_index.py --incremental
```

2. **Search the JSONL** for the given term(s):
```bash
grep -i "$ARGUMENTS" {{VAULT_PATH}}/00-Dashboard/session-index.jsonl
```

3. **Process results:**
   - Extract: date, first_prompt, keywords, prompt_count
   - Sort by date (most recent first)
   - Show top 10 matches

4. **Response format:**

```
## Sessions found for "$ARGUMENTS"

| Date | First Prompt | Keywords | Prompts |
|------|-------------|----------|---------|
| ... | ... | ... | ... |
```

5. **If the user asks for details on a specific session:**
   - Read the corresponding entry from the JSONL (field `all_prompts` in the index)
   - Extract relevant excerpts
   - NEVER dump raw JSONL into context. Summarize.

## Constraints

- Max 10 results in initial response
- If grep returns 0: suggest alternative terms or a broader search
- Token budget per recall: ~1-3K tokens
- Do not read raw session JSONL unless the user asks for details
