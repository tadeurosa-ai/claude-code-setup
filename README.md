# Claude Code Setup Lite

**Setup profissional do Claude Code em um comando — para devs e criadores brasileiros.**

> Por [Tadeu Rosa](https://github.com/tadeurosa-ai) · CC BY-NC-ND 4.0

---

## O problema

Você instalou o Claude Code. Ele funciona. Mas está longe do potencial real.

Sem uma estrutura certa, você:
- Repete contexto toda vez que abre uma conversa nova
- Perde tempo com configurações que poderiam ser automáticas
- Não usa skills, hooks nem memória persistente
- Trabalha com o Claude como se fosse só um chat

---

## O que este setup faz

```
~/.claude/
├── CLAUDE.md          ← Instruções permanentes pro Claude
├── settings.json      ← Configurações otimizadas
├── skills/            ← Comandos personalizados (/daily, /review...)
└── hooks/             ← Automações que rodam em eventos

~/claude/
├── projetos/          ← Contexto por projeto
├── chats/             ← Histórico organizado
└── memory/            ← Memória persistente entre sessões
```

Com isso, o Claude:
- Lembra quem você é e como você trabalha
- Responde no seu estilo sem você pedir
- Executa tarefas recorrentes com um comando
- Mantém contexto entre sessões

---

## Instalação (Lite — grátis)

```bash
curl -fsSL https://raw.githubusercontent.com/tadeurosa-ai/claude-code-setup/main/install.sh | bash
```

Ou clone e rode localmente:

```bash
git clone https://github.com/tadeurosa-ai/claude-code-setup
cd claude-code-setup
bash install.sh
```

**Requisitos:** macOS ou Linux · Claude Code instalado · Git

---

## Backup, formatação e restore

Vai formatar a máquina? Quer migrar para um computador novo? Três comandos resolvem.

### 1. Antes de formatar — faça o backup

```bash
bash backup.sh
```

O script salva sua configuração completa do Claude Code (skills, memória, hooks, projetos) em um arquivo `.tar.gz`. Você escolhe onde salvar: USB, iCloud Drive ou Google Drive.

> **Atenção:** este backup cobre **apenas** os arquivos do Claude Code.
> Para documentos, fotos e vídeos use **Time Machine** (Mac) ou **Backup e Restauração** (Windows) antes de formatar.

### 2. Formate normalmente

Formate a máquina, instale o sistema operacional e instale o Claude Code:

```
https://claude.ai/code
```

### 3. Restaure tudo

```bash
bash restore.sh
```

O script localiza o backup automaticamente (iCloud, Google Drive, Downloads ou Desktop), verifica a integridade e restaura tudo no lugar certo. Se houver algum arquivo existente, pergunta antes de substituir.

Também funciona passando o caminho direto:

```bash
bash restore.sh /Volumes/USB/claude-code-snapshot-20260416-120000.tar.gz
```

**Compatível com:** macOS · Linux · Windows (Git Bash)

---

## O que está incluído no Lite

| Componente | Lite (grátis) | Pro (pago) |
|---|---|---|
| Estrutura de pastas | ✓ | ✓ |
| CLAUDE.md base | ✓ | ✓ completo |
| Skills essenciais (3) | ✓ | ✓ 20+ skills |
| Hooks de automação | — | ✓ |
| Memória persistente | — | ✓ |
| RTK (economy de tokens) | — | ✓ |
| Guia completo em PT | — | ✓ |
| Suporte direto | — | ✓ Pro |

---

## Skills incluídas no Lite

### `/daily`
Resumo do dia: tarefas abertas, contexto de projetos, próximos passos.

### `/review`
Revisão de código com foco em segurança, qualidade e boas práticas.

### `/backlog`
Salva ideias e tarefas no backlog sem sair do fluxo.

---

## Quer o setup completo?

O **Claude Code Setup Pro** inclui tudo que uso no meu trabalho real:

- 20+ skills prontas (daily, review, deploy, pesquisa, conteúdo...)
- Hooks que executam ações automáticas em eventos do Claude
- Sistema de memória que persiste contexto entre sessões
- RTK — proxy que reduz uso de tokens em 60-90%
- Guia completo em português passo a passo
- Suporte direto para dúvidas de configuração

**→ [Adquirir Setup Pro](https://tadeurosa.gumroad.com/l/claude-code-setup-pro)**

---

## Licença

CC BY-NC-ND 4.0 — uso pessoal permitido.
Redistribuição, venda ou modificação sem autorização proibidos.

© Tadeu Rosa, 2026
