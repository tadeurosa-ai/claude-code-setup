# /debug — Protocolo de Debugging Estruturado

Para de tentar na tentativa e erro. Debugging sistemático que resolve mais rápido.

## O que faz

Guia você (e o Claude) por um protocolo estruturado:
1. **Descrever** o comportamento esperado vs. o atual
2. **Levantar hipóteses** ordenadas por probabilidade
3. **Isolar** o problema com o menor caso reproduzível
4. **Testar** hipótese por hipótese
5. **Documentar** a causa raiz e a solução

## Uso

```
/debug
/debug [descrição breve do problema]
```

Exemplo:
```
/debug usuário não consegue fazer login após mudar senha
```

## Protocolo

```
## Debug — [problema] — [data]

### Comportamento esperado
[o que deveria acontecer]

### Comportamento atual
[o que está acontecendo — com mensagem de erro se houver]

### Ambiente
- [linguagem/framework/versão]
- [quando começou a acontecer]
- [acontece sempre ou só às vezes?]

### Hipóteses (por probabilidade)
1. [hipótese mais provável]
2. [hipótese 2]
3. [hipótese 3]

### Menor caso reproduzível
[snippet mínimo ou passos para reproduzir]

### Testes
- [ ] Hipótese 1: [resultado]
- [ ] Hipótese 2: [resultado]

### Causa raiz
[o que causou o problema]

### Solução aplicada
[o que foi feito para resolver]
```

## O que NÃO faz

- Não executa código diretamente
- Não garante que vai resolver — garante que vai encontrar o problema

---
*Claude Code Setup PRO — by Tadeu Rosa · CC BY-NC-ND 4.0*
