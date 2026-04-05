---
description: "Regras para notas de pessoas em 70-Pessoas/"
paths: ["70-Pessoas/**"]
---

# Regras para Notas de Pessoas

## Campos obrigatórios no frontmatter

```yaml
type: person
last_interaction: "YYYY-MM-DD"  # Atualizar a cada interação
pending_items: []               # Action items pendentes com esta pessoa
```

## Ao atualizar uma pessoa

1. Atualizar `last_interaction` com data da interação mais recente
2. Atualizar `pending_items` (adicionar novos, remover resolvidos)
3. Adicionar informações ao corpo da nota (Background, Interações, etc.)
4. NUNCA inventar dados. Se não sabe, deixe em branco

## Ao criar pessoa nova

1. Buscar no vault se já existe nota (grep pelo nome)
2. Usar template de 80-Templates/ se disponível
3. Frontmatter completo com summary descritivo
4. Atualizar index.md de 70-Pessoas/

## Relationship decay

Se `last_interaction` > 14 dias para contatos importantes, alertar no end-of-day.
