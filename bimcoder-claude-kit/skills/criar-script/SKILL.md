---
name: criar-script
description: Preenche um script.py de pushbutton pyRevit a partir de descrição em linguagem natural. Atua diretamente no arquivo alvo, não cria pastas, ícones ou bundle. Use quando o aluno já tem o pushbutton criado e quer só escrever o conteúdo do script.
---

# Criar Script. Preenche `script.py` de Pushbutton

Você é especialista em escrever scripts pyRevit. Esta skill recebe uma descrição em linguagem natural do que o pushbutton deve fazer e escreve o `script.py` completo dentro do `.pushbutton/` correto, respeitando as 9 Regras Técnicas Absolutas do `CLAUDE.md`.

## Quando esta skill é acionada

- O aluno digita `/criar-script` (sozinho ou com descrição inline)
- O aluno descreve no chat que quer preencher um script existente
- Outra skill (ex: `/criar-pushbutton`) delegou o passo de escrever o conteúdo

## NÃO use esta skill quando

- O pushbutton ainda não foi criado (sugira `/criar-pushbutton` antes)
- O aluno quer um plano antes do código (sugira `/planejar-plugin`)
- O aluno quer migrar um script existente para C# (use `/migrar-csharp`)

---

## Fluxo obrigatório

### Passo 0. Carregar contexto

Antes de qualquer coisa, confirme que você está com o `CLAUDE.md` carregado. Ele tem as 9 Regras Técnicas Absolutas, o critério trivial vs não-trivial, o modo RevitFlow Builder e a auto-revisão dupla.

Consulte os arquivos de `references/` apenas quando precisar validar uma API ou padrão específico:
- `references/revit-api-dictionary.md`. Quando precisar de método, classe, propriedade ou enum da Revit API
- `references/armadilhas.md`. Quando o código gerado se encaixar numa armadilha conhecida
- `references/pyrevit-fundamentals.md`. Quando precisar de detalhe sobre `forms`, `output`, IronPython

Não cite os arquivos pro aluno. Aplique o conhecimento silenciosamente.

### Passo 1. Detectar prompt do RevitFlow Builder

Se a descrição do aluno tiver cabeçalho do tipo:

```
SCRIPT PYREVIT — N ETAPAS
============================================================
```

ou estrutura numerada por ETAPAs com `API: Classe` e `API: Método`, mude pro **modo RevitFlow Builder** descrito no `CLAUDE.md`. Nesse modo:

- Não acione `/planejar-plugin`
- Siga as ETAPAs em ordem, comentando `# ETAPA N` no código
- Faça análise crítica do prompt (imports quebrados, placeholders entre chaves, enums em formato livre, valores com tipo errado)
- Aplique as 9 Regras mesmo que o prompt sugira o contrário
- Continue do Passo 5 abaixo (pular Passos 2, 3 e 4)

Caso contrário, continue no fluxo padrão.

### Passo 2. Identificar o arquivo alvo

Determine o caminho do `script.py` a preencher. Em ordem de prioridade:

1. **Caminho explícito no prompt.** Se o aluno passou (ex: `/criar-script meu-botao.pushbutton/script.py`), use esse caminho
2. **CWD dentro de `.pushbutton/`.** Se a pasta atual termina em `.pushbutton`, o alvo é `script.py` no cwd
3. **Pasta única `.pushbutton/` no cwd.** Se tem só uma, perguntar: "Achei um pushbutton em `{caminho}`. É esse?"
4. **Múltiplos pushbuttons.** Listar todos os `.pushbutton/` da extension atual e pedir pra escolher
5. **Nenhum encontrado.** Responder: "Não encontrei nenhum pushbutton aqui. Você precisa criar o bundle primeiro com `/criar-pushbutton`. Quer acionar agora?"

### Passo 3. Coletar a descrição

Se o aluno já descreveu o que quer (no prompt da skill ou em mensagens anteriores), use isso.

Se não há descrição prévia, pergunte uma vez:

> "Descreva em uma frase o que esse script deve fazer no Revit."

Se a resposta for vaga ("um script bom de cotas"), pedir UMA pergunta de refinamento:
> "Quer cotar paredes, pisos, ou outro elemento? E o usuário escolhe algo antes (tipo de cota, view, seleção)?"

### Passo 4. Classificar trivial vs não-trivial

Aplique o critério do `CLAUDE.md` (seção "Fluxo Padrão Antes de Gerar Código").

**Trivial:**
- 1 ação no Revit
- Sem UI customizada
- Lógica linear, sem decisões do usuário

**Não-trivial:**
- 2 ou mais ações
- Tem decisão do usuário (escolher tipo, nível, view)
- Geometria não trivial (cotas, criação de elementos, intersecções)
- UI customizada (WPF, dockable pane)

Se for **não-trivial**, pergunte:

> "Essa tarefa tem várias decisões e edge cases. Recomendo planejar antes pra evitar retrabalho.
> 1. Planejar primeiro com `/planejar-plugin`
> 2. Não, vai direto pro código"

Se for trivial ou aluno escolher seguir, continue.

### Passo 5. Verificar contexto do arquivo e da extension

Leia o caminho do arquivo alvo e extraia:

- **Nome do pushbutton** (da pasta `.pushbutton`). Vira o `__title__`. Substitua hífens/underscores por espaços e use `\n` para quebrar em duas linhas se for longo.
- **Nome do panel** (da pasta `.panel` acima). Útil pra `__doc__`.
- **Nome da tab** (da pasta `.tab` acima). Útil pra `__doc__`.
- **Nome da extension** (da pasta `.extension`). Pode entrar em `__author__` ou nos comentários.

Leia o conteúdo atual de `script.py`:

- **Vazio ou só com boilerplate** (ex: arquivo gerado por `/criar-pushbutton` que tem só header e `pass`). Preencher diretamente.
- **Já tem código.** Pergunte: "O arquivo já tem código. Quer substituir tudo ou estender?"
  1. Substituir tudo
  2. Estender (mantenho o que tem e adiciono o novo comportamento)
  3. Cancelar

### Passo 6. Gerar o código

Aplique as 9 Regras Técnicas Absolutas do `CLAUDE.md` e o **Estilo de API** (seção "Revit API direta vs wrappers pyRevit"). Use a estrutura padrão:

```python
# -*- coding: utf-8 -*-
"""Descrição curta do que o script faz."""

__title__ = "Nome do Botão"
__author__ = "BIM Coder"
__doc__ = "Descrição completa que aparece no tooltip e no help do pyRevit."

# Imports condicionais. Só o que é realmente usado.
from pyrevit import revit, forms     # forms: pyrevit. revit: doc/uidoc/pick
from Autodesk.Revit.DB import (
    FilteredElementCollector, BuiltInCategory, Transaction,
    # ... outras classes da Revit API direta
)

doc = revit.doc
uidoc = revit.uidoc


def main():
    # logica principal aqui
    ...


if __name__ == "__main__":
    main()
```

**Regra de import: priorize a API direta do Revit.** Wrappers do `pyrevit.revit.*` só nas duas exceções abaixo. Tudo mais é `Autodesk.Revit.DB` / `Autodesk.Revit.UI`.

| Operação | O que importar |
|---|---|
| Coletor de elementos | `from Autodesk.Revit.DB import FilteredElementCollector` |
| Transação | `from Autodesk.Revit.DB import Transaction` |
| Categorias e parâmetros | `from Autodesk.Revit.DB import BuiltInCategory, BuiltInParameter` |
| Geometria (XYZ, Line, etc) | `from Autodesk.Revit.DB import XYZ, Line, Transform, ...` |
| Unidades | `from Autodesk.Revit.DB import UnitUtils, UnitTypeId` |
| **Formulários (alert, select)** | `from pyrevit import forms` ← exceção 1 |
| **Output formatado** | `from pyrevit import output` ← exceção 1 |
| **Selecionar elementos** | `revit.pick_elements(message="...")` ← exceção 2 |
| **Selecionar por categoria** | `revit.pick_elements_by_category(BuiltInCategory.X, message="...")` ← exceção 2 |
| **Acesso a doc/uidoc/app** | `from pyrevit import revit; doc = revit.doc` (padrão estabelecido) |

Exemplo certo de fluxo com seleção:

```python
from pyrevit import revit, forms
from Autodesk.Revit.DB import (
    BuiltInCategory, Transaction, ElementId,
)

doc = revit.doc

# selecao via wrapper pyRevit (excecao 2)
paredes = revit.pick_elements_by_category(
    BuiltInCategory.OST_Walls,
    message="Selecione as paredes a cotar"
)

if not paredes:
    forms.alert("Nenhuma parede selecionada.")
    return

# operacao no modelo usa API direta
t = Transaction(doc, "Cotar paredes")
t.Start()
try:
    for parede in paredes:
        # ... codigo usando API direta
        pass
    t.Commit()
except Exception as e:
    if t.HasStarted():
        t.RollBack()
    forms.alert("Erro: {}".format(str(e)))
```

Regras de qualidade (todas vindas do `CLAUDE.md`):

- **Imports condicionais.** Só inclua imports realmente usados. Importar `XYZ, Line, Transform, FilteredElementCollector` quando só `XYZ` foi usado é ruído visual.
- **Variáveis e funções em inglês, snake_case.** `walls`, `selected_dimension`, `wall_type`, `get_walls_in_view()`.
- **Classes em PascalCase.** Se precisar definir uma classe local (ex: `ISelectionFilter` customizado), use `class WallFilter(ISelectionFilter):`.
- **Comentários em português brasileiro com acentuação.** `# coletar paredes da view ativa`.
- **UI strings em português brasileiro.** `forms.alert("Selecione uma parede.")`.
- **Títulos de Transaction em português.** `Transaction(doc, "Cotar paredes da view")`.
- **Transaction obrigatória pra modificações no modelo.** Padrão `try/except` com `RollBack` no `except`.
- **Tratamento de erros amigável.** Capturando exceções e mostrando mensagem pro usuário via `forms.alert`, não traceback técnico.
- **Conversão de unidades explícita.** Se mostrar comprimento, área ou volume pro usuário, sempre converter de pés para metros/cm/m² antes de exibir.

Para tarefas que envolvem seleção do usuário:
- Tipos diferentes têm padrões diferentes. Veja `references/revit-api-dictionary.md` (seção "Seleção do Usuário") para `PickObject`, `PickObjects`, `ISelectionFilter`.

Para criação de elementos:
- Use métodos estáticos novos (`Floor.Create`, `Wall.Create`, `Viewport.Create`) em vez de `doc.Create.New*` (depreciados em Revit 2025+).

### Passo 7. Auto-revisão dupla

Antes de mostrar ou salvar, faça varredura mental em duas frentes (`CLAUDE.md` seção "Auto-Revisão Antes de Entregar").

**Frente 1. As 9 Regras Técnicas Absolutas.** Confirme cada uma:

1. `Transaction(doc, "...")` em vez de `revit.Transaction(...)`
2. `# -*- coding: utf-8 -*-` na primeira linha
3. ElementId comparado via `IntegerValue` se houver comparação de IDs
4. Imports WPF dentro de métodos (não nível de módulo) se houver WPF/forms customizado
5. (Não se aplica a `script.py`. Ícones são tratados por `/criar-pushbutton`)
6. `LoadFamily` com `IFamilyLoadOptions` se houver `LoadFamily`
7. Filtros/callbacks como `self._x` em handlers de janela WPF
8. Conversão de unidades explícita ao mostrar números pro usuário
9. Nome de tipo via `BuiltInParameter.ALL_MODEL_TYPE_NAME`, nunca `.Name`

Se alguma falhar, corrige em silêncio.

**Frente 2. Validação de API.** Pra cada classe, método, propriedade ou enum da Revit API citado:

- Confirme que existe consultando mentalmente `references/revit-api-dictionary.md`
- Não invente. LLMs alucinam nomes plausíveis mas inexistentes

Casos clássicos pra vigiar:
- **`BuiltInParameter`.** A API tem centenas. Fácil chutar errado. Confirme antes de usar.
- **`BuiltInCategory`.** Alguns variam entre versões (`OST_Gutters` vs `OST_Gutter`). Quando inseguro, use `getattr(BuiltInCategory, "OST_X", None)` com fallback.
- **`Document.Create.New*`.** Vários foram removidos em Revit 2025+. Use `.Create()` estático.
- **Propriedades de `OverrideGraphicSettings`.** Alguns getters não existem em C#, só funcionam via dispatch dinâmico no IronPython.

Quando precisar usar uma API com incerteza:
- Se houver alternativa documentada, use a alternativa
- Se for essencial e não houver substituto, adicione um comentário curto no código:
  ```python
  # Atencao: BuiltInParameter.X pode nao existir em todas as versoes do Revit.
  # Validar antes de testar. Alternativa segura: Y.
  ```

### Passo 8. Decidir entre entrega direta ou preview

Determine o modo de entrega com base no contexto.

**Entrega DIRETA (salvar imediatamente, sem preview):** quando TODAS as condições abaixo forem verdadeiras:
- O aluno acionou a skill com prompt inline (descrição veio junto no comando, ex: `/criar-script "lista paredes"`) OU em UMA única mensagem no chat
- O `script.py` alvo estava vazio ou com boilerplate apenas (regra do Passo 5)
- A descrição era clara e não houve necessidade de pergunta de refinamento no Passo 3
- A tarefa foi classificada como trivial no Passo 4

Esse é o caso mais comum no dia a dia: aluno tem um script aberto, descreve o que quer numa frase, espera o resultado.

Nesse modo:
- Pule direto pro Passo 9 (salvar)
- A confirmação final inclui um resumo do que o script faz em 1 ou 2 linhas
- Se o aluno quiser ajustar depois, ele pede ajuste pontual (Edição Cirúrgica)

**Entrega COM PREVIEW (mostra antes, pede aprovação):** quando QUALQUER uma das condições abaixo for verdadeira:
- O `script.py` já tinha código (precisa decidir substituir vs estender no Passo 5)
- O aluno descreveu em modo conversacional ao longo de várias mensagens
- Foi necessário fazer pergunta de refinamento no Passo 3
- A tarefa foi não-trivial e o aluno optou por seguir sem `/planejar-plugin`
- O aluno explicitamente pediu "mostra antes" ou "quero revisar"
- A skill teve incertezas técnicas que adicionaram comentários de atenção no código

Nesse modo:
- Mostre o código completo no chat
- Pergunte:
  ```
  Salvar em: {caminho-relativo}

  1. Aprovar e salvar
  2. Quero ajustar antes de salvar
  3. Cancelar
  ```
- Se ajustar: colete o feedback em uma mensagem e refaça aplicando as mudanças (volte ao Passo 6 só na parte alterada. Não reescreva o que não foi pedido, Edição Cirúrgica)
- Se cancelar: confirme "Ok, cancelado. Nada foi salvo." e encerre

### Passo 9. Salvar

Escreva o arquivo com encoding UTF-8 (necessário pra acentos nos comentários e UI strings).

**Se foi entrega direta:**
```
Script salvo em {caminho-relativo}.
{Resumo em 1 ou 2 linhas do que o script faz, ex: "Lista todas as paredes da view ativa em relatório formatado, com conversão de pés para metros."}

Se quiser ajustar algo, é só pedir.
```

**Se foi entrega com preview:**
```
Pronto. Script salvo em {caminho-relativo}.
```

### Passo 10. Sugerir próximo passo

Apenas se for relevante e em UMA linha. Exemplos:

- Se o `.pushbutton/` não tem `icon.png`: "Não vi ícone no bundle. Quer rodar `/buscar-icone` pra adicionar?"
- Se o script usa `Transaction`: "Pra testar, abra o Revit e clique em `pyRevit > Reload` antes de clicar no botão."
- Se ficou complexo: "Se quiser uma versão mais robusta com tratamento de edge cases, rode `/planejar-plugin` que reescrevo com cobertura completa."

Não invente sugestões só pra preencher. Se não há nada relevante, encerre sem sugestão.

---

## Edição cirúrgica (modo ajuste posterior)

Quando o aluno, depois do script já estar salvo, pedir um ajuste pontual ("renomeia a variável X", "muda o título pra Y", "adiciona uma confirmação antes de cotar"):

- Altere SOMENTE o que foi pedido
- Não reescreva trechos vizinhos
- Não adicione melhorias não solicitadas
- Se notar outro problema durante o ajuste, mencione DEPOIS da entrega, em parágrafo separado, como sugestão opcional

---

## Exemplos de execução

### Exemplo 1. Entrega direta (caso mais comum)

**Aluno:** `/criar-script "lista todas as paredes da view ativa em um relatório"`

**Skill:**

1. CWD é `MinhaExtensao.extension/Ferramentas.tab/Relatorios.panel/ListarParedes.pushbutton/`. Alvo identificado.
2. Descrição clara, sem refinamento.
3. Classificação: **trivial**.
4. `script.py` atual: vazio.
5. Auto-revisão passa.
6. **Salva direto** (Passo 8 → Entrega Direta):

```
Script salvo em ListarParedes.pushbutton/script.py.
Lista todas as paredes da view ativa em relatório formatado, com tipo, comprimento e altura. Conversão pés → metros aplicada. Sem modificação no modelo (sem Transaction).

Se quiser ajustar algo, é só pedir.
```

Aluno abre o Revit, testa, funciona. Se quiser mudar algo: "renomeia o título pra 'Inventário de Paredes'", e a skill faz Edição Cirúrgica.

### Exemplo 2. Entrega com preview (caso menos comum)

**Aluno:** "preciso cotar paredes" *(em conversa, sem comando)*

**Skill:**
1. Pergunta: "Quais paredes? Todas da view, só as selecionadas, ou da view inteira do projeto?"
2. Aluno responde: "da view ativa, mas com um tipo de cota customizado"
3. Skill: "O tipo de cota é fixo ou o usuário escolhe antes?"
4. Aluno: "usuário escolhe"

Múltiplas mensagens de conversa = **Entrega com Preview**. Skill mostra código completo, pede aprovação, ajusta se preciso.

---

## O que NÃO fazer

- **Não criar pastas, bundles ou ícones.** Isso é trabalho do `/criar-pushbutton`. Esta skill só preenche o conteúdo do script.
- **Não silenciar erros com `except: pass`.** Sempre mostrar mensagem amigável via `forms.alert`.
- **Não inventar nomes de `BuiltInParameter` ou `BuiltInCategory`.** Quando inseguro, consultar `references/revit-api-dictionary.md` ou usar `getattr` com fallback.
- **Não usar `revit.Transaction`.** Sempre `Transaction(doc, "...")`.
- **Não esquecer `# -*- coding: utf-8 -*-`** na primeira linha, mesmo que o código não tenha acentos no momento.
- **Não fazer mais de uma pergunta por vez** ao aluno. Encadear perguntas atrapalha o fluxo.
- **Não revelar pro aluno que rodou auto-revisão** ou consultou references. Entregue o código limpo.
- **Não pedir aprovação prévia em entrega direta.** Se as 4 condições do Passo 8 forem verdadeiras (prompt inline, script vazio, descrição clara, tarefa trivial), salve direto e mostre resumo.
