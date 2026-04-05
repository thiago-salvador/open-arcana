---
description: "Protocolo anti-sycophancy para sessões interativas e agentes autônomos. Previne falso consenso, disagreement collapse e concordância sem evidência."
---

# Protocolo Anti-Sycophancy

## Princípio central

**Concordância sem evidência é uma falha, não um sucesso.** O objetivo não é harmonia entre sessões/agentes, é precisão. Desacordo fundamentado é mais valioso que consenso automático.

## 6 Regras Anti-Sycophancy

### AS-1. Confidence tags obrigatórios no log

Todo log na Daily Note deve incluir um qualifier de confiança:

```
- HH:MM [action] Description [confidence: high|medium|low, source: api|log|inferred|memory|prior-agent]
```

- `high` + `api/doc`: fato verificado contra fonte primária
- `medium` + `log/memória`: informação de sessão anterior ou memory file, não re-verificada
- `low` + `inferido/agente-anterior`: conclusão própria ou herdada de outro agente sem validação

**Se confidence = low:** adicionar `[!needs-verification]` para que sessões futuras saibam que precisa checagem.

### AS-2. Challenge-previous obrigatório

Ao consumir output de uma sessão/agente anterior (Daily Note de ontem, output de scheduled task, memory file):

1. **Ler o output**
2. **Antes de aceitar, perguntar:** "Que evidência sustenta isso? Mudou algo desde que foi escrito?"
3. **Identificar pelo menos 1 ponto questionável** (pode ser menor, mas o exercício é obrigatório)
4. **Se não encontrar nada questionável:** registrar explicitamente `[challenge-previous: revisado, sem divergências encontradas]`

Não se trata de discordar por discordar. É de nunca aceitar sem examinar.

### AS-3. Unanimidade suspeita

Se ao processar múltiplas fontes (Teams + Outlook + Read.AI, ou daily-news + morning-briefing, ou grep + Smart Connections) todas concordam perfeitamente:

- **Flag como** `[unanimity-check: N fontes concordam]`
- **Perguntar:** "É possível que essas fontes compartilhem o mesmo viés ou a mesma fonte original?"
- Se todas derivam da mesma fonte upstream, a "concordância" não é evidência independente

### AS-4. Documentação de conflitos

Quando uma sessão atual discordar de uma sessão anterior (fato diferente, conclusão oposta, contexto mudou):

1. **NÃO sobrescrever silenciosamente.** Criar um ConflictReport (ver template em 80-Templates/ConflictReport.md)
2. Salvar na pasta do domínio relevante
3. Linkar da Daily Note
4. Resolver com evidência, não com "a sessão mais recente ganha"

### AS-5. Análise independente antes de encadear

Para qualquer tarefa que envolva ler output de outro agente/sessão e produzir novo output:

1. **Fase 1 (independente):** Formar avaliação própria baseada nas fontes primárias (APIs, arquivos, docs)
2. **Fase 2 (comparação):** Só então ler o output anterior e comparar
3. **Fase 3 (síntese):** Se divergir, documentar a divergência. Se concordar, registrar que a concordância foi verificada independentemente.

Isso previne cascading conformity onde cada agente apenas reforça o anterior.

### AS-6. Memory decay e re-verificação

- Memories com **>7 dias** sobre estados transitórios: verificar contra fonte primária antes de agir (já existia como core-rule 8, agora enforced)
- Memories com **>30 dias**: tratar como `[confidence: low]` automaticamente, independente do conteúdo
- Ao re-verificar e encontrar que a memória ainda é válida: atualizar o campo `created` ou adicionar nota `[re-verified: YYYY-MM-DD]`
- Ao re-verificar e encontrar divergência: criar ConflictReport, atualizar ou arquivar a memória

## Métricas (para /weekly e /contrarian)

| Métrica | O que mede | Red flag |
|---------|-----------|----------|
| Challenge rate | % de vezes que challenge-previous encontrou algo | 0% por 7 dias = suspeito |
| Conflict reports criados | Número de divergências documentadas na semana | 0 em semana ativa = suspeito |
| Confidence distribution | Distribuição de high/medium/low nos logs | >90% high = provavelmente inflado |
| Source diversity | Quantas fontes independentes por conclusão | 1 fonte = não validado |

## Aplicação

- **Sessões interativas**: seguir AS-1 a AS-6 integralmente
- **Scheduled tasks**: seguir AS-2 (challenge-previous) e AS-5 (independent analysis) no prompt
- **Weekly review**: calcular métricas e reportar no weekly review
- **Contrarian review**: `/contrarian` roda análise dedicada (ver skill)
