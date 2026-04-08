---
name: tree
description: "Visualize session message tree with branch points. Requires tools/session_index.py."
allowed-tools: "Read,Grep,Bash"
---

# /tree -- Session Tree Visualization

Visualize the message tree for a session matching "$ARGUMENTS" (date, keyword, or session ID).

## Procedure

1. **Update index** (incremental, <5s):
```bash
python3 {{VAULT_PATH}}/../tools/session_index.py --incremental
```

2. **Search the JSONL** for matching sessions:
```bash
grep -i "$ARGUMENTS" {{VAULT_PATH}}/00-Dashboard/session-index.jsonl
```

3. **If multiple sessions match**, show a numbered selection list:

```
## Sessions matching "$ARGUMENTS"

| # | Date | First Prompt | Branches |
|---|------|-------------|----------|
| 1 | ... | ... | ... |
| 2 | ... | ... | ... |

Which session? (number or "all")
```

Wait for user selection before proceeding.

4. **For the selected session, read the raw JSONL file:**

The session files live at `~/.claude/projects/<vault-slug>/`. The vault slug is the VAULT_PATH with `/` replaced by `-`.

```bash
# Get the filename from the index entry's "file" field
# Derive vault slug: replace / with - in VAULT_PATH
# e.g., /Users/me/vault -> -Users-me-vault
cat ~/.claude/projects/<vault-slug>/<filename>.jsonl
```

5. **Build and display the tree:**

Parse the JSONL using `uuid` and `parentUuid` fields. Build a tree structure.

### For sessions WITH branches (branch_count > 0):

Display an ASCII tree showing the conversation flow with branch markers:

```
## Session Tree: <date> (<N> branches, depth <M>)

Source: <first_prompt truncated to 80 chars>

◈ "User prompt text here"               [human]
├── ◇ (assistant response)              [assistant]
│   ├── ◈ "Follow-up prompt"            [human]      ← branch point (2 children)
│   │   ├── ◇ (assistant response A)    [assistant]
│   │   │   └── ◈ "Continued on path A" [human]
│   │   └── ◇ (assistant response B)    [assistant]   ← alternative branch
│   │       └── ◈ "Continued on path B" [human]
│   └── ◈ "Different direction"         [human]
└── ◇ (tool result)                     [tool]
```

**Node symbols:**
- `◈` = human prompt (show first 60 chars of text)
- `◇` = assistant response (show "(assistant response)" or first 40 chars if short)
- `○` = tool result / system message (show "(tool result)" or "(system)")
- `▸` = sidechain message (show "(sidechain)")

**Branch markers:**
- Append `← branch point (N children)` to nodes with multiple children
- Append `← alternative branch` to the 2nd+ child of a branch point

### For sessions WITHOUT branches (branch_count = 0):

Display a simple linear timeline:

```
## Session Timeline: <date> (linear, depth <M>)

Source: <first_prompt truncated to 80 chars>

1. ◈ "Initial prompt text"
2. ◇ (assistant response)
3. ○ (tool result)
4. ◇ (assistant response)
5. ◈ "Second user prompt"
6. ◇ (assistant response)
...
```

Only show human prompts with text and assistant responses. Skip tool_result and sidechain messages in linear view (they add noise without branches to contextualize). Show count of skipped messages: `(+N tool/system messages omitted)`

## Tree Building Algorithm

```python
# Pseudocode for building the tree from JSONL

nodes = {}      # uuid -> {type, parent, children, text, is_human, is_sidechain}
roots = []      # nodes with no parent or parent not in nodes

for line in jsonl_lines:
    obj = json.loads(line)
    uuid = obj.get("uuid")
    if not uuid:
        continue
    parent = obj.get("parentUuid")
    msg_type = obj.get("type")

    # Extract text for human messages
    text = ""
    if msg_type == "user":
        content = obj.get("message", {}).get("content", "")
        # Handle string or list content
        # Check if it's a real human prompt (not tool_result)

    nodes[uuid] = {type, parent, children=[], text, ...}
    if parent and parent in nodes:
        nodes[parent]["children"].append(uuid)

roots = [u for u in nodes if nodes[u]["parent"] not in nodes]

# Render tree recursively from roots
def render(uuid, prefix="", is_last=True):
    node = nodes[uuid]
    connector = "└── " if is_last else "├── "
    # ... render with symbols and branch markers
```

## Constraints

- **Token budget:** 2-5K tokens per tree visualization
- **Max display depth:** 20 levels. If tree is deeper, show first 20 levels and note: `... (+N deeper levels not shown)`
- **Max nodes displayed:** 100. If more, collapse tool_result chains into `... (N tool interactions)` 
- **If grep returns 0 matches:** suggest alternative terms or `grep -l` on session files
- **NEVER dump raw JSONL.** Always process into readable tree or timeline.
- **Sidechain messages:** collapse into a single `▸ (sidechain, N messages)` node
- **The tree is for understanding conversation flow, not debugging JSONL format**
