---
name: background-review
description: "Review pós-turno invocado quando iteration counter cruza threshold. Decide autonomamente se algo da sessão vale virar memory entry, skill/command, ou distill. 'Nothing to save' é output aceitável."
allowed-tools: "Read,Write,Edit,Bash,Grep,Glob"
---

# /background-review, Turn-Deferred Review

Inspirado no nudge system do Hermes Agent (nousresearch/hermes-agent). Diferença arquitetural: Hermes forka AIAgent em thread background, Open Arcana usa Task subagent dispatch (deferred review no próximo turn).

**Quando é invocado:**

O hook `turn-boundary-check.sh` seta um flag file quando:
1. Turno anterior teve 8+ iterations (trial-and-error signal), OU 5+ iterations com 2+ struggle signals
2. Cumulativo passou de 15 iterations desde último review

Ao iniciar próximo turno, additionalContext manda invocar este command.

## Procedimento

### Step 1: Ler o flag file

```bash
FLAG="/tmp/claude-review-flag-$(date +%Y%m%d).txt"
cat "$FLAG" 2>/dev/null || echo "no-flag"
```

Flags possíveis: `distill|...`, `review|...`. Um ou ambos.

### Step 2: Coletar contexto mínimo

- Daily Note de hoje: `Daily-Notes/$(date +%Y-%m-%d).md`
- Últimas 10-15 linhas adicionadas na DN
- State file: `/tmp/claude-iter-state-$(date +%Y%m%d).json` (turn_tools mostra a sequência)

**NÃO carregar histórico completo da sessão.** Trabalhar só com a DN como proxy.

### Step 3: Escolher template(s)

| Flag | Template | O que avalia |
|------|----------|-------------|
| `distill` | Template A (Distill/Skill) | Houve workflow 5+ steps reusável? |
| `review` | Template B (Memory) | Revelou preferência/correção que deveria virar memory entry? |
| ambos | Template C (Combined) | Ambos + index.md checks |

---

## Template A (Distill / Skill Review)

> Pergunta central: O turno anterior executou um workflow não-trivial que vale ser encapsulado?

**Critérios para ação (TODOS devem bater):**
1. Sequência de 5+ tool calls com outcome coerente
2. Padrão reusável em sessões futuras (não one-off)
3. Pelo menos 1 erro superado OU correção do usuário mid-turn
4. Não existe command/skill parecido em `.claude/commands/` ou rules

**Se todos batem, propor:**
- **Novo command** em `.claude/commands/{nome}.md` com frontmatter padrão + steps numerados
- **Nova rule** em `85-Rules/Workflow/` se for convenção que deve persistir
- **Template** em `80-Templates/` se for estrutura de nota reusável

**Antes de criar**: grep para confirmar que não existe equivalente. Skip se existir.

**Se não bate:** output `"Nothing to distill. Turn had N iterations but no reusable pattern."`

---

## Template B (Memory Review)

> Pergunta central: O usuário revelou preferência, correção, ou fato que deveria virar memory entry?

**Sinais de memória valer captura:**
- Usuário corrigiu abordagem ("não, faz assim...")
- Usuário validou approach não-óbvio ("perfeito, continua assim")
- Fato sobre role/permissões/stack/tools não nos memory files
- Constraint sobre domínio específico

**Classificar tipo:**

| Tipo | Arquivo | Quando |
|------|---------|--------|
| `user_*` | `memory/user_{topic}.md` | Role, knowledge, preferências |
| `feedback_*` | `memory/feedback_{topic}.md` | Regras de trabalho, correções |
| `project_*` | `memory/project_{name}.md` | Estado de projetos |
| `reference_*` | `memory/reference_{topic}.md` | Pointers pra fontes externas |

**Antes de criar:**
1. Grep em `memory/MEMORY.md` por keywords relacionadas
2. Se existe: `Edit` o existente em vez de criar novo
3. Se não: criar arquivo + adicionar linha no MEMORY.md index

**Estrutura:**

```yaml
---
name: {name}
description: {one-line}
type: {user|feedback|project|reference}
---

{rule/fact}

**Why:** {reason the user gave}
**How to apply:** {when/where this kicks in}
```

**Se nada bate:** output `"Nothing to save to memory."`

---

## Template C (Combined + Vault Hygiene)

> Roda A + B + checks adicionais do vault.

**Além de A e B, verificar:**

1. **Index.md updates pendentes?** Se o turn criou nota nova, conferir se index da pasta tem entry.
2. **MOC connections?** Se tocou em 2+ domínios, verificar cross-domain links.
3. **Pessoa nova mencionada sem nota?** Grep last DN entries por nomes próprios. Comparar com `70-Pessoas/` (se vault-structure module ativo).
4. **Decision record faltando?** Se usuário disse "vai com X" e não tem decision record, propor criar.

**Anti-gold-plating:** não criar stubs por stub. Só se há evidência clara.

---

## Step 5: Executar ações (se houver)

Para cada ação:
1. Mostrar o que vai fazer (1 linha)
2. Executar (Write/Edit)
3. Log na Daily Note: `- HH:MM — [background-review] **Action taken.** [confidence: high, source: auto]`

### Step 6: Record outcome + clean up

Esta etapa é **obrigatória** para alimentar adaptive thresholds. Toda invocação grava outcome em `~/.claude/review-history.json`, que o `turn-boundary-check.sh` lê para ajustar thresholds.

```bash
FLAG_TYPE=$(cat /tmp/claude-review-flag-$(date +%Y%m%d).txt 2>/dev/null | head -1 | cut -d'|' -f1)
FLAG_TYPE=${FLAG_TYPE:-unknown}

# Set OUTCOME based on what this review did:
#   OUTCOME="acted"   if you created/edited memory file, skill, command, or vault note
#   OUTCOME="nothing" if you concluded "Nothing to save" (any template)
OUTCOME="nothing"  # default, change to "acted" if you took action

python3 <<PYEOF
import json, time
from pathlib import Path

HIST = Path.home() / '.claude' / 'review-history.json'
HIST.parent.mkdir(parents=True, exist_ok=True)

data = {"history": [], "current_thresholds": None}
if HIST.exists():
    try:
        data = json.loads(HIST.read_text())
    except Exception:
        pass

data.setdefault("history", []).append({
    "ts": time.strftime("%Y-%m-%dT%H:%M:%S"),
    "flag_type": "$FLAG_TYPE",
    "outcome": "$OUTCOME",
})
data["history"] = data["history"][-20:]

HIST.write_text(json.dumps(data, indent=2))
print("Recorded: flag=$FLAG_TYPE outcome=$OUTCOME")
PYEOF

# Delete flag file (marks it as consumed)
rm -f /tmp/claude-review-flag-$(date +%Y%m%d).txt
```

**Por que isso importa:** sem o record, os thresholds ficam estáticos. Com o record, o sistema aprende.

**Nota sobre state reset:** `last_review_iter` é atualizado automaticamente pelo `turn-boundary-check.sh` na emissão. Você não precisa mexer no state file aqui.

### Step 7: Rapid output

Uma linha ou duas no máximo:

```
Background review: {resumo}. Actions: {lista ou 'none'}.
```

## Anti-gold-plating rules (Hermes-inspired)

1. **"Nothing to save" is valid output.** Não force criação.
2. **Prefer Edit over Create.** Merge em memory/skill existente quando possível.
3. **Grep before write.** Confirmar que não existe equivalente.
4. **Max 3 actions por review.** Se identificar mais, salvar as 3 mais fortes.
5. **Não tocar arquivo editado pelo usuário na última hora.**

## Config (future adaptive tuning)

Thresholds atuais são adaptativos via `~/.claude/review-history.json`:
- Last 5 reviews "nothing" → thresholds sobem
- Last 5 "acted" → thresholds descem
- Mixed → defaults

Defaults: distill=8, struggle=5, cumulative=15.
Floor: 4/3/10. Ceiling: 14/9/25.

## Quando NÃO invocar

- Sessão tem <5 iterations totais
- Flag file não existe
- Usuário explicitamente pediu pra não revisar
