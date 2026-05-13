# pyRevit Fundamentals

Fundamentos da criação de extensions pyRevit. Cobre estrutura de pastas, tipos de bundle, variáveis globais do ambiente, IronPython 2.7, formulários nativos, output, ícones e layout.

Para o dicionário da Revit API em si (FilteredElementCollector, geometria, parâmetros, transações), veja `revit-api-dictionary.md`. Para o padrão completo de dockable pane (painel ancorado nativo), veja `dockable-pane-pattern.md`.

---

## Estrutura de uma Extension pyRevit

```
MinhaExtensao.extension/
├── extension.json
└── MinhaFerramenta.tab/
    └── MeuPainel.panel/
        └── MeuBotao.pushbutton/
            ├── script.py
            ├── icon.png
            └── icon.dark.png
```

O `extension.json` registra a extensão e define nome, autor e versão. pyRevit detecta automaticamente ao reiniciar.

---

## Tipos de Bundle

| Bundle | Função |
|---|---|
| `.pushbutton` | Botão simples. Executa `script.py` ao clicar |
| `.pulldown` | Botão com dropdown de sub-botões |
| `.splitpushbutton` | Botão split com ação padrão e lista de alternativas |
| `.smartbutton` | Botão dinâmico baseado em condição (habilita/desabilita) |
| `.stack`, `.stack2`, `.stack3` | Empilha 2 ou 3 botões verticalmente no painel |
| `.panel` | Agrupa bundles numa aba |
| `.tab` | Aba no ribbon do Revit |

Stack com 2 botões pode usar `.stack2`, com 3 usa `.stack3`, ou simplesmente `.stack` que o pyRevit detecta pela quantidade de filhos.

### Conteúdo esperado de cada bundle

| Bundle | Contém |
|---|---|
| `.pushbutton` | `script.py`, `icon.png`, `icon.dark.png`, (opcional) `bundle.yaml` |
| `.pulldown` | `bundle.yaml` (title+tooltip), `icon.png`, `icon.dark.png`, N `.pushbutton/` dentro, `_layout.yaml` |
| `.stack` / `.stack2` / `.stack3` | 2 ou 3 `.pushbutton/` dentro (sem bundle/ícone — stacks são anônimos) |
| `.panel` | `bundle.yaml` (title), `_layout.yaml`, N bundles dentro |
| `.tab` | `bundle.yaml` (title), `_layout.yaml`, N `.panel/` dentro |
| `.extension` | `extension.json`, `_layout.yaml`, N `.tab/` dentro |

Observação prática: `bundle.yaml` em pushbutton é redundante. O `__title__` do `script.py` já cumpre esse papel. Os bundles em panel e pulldown é que importam de fato.

---

## Variáveis globais do ambiente pyRevit

No ambiente pyRevit, as seguintes variáveis já estão disponíveis sem importação explícita:

```python
from pyrevit import revit, DB, UI, script, forms, output

doc = revit.doc          # documento ativo (Autodesk.Revit.DB.Document)
uidoc = revit.uidoc      # UI document ativo (Autodesk.Revit.UI.UIDocument)
app = revit.app          # aplicação Revit (Autodesk.Revit.ApplicationServices.Application)
```

Em scripts dentro de `.pushbutton`, `__revit__` também está disponível (equivale a `UIApplication`).

---

## Padrão de Script Bem Estruturado

```python
# -*- coding: utf-8 -*-
"""Descrição curta do script."""

__title__ = "Nome do Botão"
__author__ = "Seu Nome"
__doc__ = "Descrição completa do que o script faz."

from pyrevit import revit, DB, forms, output, script
from Autodesk.Revit.DB import Transaction, FilteredElementCollector

doc = revit.doc
uidoc = revit.uidoc
op = output.get_output()

def main():
    # lógica principal
    t = Transaction(doc, "Operação X")
    t.Start()
    try:
        # modificações no modelo
        t.Commit()
        forms.alert("Operação concluída com sucesso.")
    except Exception as e:
        if t.HasStarted():
            t.RollbackToSavepoint()
        forms.alert("Erro: {}".format(str(e)))

if __name__ == "__main__":
    main()
```

Itens obrigatórios em todo `script.py`:
- Encoding `# -*- coding: utf-8 -*-` na primeira linha
- `__title__` definindo o nome que aparece no ribbon
- `__doc__` com descrição (aparece no tooltip do botão e no help do pyRevit)

---

## Helpers do pyRevit. Quando usar em vez da Revit API direta

**Regra geral:** API original do Revit (`Autodesk.Revit.DB`, `Autodesk.Revit.UI`) é o padrão. Wrappers do `pyrevit.revit.*` só em duas exceções: formulários e seleção do usuário.

### Exceção 1. Formulários e UI (`pyrevit.forms`)

Veja a seção "Formulários com `pyrevit.forms`" mais abaixo. Use `forms.alert`, `forms.SelectFromList`, `forms.ask_for_one_item`, `forms.pick_file` etc. em vez de criar WPF próprio.

### Exceção 2. Seleção do usuário (`revit.pick_elements*`)

Em vez de chamar `uidoc.Selection.PickObjects(...)` cru da Revit API, use os wrappers do pyRevit. Eles encapsulam:
- Tratamento de `OperationCanceledException` (usuário aperta ESC)
- Criação correta de `ISelectionFilter` interno (evitando a armadilha de variável local coletada pelo GC do IronPython)
- Retorno em lista de `Element` já pronta (não precisa converter `Reference` → `Element` manualmente)

```python
from pyrevit import revit
from Autodesk.Revit.DB import BuiltInCategory

# Pegar elementos sem filtro (qualquer categoria)
elementos = revit.pick_elements(message="Selecione os elementos")

if elementos:
    for e in elementos:
        print(e.Id.IntegerValue, e.Category.Name)
```

```python
# Pegar elementos filtrando por uma categoria
paredes = revit.pick_elements_by_category(
    BuiltInCategory.OST_Walls,
    message="Selecione as paredes"
)
```

```python
# Pegar UM elemento (singular)
elemento = revit.pick_element(message="Selecione um elemento")
```

Retorno:
- Se o usuário **cancelar** (ESC), retorna `None` ou lista vazia (varia por versão do pyRevit). Trate sempre com `if not selecao:`.
- Se selecionar com sucesso, retorna lista de `Element` (no `pick_elements*`) ou um `Element` único (no `pick_element`).

### O que continua sendo Revit API direta

Tudo o que NÃO é form ou seleção de usuário no modelo:

- `FilteredElementCollector` (coleta programática)
- `Transaction` (modificação no modelo)
- Geometria (`XYZ`, `Line`, `CurveLoop`, `Transform`, `Options`)
- Parâmetros (`element.LookupParameter`, `BuiltInParameter`)
- Materiais, Views, Sheets, Levels, Links
- `UnitUtils.ConvertFromInternalUnits` / `ConvertToInternalUnits`
- `TaskDialog.Show` (dialogo simples)
- `ElementTransformUtils.MoveElement` / `RotateElement` / `CopyElements`

### Por que esse padrão

- **Portabilidade:** código que usa Revit API direta migra pra C# sem refatoração. Wrappers do pyRevit não existem em C#.
- **Documentação:** docs oficiais da Autodesk, StackOverflow, GitHub, livros, todos usam a API direta. Aluno que se acostuma com wrappers fica preso no ecossistema pyRevit.
- **Manutenção:** wrappers do pyRevit podem mudar entre versões. A API direta é estável.
- **Exceções justificadas:** `forms` e `pick_elements*` resolvem problemas reais (boilerplate de WPF, GC do IronPython coletando filtro). Outros wrappers não dão ganho equivalente.

---

## IronPython 2.7. Limitações e Atenções

O pyRevit roda em IronPython 2.7. Isso impõe restrições importantes:

- **Versão Python**: 2.7. Não tem features modernas
- **Não disponíveis**: f-strings, walrus operator, match/case, type hints
- **Encoding**: sempre declarar `# -*- coding: utf-8 -*-` no topo se usar acentos
- **Print**: usar `print("texto")` com parênteses
- **Bibliotecas**: apenas as compatíveis com IronPython. Sem `pandas`, `numpy` nativo, `requests` ou outras que dependem de C/CPython
- **Formatação de string**: usar `"{}".format(valor)` ou `"%s" % valor`, nunca f-string

```python
# ERRADO em IronPython 2.7
nome = "Fulano"
print(f"Olá, {nome}")  # SyntaxError

# CORRETO
print("Olá, {}".format(nome))
```

---

## Formulários com `pyrevit.forms`

A módulo `forms` fornece UI padronizada sem precisar de WPF customizado.

```python
from pyrevit import forms

# Seleção simples de item
opcoes = ["Opção A", "Opção B", "Opção C"]
selecionado = forms.ask_for_one_item(opcoes, prompt="Escolha uma opção")

# Input de texto
texto = forms.ask_for_string(prompt="Digite o valor", title="Input")

# Confirmação
if forms.alert("Confirma a operação?", ok=True, cancel=True):
    # executar
    pass

# Seleção de arquivo
caminho = forms.pick_file(file_ext="csv")

# Alert com opções (botões customizados)
res = forms.alert(
    "Escolha o modo de operação:",
    options=["Opção A", "Opção B", "Opção C"]
)
if res == "Opção A":
    pass

# Seleção múltipla com checkboxes
selecionados = forms.SelectFromList.show(
    lista_de_objetos,
    title="Título da Janela",
    multiselect=True,
    button_name="Selecionar",
)
# Os objetos da lista precisam ter __str__() definido para exibição
```

Para formulários customizados que `forms` não cobre, use WPF próprio. Veja `dockable-pane-pattern.md` para o padrão WPF + IronPython.

---

## Output e Log

O `pyrevit.output` permite renderizar resultados ricos (Markdown, tabelas, links clicáveis) numa janela que abre ao final do script.

```python
from pyrevit import output

op = output.get_output()

# Markdown
op.print_md("## Resultado da Operação")
op.print_md("- Item 1")
op.print_md("- Item 2")

# Tabela
op.print_table(
    table_data=[["Col1", "Col2"], ["val1", "val2"]],
    title="Tabela de Resultados",
    columns=["Coluna 1", "Coluna 2"]
)

# Link clicável que abre o elemento no Revit
op.linkify(element.Id)
```

Útil para relatórios de auditoria, listagens longas e debugging.

---

## Ícones. Dual 96×96 (light + dark)

O pyRevit (4.8+) espera **dois PNGs 96×96** dentro de cada bundle `.pushbutton` ou `.pulldown`:

```
MeuBotao.pushbutton/
├── script.py
├── icon.png           ← tema claro, linhas cinza (#344054)
└── icon.dark.png      ← tema escuro, linhas BRANCAS (#FFFFFF)
```

Pontos importantes:
- **Não é 32x32.** Muitas referências antigas citam 32x32, mas o padrão atual é 96x96 PNG transparente
- **`icon.dark.png` não é só um PNG invertido.** É um PNG com as linhas já desenhadas em branco
- **O Revit alterna automaticamente** entre os dois conforme o tema da UI. Só precisa que os dois arquivos existam

### Gerar via Iconify (Canvas API)

```javascript
// Tema claro
const url = `https://api.iconify.design/${prefix}/${name}.svg?height=96&color=%23344054`;

// Tema escuro
const url = `https://api.iconify.design/${prefix}/${name}.svg?height=96&color=%23FFFFFF`;

// Renderiza no <img> → desenha no <canvas width=96 height=96> → toBlob('image/png')
```

O Iconify dá acesso a 200 mil ícones de 150 bibliotecas (Lucide, Material Symbols, Tabler, Phosphor, etc.). Para gerar via Python (server-side), usar `cairosvg` ou `Pillow` + `svglib`.

---

## Estrutura de `_layout.yaml` em todos os níveis

Para preservar ordem de tabs, panels e botões, o pyRevit usa `_layout.yaml` (ou `_layout` plain text) **em cada nível da hierarquia**:

```
MinhaExt.extension/
├── _layout.yaml              ← ordena as tabs
├── Tab1.tab/
│   ├── _layout.yaml          ← ordena os panels dentro da tab
│   ├── bundle.yaml           ← metadata da tab (title)
│   └── Panel1.panel/
│       ├── _layout.yaml      ← ordena os botões dentro do panel
│       ├── bundle.yaml       ← metadata do panel (title)
│       └── Pulldown1.pulldown/
│           ├── _layout.yaml  ← ordena os botões filhos do pulldown
│           ├── bundle.yaml   ← title, tooltip, icon ref
│           └── Botao1.pushbutton/
│               ├── script.py
│               ├── icon.png
│               └── icon.dark.png
```

### Formato YAML list (preferido)

```yaml
- Botao1
- Pulldown1
- Stack1
```

### Formato plain text (`_layout` sem extensão)

```
Botao1
Pulldown1
Stack1
```

### Formato alternativo dentro do `bundle.yaml`

```yaml
title: "Meu Panel"
layout:
  - Botao1
  - Pulldown1
```

Nome no layout pode ser com ou sem extensão (`Botao1` ou `Botao1.pushbutton`). Parser do pyRevit aceita ambos.

Sem `_layout`, a ordem fica alfabética ou pela ordem em que o sistema de arquivos enumera. Frequentemente errada.

---

## `extension.json` (raiz da extension)

```json
{
    "name": "MinhaExtensao",
    "description": "Descrição do que a extension faz",
    "author": "Seu Nome",
    "rocket_mode_compatible": true,
    "version": "1.0.0"
}
```

`rocket_mode_compatible: true` indica que a extension pode rodar com o Rocket Mode ativo (modo otimizado do pyRevit que mantém scripts carregados em memória entre cliques).

---

## Workflow do desenvolvimento

1. **Criar a extension** em qualquer pasta. O pyRevit detecta extensions em três lugares por padrão:
   - `%APPDATA%\pyRevit\Extensions\` (pasta padrão do usuário)
   - `%APPDATA%\pyRevit\GitHubAddins\` (pasta de extensions clonadas do GitHub)
   - Qualquer pasta adicionada manualmente em `pyRevit > Settings > Custom Extension Folders`

2. **Reiniciar o Revit** após criar/renomear pastas de extension, tab ou panel. Mudanças em `script.py` (conteúdo) não exigem reinicialização.

3. **Recarregar a extension** sem reiniciar o Revit: usar o botão `Reload` do próprio pyRevit (na tab pyRevit do ribbon).

4. **Debug:** o console do pyRevit (`Ctrl + Shift + clicar no botão`) abre o script no modo debug, mostrando print() em tempo real.

---

## Considerações de Performance

- **Rocket Mode** acelera muito execução de scripts longos, mas reinicializa o estado a cada novo script. Não dá pra confiar em globais persistentes entre execuções
- **Imports pesados** (WPF, .NET) podem demorar 1 a 2 segundos no primeiro clique. Considerar lazy imports dentro de funções
- **`FilteredElementCollector`** é eficiente para coletas grandes, mas evite iterar e filtrar manualmente em Python (`for elem in collector if elem.Category...`) quando o filtro pode ser feito no próprio coletor (`.OfCategory(...)`)
