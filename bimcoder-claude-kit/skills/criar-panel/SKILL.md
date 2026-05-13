---
name: criar-panel
description: Adiciona um panel novo dentro de uma tab pyRevit existente. Cria a pasta MeuPanel.panel, o bundle.yaml com o título exibido no ribbon, o _layout.yaml inicial e atualiza o _layout.yaml da tab pai pra incluir o novo panel na ordem.
---

# Criar Panel. Agrupamento de Botões na Tab

Você é especialista em criar panels (agrupamentos de botões) do ribbon pyRevit. Esta skill adiciona uma nova `.panel/` dentro de uma `.tab/` existente, com `bundle.yaml`, `_layout.yaml` e atualização da ordem na tab pai.

## Quando esta skill é acionada

- O aluno digita `/criar-panel` (sozinho ou com nome inline)
- A skill `/criar-tab` propôs criar o primeiro panel
- O aluno quer agrupar um conjunto de botões relacionados

## NÃO use esta skill quando

- A tab ainda não existe. Use `/criar-tab` antes
- O aluno quer criar um pushbutton dentro de um panel. Use `/criar-pushbutton`
- O aluno quer só renomear um panel existente (edição cirúrgica direto no `bundle.yaml`)

---

## Fluxo obrigatório

### Passo 0. Carregar contexto

Confirme que o `CLAUDE.md` está carregado. Consulte `references/pyrevit-fundamentals.md` se precisar.

### Passo 1. Identificar a tab destino

O `.panel/` precisa morar dentro de uma `.tab/`. Determine onde criar:

1. **CWD dentro de `.tab/`.** Se cwd termina em `.tab`, criar o panel aqui
2. **CWD em `.extension/` com várias tabs.** Listar tabs e pedir pra escolher
3. **CWD em `.extension/` com uma tab só.** Confirmar se é essa
4. **Caminho explícito no prompt.** Se o aluno passou
5. **Nenhuma tab encontrada.** Sugerir `/criar-tab` antes

### Passo 2. Coletar nome do panel

Pergunte UMA vez:

> "Qual o nome do panel? Pode usar acentos no título exibido (vai pro ribbon).
>
> Exemplo: 'Cotas' (pasta) com título 'Cotagem'"

Extraia:
- **Nome da pasta** (PascalCase, sem espaços, sem acentos). Ex: `Cotas`, `Auditoria`, `Pranchas`
- **Título exibido** (com acentos se aplicável). Ex: `Cotas`, `Auditoria de Modelo`

Se o aluno informou só o título, gere o nome da pasta removendo acentos e espaços.

### Passo 3. Criar estrutura

Operações em ordem:

1. **Criar pasta** `{NomePanel}.panel/` dentro da `.tab/`
2. **Criar `bundle.yaml`** dentro da `.panel/`:

```yaml
title: "{Título exibido}"
```

3. **Criar `_layout.yaml`** vazio dentro da `.panel/`:

```yaml
# Ordem dos botões neste panel.
# Adicione o nome de cada .pushbutton/, .pulldown/ ou .stack/ (sem extensão) na ordem desejada.
```

4. **Atualizar `_layout.yaml`** da `.tab/` pai, adicionando o novo panel no final (ou na posição que o aluno indicar):

```yaml
- PanelExistente1
- {NomeNovoPanel}     # nova entrada
```

### Passo 4. Confirmar entrega

```
Panel criado: {NomePanel} (título "{Título exibido}")

Pasta:        {NomeExtension}.extension/{NomeTab}.tab/{NomePanel}.panel/
Arquivos:
  - bundle.yaml      (title)
  - _layout.yaml     (vazio, vai ser preenchido conforme botões forem criados)
Layout tab:   _layout.yaml da tab atualizado
```

### Passo 5. Próximo passo

Pergunte:

> "Quer criar o primeiro botão do panel agora?
> 1. Pushbutton (botão simples) → `/criar-pushbutton`
> 2. Pulldown (botão com sub-itens) → `/criar-pulldown`
> 3. Stack (2 ou 3 botões empilhados) → `/criar-stack`
> 4. Não, vou criar manualmente depois"

Se aluno escolher 1, 2 ou 3, acione a skill correspondente no contexto do panel recém-criado.

---

## Edição posterior

- **Renomear panel:** renomear pasta `.panel` + atualizar `title` no `bundle.yaml` + atualizar `_layout.yaml` da tab pai
- **Mudar título exibido:** editar `bundle.yaml` direto
- **Reordenar panels:** editar `_layout.yaml` da tab pai

Sempre Edição Cirúrgica.

---

## O que NÃO fazer

- **Não criar panel fora de uma `.tab/`.** O pyRevit ignora.
- **Não esquecer do `bundle.yaml` com title.** Sem ele, o título no ribbon vira o nome cru da pasta.
- **Não criar pushbutton, pulldown ou stack aqui.** Cada um tem sua skill própria.
- **Não usar acentos no nome da pasta.** PascalCase ASCII.
