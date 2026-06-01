---
name: criar-stack
description: Cria um stack (empilhamento vertical de 2 ou 3 pushbuttons) dentro de um panel pyRevit. Gera a pasta MeuStack.stack contendo os sub-pushbuttons já criados, sem bundle.yaml próprio (stacks são anônimos). Atualiza _layout.yaml do panel pai.
---

# Criar Stack. Empilhar 2 ou 3 Pushbuttons

Você é especialista em criar stacks pyRevit. Esta skill cria uma pasta `.stack/` contendo 2 ou 3 pushbuttons empilhados verticalmente no panel. Diferente de pulldown, stacks são anônimos (sem botão pai) e os sub-pushbuttons aparecem todos juntos.

## Quando esta skill é acionada

- O aluno digita `/criar-stack` (sozinho ou com nomes inline)
- O aluno quer aproveitar espaço vertical do panel com botões pequenos
- O aluno tem 2 ou 3 botões relacionados que ficam melhor juntos do que separados

## NÃO use esta skill quando

- O aluno quer 1 botão simples grande. Use `/criar-pushbutton`
- O aluno quer mais de 3 botões. Use `/criar-pulldown` ou crie um segundo panel
- O panel ainda não existe. Use `/criar-panel` antes

---

## Fluxo obrigatório

### Passo 0. Carregar contexto

Leia `references/regras-essenciais.md` uma vez se as regras ainda não estiverem no seu contexto. Tenha em mente:
- `references/pyrevit-fundamentals.md` (stacks são `.stack`, `.stack2`, `.stack3`. Sem `bundle.yaml`. Sem ícone próprio. Anônimos.)

### Passo 1. Identificar o panel destino

Igual `/criar-pushbutton` e `/criar-pulldown`. CWD em `.panel/`, lista, ou caminho explícito.

### Passo 2. Coletar quantos botões e nomes

Pergunte UMA vez:

> "Quantos botões no stack (2 ou 3) e qual o nome+descrição de cada?
>
> Exemplo:
> '2 botões: AbrirRelatorio (abre relatório anual) e SalvarRelatorio (salva PDF)'"

Extraia:
- **Quantidade** (2 ou 3, validar)
- **Nome de cada pushbutton** (PascalCase ASCII)
- **Descrição curta** de cada (vai pro `__doc__`)

### Passo 3. Coletar nome do stack (opcional)

O nome da pasta do stack não aparece no ribbon. Use um nome interno organizativo:

> "Como vai nomear a pasta do stack? (interno, não aparece no ribbon)
> Sugestão: `Stack_{primeiro-botao}_{segundo-botao}`"

Ex: `Stack_Abrir_Salvar` ou simplesmente `Relatorios`.

### Passo 4. Criar estrutura

Operações:

1. **Criar pasta** com nome apropriado:
   - `.stack/` se 2 ou 3 (genérico, pyRevit detecta)
   - `.stack2/` se quiser ser explícito sobre 2 botões
   - `.stack3/` se 3 botões

   Recomendação: usar `.stack` (mais flexível).

   Caminho: `{panel}/{NomeStack}.stack/`

2. **Criar cada sub-pushbutton** dentro do stack, em ordem. Pra cada um, chamar `/criar-pushbutton` internamente com:
   - Caminho destino: `{panel}/{NomeStack}.stack/{NomePushbutton}.pushbutton/`
   - Nome, descrição que o aluno deu
   - Ícone: skill escolhe automaticamente baseado na descrição

   Cada sub-pushbutton terá `script.py` boilerplate, `icon.png` e `icon.dark.png`.

3. **Stack NÃO tem `bundle.yaml`** (regra do pyRevit). Não criar.

4. **Stack NÃO tem ícone próprio**. Os ícones dos sub-pushbuttons aparecem.

5. **Atualizar `_layout.yaml`** do panel pai:

```yaml
- BotaoExistente
- {NomeStack}     # stack novo
```

### Passo 5. Confirmar entrega

```
Stack criado: {NomeStack} ({N} botões)

Pasta:        {panel}/{NomeStack}.stack/
Sub-botões criados:
  - {NomeBotao1}.pushbutton/   script.py + icon.png + icon.dark.png
  - {NomeBotao2}.pushbutton/   script.py + icon.png + icon.dark.png
  {- {NomeBotao3}.pushbutton/  script.py + icon.png + icon.dark.png}
Layout panel: _layout.yaml atualizado

No ribbon, os botões aparecem empilhados verticalmente em vez de
lado a lado.
```

### Passo 6. Próximo passo

Pergunte:

> "Os scripts dos sub-botões estão vazios (só boilerplate). Quer preencher algum agora?
> 1. Sim, qual?
> 2. Não, vou preencher depois com `/criar-script` em cada um"

---

## Edição posterior

- **Adicionar 3º botão a um stack de 2:** criar um `.pushbutton/` dentro do `.stack/` + atualizar nada (pyRevit detecta)
- **Remover botão:** deletar a pasta `.pushbutton/` (pyRevit detecta)
- **Reordenar:** se houver `_layout.yaml` interno no stack (incomum), editar ele

---

## O que NÃO fazer

- **Não criar stacks com 1 botão.** Use `/criar-pushbutton` direto. `AddStackedItems` da Revit API requer mínimo 2 itens.
- **Não criar stacks com mais de 3 botões.** Limite da Revit API.
- **Não criar `bundle.yaml` no stack.** Stack é anônimo, não tem title.
- **Não criar `icon.png` no stack.** Só os sub-pushbuttons têm ícone.
- **Não usar acentos no nome da pasta do stack.** PascalCase ASCII.
