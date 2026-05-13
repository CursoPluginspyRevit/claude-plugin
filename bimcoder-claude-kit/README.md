# BIMCoder Claude Kit

Toolkit de plugin Claude Code para criar extensões pyRevit com IA.

## O que é

Conjunto de skills, agentes e regras para Claude Code (https://claude.com/claude-code) que acelera a criação de plugins pyRevit. Você descreve a ideia em linguagem natural, o assistente conduz o planejamento, escreve o código com as armadilhas conhecidas já tratadas e empacota tudo na estrutura correta de uma `.extension` do pyRevit.

Não substitui aprender a Revit API. Substitui o trabalho repetitivo de lembrar de cada detalhe (encoding correto, transação no padrão certo, ícones em dois temas, layout.yaml, etc).

## Status

Em construção. Versão 0.1.

## Skills planejadas

| Skill | O que faz |
|---|---|
| `/planejar-plugin` | Conduz entrevista estratégica em 5 camadas e gera plano técnico antes do código |
| `/criar-extension` | Cria a estrutura raiz de uma extension pyRevit |
| `/criar-tab` | Adiciona uma tab dentro de uma extension existente |
| `/criar-panel` | Adiciona um panel |
| `/criar-pushbutton` | Cria pushbutton completo: script.py, ícones dual 96x96, bundle.yaml, layout.yaml |
| `/criar-script` | Preenche o `script.py` aberto no editor a partir de descrição em linguagem natural. Atua direto no arquivo em foco |
| `/criar-pulldown` | Cria pulldown com sub-pushbuttons |
| `/criar-stack` | Cria stack de 2 ou 3 botões |
| `/criar-dockable-pane` | Cria painel ancorado nativo do Revit (startup, singleton, XAML, provider) |
| `/criar-form-wpf` | Cria janela WPF customizada |
| `/criar-instalador-inno` | Gera instalador Inno Setup (.iss) para distribuir a extension |
| `/migrar-csharp` | Porta um pushbutton pyRevit para Add-in C# |
| `/buscar-icone` | Sugere ícones do Iconify a partir da ideia em português |
| `/auditar-extension` | Varre a extension procurando armadilhas conhecidas |
| `/consultar-api` | Busca rápida no dicionário da Revit API |
| `/debugar-pyrevit` | Diagnóstico de erros comuns (lentidão, _wpf, modulo nao encontrado) |

## Roadmap

- [ ] **Fase 1 (MVP).** `planejar-plugin` + `criar-pushbutton` + `criar-script` + 3 hooks principais
- [ ] **Fase 2 (Esqueleto).** `criar-extension`, `criar-tab`, `criar-panel`, `criar-pulldown`, `criar-stack`, `auditar-extension`
- [ ] **Fase 3 (Avançado).** `criar-dockable-pane`, `criar-form-wpf`, `criar-instalador-inno`, `migrar-csharp`, `debugar-pyrevit`

## Como usar

O kit é distribuído como **plugin global do Claude Code**. Instalação prevista (a finalizar):

1. Clonar o repositório em `~/.claude/plugins/bimcoder-claude-kit/` (ou instalar via marketplace do Claude Code quando publicado)
2. Abrir o Claude Code direto dentro da pasta da extension pyRevit que está desenvolvendo (ex: `MinhaExtensao.extension/`)
3. As skills `/planejar-plugin`, `/criar-script`, `/criar-pushbutton` etc. ficam disponíveis automaticamente em qualquer pasta

Atualizações: o kit aprende com o uso. Novas armadilhas, padrões e métodos da Revit API descobertos no dia a dia são adicionados às `references/` e distribuídos via `git pull` (ou via a skill `/atualizar-kit` quando implementada).

## Autor

BIM Coder (https://www.youtube.com/@bimcoder).

## Licença

A definir.
