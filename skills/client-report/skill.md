# /client-report — Relatório para Cliente

Converte o trabalho técnico em linguagem de negócio para o cliente.

## O que faz

Gera um relatório quinzenal (ou semanal) com:
- Resumo executivo do progresso
- Funcionalidades entregues (em linguagem não técnica)
- Métricas relevantes (tempo, entregas, pendências)
- Próximos passos
- Perguntas que precisam de resposta do cliente

## Uso

```
/client-report
/client-report semanal       ← relatório da semana
/client-report quinzenal     ← padrão
/client-report mensal        ← visão do mês
```

## Formato

```
## Relatório de Progresso — [período]
**Projeto:** [nome]  
**Responsável:** [seu nome]

### Resumo
[2-3 frases sobre o estado geral do projeto]

### O que foi entregue
- [funcionalidade em linguagem de usuário]
- [funcionalidade em linguagem de usuário]

### Em desenvolvimento
- [item] — previsão: [data]

### Precisamos de você
- [decisão ou informação pendente do cliente]

### Próximos passos
1. [passo]
2. [passo]
```

## Dica

Use junto com `/standup cliente` para comunicação diária e `/client-report` para comunicação formal quinzenal.

---
*Claude Code Setup PRO — by Tadeu Rosa · CC BY-NC-ND 4.0*
