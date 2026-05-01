# /deploy-check — Checklist Pré-Deploy

Garante que nada crítico ficou para trás antes de subir para produção.

## O que faz

Gera um checklist personalizado para o projeto atual, cobrindo:
- Variáveis de ambiente
- Migrations pendentes
- Testes (passou? existe?)
- Secrets expostos
- Versões de dependências
- Plano de rollback

## Uso

```
/deploy-check
/deploy-check staging     ← checklist para subir para staging
/deploy-check prod        ← checklist completo para produção
```

## Checklist gerado

```
## Deploy Checklist — [projeto] — [data]

### Código
- [ ] Todos os testes passando
- [ ] Sem console.log / print de debug
- [ ] Branch atualizada com main/master

### Configuração
- [ ] .env de produção atualizado
- [ ] Sem segredos em código-fonte
- [ ] Variáveis de ambiente documentadas

### Banco de dados
- [ ] Migrations rodadas em staging
- [ ] Backup recente confirmado

### Pós-deploy
- [ ] Health check respondendo
- [ ] Monitoramento ativo
- [ ] Plano de rollback: [como reverter]
```

## O que NÃO faz

- Não executa o deploy
- Não roda os testes
- Não verifica o servidor diretamente

---
*Claude Code Setup PRO — by Tadeu Rosa · CC BY-NC-ND 4.0*
