---
name: criar-pulldown
description: Cria um pulldown (botão com dropdown de sub-itens) dentro de um panel pyRevit. Gera a pasta MeuPulldown.pulldown, bundle.yaml com título e tooltip, ícone dual 96x96, _layout.yaml inicial pros sub-pushbuttons e atualiza _layout.yaml do panel pai.
---

# Criar Pulldown. Botão com Dropdown de Sub-itens

Você é especialista em criar pulldowns pyRevit. Esta skill cria a estrutura completa de um pulldown: pasta `.pulldown/`, `bundle.yaml` com título, ícone dual e `_layout.yaml` interno que vai listar os sub-pushbuttons que o aluno adicionar depois.

## Quando esta skill é acionada

- O aluno digita `/criar-pulldown` (sozinho ou com nome inline)
- O aluno quer agrupar vários botões relacionados num menu dropdown
- O panel está ficando cheio e faz sentido condensar botões secundários

## NÃO use esta skill quando

- O aluno quer um botão simples. Use `/criar-pushbutton`
- O aluno quer empilhar 2 ou 3 botões verticalmente. Use `/criar-stack`
- O panel ainda não existe. Use `/criar-panel` antes

---

## Fluxo obrigatório

### Passo 0. Carregar contexto

Leia `references/regras-essenciais.md` uma vez se as regras ainda não estiverem no seu contexto. Tenha em mente:
- `references/pyrevit-fundamentals.md` (estrutura de pulldown, bundle.yaml com title+tooltip)
- `helpers/icon-fetcher.py` (pra baixar ícone)

### Passo 1. Identificar o panel destino

O `.pulldown/` precisa morar dentro de um `.panel/`. Determine:

1. **CWD termina em `.panel/`** → criar aqui
2. **Caminho explícito no prompt**
3. **Único panel na extension** → confirmar
4. **Múltiplos panels** → listar e perguntar
5. **Nenhum** → sugerir `/criar-panel`

### Passo 2. Coletar nome, título e tooltip

Pergunte UMA vez:

> "Qual o nome do pulldown, título exibido e descrição breve (tooltip)?
>
> Exemplo: 'Cotas. Cotas de Paredes. Ferramentas de cotagem automática (paredes, pisos, perímetros).'"

Extraia:
- **Nome da pasta** (PascalCase, sem espaços/acentos). Ex: `Cotas`
- **Título exibido** no botão (pode ter `\n`). Ex: `"Cotas"`
- **Tooltip** (texto longo). Ex: `"Ferramentas de cotagem automática"`

### Passo 3. Escolher o ícone

Padrão: skill escolhe automaticamente baseado no nome/descrição.

Execute o helper:
```bash
python helpers/icon-fetcher.py "<descricao-do-pulldown>" "<pasta-temporaria>"
```

Mostre sugestão e peça aprovação (igual à `/criar-pushbutton`). Se o aluno especificou ícone, use o que ele pediu.

### Passo 4. Criar estrutura

Operações:

1. **Criar pasta** `{NomePulldown}.pulldown/` dentro do panel
2. **Criar `bundle.yaml`**:

```yaml
title: "{Título exibido}"
tooltip: "{tooltip mais longo}"
```

3. **Baixar ícones** via `icon-fetcher.py` na pasta do pulldown
4. **Criar `_layout.yaml`** vazio dentro do pulldown:

```yaml
# Ordem dos sub-pushbuttons dentro deste pulldown.
# Adicione o nome de cada .pushbutton filho (sem extensão) na ordem desejada.
```

5. **Atualizar `_layout.yaml`** do panel pai, incluindo o pulldown:

```yaml
- BotaoExistente1
- {NomeNovoPulldown}    # novo pulldown
```

### Passo 5. Confirmar entrega

```
Pulldown criado: {NomePulldown}

Pasta:        {panel}/{NomePulldown}.pulldown/
Arquivos:
  - bundle.yaml      (title + tooltip)
  - icon.png         (tema claro)
  - icon.dark.png    (tema escuro)
  - _layout.yaml     (vazio, vai listar os sub-botões)
Layout panel: _layout.yaml atualizado

O pulldown vai aparecer no ribbon mas vazio (sem sub-itens).
Pra adicionar os primeiros pushbuttons dentro dele, use `/criar-pushbutton`
e passe o caminho do pulldown como destino.
```

### Passo 6. Próximo passo

Pergunte:

> "Quer adicionar o primeiro pushbutton dentro deste pulldown agora?
> 1. Sim, criar com `/criar-pushbutton` apontando pra este pulldown
> 2. Não, vou adicionar depois"

---

## Edição posterior

- **Renomear:** renomear pasta + atualizar `title` no `bundle.yaml` + atualizar `_layout.yaml` do panel
- **Mudar título exibido:** editar `bundle.yaml`
- **Mudar tooltip:** editar `bundle.yaml`
- **Trocar ícone:** rodar `icon-fetcher.py` apontando pra pasta do pulldown
- **Reordenar sub-pushbuttons:** editar `_layout.yaml` do pulldown

Sempre Edição Cirúrgica.

---

## O que NÃO fazer

- **Não criar pulldown fora de `.panel/`.** Não vai aparecer.
- **Não esquecer do `bundle.yaml` com title.** Pulldown sem title fica sem nome no ribbon.
- **Não esquecer dos ícones dual.** Pulldown sem ícone fica feio no Revit.
- **Não criar pushbuttons aqui.** Cada sub-botão é uma chamada separada de `/criar-pushbutton`.
- **Não usar acentos na pasta.** PascalCase ASCII.
