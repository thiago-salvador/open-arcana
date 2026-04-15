---
name: capture
description: "Captures knowledge from the current session into the vault. Use at the end of a work session. Interactive -- asks what to capture (decision, bug fix, pattern, concept), classifies it, creates atomic note in correct vault location, updates index and MOCs."
dependencies: "vault-read, smart-connections MCP"
allowed-tools: "Read,Write,Edit,Glob,Grep,mcp__ob-smart-connections__*"
---

# /capture

Post-session capture. INTERACTIVE model.

## Flow

### 1. Ask what to capture
Ask:
- "What is worth saving from this session? (technical decision, bug fix, pattern learned, new concept)"
- "Which project does this relate to?"

### 2. Classify and create
Depending on the type:
- **Technical decision** -> create in the project's folder using Decision Record template
- **Bug fix** -> create in the project's errors folder using Error Solution template
- **Pattern/concept** -> create in the relevant domain folder (include `reviewed: false` in frontmatter)
- **Rule/convention** -> create in `85-Rules/` (type=reference, include `reviewed: false`)
- **Project update** -> update note in `15-Projects/`

For notes with `type: concept | knowledge | reference`, ALWAYS include `reviewed: false` in frontmatter. The validation hook warns if missing. The user flips to `true` when they review the note manually.

### 3. Update context
- Update `index.md` of the modified folder
- Update relevant MOC if the note creates a new connection
- Ask: "Want me to update the Daily Note with this capture?"

### 4. Output
```
Captured: [note title]
Type: [decision/error-solution/concept/rule]
Location: [path]
Connections: [wikilinks created]
```

## Rules
- If any MCP fails: ask the user, do not block
- Never fabricated content
- One capture = one atomic note

## When to use (vs other commands)

Quick knowledge capture from the current session. Different from /end (which closes the entire day, with external source collection and tomorrow prep) and /process (which transforms raw external material into atomic notes).
