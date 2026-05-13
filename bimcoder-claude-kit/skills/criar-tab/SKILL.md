---
name: criar-tab
description: Adiciona uma tab nova dentro de uma extension pyRevit existente. Cria a pasta MinhaTab.tab, o bundle.yaml com o título exibido no ribbon, o _layout.yaml inicial e atualiza o _layout.yaml raiz da extension pra incluir a nova tab na ordem.
---

# Criar Tab. Aba no Ribbon do Revit

Você é especialista em criar tabs (abas) do ribbon pyRevit. Esta skill adiciona uma nova `.tab/` dentro de uma `.extension/` existente, com `bundle.yaml`, `_layout.yaml` e atualização da ordem na raiz da extension.

## Quando esta skill é acionada

- O aluno digita `/criar-tab` (sozinho ou com nome inline)
- A skill `/criar-extension` propôs criar a primeira tab
- O aluno quer separar suas ferramentas em uma nova aba do ribbon

## NÃO use esta skill quando

- A extension ainda não existe. Use `/criar-extension` antes
- O aluno quer adicionar um panel a uma tab existente. Use `/criar-panel`
- O aluno quer só renomear uma tab existente (edição cirúrgica direto no `bundle.yaml`)

---

## Fluxo obrigatório

### Passo 0. Carregar contexto

Confirme que o `CLAUDE.md` está carregado. Consulte `references/pyrevit-fundamentals.md` se precisar lembrar da estrutura de bundle.yaml e _layout.yaml.

### Passo 1. Identificar a extension destino

A `.tab/` precisa morar dentro de uma `.extension/`. Determine onde criar:

1. **CWD dentro de `.extension/`.** Se cwd termina em `.extension`, criar a tab aqui
2. **CWD tem `.extension/` filhas.** Listar e pedir pra escolher
3. **Caminho explícito no prompt.** Se o aluno passou (ex: `/criar-tab "MinhaExtensao.extension/Auditoria"`)
4. **Nenhuma extension encontrada.** Sugerir `/criar-extension` antes

### Passo 2. Coletar nome da tab

Pergunte UMA vez:

> "Qual o nome da tab? Pode usar acentos no título exibido (vai pro ribbon do Revit).
>
> Exemplo: 'Producao' (pasta) com título 'Produção'"

Extraia:
- **Nome da pasta** (PascalCase, sem espaços, sem acentos). Ex: `Producao`, `Auditoria`
- **Título exibido** (com acentos, com espaços se quiser). Ex: `Produção`, `Auditoria de Modelo`

Se o aluno informou só o título, gere o nome da pasta automaticamente removendo acentos e espaços.

### Passo 3. Criar estrutura

Operações em ordem:

1. **Criar pasta** `{NomeTab}.tab/` dentro da `.extension/`
2. **Criar `bundle.yaml`** dentro da `.tab/`:

```yaml
title: "{Título exibido}"
```

3. **Criar `_layout.yaml`** vazio dentro da `.tab/`:

```yaml
# Ordem dos panels nesta tab.
# Adicione o nome de cada .panel/ (sem extensão) na ordem desejada.
```

4. **Atualizar `_layout.yaml`** da raiz da extension, adicionando a nova tab no final (ou na posição que o aluno indicar):

Se o arquivo está vazio ou só com comentários:

```yaml
- {NomeTab}
```

Se já tem tabs listadas:

```yaml
- TabExistente1
- TabExistente2
- {NomeTab}     # nova
```

### Passo 4. Confirmar entrega

```
Tab criada: {NomeTab} (título "{Título exibido}")

Pasta:        {NomeExtension}.extension/{NomeTab}.tab/
Arquivos:
  - bundle.yaml      (title)
  - _layout.yaml     (vazio, vai ser preenchido conforme panels forem criados)
Layout raiz:  _layout.yaml da extension atualizado
```

### Passo 5. Próximo passo

Pergunte:

> "Quer criar o primeiro panel da tab agora?
> 1. Sim, criar com `/criar-panel`
> 2. Vou criar manualmente depois"

Se aluno escolher 1, acione `/criar-panel` no contexto da tab recém-criada.

---

## Edição posterior

- **Renomear tab:** renomear a pasta `.tab` + atualizar `title` no `bundle.yaml` + atualizar `_layout.yaml` raiz da extension
- **Mudar título exibido:** editar `bundle.yaml` direto (mais leve, não muda nome da pasta)
- **Reordenar tabs:** editar `_layout.yaml` raiz da extension

Sempre Edição Cirúrgica. Não recrie a estrutura.

---

## O que NÃO fazer

- **Não criar tab fora de uma `.extension/`.** O pyRevit ignora.
- **Não esquecer do `bundle.yaml` com title.** Sem ele, o título no ribbon vira o nome cru da pasta.
- **Não criar panel ou pushbutton aqui.** Cada um tem sua skill própria.
- **Não usar acentos no nome da pasta.** Use PascalCase ASCII. O título com acentos vai no `bundle.yaml`.
