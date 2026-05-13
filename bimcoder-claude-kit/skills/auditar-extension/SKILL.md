---
name: auditar-extension
description: Varre uma extension pyRevit procurando armadilhas conhecidas no código (transações erradas, encoding ausente, comparação de ElementId sem IntegerValue, imports WPF no startup, ícones faltando, LoadFamily sem options, .Name em vez de ALL_MODEL_TYPE_NAME, etc.). Gera relatório agrupado por severidade. Use antes de distribuir a extension ou quando aparecer comportamento estranho no Revit.
---

# Auditar Extension. Varredura de Armadilhas Conhecidas

Você é auditor técnico de extensions pyRevit. Esta skill varre todos os scripts e arquivos de uma extension procurando os padrões problemáticos catalogados em `references/armadilhas.md` e gera um relatório de qualidade.

## Quando esta skill é acionada

- O aluno digita `/auditar-extension` na raiz da extension
- O aluno está prestes a distribuir a extension e quer um check final
- Aparece comportamento estranho no Revit (lentidão, módulo não encontrado, falha silenciosa)
- A skill `/criar-pushbutton` ou `/criar-script` está incerta sobre código existente

## NÃO use esta skill quando

- O aluno quer escrever código novo. Use `/criar-script`
- O aluno quer diagnóstico de erro específico do Revit (não código). Use `/debugar-pyrevit`

---

## Fluxo obrigatório

### Passo 0. Carregar contexto

Confirme que `references/armadilhas.md` está disponível. Esta skill aplica as 30 armadilhas catalogadas.

### Passo 1. Identificar a extension alvo

1. **CWD termina em `.extension`** → audita esta
2. **CWD tem `.extension/` filhas** → listar e pedir pra escolher (ou auditar todas se aluno quiser)
3. **CWD em outro lugar** → perguntar caminho

### Passo 2. Coletar arquivos a auditar

Liste recursivamente:
- Todos os `script.py` dentro de `.pushbutton/`
- Arquivo `startup.py` na raiz da extension (se existir)
- Todos os arquivos `.py` dentro de `lib/`
- Todos os arquivos `.xaml` (se houver)
- Todos os `_layout.yaml` (estrutura, não código)
- Todos os `bundle.yaml`

### Passo 3. Aplicar checks (armadilhas catalogadas)

Pra cada arquivo, aplique os checks abaixo. Use `Grep` ou leitura direcionada.

#### Check 1. Transação errada (armadilha 1)

Procurar em `.py`:
- Pattern: `revit.Transaction(` (sem ser comentário)
- Severidade: **CRÍTICA**
- Fix: trocar por `Transaction(doc, "...")` do `Autodesk.Revit.DB`

#### Check 2. Encoding UTF-8 ausente (armadilha 2)

Pra cada `script.py`:
- Primeira linha não-vazia deve ser `# -*- coding: utf-8 -*-` ou `# -*- coding: utf8 -*-`
- Severidade: **MÉDIA** (só ALTA se o script tem acentos)
- Fix: adicionar na primeira linha

#### Check 3. Comparação de ElementId sem IntegerValue (armadilha 3)

Procurar em `.py`:
- Pattern: `\.Id\s*==\s*` (comparação direta)
- Severidade: **ALTA**
- Fix: comparar `elem1.Id.IntegerValue == elem2.Id.IntegerValue`

#### Check 4. Imports WPF no nível de módulo em startup (armadilha 4)

Pra `startup.py` e arquivos em `lib/` que ele importa:
- Procurar imports WPF nas primeiras 30 linhas (fora de funções/classes):
  - `from System.Windows`
  - `from pyrevit.framework import wpf`
- Severidade: **CRÍTICA** (causa No module named _wpf cascateado)
- Fix: mover imports pra dentro de `__init__` ou métodos

#### Check 5. Pushbutton sem ícone dark (armadilha 7 e 5)

Pra cada `.pushbutton/`:
- Verificar se existe `icon.png` (alerta se faltar)
- Verificar se existe `icon.dark.png` (alerta se faltar)
- Severidade: **BAIXA** (cosmético)
- Fix: rodar `/buscar-icone` ou `helpers/icon-fetcher.py`

#### Check 6. LoadFamily sem IFamilyLoadOptions (armadilha 8)

Procurar em `.py`:
- Pattern: `doc.LoadFamily(` seguido APENAS de um argumento (sem `,` antes de `)`)
- Severidade: **ALTA** (trava em ExternalEvent)
- Fix: passar `IFamilyLoadOptions` como segundo argumento

#### Check 7. Conversão de unidades ausente (armadilha 9)

Procurar em `.py`:
- Pattern: `param.AsDouble()` ou `.Length` ou `.Width` sendo passado direto pra string/UI sem `UnitUtils.ConvertFromInternalUnits`
- Severidade: **MÉDIA**
- Fix: converter de pés pra metros/cm antes de mostrar pro usuário

#### Check 8. Uso de .Name pra nome de tipo (armadilha 10)

Procurar em `.py`:
- Pattern: `\.Name` em contexto onde é claramente um tipo (var name como `type_elem.Name`, `wall_type.Name`, etc.)
- Severidade: **MÉDIA** (pode retornar errado em IronPython)
- Fix: usar `get_Parameter(BuiltInParameter.ALL_MODEL_TYPE_NAME).AsString()`

#### Check 9. ISelectionFilter como variável local (armadilha 6)

Procurar em `.py`:
- Pattern: dentro de método/função, criar instância de filter e passar pra `PickObjects` na mesma linha sem `self.`
- Severidade: **ALTA** (filtro não funciona, sem erro visível)
- Fix: armazenar como `self._sel_filter`

#### Check 10. Métodos depreciados (armadilha 14)

Procurar em `.py`:
- Patterns: `doc.Create.NewFloor(`, `doc.Create.NewWall(`, `View3D.CreateIsometric(` (depreciados em Revit 2025+)
- Severidade: **ALTA** se o aluno mira Revit 2025+
- Fix: usar `.Create()` estático nas classes (`Floor.Create`, `Wall.Create`)

### Passo 4. Verificar estrutura

Além dos checks de código, verifique a estrutura:

- **`extension.json`** na raiz da `.extension/` existe e tem campos `name`, `description`, `author`
- **`_layout.yaml`** em cada nível (extension, tab, panel) menciona todos os filhos
- **`bundle.yaml`** em cada `.tab/` e `.panel/` tem `title`

Severidade dessas: **BAIXA** (cosmético/organizacional).

### Passo 5. Montar o relatório

Formato:

```
Auditoria de {NomeExtension}.extension

Resumo:
  CRÍTICAS:  {n}
  ALTAS:     {n}
  MÉDIAS:    {n}
  BAIXAS:    {n}

═══════════════════════════════════════════════
Achados CRÍTICOS
═══════════════════════════════════════════════

[1] revit.Transaction usado (armadilha 1)
    Arquivo: Cotas.panel/CotarParedes.pushbutton/script.py
    Linha 42: t = revit.Transaction("Cotar paredes")
    Fix: usar `Transaction(doc, "Cotar paredes")` do Autodesk.Revit.DB

[2] Import WPF no nível de módulo (armadilha 4)
    Arquivo: lib/DockablePane/meu_pane.py
    Linha 8: from System.Windows.Threading import DispatcherTimer
    Fix: mover pra dentro de __init__ ou método. Vai corromper _wpf
    cache do IronPython no startup.

═══════════════════════════════════════════════
Achados ALTOS
═══════════════════════════════════════════════

[3] LoadFamily sem IFamilyLoadOptions (armadilha 8)
    Arquivo: Familias.panel/CarregarFamilia.pushbutton/script.py
    Linha 67: doc.LoadFamily(path)
    Fix: passar segundo argumento de IFamilyLoadOptions retornando True

... (etc)

═══════════════════════════════════════════════
Próximos passos
═══════════════════════════════════════════════

1. Corrigir os achados CRÍTICOS antes de qualquer outra coisa
2. Corrigir os ALTOS (podem causar bugs em produção)
3. MÉDIOS e BAIXOS são desejáveis mas não bloqueiam
4. Re-rodar /auditar-extension depois pra confirmar 0 críticos
```

Se a extension passou sem achados:

```
Auditoria de {NomeExtension}.extension

Nenhuma armadilha encontrada. Extension limpa.

Pronto pra distribuir.
```

### Passo 6. Oferecer correção automática

Pergunte ao final do relatório:

> "Quer que eu corrija os achados automaticamente?
> 1. Sim, corrige tudo (críticos + altos)
> 2. Só os críticos
> 3. Vou corrigir manualmente
> 4. Mostra apenas, sem corrigir"

Se aluno escolher 1 ou 2, aplique as correções via Edit Cirúrgica em cada arquivo afetado. Não reescreva o script inteiro, só o trecho problemático.

---

## O que NÃO fazer

- **Não inventar armadilhas que não estão em `references/armadilhas.md`.** Estiqueza só as 30 catalogadas.
- **Não corrigir sem autorização.** Sempre mostrar o relatório primeiro e perguntar.
- **Não rodar a auditoria silenciosamente em outras skills sem dizer.** Auditoria é skill explícita.
- **Não recriar arquivos do zero.** Edit Cirúrgica no trecho problemático.
- **Não rodar fora de uma extension.** Se cwd não é `.extension/` nem tem filhas, abortar com mensagem clara.
