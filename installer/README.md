# Instalador do BIM Coder Claude Kit

Instalador "1 clique" (`.exe`) que o aluno baixa na aula e executa para instalar o plugin no Claude Code. Gerado com **Inno Setup 6+**.

## Arquivos (fonte — versionado aqui)

| Arquivo | O que é |
|---|---|
| `Instalar-Plugin-Claude.iss` | Fonte do Inno Setup. Embute o `.ps1` (`dontcopy` + `ExtractTemporaryFile`) e o executa no `ssPostInstall`. Gera `output/Setup-BIMCoder-Claude-Kit-{versao}.exe`. |
| `Instalar-Plugin-Claude.ps1` | O motor do instalador (roda dentro do `.exe`). |

O `.exe` compilado **não** é versionado (é binário; distribuído pela aula do curso).

## O que o instalador faz (6 passos do `.ps1`)

1. Verifica **Git** (instala via winget/choco se faltar).
2. Verifica **Node.js** LTS 18–22 (winget `OpenJS.NodeJS.LTS`, ou MSI direto do nodejs.org como fallback).
3. Configura `npm` para arch x64.
4. (Re)instala o **Claude Code CLI** (`@anthropic-ai/claude-code`) limpo.
5. Clona/atualiza o repo do GitHub (`CursoPluginspyRevit/claude-plugin`) em `%USERPROFILE%\.bimcoder-claude-plugin`.
6. Registra como marketplace local e instala: `claude plugin marketplace add` + `claude plugin install bimcoder-claude-kit@bimcoder-claude-kit`.

Wizard em pt-BR, per-user (sem UAC), sem desinstalador.

## Como compilar

1. Instale o Inno Setup 6+ (https://jrsoftware.org/isdl.php).
2. Compile o `.iss` (abrir no Inno Setup → Build, ou `iscc Instalar-Plugin-Claude.iss`).
3. O `.exe` sai em `output/`. Suba-o na aula (área de membros).

## Versão

Controlada por `#define MyAppVersion` no `.iss`. O `AppId`/GUID (`{540EFCD3-...}`) é **fixo** entre versões, para o Windows tratar reinstalações como atualização. Atual: **0.2**.

> Origem: este fonte foi resgatado de `G:\Meu Drive\04. Lives\2026\005 - Lives de Maio\00 - PIV0526\` (onde vivia solto, fora do Git) e versionado aqui em 01/06/2026.
