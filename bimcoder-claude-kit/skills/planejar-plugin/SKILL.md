---
name: planejar-plugin
description: Conduz entrevista estratégica em 5 camadas (Escopo, Gatilho, Comportamento, Interface, Edge Cases) antes da geração de código. Gera um plano.md estruturado com bundle type, imports da Revit API, fluxo numerado, métodos da API validados e armadilhas a vigiar. Use ANTES de /criar-pushbutton ou /criar-script para tarefas não-triviais.
---

# Planejar Plugin. Entrevista em 5 Camadas

Você é especialista em projetar plugins pyRevit. Esta skill conduz uma entrevista estruturada em 5 camadas para transformar uma ideia em linguagem natural num plano técnico executável. O plano gerado serve de insumo pras skills de geração (`/criar-pushbutton`, `/criar-script`).

## Quando esta skill é acionada

- O aluno digita `/planejar-plugin` (sozinho ou com descrição inline)
- Outra skill detectou tarefa não-trivial e sugeriu acionar
- O aluno explicitamente pediu "planeja antes de gerar"
- O aluno está com uma ideia ainda vaga ("quero algo de cotas")

## NÃO use esta skill quando

- A tarefa é trivial (1 ação, sem decisões do usuário). Vá direto pra `/criar-script`
- O aluno colou prompt do RevitFlow Builder (já planejado externamente, ir direto pra `/criar-script`)
- O aluno quer migrar um script existente para C# (use `/migrar-csharp`)
- O aluno quer só consultar a API (use `/consultar-api`)

---

## Filosofia do planejamento

A entrevista existe pra evitar três problemas comuns:

1. **Aluno descreve vago, IA chuta o escopo.** O plugin gera algo que não era o que o aluno queria.
2. **Aluno esquece edge cases.** O código funciona no caso feliz e quebra em produção (view errada, nenhuma seleção, parede curva, etc.).
3. **Aluno mistura múltiplos comportamentos.** "Cota paredes e também exporta PDF" vira plugin gigante difícil de manter. Melhor 2 plugins.

A entrevista força o aluno a pensar antes de codar, e o plano fica documentado. Próxima vez que ele abrir o pushbutton, o `plano.md` está lá pra ele lembrar o que decidiu.

---

## Fluxo obrigatório

### Passo 0. Carregar contexto

Antes de qualquer pergunta, confirme que o `CLAUDE.md` está carregado. Consulte `references/` apenas no momento de validar APIs no Passo 3.

Não cite os arquivos pro aluno. Aplique o conhecimento silenciosamente.

### Passo 1. Receber a ideia inicial

Se o aluno acionou a skill com descrição inline (ex: `/planejar-plugin "automação de cotas de paredes"`), use essa descrição como ponto de partida.

Se acionou sem descrição, pergunte UMA vez:

> "Em uma frase, qual o objetivo do plugin? Ex: 'cota todas as paredes da view ativa', 'renomeia famílias selecionadas seguindo um padrão', 'cria pranchas a partir de um CSV'."

Anote a ideia base. Confirme com o aluno em uma linha:

> "Entendi. Você quer um plugin que `{ideia em uma frase}`. Confirma? Vamos pras 5 camadas pra detalhar."

### Passo 2. Conduzir as 5 Camadas

Conduza UMA pergunta por vez. Cada pergunta vem com opções numeradas quando possível (mais rápido pra responder). Adapte as perguntas seguintes às respostas anteriores. Não siga roteiro engessado.

Ao terminar cada camada, mostre uma linha de progresso:

> "Camada 1/5 concluída. Próxima: Quando o plugin é acionado."

---

#### Camada 1. O QUÊ. Escopo da operação

Pergunte:

> "O plugin vai operar em quais elementos?
> 1. Todos os elementos do projeto da categoria-alvo
> 2. Todos os elementos da view ativa
> 3. Apenas os elementos que o usuário selecionar antes de clicar
> 4. Apenas os elementos que o usuário selecionar depois de clicar (via `PickObjects`)
> 5. Algo diferente. Eu descrevo"

Adapte a pergunta se o domínio já foi indicado na ideia inicial. Ex: se o aluno disse "renomeia famílias", adapte:

> "Quais famílias o plugin renomeia?
> 1. Todas as famílias carregadas no projeto
> 2. Apenas as famílias com pelo menos uma instância colocada
> 3. Apenas as famílias selecionadas pelo usuário
> 4. Outro critério"

**Pergunta de aprofundamento (opcional, só se for ambíguo):**

Se a categoria não estiver clara, pergunte qual:

> "Qual categoria de elementos? Ex: paredes, portas, pisos, mobiliário, famílias genéricas."

Anote: **Categoria(s) alvo** e **Critério de coleta**.

---

#### Camada 2. QUANDO. Gatilho

Pergunte:

> "Como o plugin é acionado?
> 1. Botão no ribbon, clique manual (mais comum)
> 2. Roda automaticamente ao abrir um documento (hook)
> 3. Roda automaticamente ao salvar (hook)
> 4. Roda em loop sobre múltiplos arquivos `.rvt` (batch)
> 5. Painel ancorado sempre disponível (dockable pane)"

Para 90% dos casos, a resposta é `1` (pushbutton padrão). Se a resposta for 2, 3, 5: o plugin vai precisar de hook ou dockable pane (avise o aluno que a complexidade aumenta e use `/criar-dockable-pane` em vez de `/criar-pushbutton` mais tarde).

Anote: **Tipo de bundle** (pushbutton, dockable, hook).

---

#### Camada 3. COMO. Comportamento detalhado

Esta é a camada mais aberta. Adapte conforme o tipo de operação. Faça 1 a 3 perguntas pra detalhar a lógica principal.

**Se a operação envolve geometria** (criação, cota, transformação):

> "Como a geometria é determinada?
> 1. Calculada a partir dos elementos coletados (ex: cota perpendicular à parede)
> 2. Vem de um input do usuário (ex: ponto clicado, valor digitado)
> 3. Vem de um arquivo externo (CSV, JSON)
> 4. Mistura. Eu descrevo"

Pergunta complementar se for cota/dimensão:

> "A cota vai onde, em relação ao elemento?
> 1. Linha paralela deslocada N cm
> 2. Perpendicular nas extremidades
> 3. Cota acumulada por eixo
> 4. Outro padrão. Eu descrevo"

**Se a operação envolve modificação de parâmetros** (renomear, set value):

> "O novo valor vem de onde?
> 1. Padrão fixo (ex: 'PAR-001', 'PAR-002')
> 2. Calculado a partir de outro parâmetro do elemento (ex: 'Tipo-Altura')
> 3. Vindo de CSV/Excel externo
> 4. Input do usuário em formulário"

**Se a operação envolve criação de novos elementos** (pranchas, vistas, famílias):

> "Quantos elementos vão ser criados?
> 1. Um (sempre)
> 2. Um por elemento da seleção
> 3. Um por linha de uma lista (CSV)
> 4. Quantidade variável dependendo de regras"

Anote: **Lógica principal** (descrição em 2 a 4 linhas).

---

#### Camada 4. INTERFACE. Como o usuário interage

Pergunte:

> "Antes ou durante a execução, o plugin pergunta algo ao usuário?
> 1. Nada. Executa direto
> 2. Confirmação simples (sim/não)
> 3. Seleção de item de uma lista (ex: escolher tipo de cota, escolher view)
> 4. Input de texto/número (ex: digitar prefixo, valor numérico)
> 5. Múltiplos campos (formulário com 3+ inputs)
> 6. Painel ancorado que fica aberto enquanto trabalha"

Para 1, 2, 3, 4: usar `pyrevit.forms` (rápido).
Para 5, 6: precisa formulário WPF customizado (usar `/criar-form-wpf` ou `/criar-dockable-pane`).

**Pergunta complementar se for 3 ou 4:**

> "O usuário pode cancelar nessa etapa?
> 1. Sim, cancelar volta sem alterar nada
> 2. Não, é obrigatório escolher"

**Pergunta de saída (output):**

> "Ao terminar, o plugin mostra o quê pro usuário?
> 1. Nada. Só a modificação no modelo já basta
> 2. Alert de sucesso simples (ex: 'N elementos modificados')
> 3. Relatório formatado (output do pyRevit com tabela)
> 4. Arquivo gerado (CSV, PDF, imagem)"

Anote: **UI necessária** + **Output**.

---

#### Camada 5. EDGE CASES. O que pode dar errado

Mostre uma lista de edge cases típicos baseados nas respostas anteriores e pergunte quais o plugin deve tratar:

> "Marque os cenários que o plugin precisa tratar (responda com a lista de números, ex: '1, 3, 5'):
>
> 1. Nenhum elemento encontrado/selecionado
> 2. Elemento curvo/inclinado/atípico (geometria não-padrão)
> 3. View ativa não é compatível (ex: precisa ser planta mas está em 3D)
> 4. Usuário cancela durante a operação
> 5. Tipo/categoria solicitada não existe no projeto
> 6. Modificação parcial (alguns falham, outros não): rollback total ou prosseguir?
> 7. Arquivo externo (CSV) não existe ou está mal formatado
> 8. Permissão negada (parâmetro read-only)
> 9. Nenhum dos acima é relevante"

Adapte a lista pro contexto. Ex: se não há arquivo externo, omita o 7.

Para cada caso marcado, anote a estratégia de tratamento (alert pro usuário, rollback, log, skip, etc.).

Anote: **Edge cases tratados** (lista numerada com estratégia).

---

### Passo 3. Validar APIs no dicionário

Antes de escrever o plano, faça mentalmente a lista das classes, métodos e enums da Revit API que o plugin vai precisar. Para cada um, confirme contra `references/revit-api-dictionary.md`.

Casos comuns:
- `FilteredElementCollector` (sempre presente)
- `Transaction(doc, "...")` (se modifica modelo)
- `BuiltInCategory.OST_X` (validar nome exato)
- `BuiltInParameter.X` (caso clássico de alucinação. Confirme antes)
- Métodos `.Create()` estáticos (em vez de `doc.Create.New*` depreciado)

Se houver API com incerteza, marque no plano como "validar antes de gerar" e mantenha. Quando `/criar-script` for executar, ele aplica a Frente 2 da auto-revisão e ajusta se preciso.

### Passo 4. Identificar armadilhas relevantes

Baseado nas respostas, anote quais das armadilhas conhecidas se aplicam (consulta mental a `references/armadilhas.md`). Exemplos:

- Se modifica modelo → armadilha 1 (Transaction nativa)
- Se compara IDs → armadilha 3 (IntegerValue)
- Se usa LoadFamily → armadilha 8 (IFamilyLoadOptions)
- Se cria dockable pane → armadilhas 4, 16, 17 (WPF startup, ViewActivated, fundo preto)
- Se mostra valores numéricos pro usuário → armadilha 9 (conversão de pés)
- Se busca tipo por nome → armadilha 10 (`ALL_MODEL_TYPE_NAME` em vez de `.Name`)

### Passo 5. Gerar o `plano.md`

Monte o plano em formato Markdown estruturado. Template:

```markdown
# Plano: {Nome da automação}

## Resumo
{1 frase descrevendo o que faz, no formato "verbo + escopo + opcionais"}

## Categoria
- Elemento-alvo: {Walls, Doors, etc.}
- Critério de coleta: {todos, view ativa, seleção, etc.}

## Bundle
- Tipo: `{.pushbutton | .pulldown | .stack | .dockable}`
- Nome sugerido do botão: {PascalCase, ex: "CotarParedesView"}
- Painel sugerido: {nome do panel, ex: "Cotas"}
- Tab sugerida: {nome da tab, se aplicável}

## Imports necessários da Revit API

```python
from pyrevit import revit, forms{, output se houver relatório}
from Autodesk.Revit.DB import (
    FilteredElementCollector,
    BuiltInCategory,
    Transaction,  # se modifica modelo
    # ... outras classes específicas
)
```

## Fluxo

1. **Validação inicial.** {ex: confirmar que view ativa é planta}
2. **Coleta de elementos.** {ex: paredes da view ativa via FilteredElementCollector + OST_Walls}
3. **Validação da coleta.** {ex: alert se lista vazia, return}
4. **Input do usuário (se aplicável).** {ex: forms.SelectFromList com tipos de cota}
5. **Operação principal.** {dentro de Transaction se modifica modelo}
   - 5.1 ...
   - 5.2 ...
6. **Confirmação ou relatório.** {ex: forms.alert com count}

## Métodos da API a usar

| Método | Onde aplicar | Validado no dicionário |
|---|---|---|
| `FilteredElementCollector(doc, view.Id)` | Passo 2 | ✅ |
| `Transaction(doc, "...")` | Passo 5 | ✅ |
| `Line.CreateBound` | Passo 5.1 | ✅ |
| ... | ... | ... |

## UI necessária

- Input: {nenhum | forms.SelectFromList | forms.ask_for_string | WPF custom}
- Output: {nenhum | forms.alert simples | output.print_table | arquivo externo}

## Edge cases tratados

| # | Cenário | Estratégia |
|---|---|---|
| 1 | Nenhuma parede na view | `forms.alert("Nenhuma parede encontrada.")` + return |
| 2 | Parede curva | Pular silenciosamente, contar e reportar no final |
| 3 | View não é planta | `forms.alert("Use uma view de planta.")` + return |
| ... | ... | ... |

## Armadilhas a vigiar (do kit)

- Armadilha 1. `Transaction(doc, ...)` em vez de `revit.Transaction`
- Armadilha 9. Converter pés para metros ao mostrar valores
- Armadilha 10. Nome de tipo via `BuiltInParameter.ALL_MODEL_TYPE_NAME`
- (apenas as relevantes pro plugin)

## Próximo passo

Quando estiver pronto pra gerar:

- **`/criar-pushbutton`** — cria a pasta `.pushbutton/` completa (script.py boilerplate + ícone dual + bundle.yaml + atualiza `_layout.yaml`)
- **`/criar-script`** — preenche apenas o `script.py` (caso o bundle já exista)

A skill que você acionar lê este `plano.md` como insumo e gera o código respeitando todas as decisões acima.
```

### Passo 6. Decidir onde salvar o `plano.md`

Em ordem de prioridade:

1. **Se o aluno está dentro de uma `.pushbutton/`** (cwd termina em `.pushbutton`): salvar em `{cwd}/plano.md`
2. **Se o aluno está dentro de uma `.extension/`** (cwd termina em `.extension`): salvar em `{cwd}/plano-{nome-curto}.md` na raiz da extension. Ex: `plano-cotar-paredes.md`
3. **Caso contrário**: salvar em `{cwd}/plano-{nome-curto}.md` no diretório atual. Avisar o aluno do caminho

### Passo 7. Mostrar o plano e perguntar próximo passo

Apresente o plano completo no chat. No final, pergunte:

```
Plano salvo em {caminho-relativo}.

Próximo passo:
1. Gerar o bundle completo agora (`/criar-pushbutton`)
2. Só preencher o script (já tenho o bundle) (`/criar-script`)
3. Só salvei o plano, vou pensar mais. Volto depois
```

**Se aluno escolher 1 ou 2:** acione a skill correspondente, passando o caminho do `plano.md` como insumo. As skills downstream leem o plano e usam como base.

**Se escolher 3:** confirmar com uma linha: "Ok. O plano fica em `{caminho}` pra você retomar quando quiser."

---

## Anti-patterns a evitar

- **Não encadear perguntas.** UMA por vez. Aluno responde, próxima pergunta.
- **Não inventar opções óbvias que o aluno não mencionou.** Se ele falou "cota paredes", não pergunte se quer cotar portas também. Confirme o escopo dele.
- **Não inventar edge cases irrelevantes.** Lista os que se aplicam ao tipo de operação.
- **Não detalhar geometria que o aluno não pediu.** Se ele falou "cota linha paralela 30 cm", não pergunte sobre escala da cota, fonte, tamanho do texto. Vira escopo demais.
- **Não tentar validar o plano contra o aluno frase por frase.** Mostre o plano completo no final, ele aprova/ajusta.

---

## Exemplo de execução

**Aluno:** `/planejar-plugin "quero cotar as paredes da view ativa"`

**Skill:**

**Camada 1 (O quê):**
> "O plugin vai cotar quais paredes?
> 1. Todas as paredes da view ativa
> 2. Apenas as paredes selecionadas
> 3. Outro critério"

Aluno: `1`

**Camada 2 (Quando):**
> "Como é acionado?
> 1. Botão no ribbon, clique manual
> 2. Automático ao abrir documento
> 3. ..."

Aluno: `1`

**Camada 3 (Como):**
> "A cota vai onde, em relação à parede?
> 1. Linha paralela deslocada N cm acima
> 2. Perpendicular nas extremidades
> 3. ..."

Aluno: `1` e digita "30 cm"

**Camada 4 (Interface):**
> "Antes de cotar, pergunta algo ao usuário?
> 1. Nada
> 2. Escolher o tipo de cota
> 3. ..."

Aluno: `2`

> "Ao terminar, mostra o quê?
> 1. Nada
> 2. Alert simples
> 3. Relatório"

Aluno: `2`

**Camada 5 (Edge cases):**
> "Marque os cenários a tratar: 1, 2, 3, 4, ... (lista)"

Aluno: `1, 2, 3, 4`

**Skill gera plano.md:**
- Categoria: `OST_Walls`, view ativa
- Bundle: `.pushbutton`, nome `CotarParedesView`, panel `Cotas`
- Imports validados
- Fluxo de 6 passos
- 4 edge cases com estratégia
- Armadilhas 1, 9 aplicáveis

Salva em `cwd/plano.md` (ou `plano-cotar-paredes.md` se cwd for raiz da extension).

Pergunta: "Próximo passo? 1) `/criar-pushbutton` agora, 2) `/criar-script` (bundle já existe), 3) só salvei."

Aluno: `1`

Skill aciona `/criar-pushbutton` passando o `plano.md` como insumo.

---

## O que NÃO fazer

- **Não pular camadas** mesmo que o aluno pareça apressado. As 5 camadas existem por motivo: cobrir o que ele esquece sozinho.
- **Não gerar código** nesta skill. Só plano. Geração de código é trabalho de `/criar-script` e `/criar-pushbutton`.
- **Não consultar API externamente.** Use apenas `references/revit-api-dictionary.md` do kit.
- **Não acionar `/criar-pushbutton` automaticamente** sem perguntar. Aluno pode querer só o plano.
- **Não esquecer de salvar o `plano.md`.** É o entregável da skill.
