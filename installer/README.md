# Instalador do BIM Coder Claude Kit

Instalador "1 clique" (`.exe`) que o aluno baixa na aula e executa. Na primeira tela ele **escolhe o que instalar**: **Claude Code**, **Codex**, ou os dois. Gerado com **Inno Setup 6+**.

## Arquivos (fonte — versionado aqui)

| Arquivo | O que é |
|---|---|
| `Instalar-Plugin-Claude.iss` | Fonte do Inno Setup. Página de seleção (`[Tasks]` `claude`/`codex`) → passa `-InstallClaude`/`-InstallCodex` pro `.ps1`. Gera `output/Setup-BIMCoder-Claude-Kit-{versao}.exe`. |
| `Instalar-Plugin-Claude.ps1` | O motor. Aceita os switches `-InstallClaude` e `-InstallCodex` (sem nenhum = instala os dois). |

O `.exe` compilado **não** é versionado (é binário; distribuído pela aula do curso).

## O que o instalador faz

**Página de seleção:** o aluno marca "Instalar Claude e seus complementos" e/ou "Instalar Codex e seus complementos" (pelo menos uma — validado no `NextButtonClick`).

**Passos comuns (sempre):**
1. **Git** (instala via winget/choco se faltar) — necessário pra baixar o plugin.
2. **Node.js** LTS — só se for instalar algum CLI (Claude, ou Codex quando ausente).
3. **Clona/atualiza** o repo do GitHub (`CursoPluginspyRevit/claude-plugin`) em `%USERPROFILE%\.bimcoder-claude-plugin`.

**Se "Claude" marcado:**
- (Re)instala o **Claude Code CLI** (`@anthropic-ai/claude-code`) limpo.
- Registra o marketplace local e instala: `claude plugin marketplace add` + `claude plugin install bimcoder-claude-kit@bimcoder-claude-kit`.

**Se "Codex" marcado:**
- Garante o **Codex** (instala o `@openai/codex` CLI só se não houver CLI nem a extensão do VS Code).
- Copia as **16 skills** pra `~/.codex/skills/<nome>/`, cada uma autossuficiente (com as `references/` injetadas dentro). Mesmo formato `SKILL.md` — auto-invocação pela `description`, igual ao Claude.

Wizard em pt-BR, per-user (sem UAC), sem desinstalador.

## Como compilar

1. Instale o Inno Setup 6+ (https://jrsoftware.org/isdl.php).
2. Compile o `.iss` (abrir no Inno Setup → Build, ou `iscc Instalar-Plugin-Claude.iss`).
3. O `.exe` sai em `output/`. Suba-o na aula (área de membros).

## Versão

Controlada por `#define MyAppVersion` no `.iss`. O `AppId`/GUID (`{540EFCD3-...}`) é **fixo** entre versões, para o Windows tratar reinstalações como atualização. Atual: **0.3** (adicionada a seleção Claude/Codex).

### Pendência conhecida
O helper `helpers/icon-fetcher.py` (usado por `buscar-icone` e pelo passo de ícone do `criar-pushbutton`) ainda não é portado pra estrutura por-skill do Codex. As demais skills funcionam normalmente no Codex.

> Origem: este fonte foi resgatado de `G:\Meu Drive\04. Lives\2026\005 - Lives de Maio\00 - PIV0526\` e versionado aqui em 01/06/2026.
