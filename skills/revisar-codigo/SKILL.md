---
name: revisar-codigo
description: "Revisa código com foco em segurança, qualidade e boas práticas."
metadata:
  origem: claude-code-setup
---
# /revisar-codigo — Revisão de Código

Revisa código com foco em segurança, qualidade e boas práticas.

## O que faz

Analisa o código atual ou o arquivo indicado e aponta:
- Vulnerabilidades de segurança (OWASP Top 10)
- Bugs potenciais (incluindo edge cases)
- Code smells e problemas de manutenibilidade
- Sugestões de melhoria (sem refatorar automaticamente)
- Complexidade excessiva

## Uso

```
/revisar-codigo                    ← revisa arquivos modificados
/revisar-codigo src/auth.ts        ← revisa arquivo específico
/revisar-codigo --security-only    ← foco só em segurança
/revisar-codigo --quick            ← revisão rápida, só críticos
```

## Severidade dos achados

| Nível | Significado |
|-------|-------------|
| 🔴 CRÍTICO | Bug ou vulnerabilidade que vai em produção |
| 🟠 ALTO | Risco real, corrigir antes do deploy |
| 🟡 MÉDIO | Corrigir no sprint atual |
| 🟢 BAIXO | Melhoria técnica, quando possível |

## O que NÃO faz

- Não refatora automaticamente
- Não adiciona features
- Não muda lógica de negócio sem aprovação explícita

---
*Claude Code Setup — by Tadeu Rosa · CC BY 4.0*
