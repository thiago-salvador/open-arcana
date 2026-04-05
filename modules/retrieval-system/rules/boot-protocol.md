---
description: "Boot sequence e retrieval layers (Engram-inspired). Hot-cache no boot, demais sob demanda."
---

# Protocolo de Boot

## Na inicialização (auto-loaded pelo SessionStart hook)

1. **MEMORY.md** - índice de memory files (auto-loaded pelo Claude Code memory system)
2. **Daily Note de hoje** - criar se não existir (com frontmatter + Rules Manifest). Checar Estado Atual e pendências.
3. **Hot cache** - Tier 1+2 notes injetadas automaticamente pelo `session-scan.sh`

Concept-index e aliases NÃO são carregados no boot (só contagem). Ler sob demanda.

## Retrieval sob demanda (Engram layers)

Usar SOMENTE quando a tarefa exigir:

| Layer | Quando usar | Como |
|-------|-------------|------|
| 1. Concept index / aliases | Task menciona conceito específico | Lookup em `00-Dashboard/concept-index.md` ou `aliases.md` |
| 2. Grep filtrado | Layer 1 não resolveu | `grep -rl "termo" <pasta-filtrada>/` max 5 results |
| 3. Smart Connections | Grep retorna vazio E conceito não está no index | `ob-smart-connections` MCP, max 3 results |
| 4. Fallback | Todas as camadas retornaram vazio | Listar arquivos recentes no domínio ativo (`ls -t <pasta>/`) ou pedir clarificação ao usuário |

**Context-Aware Gating:** Antes de buscar (layers 3-4), definir domínio ativo (work, studio, content, research, personal) para filtrar resultados irrelevantes.

**Budget:** max 3 reads completos por query. Se precisa mais, ler summaries no frontmatter primeiro.

## Rules Manifest (adicionar na Daily Note se ausente)

```markdown
## Rules Manifest
> [!info] Regras ativas
> - `core-rules.md` - 12 regras operacionais + pre-delivery (5 checks); anti-sycophancy só em `anti-sycophancy.md`
> - `anti-sycophancy.md` - 6 regras AS: confidence tags, challenge-previous, unanimidade, conflicts, independent analysis, memory decay
> - `boot-protocol.md` - Boot + retrieval layers
> - `connected-sources.md` - Fontes MCP + known issues
> - `content.md` - Identidade editorial (scope: 30-Content/)
> - `pessoas.md` - Formato pessoas (scope: 70-People/)
> - `work.md` - Contexto Work (scope: 10-Work/)
> - `memory/MEMORY.md` - Memory files (feedback, project, reference)
```

## Sistema de Memória

```
~/.claude/projects/.../memory/
├── MEMORY.md           → Índice
├── feedback_*.md       → Regras aprendidas (14)
├── project_*.md        → Contexto projetos (3)
└── reference_*.md      → Dados de referência (6)
```
