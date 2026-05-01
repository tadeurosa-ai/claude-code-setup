# /pr — Descrição de Pull Request

Gera uma descrição completa e profissional para o seu PR.

## O que faz

Analisa as mudanças no branch atual e produz:
- Título seguindo Conventional Commits
- Sumário das mudanças
- Motivação (por que essa mudança existe)
- Como testar
- Checklist de review

## Uso

```
/pr
/pr fix     ← PR de correção de bug
/pr feat    ← PR de nova funcionalidade
/pr refac   ← PR de refatoração
```

## Formato

```
## [tipo]: [descrição curta]

### O que muda
[2-3 frases sobre o que foi alterado]

### Por que
[motivação — problema que estava acontecendo ou feature solicitada]

### Como testar
1. [passo 1]
2. [passo 2]
3. Espera-se que: [comportamento esperado]

### Checklist
- [ ] Testes passando
- [ ] Sem breaking changes (ou documentados)
- [ ] Documentação atualizada (se aplicável)
- [ ] Sem secrets ou dados sensíveis
```

## Tipos (Conventional Commits)

| Tipo | Quando usar |
|------|-------------|
| `feat` | Nova funcionalidade |
| `fix` | Correção de bug |
| `refactor` | Refatoração sem mudança de comportamento |
| `docs` | Só documentação |
| `test` | Adição ou correção de testes |
| `chore` | Build, dependências, configs |

---
*Claude Code Setup PRO — by Tadeu Rosa · CC BY-NC-ND 4.0*
