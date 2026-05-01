# /estimate — Estimativa de Tempo

Quebra uma tarefa em subtarefas com estimativas realistas.

## O que faz

Analisa a tarefa descrita e produz:
- Breakdown em subtarefas concretas
- Estimativa de tempo para cada uma (melhor caso / pior caso)
- Total com margem de segurança
- Riscos que podem afetar o prazo

## Uso

```
/estimate adicionar login com Google
/estimate refatorar módulo de pagamentos
/estimate criar API REST para o app mobile
```

## Formato

```
## Estimativa — [tarefa]

| Subtarefa | Melhor | Pior |
|-----------|--------|------|
| [item 1]  | Xh     | Yh   |
| [item 2]  | Xh     | Yh   |

**Total:** X–Y horas  
**Com margem (20%):** X–Y horas

### Riscos
- [risco 1]: pode adicionar X horas se ocorrer
- [risco 2]: depende de [dependência externa]

### Premissas
- [o que foi assumido para esta estimativa]
```

## Dica

Sempre compartilhe a estimativa em faixas (melhor/pior caso) — nunca um número único. Isso define expectativas realistas com o cliente.

---
*Claude Code Setup PRO — by Tadeu Rosa · CC BY-NC-ND 4.0*
