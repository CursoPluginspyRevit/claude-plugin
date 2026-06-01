---
name: criar-extension
description: Cria a estrutura raiz de uma extension pyRevit. Gera a pasta MinhaExtensao.extension, o extension.json com metadata (nome, autor, versão), o _layout.yaml vazio e oferece criar uma tab logo em seguida via /criar-tab.
---

# Criar Extension. Estrutura Raiz pyRevit

Você é especialista em criar extensions pyRevit. Esta skill gera a estrutura raiz de uma extension nova: pasta `.extension/`, arquivo `extension.json` com metadata e `_layout.yaml` inicial.

## Quando esta skill é acionada

- O aluno digita `/criar-extension` (sozinho ou com nome inline)
- O aluno explicitamente diz "quero criar uma extension nova"
- O aluno está numa pasta vazia e precisa começar do zero

## NÃO use esta skill quando

- O aluno já está dentro de uma `.extension/` existente (não recrie)
- O aluno quer adicionar uma tab a uma extension existente. Use `/criar-tab`

---

## Fluxo obrigatório

### Passo 0. Carregar contexto

Leia `references/regras-essenciais.md` uma vez se as regras ainda não estiverem no seu contexto. Tenha em mente:
- `references/pyrevit-fundamentals.md` (estrutura de extension, `extension.json`, layout)

### Passo 1. Detectar contexto da pasta atual

Verifique o cwd:

1. **Se cwd já termina em `.extension`** → avisa que já está em uma extension, pergunta se quer criar nova ao lado ou cancelar
2. **Se cwd tem `.extension/` filhas** → lista e pergunta se é pra criar mais uma ao lado das existentes
3. **Se cwd está limpo** → criar a extension aqui

### Passo 2. Coletar nome e metadata

Pergunte UMA vez:

> "Qual o nome da extension e uma descrição curta?
>
> Exemplo: 'MinhaFerramenta. ferramentas pessoais de cotagem, exportação e auditoria.'"

Extraia:
- **Nome da extension** (PascalCase, sem espaços, sem acentos). Ex: `MinhaFerramenta`, `RevitTools`
- **Descrição** (texto livre, vai pro `extension.json`)

Pergunte uma segunda vez (única pergunta complementar):

> "Autor da extension? (padrão: BIM Coder)"

Se não responder, usa padrão `"BIM Coder"`.

### Passo 3. Criar estrutura

Operações em ordem:

1. **Criar pasta** `{NomeExtension}.extension/` no cwd
2. **Criar `extension.json`** na raiz da extension:

```json
{
    "name": "{NomeExtension}",
    "description": "{descrição}",
    "author": "{autor}",
    "rocket_mode_compatible": true,
    "version": "1.0.0"
}
```

3. **Criar `_layout.yaml`** vazio (ou com comentário explicativo):

```yaml
# Ordem das tabs nesta extension.
# Adicione o nome de cada .tab/ (sem extensão) na ordem desejada.
# Ex:
#   - Producao
#   - Documentacao
#   - Auditoria
```

### Passo 4. Confirmar entrega

Mostre confirmação enxuta:

```
Extension criada: {NomeExtension}

Pasta:        {NomeExtension}.extension/
Arquivos:
  - extension.json   (metadata)
  - _layout.yaml     (vazio, vai ser preenchido conforme tabs forem criadas)

Para o pyRevit detectar:
  1. Mova ou crie symlink desta pasta dentro de:
     %APPDATA%\pyRevit\Extensions\ (ou GitHubAddins/)
  2. OU adicione a pasta atual como "Custom Extension Folder" nas
     settings do pyRevit (pyRevit > Settings > Custom Extension Folders)
  3. Reinicie o Revit
```

### Passo 5. Próximo passo

Pergunte:

> "Quer criar a primeira tab agora?
> 1. Sim, criar com `/criar-tab`
> 2. Não, vou organizar manualmente
> 3. Vou primeiro mover pra pasta certa do pyRevit"

Se aluno escolher 1, acione `/criar-tab` no contexto da extension recém-criada.

---

## Edição posterior

Se o aluno quiser renomear a extension, editar descrição ou versão:

- **Renomear:** renomear a pasta `.extension` (manual ou via comando) + atualizar `name` em `extension.json`
- **Mudar descrição/versão:** editar `extension.json` direto

Aplique Edição Cirúrgica. Não recrie a estrutura.

---

## O que NÃO fazer

- **Não criar extension dentro de outra extension.** Não tem suporte aninhado no pyRevit.
- **Não esquecer do `extension.json`.** Sem ele, o pyRevit pode não detectar a extension.
- **Não criar `.tab/`, `.panel/` ou `.pushbutton/` nesta skill.** Cada uma tem sua skill própria.
- **Não usar acentos nem espaços no nome da pasta.** Use PascalCase ASCII.
