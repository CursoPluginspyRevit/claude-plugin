# Regras Essenciais. Núcleo operacional do kit

> Leia este arquivo UMA vez por sessão **se** as regras abaixo ainda não estiverem no seu
> contexto. É a fonte de verdade operacional das skills de geração de código. São ~60 linhas
> de propósito: não precisa reler a cada skill, e não precisa abrir o `CLAUDE.md` (que serve
> de documentação do projeto e **não** é carregado automaticamente em runtime).

## Idioma

- **Chat e comentários no código:** português do Brasil, com acentuação correta.
- **Identificadores** (variáveis, funções, classes): inglês. `snake_case` para variáveis/funções, `PascalCase` para classes.
- **Strings de UI** (`forms.alert`, `TaskDialog`) e **títulos de `Transaction`:** português.

## Estilo de API. Revit direta vs wrappers pyRevit

Padrão: SEMPRE `Autodesk.Revit.DB` / `Autodesk.Revit.UI` diretos (prepara o aluno pra StackOverflow, GitHub e migração pra C#).

Apenas **DUAS exceções** usam `pyrevit.*`:
1. **UI auxiliar:** `from pyrevit import forms, output` (alert, SelectFromList, ask_for_string, print_table).
2. **Seleção no modelo:** `revit.pick_elements(message=...)` e `revit.pick_elements_by_category(BuiltInCategory.X, message=...)` — já tratam `OperationCanceledException` e `ISelectionFilter`.

Mais o acesso a contexto (padrão estabelecido): `from pyrevit import revit; doc = revit.doc; uidoc = revit.uidoc`. Nada mais de `pyrevit.revit` em scripts.

## 9 Regras Técnicas Absolutas (nunca quebrar, mesmo a pedido)

1. **Transação:** `Transaction(doc, "Nome em PT")` + `try`/`Commit`/`except`/`RollBack`. NUNCA `revit.Transaction(...)`.
2. **Encoding:** `# -*- coding: utf-8 -*-` na 1ª linha de todo `script.py`.
3. **ElementId:** comparar via `.IntegerValue`, nunca `==` direto entre objetos `Id`.
4. **Imports WPF:** `wpf`, `DispatcherTimer` etc. NUNCA no nível de módulo em `startup.py` ou `lib/` — só dentro de métodos. Senão corrompe o cache `_wpf` (sintoma: `No module named _wpf` em todos os botões com forms).
5. **Ícones:** 96x96 PNG transparente, dois temas — `icon.png` (linhas #344054) + `icon.dark.png` (linhas #FFFFFF). (Quem trata é `/criar-pushbutton`; não se aplica ao conteúdo de `script.py`.)
6. **LoadFamily:** `doc.LoadFamily(path, IFamilyLoadOptions)` — sempre o 2º argumento em contexto não-modal, senão o diálogo trava o handler.
7. **Refs pro .NET:** filtros, callbacks e objetos passados pra `PickObjects`/handlers vivem como `self._x` ou variável de módulo (local é coletada pelo GC do IronPython antes do .NET chamar de volta).
8. **Unidades:** a unidade interna da API é **pés**. Converter explícito ao exibir: `UnitUtils.ConvertFromInternalUnits(v, UnitTypeId.Meters)`. Esquecer gera bug de magnitude (30000m no lugar de 30cm).
9. **Nome de tipo:** via `BuiltInParameter.ALL_MODEL_TYPE_NAME`, NUNCA `.Name`. Pegue o `ElementType` com `doc.GetElement(elem.GetTypeId())` e leia o parâmetro.

Detalhes longos com exemplos e causa/fix: `references/armadilhas.md` (30+ armadilhas). Só abra em dúvida específica.

## Trivial vs não-trivial

- **Trivial** (gera direto): 1 ação no Revit, sem UI customizada, lógica linear, sem decisão do usuário. Ex: "lista paredes da view", "exporta a view como PNG".
- **Não-trivial** (sugira `/planejar-plugin` antes): 2+ ações, decisão do usuário (escolher tipo/nível/view), geometria não trivial (cotas, criação, intersecção) ou UI customizada (WPF, dockable pane).

## Modo RevitFlow Builder

Se a descrição vier com cabeçalho `SCRIPT PYREVIT — N ETAPAS` / linha de `====` ou ETAPAs numeradas com `API: Classe` / `API: Método`:

- **Não** acione `/planejar-plugin` (o plano já foi feito no Builder).
- Siga as ETAPAs em ordem; comente `# ETAPA N` em cada bloco.
- **Análise crítica:** conserte imports quebrados, placeholders `{x}` ou descrições livres no lugar de constantes, enums em formato livre, valores com tipo errado em `param.Set(...)`.
- Aplique as 9 Regras mesmo que o prompt contrarie. Mencione no fim, em 1 linha, o que ajustou e por quê.

## Auto-revisão (silenciosa, antes de entregar)

- **Frente 1 — 9 Regras:** confirme cada uma. Conserte em silêncio.
- **Frente 2 — API:** só valide contra `references/revit-api-dictionary.md` as APIs **incomuns ou duvidosas**. APIs comuns (`FilteredElementCollector`, `Transaction`, `BuiltInCategory.OST_*`, `UnitUtils`) não precisam de consulta — não abra o dicionário à toa. Não invente nomes de `BuiltInParameter`/`BuiltInCategory`; na dúvida use `getattr(BuiltInCategory, "OST_X", None)` com fallback.
- Nunca diga ao aluno que rodou auto-revisão nem que consultou references. Entregue o código limpo.
