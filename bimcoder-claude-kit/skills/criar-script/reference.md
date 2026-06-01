# Referência da skill `criar-script`

Material de apoio carregado **sob demanda**. A `SKILL.md` cobre o fluxo; abra este arquivo
só quando precisar do exemplo completo, da tabela de imports ou dos casos de entrega.

---

## Estrutura padrão do `script.py`

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

## Tabela de imports. O que vem de onde

Priorize a API direta do Revit. Wrappers do `pyrevit.revit.*` só nas duas exceções marcadas.

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

## Exemplo completo. Fluxo com seleção + transação

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

## Notas de geração

- **Imports condicionais.** Só inclua o que é usado. Importar `XYZ, Line, Transform` quando só `XYZ` foi usado é ruído.
- **Seleção do usuário.** Tipos diferentes têm padrões diferentes. Veja `references/revit-api-dictionary.md` (seção "Seleção do Usuário") para `PickObject`, `PickObjects`, `ISelectionFilter`.
- **Criação de elementos.** Use os métodos estáticos novos (`Floor.Create`, `Wall.Create`, `Viewport.Create`) em vez de `doc.Create.New*` (depreciados em Revit 2025+).
- **Tratamento de erro amigável.** Capture exceções e mostre mensagem via `forms.alert`, nunca traceback técnico. Nunca `except: pass`.

---

## Casos de entrega

### Entrega DIRETA (caso mais comum)

**Aluno:** `/criar-script "lista todas as paredes da view ativa em um relatório"`

Arquivo alvo identificado pelo cwd, descrição clara, tarefa trivial, `script.py` vazio → salva direto:

```
Script salvo em ListarParedes.pushbutton/script.py.
Lista todas as paredes da view ativa em relatório formatado, com tipo, comprimento e altura.
Conversão pés → metros aplicada. Sem modificação no modelo (sem Transaction).

Se quiser ajustar algo, é só pedir.
```

### Entrega COM PREVIEW (caso menos comum)

**Aluno:** "preciso cotar paredes" *(conversa, várias mensagens, escolhas do usuário)* → tarefa não-trivial. Mostra o código completo, pergunta:

```
Salvar em: {caminho-relativo}

1. Aprovar e salvar
2. Quero ajustar antes de salvar
3. Cancelar
```

Se ajustar: colete o feedback numa mensagem e refaça só a parte alterada (Edição Cirúrgica). Se cancelar: "Ok, cancelado. Nada foi salvo."
