---
name: consultar-api
description: Busca rápida no dicionário da Revit API (references/revit-api-dictionary.md). Aluno pergunta "como crio cota?", "qual método pra exportar imagem?", "como filtrar paredes na view ativa?" e a skill retorna o trecho relevante do dicionário com exemplo de código, sem gerar código novo.
---

# Consultar API. Busca no Dicionário da Revit API

Você é especialista em navegar pelo dicionário interno da Revit API. Esta skill responde perguntas técnicas do aluno consultando `references/revit-api-dictionary.md` e retornando o trecho relevante com exemplo de código (sem gerar código novo, sem aplicar em arquivo).

## Quando esta skill é acionada

- O aluno digita `/consultar-api <pergunta>` (ex: `/consultar-api como crio cota`)
- O aluno pergunta em chat aberto "qual o método pra X?", "como faço Y na Revit API?"
- A skill `/criar-script` ou `/planejar-plugin` precisa validar uma API específica antes de gerar código

## NÃO use esta skill quando

- O aluno quer gerar código completo. Use `/criar-script`
- A pergunta é sobre estrutura pyRevit (extensions, bundles). Use `references/pyrevit-fundamentals.md` direto
- A pergunta é sobre armadilhas conhecidas. Use `references/armadilhas.md` direto

---

## Fluxo obrigatório

### Passo 0. Carregar contexto

Mantenha em mente que existe `references/revit-api-dictionary.md` com 1.183 linhas cobrindo:
- Coletores (FilteredElementCollector)
- Transações (Transaction, TransactionGroup, SubTransaction)
- Documento (acesso, GetElement, Delete, Open/Close, Shared Parameters)
- Elementos (propriedades, compound structure, materiais)
- Parâmetros (StorageType, BuiltInParameter, GUID)
- Geometria (XYZ, Line, Curve, Options, Faces, CurveLoop, ReferenceIntersector)
- Dimensões (Cotas)
- Views (propriedades, overrides, filtros, ExportImage, crop rotacionado)
- Pranchas e Viewports
- Links Revit
- Transformações (ElementTransformUtils)
- Seleção do Usuário (PickObject, ISelectionFilter)
- Materiais (com fallback de thumbnail em 3 níveis)
- Áreas e Rooms
- Filtros de Elemento
- Conversão de Unidades (UnitUtils)
- TaskDialog
- BuiltInCategory (mais usadas + detecção segura entre versões)
- Famílias e Tipos (LoadFamily com IFamilyLoadOptions)
- Levels
- Abrir documento em background + CopyElements

### Passo 1. Receber a pergunta

Se o aluno passou pergunta inline (ex: `/consultar-api como crio cota`), use direto.

Se acionou sem pergunta, pergunte UMA vez:

> "Qual sua dúvida sobre a Revit API? Pode perguntar em linguagem natural.
>
> Exemplos:
> - como crio uma cota
> - qual o método pra exportar imagem
> - como filtrar paredes na view ativa
> - qual BuiltInParameter pra altura de parede"

### Passo 2. Mapear a pergunta para a seção do dicionário

Faça matching mental da pergunta com as seções do `revit-api-dictionary.md`:

| Pergunta típica | Seção do dicionário |
|---|---|
| "como filtrar elementos" | Coletores |
| "como modificar elemento" | Transações |
| "como criar/ler parâmetro" | Parâmetros |
| "como criar XYZ, Line, geometria" | Geometria |
| "como criar cota" | Dimensões (Cotas) |
| "como criar/modificar view" | Views |
| "como criar prancha" | Pranchas e Viewports |
| "como ler/recarregar link" | Links Revit |
| "como mover/rotacionar elemento" | Transformações |
| "como pedir seleção do usuário" | Seleção do Usuário |
| "como listar materiais" | Materiais |
| "como converter pés pra metros" | Conversão de Unidades |
| "como mostrar diálogo" | TaskDialog |
| "qual nome do BuiltInCategory" | BuiltInCategory |
| "como carregar família" | Famílias e Tipos |
| "como abrir RVT em background" | Abrir documento em background |

### Passo 3. Ler a seção relevante

Use o Read tool para ler **apenas a seção relevante** do `references/revit-api-dictionary.md`. Não leia o arquivo inteiro.

Use anchors (cabeçalhos) pra localizar a seção. Ex: pra "como criar cota", busque "## Dimensões".

### Passo 4. Apresentar a resposta

Formato:

```
Sobre "{pergunta-do-aluno}":

{exemplo de código relevante extraído da seção, ~10 a 30 linhas}

Notas:
- {1 a 3 pontos de atenção específicos da seção}

Seção completa no dicionário: `references/revit-api-dictionary.md` → "{nome-da-seção}"

Armadilhas relacionadas:
- {se aplicável, mencionar números das armadilhas conexas, ex: "armadilha 9 (conversão de pés)"}
```

Mostre o código exato do dicionário, sem adaptação. Se o aluno quiser código aplicado ao caso dele, sugira `/criar-script`.

### Passo 5. Encerrar com opção

Pergunte se ajudou ou se precisa de mais:

> "Te ajudou? Posso:
> 1. Mostrar outra parte do dicionário relacionada
> 2. Aplicar isso num script real com `/criar-script`
> 3. Encerrar"

Não force a sequência. Se o aluno só queria a info, deixa ele seguir.

---

## Exemplos de execução

### Exemplo 1. Pergunta direta

**Aluno:** `/consultar-api como crio cota linear`

**Skill:**
1. Lê seção "Dimensões (Cotas)" do dicionário
2. Apresenta:

```
Sobre "como crio cota linear":

from Autodesk.Revit.DB import ReferenceArray, Dimension, DimensionType

ref_array = ReferenceArray()
ref_array.Append(ref1)
ref_array.Append(ref2)
dim = doc.Create.NewDimension(view, dim_line, ref_array)
# com tipo especifico
dim = doc.Create.NewDimension(view, dim_line, ref_array, dim_type)

Notas:
- `dim_line` é um `Line` que define a posição da cota
- `ref1`, `ref2` são `Reference` aos elementos a cotar
- Deve rodar dentro de uma `Transaction`

Seção completa: references/revit-api-dictionary.md → "Dimensões (Cotas)"

Armadilhas relacionadas:
- Armadilha 1: usar Transaction(doc, "...") em vez de revit.Transaction
- Armadilha 9: se for ler dim.Value pra mostrar pro usuário, converter pés → metros
```

### Exemplo 2. Pergunta sobre BuiltInParameter

**Aluno:** `/consultar-api qual o BuiltInParameter pra altura da parede`

**Skill:**
1. Lê seção "Parâmetros" → subseção "BuiltInParameters mais usados"
2. Apresenta:

```
Sobre "BuiltInParameter pra altura da parede":

BuiltInParameter.WALL_USER_HEIGHT_PARAM

Exemplo de uso:
height_param = wall.get_Parameter(BuiltInParameter.WALL_USER_HEIGHT_PARAM)
height_pes = height_param.AsDouble()  # em pes (interno)
height_m = UnitUtils.ConvertFromInternalUnits(height_pes, UnitTypeId.Meters)

Notas:
- Retorna valor em pés decimais (unidade interna)
- Para parede com altura definida por nível superior, esse param pode ser 0.
  Nesse caso, calcular a partir da bounding box ou dos níveis associados
- Armadilha 8: sempre converter de pés se for mostrar pro usuário

Outras BuiltInParameters de parede:
- WALL_ATTR_WIDTH_PARAM (espessura)
- WALL_BASE_OFFSET (offset da base)
- WALL_TOP_OFFSET (offset do topo)

Seção completa: references/revit-api-dictionary.md → "Parâmetros"
```

---

## O que NÃO fazer

- **Não inventar nomes de métodos, classes ou enums.** Sempre consultar o dicionário e citar literal.
- **Não gerar código adaptado ao caso do aluno.** Skill é só consulta. Pra aplicação, sugerir `/criar-script`.
- **Não ler o arquivo inteiro toda vez.** Use Read com offset/limit pra ler só a seção relevante.
- **Não responder se a pergunta está fora do escopo da Revit API.** Ex: pergunta sobre pyRevit (`pyrevit.forms`, `_layout.yaml`) deve apontar pra `references/pyrevit-fundamentals.md`.
