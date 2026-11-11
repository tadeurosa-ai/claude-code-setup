# Changelog

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
