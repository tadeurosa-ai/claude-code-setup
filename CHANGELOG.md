# Changelog

## Memória: a memória automática do próprio Claude Code (install.sh e modelo do CLAUDE.md)

- O instalador não cria mais `~/.claude/memory/`. O Claude Code já vem com a memória automática ligada; ela fica em `~/.claude/projects/<projeto>/memory/`, e o comando `/memory` mostra os arquivos de memória e liga ou desliga a memória automática.
- Se você já tem `~/.claude/memory/`, ela continua como está: o instalador não mexe nela.
- Se você já tem `~/.claude/CLAUDE.md`, ele não é alterado e continua citando `~/.claude/memory/`. O modelo novo fica em `~/.claude/CLAUDE.md.example`: compare os dois e, se quiser, troque a seção antiga de memória pela seção "Memória" do modelo novo.
- O README ainda cita `~/.claude/memory/`; ele será atualizado.

## Instalação do Claude Code pelo instalador oficial (install.sh)

- Quando o Claude Code não está instalado, o `install.sh` usa o instalador oficial (`curl -fsSL https://claude.ai/install.sh | bash`). Não instala mais por npm, Homebrew nem nvm.
- O instalador oficial põe o Claude Code em `~/.local/bin`. Se essa pasta ainda não está no caminho do seu terminal, o fim da tela mostra o comando para acrescentá-la no arquivo do seu terminal (zsh: `~/.zshrc`; bash no Linux: `~/.bashrc`; bash no Mac: `~/.bash_profile`) e pede para abrir um terminal novo. O script não mexe nesses arquivos.
- O setup para e mostra o que fazer quando: falta o `curl` (diz como instalar); o instalador falha (mostra o comando oficial e o link da documentação); o instalador termina mas o Claude Code não aparece, ou o Claude Code não responde a `claude --version` (mostra o link da página de ajuda).
- Windows: o setup roda no macOS, no Linux e no WSL. No Windows, abra o terminal do WSL (por exemplo, Ubuntu) e rode o comando de instalação lá.

## Skills com nomes novos (install.sh e repair.sh)

Três skills mudaram de nome, porque o nome antigo era igual ao de um comando do próprio Claude Code (`/debug` e `/context` passavam na frente do comando do Claude Code):

| Antes | Agora |
|---|---|
| `/review` | `/revisar-codigo` |
| `/debug` | `/depurar` |
| `/context` | `/contexto-projeto` |

O arquivo de cada skill passa a se chamar `SKILL.md`, e cada skill do pacote leva a marca `origem: claude-code-setup` no início do arquivo.

**Se você já tinha as skills instaladas, ao rodar o `install.sh` de novo:**
- As antigas `review`, `debug` e `context` que vieram deste pacote saem de `~/.claude/skills` e são guardadas em `~/.claude/skills-antigas-setup-<data>/`. Nada é apagado.
- Uma skill sua com um desses três nomes (que não veio do pacote) fica onde está, e a tela avisa.
- As outras skills do pacote que ainda têm o arquivo `skill.md` passam a se chamar `SKILL.md`, com o mesmo conteúdo.
- Uma skill do pacote que você editou continua com a sua edição; a versão nova vai para a subpasta `.example/`.
- Se você escreveu alguma coisa depois da linha de rodapé de uma skill antiga do pacote, o instalador não mexe nela e mostra na tela como migrar: apagar o que vem depois do rodapé e rodar o instalador de novo.
- Arquivos seus com conteúdo nunca são movidos nem renomeados. Um arquivo de skill vazio (0 bytes) numa pasta do pacote é tratado como quebrado e trocado pela versão do pacote; se ele estiver ao lado de um arquivo com conteúdo, é guardado na pasta de antigas.

O `repair.sh` confere os mesmos casos e só manda rodar o instalador de novo quando ele resolve.

## backup.sh e restore.sh 1.3.0

> ⚠️ **Atualize o restore antes de restaurar um backup novo.** Um backup feito com o `backup.sh` 1.3.0 precisa do `restore.sh` 1.3.0 ou mais novo. O `restore.sh` antigo (1.1.0) restaura esse backup sem dar erro, mas deixa vazias as chaves do `env` no `settings.json`, sem avisar. Antes de restaurar, baixe o repositório de novo (`git pull`) e confira a versão na 4ª linha do `restore.sh` (`# Versão: 1.3.0`).

**Backup**
- O backup "sem senhas" (nuvem, ou pasta local com "N") deixa de fora arquivos com chave privada ou token no conteúdo, cópias do `settings.json` e as cópias `.anterior-<data>` que o restore cria. Cada arquivo retirado aparece na tela pelo nome.
- Atalhos (links) dentro de `~/.claude` e `~/claude` são registrados e voltam como atalho quando o restore substitui as pastas (opção 1).
- As permissões das pastas (por exemplo, `~/.claude` só para o dono) são registradas.
- Não para mais quando o terminal não consegue limpar a tela (`TERM=dumb`).

**Restore**
- Se for interrompido (Ctrl+C), desfaz o que começou e mostra onde ficou cada pasta.
- O que estava no lugar fica guardado numa pasta `.anterior-<data>`, sempre com nome único.
- Uma pasta fora de `~/.claude` e `~/claude` que já existe só é substituída se você responder "s".
- As permissões registradas só fecham, nunca abrem. Quando o restore substitui as pastas (opção 1), elas já nascem fechadas.
