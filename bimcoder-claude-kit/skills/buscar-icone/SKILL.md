---
name: buscar-icone
description: Sugere ícones do Iconify a partir de um termo em português. Traduz PT para EN, busca via Iconify API e retorna 5 candidatos priorizados das bibliotecas curadas (lucide, material-symbols, tabler, mdi, phosphor). Use quando o aluno quer escolher um ícone sem necessariamente criar um pushbutton, ou quando quer ver opções antes de aprovar a sugestão automática de /criar-pushbutton.
---

# Buscar Ícone. Sugestões via Iconify

Você é especialista em escolher ícones representativos pra botões de UI. Esta skill busca no Iconify (200 mil ícones de 150 bibliotecas) a partir de um termo em português, filtra pelas bibliotecas curadas e mostra os top 5 candidatos.

## Quando esta skill é acionada

- O aluno digita `/buscar-icone <termo>` (ex: `/buscar-icone régua de pedreiro`)
- A skill `/criar-pushbutton` precisa mostrar alternativas ao aluno
- O aluno está vendo uma sugestão de ícone e quer ver outras opções
- O aluno quer trocar o ícone de um pushbutton existente

## NÃO use esta skill quando

- O aluno quer criar o bundle completo. Use `/criar-pushbutton`
- O aluno só quer mudar texto/comentário do script, sem mexer em ícone

---

## Fluxo obrigatório

### Passo 0. Carregar contexto

Confirme que `helpers/icon-fetcher.py` existe no kit. É o script que sabe traduzir PT-EN e buscar no Iconify.

### Passo 1. Coletar o termo

Se o aluno passou termo inline (ex: `/buscar-icone régua`), use direto.

Se acionou sem termo, pergunte uma vez:

> "Qual ícone você quer? Descreva em português (ex: régua, parede, automação, lista, exportar)."

### Passo 2. Buscar candidatos

Execute o helper em modo "listar":

```bash
python helpers/icon-fetcher.py "<termo>" "<pasta-temp>"
```

O helper retorna JSON. Para listar múltiplas opções (não só a primeira), você pode chamar a função `search_iconify(query)` direto no Python ou rodar uma busca paralela. Para skills, a forma mais simples é:

1. Aplicar o dicionário PT→EN do helper (mentalmente ou via call)
2. Buscar via `https://api.iconify.design/search?query=<termo-em>` e parsear o JSON
3. Filtrar por bibliotecas curadas: `lucide`, `material-symbols`, `tabler`, `mdi`, `phosphor`, `heroicons`
4. Pegar os 5 primeiros priorizados

### Passo 3. Apresentar candidatos

Mostre os top 5 numerados:

```
Termo: "régua" (traduzido para "ruler")

Sugestões:
1. lucide:ruler                  régua simples, linhas finas, estilo Lucide
2. material-symbols:square-foot  régua de pedreiro Material Symbols
3. tabler:ruler                  régua Tabler, estilo limpo
4. mdi:ruler                     régua Material Design Icons
5. phosphor:ruler                régua Phosphor, estilo soft

Pra ver preview de cada um, abra:
https://icones.js.org/collection/lucide?s=ruler
```

Se possível, descreva brevemente o estilo de cada um. Não invente. Se não souber, omita a descrição.

### Passo 4. Pegar a escolha do aluno

Pergunte:

> "Qual prefere?
> 1, 2, 3, 4 ou 5 (escolhe um dos sugeridos)
> outro (digita o nome no formato `prefix:name` do Iconify)
> nenhum (cancelar busca)"

### Passo 5. Aplicar a escolha

A aplicação depende do contexto:

**Se a skill foi acionada por `/criar-pushbutton`:**
- Retorna o nome escolhido pra ela continuar o fluxo
- A `/criar-pushbutton` chama o `icon-fetcher.py` com o nome explícito pra baixar os PNGs

**Se a skill foi acionada standalone:**
- Pergunte onde aplicar: "Quer aplicar esse ícone num pushbutton existente?
  1. Sim, qual pushbutton?
  2. Não, só queria ver as opções"
- Se sim, execute:
  ```bash
  python helpers/icon-fetcher.py "<prefix:name>" "<caminho-do-pushbutton>"
  ```

### Passo 6. Confirmar

Se aplicou:

```
Ícone "{prefix:name}" baixado em:
  - {pasta}/icon.png       (cinza #344054, tema claro)
  - {pasta}/icon.dark.png  (branco #FFFFFF, tema escuro)

Pra ver no Revit, reinicie ou recarregue a extension via pyRevit > Reload.
```

Se foi só consulta (sem aplicar):

```
Pra usar um destes em um pushbutton novo, rode `/criar-pushbutton`.
Pra trocar o ícone de um pushbutton existente, me diz o caminho.
```

---

## Termos PT que o helper traduz bem

O dicionário interno do `icon-fetcher.py` cobre ~100 termos do contexto Revit/BIM. Exemplos:

| PT | EN |
|---|---|
| parede, paredes | wall |
| porta, portas | door |
| cota, cotas, dimensão, régua | ruler, dimensions |
| ferramenta | wrench |
| automação, robô | robot |
| exportar, importar | export, import |
| editar, renomear | edit |
| filtrar, buscar | filter, search |
| relatório, gráfico | file-text, bar-chart |
| configurar, ajustar | settings |
| auditar, verificar | shield-check, check-circle |
| família, biblioteca | package, library |
| material, cor | palette, droplet |
| prancha, vista | file, eye |
| luminária, luz | lightbulb |
| tubo, conduíte, MEP | git-fork |
| elétrica, energia | zap |

Se o termo do aluno não está no dicionário, o helper passa em PT mesmo (Iconify aceita alguns termos em PT).

---

## O que NÃO fazer

- **Não inventar nomes de ícone.** Sempre validar via Iconify search antes de sugerir.
- **Não retornar mais que 5 sugestões.** Mais que isso vira ruído visual.
- **Não escolher pelo aluno em modo standalone.** Sempre apresenta opções e deixa decidir. (Em modo `/criar-pushbutton` o auto-pick é o default, mas com opção de override.)
- **Não baixar o PNG até o aluno confirmar.** Busca é leve. Download só após escolha.
