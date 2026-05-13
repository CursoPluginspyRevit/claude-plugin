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

ou estrutura numerada por ETAPAs com `API: Classe` e `API: Método`, mude pro **modo RevitFlow Builder** descrito no `CLAUDE.md` (seção "Fluxo Padrão Antes de Gerar Código"). Nesse modo:

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
4. **Múltiplos pushbuttons.** Listar todos os `.pushbutton/` da extension atual e pedir pra escolher:
   ```
   Achei estes pushbuttons. Qual quer preencher?
   1. Ferramentas.tab/Cotas.panel/CotarParedes.pushbutton/script.py
   2. Ferramentas.tab/Cotas.panel/CotarPisos.pushbutton/script.py
   3. Ferramentas.tab/Relatorios.panel/ListarPortas.pushbutton/script.py
   ```
5. **Nenhum encontrado.** Responder: "Não encontrei nenhum pushbutton aqui. Você precisa criar o bundle primeiro com `/criar-pushbutton`. Quer acionar agora?"

### Passo 3. Coletar a descrição

Se o aluno já descreveu o que quer (no prompt da skill ou em mensagens anteriores), use isso. Confirme em uma linha que você entendeu:

> "Entendi: você quer um script que `{descrição em 1 frase}`. Confirma?"

Se não há descrição prévia, pergunte uma vez:

> "Descreva em uma frase o que esse script deve fazer no Revit."

Exemplo de boa resposta do aluno:
> "cota todas as paredes da view ativa, permitindo escolher o tipo de cota"

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

Se aluno escolher 1, acione `/planejar-plugin` passando o contexto e encerre essa skill.

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
  1. Substituir tudo (vou reescrever do zero)
  2. Estender (mantenho o que tem e adiciono o novo comportamento)
  3. Cancelar

### Passo 6. Gerar o código

Aplique as 9 Regras Técnicas Absolutas do `CLAUDE.md`. Use a estrutura padrão:

```python
# -*- coding: utf-8 -*-
"""Descrição curta do que o script faz."""

__title__ = "Nome do Botão"
__author__ = "BIM Coder"
__doc__ = "Descrição completa que aparece no tooltip e no help do pyRevit."

# Imports condicionais. Só o que é realmente usado.
from pyrevit import revit, forms
from Autodesk.Revit.DB import (
    FilteredElementCollector, BuiltInCategory, Transaction,
    # ... só os realmente usados abaixo
)

doc = revit.doc
uidoc = revit.uidoc


def main():
    # logica principal aqui
    ...


if __name__ == "__main__":
    main()
```

Regras de qualidade (todas vindas do `CLAUDE.md`):

- **Imports condicionais.** Só inclua imports realmente usados. Importar `XYZ, Line, Transform, FilteredElementCollector` quando só `XYZ` foi usado é ruído visual.
- **Variáveis e funções em inglês, snake_case.** `walls`, `selected_dimension`, `wall_type`, `get_walls_in_view()`.
- **Classes em PascalCase.** Se precisar definir uma classe local (ex: `ISelectionFilter` customizado), use `class WallFilter(ISelectionFilter):`.
- **Comentários em português brasileiro com acentuação.** `# coletar paredes da view ativa`.
- **UI strings em português brasileiro.** `forms.alert("Selecione uma parede.")`, `TaskDialog.Show("Erro", "Operação cancelada.")`.
- **Títulos de Transaction em português.** `Transaction(doc, "Cotar paredes da view")`. Aparece no histórico de undo.
- **Transaction obrigatória pra modificações no modelo.** Padrão `try/except` com `RollBack` no `except`.
- **Tratamento de erros amigável.** `try/except` capturando exceções e mostrando mensagem pro usuário via `forms.alert` ou `TaskDialog`, não traceback técnico.
- **Conversão de unidades explícita.** Se mostrar comprimento, área ou volume pro usuário, sempre converter de pés para metros/cm/m² antes de exibir.

Para tarefas que envolvem seleção do usuário:
- Tipos diferentes têm padrões diferentes. Veja `references/revit-api-dictionary.md` (seção "Seleção do Usuário") para `PickObject`, `PickObjects`, `ISelectionFilter`.

Para criação de elementos:
- Use métodos estáticos novos (`Floor.Create`, `Wall.Create`, `Viewport.Create`) em vez de `doc.Create.New*` (depreciados em Revit 2025+).

### Passo 7. Auto-revisão dupla

Antes de mostrar ao aluno, faça varredura mental em duas frentes (`CLAUDE.md` seção "Auto-Revisão Antes de Entregar").

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

Se alguma falhar, corrige em silêncio antes de mostrar.

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

### Passo 8. Mostrar preview e pedir aprovação

Mostre o código completo no chat e pergunte:

```
{código completo em bloco markdown}

Salvar em: {caminho-relativo-ao-cwd}

1. Aprovar e salvar
2. Quero ajustar antes de salvar
3. Cancelar
```

**Se aluno escolher 2 (ajustar):** colete o feedback em uma mensagem ("o que ajustar?") e refaça o código aplicando as mudanças. Volte ao Passo 6 só na parte alterada. Não reescreva o que não foi pedido (Edição Cirúrgica do `CLAUDE.md`).

**Se cancelar:** confirme "Ok, cancelado. Nada foi salvo." e encerre.

### Passo 9. Salvar

Escreva o arquivo com encoding UTF-8 (necessário pra acentos nos comentários e UI strings).

Confirme com uma linha:

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

## Exemplo de boa execução

**Aluno:** `/criar-script "lista todas as paredes da view ativa em um relatório"`

**Skill:**

1. CWD é `MinhaExtensao.extension/Ferramentas.tab/Relatorios.panel/ListarParedes.pushbutton/`. Alvo identificado: `script.py` no cwd.
2. Descrição clara, sem necessidade de refinar.
3. Classificação: **trivial** (1 ação: coletar e listar. Sem decisão do usuário, sem UI customizada).
4. `script.py` atual: vazio (só com header gerado pelo `/criar-pushbutton`).
5. Nome do botão: "Listar\nParedes". Panel: "Relatorios". Tab: "Ferramentas".
6. Geração:

```python
# -*- coding: utf-8 -*-
"""Lista todas as paredes da view ativa em um relatorio formatado."""

__title__ = "Listar\nParedes"
__author__ = "BIM Coder"
__doc__ = "Coleta todas as paredes visiveis na view ativa e exibe um relatorio com nome do tipo, comprimento e altura."

from pyrevit import revit, output
from Autodesk.Revit.DB import (
    FilteredElementCollector, BuiltInCategory, BuiltInParameter,
    UnitUtils, UnitTypeId
)

doc = revit.doc
uidoc = revit.uidoc


def main():
    # coletar paredes da view ativa
    walls = (
        FilteredElementCollector(doc, doc.ActiveView.Id)
        .OfCategory(BuiltInCategory.OST_Walls)
        .WhereElementIsNotElementType()
        .ToElements()
    )

    if not walls:
        from pyrevit import forms
        forms.alert("Nenhuma parede encontrada na view ativa.")
        return

    # montar dados do relatorio
    rows = []
    for wall in walls:
        # nome do tipo via BuiltInParameter (regra 9 do kit)
        type_elem = doc.GetElement(wall.GetTypeId())
        type_name = type_elem.get_Parameter(
            BuiltInParameter.ALL_MODEL_TYPE_NAME
        ).AsString()

        # comprimento em metros (a API retorna pes internamente)
        length_param = wall.get_Parameter(BuiltInParameter.CURVE_ELEM_LENGTH)
        length_m = UnitUtils.ConvertFromInternalUnits(
            length_param.AsDouble(), UnitTypeId.Meters
        ) if length_param else 0.0

        # altura em metros
        height_param = wall.get_Parameter(BuiltInParameter.WALL_USER_HEIGHT_PARAM)
        height_m = UnitUtils.ConvertFromInternalUnits(
            height_param.AsDouble(), UnitTypeId.Meters
        ) if height_param else 0.0

        rows.append([type_name, "{:.2f} m".format(length_m), "{:.2f} m".format(height_m)])

    # mostrar relatorio
    op = output.get_output()
    op.print_md("## Paredes da view: {}".format(doc.ActiveView.Name))
    op.print_md("Total: {} paredes".format(len(walls)))
    op.print_table(
        table_data=rows,
        title="Inventario de Paredes",
        columns=["Tipo", "Comprimento", "Altura"]
    )


if __name__ == "__main__":
    main()
```

7. Auto-revisão dupla: tudo OK. Regra 1 não se aplica (sem modificação no modelo, sem Transaction). Regra 9 cumprida. APIs validadas: `OST_Walls`, `CURVE_ELEM_LENGTH`, `WALL_USER_HEIGHT_PARAM`, `ALL_MODEL_TYPE_NAME`, `UnitTypeId.Meters` todos no dicionário.
8. Mostra preview no chat. Aluno aprova.
9. Salva em `MinhaExtensao.extension/Ferramentas.tab/Relatorios.panel/ListarParedes.pushbutton/script.py`.
10. Sugestão: "Não vi ícone no bundle. Quer rodar `/buscar-icone` pra adicionar?"

---

## O que NÃO fazer

- **Não criar pastas, bundles ou ícones.** Isso é trabalho do `/criar-pushbutton`. Esta skill só preenche o conteúdo do script.
- **Não silenciar erros com `except: pass`.** Sempre mostrar mensagem amigável via `forms.alert`.
- **Não inventar nomes de `BuiltInParameter` ou `BuiltInCategory`.** Quando inseguro, consultar `references/revit-api-dictionary.md` ou usar `getattr` com fallback.
- **Não usar `revit.Transaction`.** Sempre `Transaction(doc, "...")`.
- **Não esquecer `# -*- coding: utf-8 -*-`** na primeira linha, mesmo que o código não tenha acentos no momento.
- **Não fazer mais de uma pergunta por vez** ao aluno. Encadear perguntas atrapalha o fluxo.
- **Não revelar pro aluno que rodou auto-revisão** ou consultou references. Entregue o código limpo.
