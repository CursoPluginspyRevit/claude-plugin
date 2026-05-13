# Catálogo de Armadilhas do pyRevit + Revit API

Coletânea de armadilhas conhecidas que travam scripts pyRevit, falham silenciosamente ou geram bugs difíceis de diagnosticar. Cada entrada traz sintoma, causa raiz e fix.

A auto-revisão das skills consulta este arquivo antes de entregar código. Quando aparecer uma armadilha listada aqui, o assistente já aplica o fix correto.

---

## 1. Transação errada (`revit.Transaction`)

**Sintoma:** Erro "Cannot start transaction" ou comportamento errático ao modificar o modelo.

**Causa:** `revit.Transaction(...)` é instável ou inexistente em algumas versões do pyRevit.

**Fix:** Sempre usar `Transaction` direto da Revit API.

```python
# ERRADO
t = revit.Transaction("nome")

# CORRETO
from Autodesk.Revit.DB import Transaction

t = Transaction(doc, "Nome Descritivo da Operação")
t.Start()
try:
    # operações no modelo
    t.Commit()
except Exception:
    if t.HasStarted():
        t.RollBack()
    raise
```

---

## 2. Encoding UTF-8 ausente

**Sintoma:** `SyntaxError: Non-ASCII character ... but no encoding declared`.

**Causa:** Script tem acentos em string, comentário ou nome de variável, mas falta a declaração de encoding na primeira linha.

**Fix:** Primeira linha de todo `.py` que rode no pyRevit:

```python
# -*- coding: utf-8 -*-
```

Faça sempre, mesmo que o script não tenha acentos no momento. Custa uma linha e evita refactor depois.

---

## 3. Comparação de `ElementId` por igualdade

**Sintoma:** Filtro de elementos não funciona. Comparação de IDs sempre retorna `False` mesmo quando deveria ser `True`.

**Causa:** No IronPython, `ElementId.__eq__` pode cair em comparação de referência (não de valor). Dois `ElementId` apontando para o mesmo elemento podem ter referências diferentes e o `==` retorna `False`.

**Fix:** Sempre comparar via `IntegerValue`.

```python
# ERRADO
if elem1.Id == elem2.Id:
    ...

# CORRETO
if elem1.Id.IntegerValue == elem2.Id.IntegerValue:
    ...
```

Aplicação prática: ao filtrar elementos por categoria de uma seleção:

```python
cat_int = self._category_id.IntegerValue
elementos = [
    el for el in elementos
    if el is not None
    and el.Category is not None
    and el.Category.Id.IntegerValue == cat_int
]
```

---

## 4. Import WPF no nível de módulo durante startup

**Sintoma:** Erros aparentemente aleatórios em pushbuttons depois que uma extension foi instalada. Mensagem típica: `No module named _wpf`.

**Causa:** Algum `startup.py` ou módulo importado por ele tem `from pyrevit.framework import wpf` ou `from System.Windows.X import Y` no topo. O IronPython tenta carregar `_wpf` antes do pyRevit estar pronto, corrompe o cache, e qualquer script posterior que use forms quebra.

**Fix:** Imports WPF SEMPRE dentro de `__init__` ou métodos. Nunca no nível de módulo em código que roda no startup.

```python
# ERRADO no startup
from System.Windows.Threading import DispatcherTimer
from pyrevit.framework import wpf

class MeuControl(object):
    def __init__(self):
        ...

# CORRETO
class MeuControl(object):
    def __init__(self):
        from System.Windows.Markup import XamlReader  # import dentro do método
        ...
```

Alternativa: usar `XamlReader.Load()` no lugar de `wpf.LoadComponent` para evitar dependência de `pyrevit.framework.wpf`.

---

## 5. `No module named Threading`

**Sintoma:** Falha ao usar `DispatcherTimer` ou outras classes de `System.Windows.Threading`.

**Causa:** A assembly `WindowsBase` não está carregada por padrão.

**Fix:** Adicionar referência explícita antes do import.

```python
import clr
clr.AddReference("WindowsBase")

from System.Windows.Threading import DispatcherTimer
```

---

## 6. Filtros e callbacks como variável local

**Sintoma:** `ISelectionFilter` ou callback passado para `PickObjects` "não filtra nada". Todos os elementos ficam selecionáveis. Sem erro visível.

**Causa:** A variável local que guarda o filtro foi coletada pelo GC do IronPython antes do .NET conseguir chamar `AllowElement` de volta.

**Fix:** Guardar o filtro como atributo da instância (ou módulo).

```python
# ERRADO
def on_selecionar(self, sender, e):
    sel_filter = CategoryFilter(self._category_id.IntegerValue)
    refs = self._uidoc.Selection.PickObjects(
        ObjectType.Element, sel_filter, "Selecione...")

# CORRETO
def on_selecionar(self, sender, e):
    self._sel_filter = CategoryFilter(self._category_id.IntegerValue)
    refs = self._uidoc.Selection.PickObjects(
        ObjectType.Element, self._sel_filter, "Selecione...")
```

Regra geral: qualquer objeto Python passado para métodos .NET que precisam dele de forma assíncrona (callbacks, filtros, delegates, event handlers) deve viver via `self.xxx` ou variável de módulo.

---

## 7. Ícones 32x32 (obsoleto)

**Sintoma:** Ícone aparece borrado, pequeno demais ou em baixa qualidade no ribbon do Revit.

**Causa:** Convenção antiga (pyRevit pre-4.8) usava 32x32. O padrão atual é 96x96.

**Fix:** Sempre 96x96 PNG transparente. E sempre **dois** arquivos:

```
MeuBotao.pushbutton/
├── icon.png        ← linhas cinza (#344054), tema claro
└── icon.dark.png   ← linhas brancas (#FFFFFF), tema escuro
```

---

## 8. `LoadFamily` sem `IFamilyLoadOptions`

**Sintoma:** `IExternalEventHandler` trava ou erra com mensagem do tipo "Starting a transaction from an external application running outside of API context".

**Causa:** `doc.LoadFamily(path)` sem segundo argumento pode mostrar diálogo de confirmação ("Família já existe, sobrescrever?"). Em contexto não-modal (ExternalEvent, dockable pane), o diálogo trava.

**Fix:** Sempre passar `IFamilyLoadOptions` que retorna `True` em ambos os métodos.

```python
from Autodesk.Revit.DB import IFamilyLoadOptions

class _OverwriteOptions(IFamilyLoadOptions):
    def OnFamilyFound(self, familyInUse, overwriteParameterValues):
        overwriteParameterValues = True
        return True

    def OnSharedFamilyFound(self, sharedFamily, familyInUse, source, overwriteParameterValues):
        overwriteParameterValues = True
        return True

# Uso
opts = _OverwriteOptions()
doc.LoadFamily(path, opts)
```

---

## 9. Unidade interna em pés. Esquecer de converter

**Sintoma:** Paredes de 30000 metros, áreas absurdas, valores numéricos completamente errados.

**Causa:** A Revit API trabalha **internamente em pés decimais**. `param.AsDouble()` retorna pés. `XYZ(1,0,0)` é 1 pé. `line.Length` é em pés. Esquecer disso e tratar como metros gera bug de magnitude.

**Fix:** Sempre converter explicitamente ao ler ou escrever valores numéricos de distância, área ou volume.

```python
from Autodesk.Revit.DB import UnitUtils, UnitTypeId

# Ler: converter de pés para metros
metros = UnitUtils.ConvertFromInternalUnits(valor_em_pes, UnitTypeId.Meters)

# Escrever: converter de metros para pés antes do .Set()
pes = UnitUtils.ConvertToInternalUnits(valor_em_metros, UnitTypeId.Meters)
param.Set(pes)
```

Outras unidades: `UnitTypeId.Centimeters`, `UnitTypeId.Millimeters`, `UnitTypeId.SquareMeters`, `UnitTypeId.CubicMeters`.

---

## 10. `.Name` para nome de tipo

**Sintoma:** Nome do tipo vem vazio, vem como nome da família em vez do tipo, ou dispara erro.

**Causa:** Em IronPython, `element.Name` ou `type_elem.Name` é inconsistente. Para alguns objetos retorna string vazia, para outros retorna o nome da família (não do tipo), para outros não existe.

**Fix:** Sempre usar `BuiltInParameter.ALL_MODEL_TYPE_NAME`.

```python
from Autodesk.Revit.DB import BuiltInParameter

# Se você tem uma INSTÂNCIA, primeiro pegue o ElementType
type_elem = doc.GetElement(element.GetTypeId())

# Em qualquer ElementType (WallType, FamilySymbol, DimensionType, etc.)
type_name = type_elem.get_Parameter(
    BuiltInParameter.ALL_MODEL_TYPE_NAME
).AsString()
```

Aplicação: encontrar tipo por nome. É a forma confiável também para tipos sem classe própria (viewport types):

```python
def find_type_by_name(doc, type_name):
    """Encontra um ElementType pelo nome do tipo."""
    for t in (FilteredElementCollector(doc)
              .OfClass(ElementType)
              .WhereElementIsElementType()
              .ToElements()):
        try:
            param = t.get_Parameter(BuiltInParameter.ALL_MODEL_TYPE_NAME)
            if param and param.AsString() == type_name:
                return t
        except Exception:
            continue
    return None
```

---

## 11. `BuiltInCategory` inexistente em algumas versões

**Sintoma:** `AttributeError: type object 'BuiltInCategory' has no attribute 'OST_Gutters'`. Acontece no startup, impede a extension de carregar.

**Causa:** Nem todos os `BuiltInCategory.OST_*` existem em todas as versões do Revit. Alguns mudaram de nome (`OST_Gutters` em uma versão, `OST_Gutter` em outra).

**Fix:** Usar `getattr` com fallback.

```python
# ERRADO
cat = BuiltInCategory.OST_Gutters  # pode explodir no startup

# CORRETO
cat = getattr(BuiltInCategory, "OST_Gutters",
       getattr(BuiltInCategory, "OST_Gutter", None))

if cat is None:
    # categoria não existe nesta versão, tratar
    pass
```

Para listas de categorias, filtrar as que retornaram `None`:

```python
CATEGORIAS = [
    entry for entry in [
        (FamilySymbol, getattr(BuiltInCategory, "OST_Fascia", None)),
        (FamilySymbol, getattr(BuiltInCategory, "OST_Gutters",
                       getattr(BuiltInCategory, "OST_Gutter", None))),
    ] if entry[1] is not None
]
```

---

## 12. Tipos sem classe própria (Viewport, alguns ElementType genéricos)

**Sintoma:** `FilteredElementCollector(doc).OfClass(Viewport).ToElements()` retorna instâncias quando você queria os tipos. `OfCategory(OST_Viewports).WhereElementIsElementType()` retorna 0 elementos.

**Causa:** Viewport types (e alguns outros tipos genéricos) não têm subclasse específica na Revit API. Não respondem a `OfCategory(OST_Viewports)` na busca por tipos, e a classe `Viewport` é da instância.

**Fix:** Varrer `ElementType` sem filtro de categoria e filtrar pelo nome via `BuiltInParameter.ALL_MODEL_TYPE_NAME`.

```python
def find_viewport_type(doc, name):
    for t in (FilteredElementCollector(doc)
              .OfClass(ElementType)
              .WhereElementIsElementType()
              .ToElements()):
        try:
            param = t.get_Parameter(BuiltInParameter.ALL_MODEL_TYPE_NAME)
            if param and param.AsString() == name:
                return t
        except Exception:
            continue
    return None
```

Aplicar via `viewport.ChangeTypeId(viewport_type.Id)`.

---

## 13. Crop box de view. Mexer no `BoundingBoxXYZ.Transform` não rotaciona a vista

**Sintoma:** Tentativa de rotacionar uma vista mexendo em `view.CropBox.Transform`. O Revit re-axis-aligna ou descarta a rotação.

**Causa:** `view.CropBox` retorna um `BoundingBoxXYZ` (geometria), não o Element do crop. A crop é um Element separado com `ElementId` próprio. Pra rotacionar a vista de fato, rotaciona o Element da crop via `ElementTransformUtils.RotateElement`.

**Fix:**

```python
def find_crop_region_id(doc, view):
    """O ID da crop costuma ser view.Id + 1, +2 ou +3. Não é regra fixa."""
    view_id_int = view.Id.IntegerValue
    view_name = view.Name
    for offset in range(1, 11):
        candidate = ElementId(view_id_int + offset)
        elem = doc.GetElement(candidate)
        if elem is None:
            continue
        try:
            param = elem.get_Parameter(BuiltInParameter.VIEW_NAME)
            if param is not None and param.AsString() == view_name:
                return candidate
        except Exception:
            continue
    return None

# Uso
crop_id = find_crop_region_id(doc, view)
axis = Line.CreateBound(center, XYZ(center.X, center.Y, center.Z + 1.0))
ElementTransformUtils.RotateElement(doc, crop_id, axis, angle_rad)
doc.Regenerate()
```

Após `RotateElement`, o `crop.Transform` da view passa a ter rotação. Use `.Inverse.OfPoint(world)` para mapear pontos de mundo para o frame local rotacionado.

---

## 14. Métodos `Document.Create.New*` depreciados (Revit 2025+)

**Sintoma:** `AttributeError: 'DocumentCreation' has no attribute 'NewFloor'`. Funciona em Revit 2024, quebra em 2025+.

**Causa:** Muitos métodos `Create.New*` foram removidos em Revit 2025+. Substituídos por métodos estáticos `.Create()` nas próprias classes.

**Fix:** Usar a forma nova, que funciona do Revit 2022 em diante.

```python
# DEPRECIADO em 2025+
floor = doc.Create.NewFloor(profile, floor_type, level, False)

# CORRETO (Revit 2022+)
from Autodesk.Revit.DB import Floor, CurveLoop
loop = CurveLoop.Create(curves)
floor = Floor.Create(doc, [loop], floor_type.Id, level.Id)
```

Outros métodos afetados: `Wall.Create`, `View3D.CreateIsometric`, `Viewport.Create`, etc. Sempre verificar a doc da versão alvo.

---

## 15. `pyRevit_config.ini` corrompido. Lentidão geral

**Sintoma:** Todos os scripts ficam lentos, independente do conteúdo. Rocket Mode ativado não resolve.

**Causa:** Bug de escape recursivo nos campos de telemetria do `pyRevit_config.ini`. A cada save, o pyRevit re-escapa o valor já escapado, fazendo o arquivo crescer exponencialmente. Pode chegar a 24MB com poucas linhas.

**Fix:** Verificar e limpar manualmente.

```powershell
# Diagnóstico
$file = "$env:APPDATA\pyRevit\pyRevit_config.ini"
$size = (Get-Item $file).Length
Write-Output "Tamanho: $([math]::Round($size/1KB, 1)) KB"

# Se acima de 100KB, está corrompido
```

Fix:

```powershell
Copy-Item "$env:APPDATA\pyRevit\pyRevit_config.ini" "$env:APPDATA\pyRevit\pyRevit_config.ini.bak"
$lines = Get-Content "$env:APPDATA\pyRevit\pyRevit_config.ini"
$lines = $lines | ForEach-Object {
    if ($_ -match "^(telemetry_file_dir|telemetry_server_url|apptelemetry_server_url)") {
        ($_ -split "=")[0] + ' = ""'
    } else {
        $_
    }
}
$lines | Set-Content "$env:APPDATA\pyRevit\pyRevit_config.ini" -Encoding UTF8
```

Prevenção permanente: desabilitar telemetria em `pyRevit (ribbon) > Settings > Telemetry > desmarcar tudo`.

---

## 16. Dockable pane abre sozinho ao iniciar o Revit

**Sintoma:** O painel ancorado abre automaticamente toda vez que o Revit é iniciado, mesmo que `Hide()` seja chamado no `startup.py`.

**Causa:** O Revit salva o layout dos dockable panes entre sessões. Se o painel estava visível quando o Revit foi fechado, ele reabre na próxima sessão. `Hide()` no startup é sobrescrito pelo layout restaurado.

**Fix:** Assinar `ViewActivated` no `init()` e esconder na primeira ativação de vista (que ocorre depois do layout ser restaurado).

```python
def init(uiapp):
    global _control
    _control = MeuControl()
    uiapp.RegisterDockablePane(PANE_ID, "Meu Painel", MeuProvider(_control))

    def _hide_on_first_view(sender, e):
        try:
            sender.GetDockablePane(PANE_ID).Hide()
        except Exception:
            pass
        try:
            uiapp.ViewActivated -= _hide_on_first_view
        except Exception:
            pass

    uiapp.ViewActivated += _hide_on_first_view
```

Da segunda sessão em diante, o Revit salva o pane como oculto e não reabre mais.

---

## 17. Fundo preto em dockable pane

**Sintoma:** O painel ancorado renderiza fundo preto ou transparente sobre o tema escuro do Revit, deixando os textos ilegíveis.

**Causa:** Elementos WPF sem `Background` ficam transparentes/pretos no contexto do dockable pane.

**Fix:** Sempre definir `Background="White"` (ou cor do sistema) no elemento raiz do XAML.

```xml
<StackPanel
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    Background="White"
    Margin="12">
    ...
</StackPanel>
```

---

## 18. Cascata de `SelectionChanged` em ComboBox/ListBox

**Sintoma:** Ao popular um `ComboBox` programaticamente, o handler `SelectionChanged` dispara várias vezes em cascata e atrapalha a inicialização.

**Causa:** `Items.Add` e `SelectedIndex = 0` disparam `SelectionChanged`. Se o handler tentar popular outro controle, a cascata se propaga.

**Fix:** Flag `_updating` para suprimir.

```python
self._updating = True
try:
    self._combo.Items.Clear()
    for item in items:
        self._combo.Items.Add(item)
    self._combo.SelectedIndex = 0
finally:
    self._updating = False

# Disparar manualmente após popular:
self._on_selection_changed(None, None)

# No handler:
def _on_selection_changed(self, sender, e):
    if self._updating:
        return
    # lógica normal
```

---

## 19. `BitmapImage` sem `Freeze()` para uso em thread diferente

**Sintoma:** `InvalidOperationException: The calling thread cannot access this object because a different thread owns it.`

**Causa:** `BitmapImage` criado em uma thread (ex: startup) e usado em outra (ex: UI thread) precisa estar congelado.

**Fix:** Sempre `Freeze()` após criar.

```python
from System.Windows.Media.Imaging import BitmapImage

bmp = BitmapImage()
bmp.BeginInit()
bmp.UriSource = Uri(path)
bmp.CacheOption = BitmapCacheOption.OnLoad
bmp.EndInit()
bmp.Freeze()  # obrigatório se for usar em outra thread
```

---

## 20. Paths com caracteres não-ASCII em IronPython

**Sintoma:** `IOError` ao abrir arquivo cujo caminho contém acentos. Funciona em CPython, falha em IronPython.

**Causa:** IronPython 2.x tem inconsistências com strings unicode em chamadas de sistema de arquivos.

**Fix:** Usar prefixo `u"..."` explícito em strings com acentos usadas com `os.path`.

```python
# CORRETO
FOLDER = u"D:\\Minha Pasta\\Famílias"

# PODE FALHAR em algumas situações
FOLDER = r"D:\Minha Pasta\Famílias"
```

---

## 21. `ExternalEvent.Raise()` é assíncrono

**Sintoma:** Tentativa de ler `handler.result` imediatamente após `event.Raise()`. Resultado sempre vem `None` ou desatualizado.

**Causa:** `Raise()` enfileira o `Execute` para a próxima janela de API do Revit. Não bloqueia. O resultado só fica disponível depois.

**Fix:** Usar `DispatcherTimer` curto (300 a 500 ms) que checa `handler.done` ou `handler.result`.

```python
def on_click(self, sender, e):
    self._handler.dados = "valor"
    self._handler.done = False
    self._event.Raise()
    self._start_result_timer()

def _start_result_timer(self):
    from System.Windows.Threading import DispatcherTimer
    from System import TimeSpan
    self._result_timer = DispatcherTimer()
    self._result_timer.Interval = TimeSpan.FromMilliseconds(300)
    self._result_timer.Tick += self._check_result
    self._result_timer.Start()

def _check_result(self, sender, e):
    if self._handler.done:
        self._result_timer.Stop()
        # processar self._handler.result
        ...
```

---

## 22. `Material.GetPreviewImage()` retorna `None` em background

**Sintoma:** Thumbnail de material vem vazio quando o documento foi aberto via `OpenDocumentFile` em background.

**Causa:** O render da esfera de preview requer contexto de renderização ativo. Documentos em background não têm.

**Fix:** Cadeia de fallback em 3 níveis.

```python
def get_material_thumb(material, doc):
    # 1. Preview nativo (funciona no doc ativo)
    thumb = material.GetPreviewImage(Size(120, 96))
    if thumb is not None:
        return thumb

    # 2. AppearanceAssetElement
    asset_id = material.AppearanceAssetId
    if asset_id != ElementId.InvalidElementId:
        asset_elem = doc.GetElement(asset_id)
        if asset_elem:
            thumb = asset_elem.GetPreviewImage(Size(120, 96))
            if thumb is not None:
                return thumb

    # 3. Swatch sólido com mat.Color
    color = material.Color
    if color.IsValid:
        bmp = Bitmap(120, 96)
        g = Graphics.FromImage(bmp)
        g.Clear(Color.FromArgb(color.Red, color.Green, color.Blue))
        g.Dispose()
        return bmp

    return None
```

---

## 23. `AddStackedItems` com apenas 1 item (C#)

**Sintoma:** Exceção em runtime ao chamar `panel.AddStackedItems(btn)` com um único item.

**Causa:** `RibbonPanel.AddStackedItems()` aceita apenas 2 ou 3 itens. Não é documentado claramente.

**Fix:** Se o stack tiver só 1 botão, usar `panel.AddItem()` normalmente.

```csharp
// CORRETO
if (botoes.Count == 1) {
    panel.AddItem(botoes[0]);
} else if (botoes.Count == 2) {
    panel.AddStackedItems(botoes[0], botoes[1]);
} else if (botoes.Count == 3) {
    panel.AddStackedItems(botoes[0], botoes[1], botoes[2]);
}
```

---

## 24. `OverrideGraphicSettings.SurfaceTransparency` sem getter (C#)

**Sintoma:** `CS1061: 'OverrideGraphicSettings' does not contain a definition for 'SurfaceTransparency'`.

**Causa:** No IronPython funciona via dispatch dinâmico, mas em C# a API não expõe getter para `SurfaceTransparency`. Tem só setter.

**Fix:** Usar valor padrão se precisar de uma referência.

```csharp
// Não dá pra ler
// int transp = ogs.SurfaceTransparency;  // CS1061

// Solução
int transp = 20; // valor padrão razoável
ogs.SetSurfaceTransparency(transp);
```

---

## 25. Multi-targeting Revit 2024 + 2025+ com `RevitAPI.dll` errada

**Sintoma:** Plugin compila mas crasha ao carregar no Revit. Mensagem de tipo "could not load file or assembly".

**Causa:** Mistura de referências `RevitAPI.dll` de versões diferentes do Revit.

**Fix:** Usar referências **condicionais** no `.csproj` por framework target.

```xml
<TargetFrameworks>net48;net8.0-windows</TargetFrameworks>

<!-- Revit 2021-2024 (.NET 4.8) -->
<ItemGroup Condition="'$(TargetFramework)' == 'net48'">
  <Reference Include="RevitAPI">
    <HintPath>C:\Program Files\Autodesk\Revit 2024\RevitAPI.dll</HintPath>
    <Private>false</Private>
  </Reference>
  <Reference Include="RevitAPIUI">
    <HintPath>C:\Program Files\Autodesk\Revit 2024\RevitAPIUI.dll</HintPath>
    <Private>false</Private>
  </Reference>
</ItemGroup>

<!-- Revit 2025+ (.NET 8) -->
<ItemGroup Condition="'$(TargetFramework)' == 'net8.0-windows'">
  <Reference Include="RevitAPI">
    <HintPath>C:\Program Files\Autodesk\Revit 2025\RevitAPI.dll</HintPath>
    <Private>false</Private>
  </Reference>
  <Reference Include="RevitAPIUI">
    <HintPath>C:\Program Files\Autodesk\Revit 2025\RevitAPIUI.dll</HintPath>
    <Private>false</Private>
  </Reference>
</ItemGroup>
```

`<Private>false</Private>` (equivale a "Copy Local = false") é crítico. Sem isso, a DLL do Revit vai dentro do output e dá conflito.

---

## 26. Namespace `Application` errado (C#)

**Sintoma:** `CS0246: Type or namespace name 'Application' could not be found`.

**Causa:** `Application` da Revit API **não** está em `Autodesk.Revit.DB`. Está em `Autodesk.Revit.ApplicationServices`.

**Fix:** Adicionar o using específico.

```csharp
using Autodesk.Revit.ApplicationServices;  // necessário para Application

Application app = uiApp.Application;
```

Outros namespaces que pegam desprevenido:
- `Room` está em `Autodesk.Revit.DB.Architecture`, não em `Autodesk.Revit.DB`
- Eventos de documento: `Autodesk.Revit.DB.Events`
- Eventos de UI: `Autodesk.Revit.UI.Events`

---

## 27. Ambiguidade `Grid` (WPF × Revit)

**Sintoma:** `CS0104: 'Grid' is an ambiguous reference`.

**Causa:** Tem `using Autodesk.Revit.DB` (Grid linha de eixo do projeto) e `using System.Windows.Controls` (Grid WPF) no mesmo arquivo.

**Fix:** Alias.

```csharp
using WpfGrid = System.Windows.Controls.Grid;

// Depois usar:
WpfGrid.SetRow(label, 0);
WpfGrid.SetColumn(label, 1);
```

---

## 28. Plugin não atualiza no Revit (DLL travada)

**Sintoma:** `dotnet build` falha com "The process cannot access the file because it is being used by another process".

**Causa:** Revit está com o plugin carregado e a DLL está travada.

**Fix:** Fechar o Revit antes de buildar. Sem alternativa razoável dentro do Revit.

Para acelerar o ciclo de desenvolvimento, considerar:
- Build hot-reload via Revit dev tools (não funciona para todos os tipos de mudança)
- Plugin com DLL "shadow copy" (carrega a partir de uma cópia, libera o arquivo original) — implementação não trivial

---

## 29. Ribbon comprimido (botões colapsados em pulldown)

**Sintoma:** Botões individuais somem do ribbon do Revit. Ficam agrupados num pulldown.

**Causa:** Quando a janela do Revit não está maximizada, o ribbon colapsa painéis automaticamente em pulldowns para economizar espaço. Não é bug do plugin, é comportamento nativo do Revit.

**Fix:** Maximizar a janela. Os botões voltam a aparecer individualmente.

Cache do ribbon: o arquivo `%AppData%\Autodesk\Revit\Autodesk Revit YYYY\RevitUILayout.xml` guarda o estado. Deletar esse arquivo força o Revit a reconstruir o ribbon do zero, útil quando um painel antigo persiste após remoção no código.

---

## 30. Detecção de tema dark/light só funciona no `OnStartup` (C#)

**Sintoma:** Plugin C# com ícones dark/light. Aluno troca o tema do Revit com o aplicativo aberto, ícones não atualizam.

**Causa:** A detecção do tema ocorre apenas no `OnStartup` do `IExternalApplication`. Trocar o tema com o Revit aberto não dispara reavaliação dos ícones.

**Fix:** Documentar a limitação. Pedir reinicialização do Revit após mudar tema.

```csharp
// Revit 2025+ via reflection (a API expõe via UIThemeManager)
var themeType = Type.GetType("Autodesk.Revit.UI.UIThemeManager, RevitAPIUI");
bool isDark = false;
if (themeType != null)
{
    var prop = themeType.GetProperty("CurrentTheme",
        BindingFlags.Public | BindingFlags.Static);
    isDark = prop?.GetValue(null)?.ToString() == "Dark";
}

// Revit 2024 e anteriores: fallback por Registry
// HKCU\Software\Autodesk\Revit\Autodesk Revit YYYY\Scheme\ColorTheme == "1" → Dark
```

---

## 31. Endpoint PNG do Iconify pode retornar 404

**Sintoma:** Skill que baixa ícone via `https://api.iconify.design/{prefix}/{name}.png?height=96&color=...` recebe HTTP 404 mesmo pra ícone válido. Build do bundle falha sem `icon.png` e `icon.dark.png`.

**Causa:** O endpoint de PNG renderizado server-side do Iconify é instável e às vezes retorna 404, mesmo pra ícones que existem no catálogo. O endpoint SVG (`.svg`) é confiável e sempre responde.

**Fix:** Baixar o SVG e converter localmente pra PNG via `resvg-py`. É renderizador SVG escrito em Rust embedado via PyO3. Funciona out-of-the-box no Windows sem libcairo nem outras dependências nativas.

```python
import urllib.request
from resvg_py import svg_to_bytes

color = "344054"  # hex sem '#'
url = f"https://api.iconify.design/lucide/ruler.svg?color=%23{color}"

svg_bytes = urllib.request.urlopen(url).read()
png_data = svg_to_bytes(bytestring=svg_bytes, width=96, height=96)

# Algumas versoes retornam list[int] em vez de bytes
if isinstance(png_data, list):
    png_data = bytes(png_data)

with open("icon.png", "wb") as f:
    f.write(png_data)
```

**Pré-requisito:** `pip install resvg-py`

Por que não outras libs:
- `cairosvg` requer libcairo nativa, instalação chata no Windows
- `svglib + Pillow` é frágil em SVGs com filters/gradients complexos
- `wand/imagemagick` requer instalação separada do ImageMagick

O `helpers/icon-fetcher.py` do kit já aplica esse fluxo desde a v0.2. Skills que usam ícone (`/criar-pushbutton`, `/criar-pulldown`, `/criar-dockable-pane`, `/buscar-icone`) chamam o helper e não precisam reimplementar a conversão.
