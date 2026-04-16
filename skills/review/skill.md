# /review — Revisão de Código

Revisa código com foco em segurança, qualidade e boas práticas.

## O que faz

Analisa o código atual ou o arquivo indicado e aponta:
- Vulnerabilidades de segurança (OWASP Top 10)
- Bugs potenciais
- Code smells e problemas de manutenibilidade
- Sugestões de melhoria (sem refatorar automaticamente)

## Uso

```
/review                    ← revisa arquivos modificados
/review src/auth.ts        ← revisa arquivo específico
/review --security-only    ← foco só em segurança
```

## O que NÃO faz

- Não refatora automaticamente
- Não adiciona features
- Não muda lógica de negócio

---
*Claude Code Setup Lite — by Tadeu Rosa · CC BY-NC-ND 4.0*
