# vault-structure

Obsidian vault folder structure, templates, and rules for use with AI agents (Claude Code, etc.).

## What's included

### `templates/`

18 Templater-compatible templates covering the most common note types:

| Template | Use case |
|----------|----------|
| Daily.md | Daily journal with log format and divergence tracking |
| Meeting.md | Meeting notes with agenda, action items, next steps |
| Project.md | General project note |
| Person.md | Contact/person note with interaction history |
| Partnership.md | Partnership CRM note |
| Event.md | Speaking events and conferences |
| Article-Draft.md | Long-form article drafts |
| Social-Post.md | Social media post drafts |
| Decision-Record.md | Architecture/business decision records |
| Dev-Log.md | Development session logs |
| Error-Solution.md | Bug/error solutions for future reference |
| Hub-Note.md | Hub pages with Dataview queries |
| Knowledge-Note.md | Technical concept notes |
| MOC.md | Map of Content (thematic navigation) |
| Project-Index.md | Project index with tech stack and Dataview |
| Toolbox-Note.md | Tool/library reference notes |
| ConflictReport.md | Divergence tracking between AI sessions (used by anti-sycophancy module) |
| Inbox-Item.md | Raw material staging area |

All templates use Obsidian Templater syntax (`<% tp.* %>`). They contain no personal data.

### `rules/`

| File | Scope | Purpose |
|------|-------|---------|
| `people.md` | `70-People/**` | Rules for person notes: required fields, update protocol, relationship decay alerts |
| `content.md` | `30-Content/**` | Editorial identity framework: voice spectrum, tone matrix, platform guidelines |
| `domain-example.md` | `10-Work/**` | Example of domain-specific rules (team roster, status, data sources). Copy and customize. |

### `scaffold.sh`

Creates the vault folder structure with a single command:

```bash
chmod +x modules/vault-structure/scaffold.sh
./modules/vault-structure/scaffold.sh /path/to/your/vault
```

Creates these folders:
- `00-Dashboard` -- Entry point, weekly reviews
- `10-Work` -- Work/company projects
- `30-Content` -- Content production
- `40-Partnerships` -- Partnership CRM
- `50-Events` -- Speaking and events
- `60-Research` -- Research and references
- `70-People` -- Contact network
- `80-Templates` -- Note templates
- `85-Rules` -- AI agent rules
- `90-Archive` -- Completed/archived items
- `99-Inbox` -- Staging area for raw material
- `Daily-Notes` -- Daily journal
- `MOCs` -- Maps of Content

Each folder (except Daily-Notes and MOCs) gets a placeholder `index.md`.

## Setup

1. Run `scaffold.sh` to create the folder structure
2. Copy templates into `80-Templates/` in your vault
3. Copy rules into `.claude/rules/` in your vault project
4. Edit `domain-example.md` to match your own work context
5. Fill in the voice spectrum and tone matrix in `content.md`

## Dependencies

- Obsidian with Templater plugin (for template syntax)
- Dataview plugin (for Hub-Note and Project-Index queries)
- Optional: anti-sycophancy module (for ConflictReport template)
