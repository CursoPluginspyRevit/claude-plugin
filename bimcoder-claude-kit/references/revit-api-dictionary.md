# Revit API. Dicionário de Referência

Dicionário das classes, métodos e padrões mais usados da Revit API, extraído de scripts reais em produção. Cobre desde coletores básicos até casos avançados como dockable panes, raycast e cópia entre documentos.

Cada seção traz exemplos práticos em Python (IronPython 2.7 / pyRevit). A maioria funciona também em C# com adaptação direta de sintaxe.

---

## Coletores. `FilteredElementCollector`

Base de quase todo script. Coletor principal para buscar elementos no modelo.

```python
from Autodesk.Revit.DB import FilteredElementCollector, BuiltInCategory, Wall, ViewSheet

# Por classe
walls = FilteredElementCollector(doc).OfClass(Wall).ToElements()
sheets = FilteredElementCollector(doc).OfClass(ViewSheet).ToElements()

# Por categoria
doors = FilteredElementCollector(doc)\
    .OfCategory(BuiltInCategory.OST_Doors)\
    .WhereElementIsNotElementType()\
    .ToElements()

# Na view ativa
elems = FilteredElementCollector(doc, doc.ActiveView.Id)\
    .OfCategory(BuiltInCategory.OST_Walls)\
    .WhereElementIsNotElementType()\
    .ToElements()

# Primeiro elemento
first = FilteredElementCollector(doc).OfClass(Wall).FirstElement()
```

### Métodos de filtro

| Método | Função |
|---|---|
| `.OfClass(Wall)` | Filtra por classe Python/.NET |
| `.OfCategory(BuiltInCategory.OST_Walls)` | Filtra por categoria do Revit |
| `.OfCategoryId(cat_id)` | Filtra por ID de categoria |
| `.WhereElementIsNotElementType()` | Retorna apenas instâncias |
| `.WhereElementIsElementType()` | Retorna apenas tipos |
| `.WherePasses(element_filter)` | Filtro customizado |

### Métodos de saída

| Método | Retorna |
|---|---|
| `.ToElements()` | Lista de elementos |
| `.ToElementIds()` | Lista de `ElementId` |
| `.FirstElement()` | Primeiro elemento |
| `.GetElementCount()` | Quantidade (sem materializar) |

### Classes filtráveis mais usadas

```python
Wall, WallType, ViewSheet, View, Dimension, DimensionType,
Material, AppearanceAssetElement, PropertySetElement,
LinePatternElement, FillPatternElement, FilledRegion, FilledRegionType,
Group, ViewFamilyType, RevitLinkInstance, HostObjAttributes,
ParameterFilterElement, Floor, FloorType, Ceiling, Family, FamilySymbol,
FamilyInstance, Level, Grid, Room, Area
```

---

## Transações

Obrigatório para qualquer modificação no modelo.

```python
from Autodesk.Revit.DB import Transaction

t = Transaction(doc, "Descrição da operação")
t.Start()
try:
    # modificações aqui
    t.Commit()
except Exception as e:
    if t.HasStarted():
        t.RollBack()
    raise
```

### Métodos

- `.Start()` inicia
- `.Commit()` salva
- `.RollBack()` desfaz
- `.HasStarted()` verifica se iniciada
- `.HasEnded()` verifica se encerrada
- `.GetFailureHandlingOptions()` opções de erro
- `.SetFailureHandlingOptions(options)` configura opções de erro

### `TransactionGroup`. Agrupar múltiplas transações

```python
from Autodesk.Revit.DB import TransactionGroup

tg = TransactionGroup(doc, "Grupo de Operações")
tg.Start()
# várias transactions individuais aqui
tg.Assimilate()  # mescla tudo num único undo
# ou tg.RollBack() para descartar tudo
```

### `SubTransaction`. Operações que podem falhar individualmente

```python
from Autodesk.Revit.DB import SubTransaction

with Transaction(doc, "Criar Paredes") as t:
    t.Start()
    for item in itens:
        with SubTransaction(doc) as st:
            st.Start()
            try:
                # criar parede individual
                st.Commit()
            except Exception:
                st.RollBack()  # só essa falha, o resto continua
    t.Commit()
```

### Tratamento silencioso de warnings

```python
from Autodesk.Revit.DB import IFailuresPreprocessor, FailureSeverity, FailureProcessingResult

class SilentFailureHandler(IFailuresPreprocessor):
    def PreprocessFailures(self, failuresAccessor):
        for failure in failuresAccessor.GetFailureMessages():
            if failure.GetSeverity() == FailureSeverity.Warning:
                failuresAccessor.DeleteWarning(failure)
            else:
                failuresAccessor.ResolveFailure(failure)
        return FailureProcessingResult.Continue

# Uso
options = t.GetFailureHandlingOptions()
options.SetFailuresPreprocessor(SilentFailureHandler())
t.SetFailureHandlingOptions(options)
```

---

## Documento

### Acesso básico

```python
doc.ActiveView          # view ativa
doc.ActiveView.Id       # ID da view ativa
doc.Title               # nome do arquivo
doc.PathName            # caminho completo do arquivo
doc.IsFamilyDocument    # True se .rfa, False se .rvt
doc.Settings.Categories # todas as categorias do projeto
doc.ParameterBindings   # bindings de parâmetros
```

### `doc.GetElement(id)`

```python
elem = doc.GetElement(elem_id)
elem_type = doc.GetElement(elem.GetTypeId())
elem_from_ref = doc.GetElement(reference.ElementId)
```

### `doc.Delete(id)`

```python
from System.Collections.Generic import List

doc.Delete(elem.Id)
doc.Delete(List[ElementId]([id1, id2]))
```

### `doc.Create.NewDimension()`

```python
from Autodesk.Revit.DB import ReferenceArray, Line

ref_array = ReferenceArray()
ref_array.Append(ref1)
ref_array.Append(ref2)
dim_line = Line.CreateBound(pt1, pt2)

dim = doc.Create.NewDimension(view, dim_line, ref_array)
# Com tipo específico
dim = doc.Create.NewDimension(view, dim_line, ref_array, dim_type)
```

### Abrir e fechar documentos

```python
from Autodesk.Revit.DB import ModelPathUtils, OpenOptions, SaveOptions, SaveAsOptions, DetachFromCentralOption

# Abrir
model_path = ModelPathUtils.ConvertUserVisiblePathToModelPath(r"C:\modelo.rvt")
opts = OpenOptions()
opts.DetachFromCentralOption = DetachFromCentralOption.DoNotDetach
novo_doc = app.OpenDocumentFile(model_path, opts)

# Converter path de volta
path_str = ModelPathUtils.ConvertModelPathToUserVisiblePath(model_path)

# Salvar
save_opts = SaveOptions()
save_opts.Compact = True
doc.Save(save_opts)

# Salvar como
save_as_opts = SaveAsOptions()
save_as_opts.OverwriteExistingFile = False
doc.SaveAs(novo_path, save_as_opts)

# Fechar
doc.Close(False)  # False = não salvar alterações
```

### Parâmetros compartilhados (Shared Parameters)

```python
from Autodesk.Revit.DB import SharedParameterElement
from System import Guid

# Definir arquivo de Shared Parameters
app.SharedParametersFilename = r"caminho\para\arquivo.txt"
spfile = app.OpenSharedParameterFile()
group = spfile.Groups.get_Item("nome_grupo")
ext_def = group.Definitions.get_Item("nome_parametro")

# Vincular ao projeto
cats = doc.Settings.Categories
cat_set = app.Create.NewCategorySet()
cat_set.Insert(cats.get_Item(BuiltInCategory.OST_Walls))

binding = app.Create.NewInstanceBinding(cat_set)
doc.ParameterBindings.Insert(ext_def, binding)

# Verificar se já existe
shared = SharedParameterElement.Lookup(doc, Guid("seu-guid-aqui"))
```

---

## Elementos. Propriedades comuns

```python
elem.Id                    # ElementId
elem.Name                  # nome (use ALL_MODEL_TYPE_NAME para nome de tipo)
elem.Category              # Category
elem.Category.Id           # ElementId da categoria
elem.GetTypeId()           # ElementId do tipo
elem.Location              # localização
elem.Location.Point        # ponto de localização (LocationPoint)
elem.Location.Curve        # curva de localização (LocationCurve. Paredes, vigas)
elem.FacingOrientation     # orientação frontal
elem.Host                  # elemento hospedeiro
elem.Width                 # largura (em pés)
elem.Parameters            # todos os parâmetros
```

### Referências de elemento

```python
from Autodesk.Revit.DB import FamilyInstanceReferenceType

refs = elem.GetReferences(FamilyInstanceReferenceType.Left)
```

### Estrutura composta (paredes, pisos, forros)

```python
compound = wall.GetCompoundStructure()
layer_count = compound.GetLayerCount()
for i in range(layer_count):
    mat_id = compound.GetMaterialId(i)
    material = doc.GetElement(mat_id)
    width = compound.GetLayerWidth(i)  # em pés
```

### Materiais do elemento

```python
mat_ids = elem.GetMaterialIds(False)  # False = não incluir pintura
for mat_id in mat_ids:
    mat = doc.GetElement(mat_id)
    print(mat.Name)
```

---

## Parâmetros

```python
from Autodesk.Revit.DB import StorageType, BuiltInParameter

# Por nome
param = elem.LookupParameter("Comentários")

# Por BuiltInParameter
param = elem.get_Parameter(BuiltInParameter.ALL_MODEL_TYPE_NAME)

# Por GUID (parâmetro compartilhado)
from System import Guid
param = elem.get_Parameter(Guid("seu-guid-aqui"))

# Leitura por StorageType
if param and not param.IsReadOnly:
    if param.StorageType == StorageType.String:
        val = param.AsString()
    elif param.StorageType == StorageType.Double:
        val = param.AsDouble()   # em pés internamente
    elif param.StorageType == StorageType.Integer:
        val = param.AsInteger()
    elif param.StorageType == StorageType.ElementId:
        val = param.AsElementId()

# Verificações
param.HasValue      # True se tem valor
param.IsReadOnly    # True se read-only
param.IsShared      # True se compartilhado
param.GUID          # GUID (se compartilhado)
param.Definition.Name                    # nome
param.Definition.BuiltInParameter        # BIP enum

# Escrita (dentro de Transaction)
param.Set("novo valor")
param.Set(0.0)           # limpar double
param.Set("")            # limpar string
```

### BuiltInParameters mais usados

```python
BuiltInParameter.RVT_LINK_FILE_NAME_WITHOUT_EXT  # nome do link
BuiltInParameter.MATERIAL_ID_PARAM               # material
BuiltInParameter.ALL_MODEL_TYPE_NAME             # nome do tipo
BuiltInParameter.ALL_MODEL_DESCRIPTION           # descrição
BuiltInParameter.ALL_MODEL_INSTANCE_COMMENTS     # comentários
BuiltInParameter.ROOM_NAME                       # nome do ambiente
BuiltInParameter.ROOM_AREA                       # área do ambiente
BuiltInParameter.WALL_ATTR_WIDTH_PARAM           # espessura da parede
BuiltInParameter.WALL_USER_HEIGHT_PARAM          # altura da parede
BuiltInParameter.VIEW_NAME                       # nome da view
BuiltInParameter.SHEET_NUMBER                    # número da prancha
BuiltInParameter.SHEET_NAME                      # nome da prancha
```

---

## Geometria

### `XYZ`. Ponto ou vetor 3D

```python
from Autodesk.Revit.DB import XYZ

p = XYZ(0, 0, 0)
p.Normalize()           # vetor unitário
p.GetLength()           # magnitude
p.DotProduct(outro)     # produto escalar
p.CrossProduct(outro)   # produto vetorial
p.DistanceTo(outro)     # distância entre pontos
p.Negate()              # inverter direção
p.Multiply(2.0)         # escalar
p.Subtract(outro)       # subtração
p.Add(outro)            # soma

# Eixos
XYZ.BasisX   # (1, 0, 0)
XYZ.BasisY   # (0, 1, 0)
XYZ.BasisZ   # (0, 0, 1)
```

### `Line`

```python
from Autodesk.Revit.DB import Line

linha = Line.CreateBound(XYZ(0,0,0), XYZ(5,0,0))
linha.Direction              # vetor direção
linha.Length                 # comprimento (em pés)
linha.GetEndPoint(0)         # ponto inicial
linha.GetEndPoint(1)         # ponto final
linha.GetEndPointReference(0)  # referência do ponto inicial
linha.GetEndPointReference(1)  # referência do ponto final
linha.Evaluate(0.5, True)    # ponto no meio da linha
linha.IsCyclic               # True se circular/arco
```

### `Curve.CreateTransformed(transform)`

Aplica transformação e retorna **nova curva**. A original não é modificada.

```python
from Autodesk.Revit.DB import Transform
import math

# Translação
transform = Transform.CreateTranslation(XYZ(5, 0, 0))
curva_nova = curva_original.CreateTransformed(transform)

# Rotação
transform_rot = Transform.CreateRotation(XYZ.BasisZ, math.pi / 2)
curva_rotacionada = curva_original.CreateTransformed(transform_rot)
```

### `Options`. Para obter geometria de elemento

```python
from Autodesk.Revit.DB import Options, ViewDetailLevel, Solid, GeometryInstance, PlanarFace

opt = Options()
opt.ComputeReferences = True
opt.DetailLevel = ViewDetailLevel.Fine
opt.IncludeNonVisibleObjects = False

geom = elem.get_Geometry(opt)
for obj in geom:
    if isinstance(obj, Solid):
        for face in obj.Faces:
            if isinstance(face, PlanarFace):
                normal = face.FaceNormal
                origin = face.Origin
                ref = face.Reference
    elif isinstance(obj, GeometryInstance):
        for inst_obj in obj.GetInstanceGeometry():
            # processar geometria interna
            pass
```

### Faces

```python
from Autodesk.Revit.DB import UV

face.ComputeNormal(UV(0, 0))  # normal em ponto UV
face.FaceNormal               # normal da face
face.Origin                   # origem da face
face.Reference                # referência para cota
face.Project(point)           # projetar ponto na face
face.EdgeLoops                # loops de arestas

for loop in face.EdgeLoops:
    for edge in loop:
        curve = edge.AsCurve()
```

### `CurveLoop`. Para criar `FilledRegion` ou `Floor`

```python
from Autodesk.Revit.DB import CurveLoop

loop = CurveLoop()
loop.Append(line1)
loop.Append(line2)
loop.Append(line3)
loop.Append(line4)
```

Forma alternativa, criar a partir de lista:

```python
loop = CurveLoop.Create([line1, line2, line3, line4])
```

### `ReferenceIntersector`. Raycast

```python
from Autodesk.Revit.DB import ReferenceIntersector, FindReferenceTarget, ElementCategoryFilter

cat_filter = ElementCategoryFilter(BuiltInCategory.OST_Walls)
intersector = ReferenceIntersector(cat_filter, FindReferenceTarget.Face, view3d)

hit = intersector.FindNearest(origin_point, direction)
hits = intersector.Find(origin_point, direction)

if hit:
    ref = hit.GetReference()
    dist = hit.Proximity
```

### `solid.IntersectWithCurve()`

```python
from Autodesk.Revit.DB import SolidCurveIntersectionOptions

opts = SolidCurveIntersectionOptions()
result = solid.IntersectWithCurve(ray, opts)
```

---

## Dimensões (Cotas)

```python
from Autodesk.Revit.DB import ReferenceArray, Dimension, DimensionType

# Criar cota
ref_array = ReferenceArray()
ref_array.Append(ref1)
ref_array.Append(ref2)
dim = doc.Create.NewDimension(view, dim_line, ref_array)
dim = doc.Create.NewDimension(view, dim_line, ref_array, dim_type)

# Ler cota
dim.Value        # valor numérico (em pés)
dim.Curve        # linha da cota
dim.References   # referências
dim.References.Size  # quantidade de referências
dim.Segments     # segmentos (cota múltipla)

# Alterar tipo
dim.ChangeTypeId(dim_type_id)

# Parâmetro de comprimento total
dim.get_Parameter(BuiltInParameter.DIM_TOTAL_LENGTH)

# Coletar tipos de cota
dim_types = FilteredElementCollector(doc).OfClass(DimensionType).ToElements()
```

---

## Views

### Propriedades comuns

```python
view.IsTemplate           # True se template
view.ViewType             # tipo (FloorPlan, Section, etc.)
view.Name                 # nome
view.UpDirection          # direção para cima
view.ViewDirection        # direção de visão
view.Scale                # escala
view.CropBoxActive        # True se crop box ativa
view.CropBox              # BoundingBoxXYZ do crop
view.CropBox.Transform.BasisX  # eixo X do crop
view.CropBox.Transform.BasisY  # eixo Y do crop
```

### Overrides gráficos

```python
from Autodesk.Revit.DB import OverrideGraphicSettings, Color

ogs = OverrideGraphicSettings()
ogs.SetProjectionLineColor(Color(255, 0, 0))
ogs.SetProjectionLineWeight(4)
ogs.SetCutLineColor(Color(255, 0, 0))
ogs.SetCutLineWeight(4)
ogs.SetSurfaceForegroundPatternColor(Color(255, 200, 200))
ogs.SetSurfaceForegroundPatternId(pattern_id)
ogs.SetSurfaceTransparency(50)

view.SetElementOverrides(elem.Id, ogs)
view.HideElements(List[ElementId]([id1, id2]))
view.AreGraphicsOverridesAllowed()  # verifica se permite override
```

### Filtros da view

```python
filtros = view.GetFilters()  # lista de IDs de filtros
visivel = view.GetFilterVisibility(filter_id)
ogs_filtro = view.GetFilterOverrides(filter_id)
```

### `ViewType` (enum)

```python
from Autodesk.Revit.DB import ViewType

ViewType.FloorPlan
ViewType.Section
ViewType.ThreeD
ViewType.Legend
ViewType.DraftingView
ViewType.Schedule
ViewType.DrawingSheet
```

### Criar vista 3D

```python
from Autodesk.Revit.DB import View3D, ViewFamily, ViewFamilyType

# Coletar tipo 3D
vft = None
for ft in FilteredElementCollector(doc).OfClass(ViewFamilyType).ToElements():
    if ft.ViewFamily == ViewFamily.ThreeDimensional:
        vft = ft
        break

if vft:
    view3d = View3D.CreateIsometric(doc, vft.Id)
```

### Crop rotacionado (gotcha)

`view.CropBox` retorna um `BoundingBoxXYZ` (geometria), não o Element do crop. Mexer no `BoundingBoxXYZ.Transform` **não** rotaciona a vista. A crop é um Element separado com `ElementId` próprio.

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
crop_id = find_crop_region_id(doc, new_view)
if crop_id is not None and abs(angle) > 1e-9:
    axis = Line.CreateBound(center, XYZ(center.X, center.Y, center.Z + 1.0))
    ElementTransformUtils.RotateElement(doc, crop_id, axis, angle)
    doc.Regenerate()
```

### `ExportImage`. Capturar vista para arquivo

```python
from Autodesk.Revit.DB import ImageExportOptions, ImageResolution, ImageFileType, ExportRange

options = ImageExportOptions()
options.ExportRange = ExportRange.CurrentView
options.FilePath = r"C:\temp\vista_export"  # sem extensão. Revit adiciona
options.HLRandWFViewsFileType = ImageFileType.PNG
options.ImageResolution = ImageResolution.DPI_150
options.PixelSize = 1920

doc.ExportImage(options)
# gera arquivo C:\temp\vista_export.png
```

`ExportRange.CurrentView` pega a vista ativa. `ExportRange.SetOfViews` permite exportar uma lista. Não requer Transaction.

---

## Pranchas e Viewports

```python
from Autodesk.Revit.DB import ViewSheet, Viewport

sheets = FilteredElementCollector(doc).OfClass(ViewSheet).ToElements()
for sheet in sheets:
    sheet.SheetNumber            # número
    sheet.Name                   # nome
    vp_ids = sheet.GetAllViewports()    # IDs dos viewports
    view_ids = sheet.GetAllPlacedViews()  # IDs de views/schedules

# Viewport
vp = doc.GetElement(vp_id)
view = doc.GetElement(vp.ViewId)

# Criar viewport numa sheet
vp = Viewport.Create(doc, sheet.Id, view.Id, XYZ(0, 0, 0))

# Mudar tipo do viewport
vp.ChangeTypeId(vp_type.Id)
```

### Buscar tipo de viewport por nome

Viewport types não respondem a `OfCategory(OST_Viewports)`. Varrer `ElementType` e filtrar pelo nome:

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

---

## Links Revit

```python
from Autodesk.Revit.DB import RevitLinkInstance, WorksetConfiguration, WorksetConfigurationOption, LinkLoadResultType

links = FilteredElementCollector(doc).OfClass(RevitLinkInstance).ToElements()
for link in links:
    link_doc = link.GetLinkDocument()    # None se descarregado
    transform = link.GetTotalTransform()

# Recarregar de novo caminho
link_type = doc.GetElement(link.GetTypeId())
ext_ref = link_type.GetExternalFileReference()
abs_path = ModelPathUtils.ConvertModelPathToUserVisiblePath(
    ext_ref.GetAbsolutePath()
)

new_path = ModelPathUtils.ConvertUserVisiblePathToModelPath(novo_caminho)
wc = WorksetConfiguration(WorksetConfigurationOption.OpenLastViewed)
result = link_type.LoadFrom(new_path, wc)

if result.LoadResult == LinkLoadResultType.LinkLoaded:
    print("Carregado com sucesso")

# Descarregar e recarregar
link_type.Unload(None)
link_type.Reload()
```

### Ciclo completo. Descarregar, abrir, modificar, salvar, recarregar

```python
from Autodesk.Revit.DB import OpenOptions

# 1. Obter path
link_type = doc.GetElement(link_instance.GetTypeId())
ext_ref = link_type.GetExternalFileReference()
path = ModelPathUtils.ConvertModelPathToUserVisiblePath(ext_ref.GetAbsolutePath())

# 2. Descarregar
link_type.Unload(None)

# 3. Abrir
model_path = ModelPathUtils.ConvertUserVisiblePathToModelPath(path)
link_doc = app.OpenDocumentFile(model_path, OpenOptions())

# 4. Modificar (ex: copiar materiais)
ids = List[ElementId]()
ids.Add(material_id)

t = Transaction(link_doc, "Copiar Materiais")
t.Start()
ElementTransformUtils.CopyElements(doc, ids, link_doc, None, CopyPasteOptions())
t.Commit()

# 5. Salvar e fechar
link_doc.Save()
link_doc.Close(False)

# 6. Recarregar no doc principal
link_type.Reload()
```

---

## Transformações

```python
from Autodesk.Revit.DB import ElementTransformUtils, Transform, CopyPasteOptions
import math

# Mover
ElementTransformUtils.MoveElement(doc, elem.Id, XYZ(1, 0, 0))

# Rotacionar
axis = Line.CreateBound(XYZ(0,0,0), XYZ(0,0,1))
ElementTransformUtils.RotateElement(doc, elem.Id, axis, math.pi/2)

# Copiar entre documentos
opts = CopyPasteOptions()
ElementTransformUtils.CopyElements(
    source_doc,
    List[ElementId]([id1, id2]),
    target_doc,
    Transform.Identity,
    opts
)
```

---

## Seleção do Usuário

```python
from Autodesk.Revit.UI.Selection import ObjectType, ISelectionFilter
from Autodesk.Revit.Exceptions import OperationCanceledException

try:
    # Um elemento
    ref = uidoc.Selection.PickObject(ObjectType.Element, "Selecione")
    elem = doc.GetElement(ref.ElementId)

    # Múltiplos
    refs = uidoc.Selection.PickObjects(ObjectType.Element, "Selecione vários")

    # Com filtro de categoria
    class WallFilter(ISelectionFilter):
        def AllowElement(self, elem):
            return elem.Category.Id.IntegerValue == int(BuiltInCategory.OST_Walls)
        def AllowReference(self, ref, point):
            return False

    self._sel_filter = WallFilter()  # OBRIGATÓRIO ser self. para não ser coletado pelo GC
    refs = uidoc.Selection.PickObjects(ObjectType.Element, self._sel_filter, "Selecione paredes")

    # Selecionar programaticamente
    uidoc.Selection.SetElementIds(List[ElementId]([id1, id2]))

except OperationCanceledException:
    pass  # usuário cancelou
```

---

## Materiais

```python
from Autodesk.Revit.DB import Material

mats = FilteredElementCollector(doc).OfClass(Material).ToElements()
for mat in mats:
    mat.Name
    mat.AppearanceAssetId   # asset de aparência (render)
    mat.ThermalAssetId      # asset térmico
    mat.StructuralAssetId   # asset estrutural
    mat.Color               # cor da superfície
```

### Thumbnail de material. Cadeia de fallback em 3 níveis

`Material.GetPreviewImage()` retorna `None` em background documents. Usar fallback:

```python
import System.Drawing as SD
from System.Windows.Interop import Imaging as WpfImaging

def get_material_thumb(material, doc):
    size = SD.Size(120, 96)

    # 1. Preview nativo (esfera de render)
    thumb = material.GetPreviewImage(size)
    if thumb is not None:
        return thumb

    # 2. AppearanceAssetElement
    asset_id = material.AppearanceAssetId
    if asset_id != ElementId.InvalidElementId:
        asset_elem = doc.GetElement(asset_id)
        if asset_elem:
            thumb = asset_elem.GetPreviewImage(size)
            if thumb is not None:
                return thumb

    # 3. Swatch sólido com mat.Color
    color = material.Color
    if color.IsValid:
        bmp = SD.Bitmap(120, 96)
        g = SD.Graphics.FromImage(bmp)
        g.Clear(SD.Color.FromArgb(color.Red, color.Green, color.Blue))
        g.Dispose()
        return bmp

    return None
```

---

## Áreas e Rooms

```python
from Autodesk.Revit.DB import SpatialElementBoundaryOptions, FilledRegion, CurveLoop

# Boundaries de room/area
opts = SpatialElementBoundaryOptions()
boundaries = room.GetBoundarySegments(opts)
for boundary_list in boundaries:
    loop = CurveLoop()
    for seg in boundary_list:
        curve = seg.GetCurve()
        loop.Append(curve)

# Criar FilledRegion
from System.Collections.Generic import List as NetList
curve_loops = NetList[CurveLoop]()
curve_loops.Add(loop)

filled_region = FilledRegion.Create(doc, fr_type_id, view.Id, curve_loops)

# Bounding box de room
bb = room.get_BoundingBox(view)
bb.Min   # XYZ mínimo
bb.Max   # XYZ máximo
```

---

## Filtros de Elemento (Filters)

```python
from Autodesk.Revit.DB import (
    ParameterFilterElement, ElementCategoryFilter,
    ElementMulticategoryFilter, LogicalAndFilter
)

# Coletar filtros da view
filter_ids = view.GetFilters()
for fid in filter_ids:
    f = doc.GetElement(fid)
    f.Name
    f.GetCategories()
    f.GetElementFilter()

# Filtros de coletor
cat_filter = ElementCategoryFilter(BuiltInCategory.OST_Walls)
multi_filter = ElementMulticategoryFilter(List[ElementId]([cat_id1, cat_id2]))

collector.WherePasses(cat_filter)

# AND/OR
combined = LogicalAndFilter(f1, f2)
```

---

## Conversão de Unidades

```python
from Autodesk.Revit.DB import UnitUtils, UnitTypeId

# Pés → outras unidades
cm = UnitUtils.ConvertFromInternalUnits(valor_em_pes, UnitTypeId.Centimeters)
m = UnitUtils.ConvertFromInternalUnits(valor_em_pes, UnitTypeId.Meters)
mm = UnitUtils.ConvertFromInternalUnits(valor_em_pes, UnitTypeId.Millimeters)

# Outras unidades → pés (para escrever na API)
pes = UnitUtils.ConvertToInternalUnits(valor_em_metros, UnitTypeId.Meters)
```

### Conversão por spec do parâmetro (forçar metros)

Para exibir sempre em metros independente das unidades do projeto:

```python
METER_SPEC_MAP = [
    ("length", UnitTypeId.Meters,       u"m"),
    ("area",   UnitTypeId.SquareMeters, u"m²"),
    ("volume", UnitTypeId.CubicMeters,  u"m³"),
]

def format_in_meters(param, total_internal):
    spec    = param.Definition.GetDataType()
    spec_id = spec.TypeId.lower() if spec else ""
    for key, unit_type_id, symbol in METER_SPEC_MAP:
        if key in spec_id:
            converted = UnitUtils.ConvertFromInternalUnits(total_internal, unit_type_id)
            return u"{:.3f} {}".format(converted, symbol)
    return None  # não é comprimento/área/volume
```

`spec.TypeId` tem formato `"autodesk.spec.aec:length-2.0.0"`. A busca por substring é robusta a versões.

---

## TaskDialog

```python
from Autodesk.Revit.UI import TaskDialog, TaskDialogCommonButtons, TaskDialogResult, TaskDialogCommandLinkId

# Simples
TaskDialog.Show("Título", "Mensagem")

# Com botões padrão
td = TaskDialog("Confirmar")
td.MainContent = "Deseja continuar?"
td.CommonButtons = TaskDialogCommonButtons.Yes | TaskDialogCommonButtons.No
result = td.Show()

if result == TaskDialogResult.Yes:
    pass

# Com Command Links (botões customizados)
td = TaskDialog("Modo de Operação")
td.MainInstruction = "Escolha o modo:"
td.AddCommandLink(TaskDialogCommandLinkId.CommandLink1, "Opção A")
td.AddCommandLink(TaskDialogCommandLinkId.CommandLink2, "Opção B")
result = td.Show()

if result == TaskDialogResult.CommandLink1:
    # opção A
    pass
```

---

## BuiltInCategory. Mais usadas

```python
BuiltInCategory.OST_Walls           # Paredes
BuiltInCategory.OST_Doors           # Portas
BuiltInCategory.OST_Windows         # Janelas
BuiltInCategory.OST_Floors          # Pisos
BuiltInCategory.OST_Ceilings        # Forros
BuiltInCategory.OST_Roofs           # Coberturas
BuiltInCategory.OST_Rooms           # Ambientes
BuiltInCategory.OST_Areas           # Áreas
BuiltInCategory.OST_Sheets          # Pranchas
BuiltInCategory.OST_TitleBlocks     # Carimbos
BuiltInCategory.OST_Lines           # Linhas de modelo
BuiltInCategory.OST_Furniture       # Mobiliário
BuiltInCategory.OST_GenericModel    # Modelo genérico
BuiltInCategory.OST_Levels          # Níveis
BuiltInCategory.OST_Grids           # Eixos
BuiltInCategory.OST_StructuralColumns  # Pilares
BuiltInCategory.OST_StructuralFraming  # Vigas
BuiltInCategory.OST_MEPSpaces       # MEP Spaces
BuiltInCategory.OST_LightingFixtures # Luminárias
BuiltInCategory.OST_ElectricalFixtures # Pontos elétricos
BuiltInCategory.OST_DuctTerminal    # Difusores de ar
```

### Detecção segura entre versões

Nem todos os `BuiltInCategory.OST_*` existem em todas as versões. Usar `getattr` com fallback:

```python
cat = getattr(BuiltInCategory, "OST_Gutters",
       getattr(BuiltInCategory, "OST_Gutter", None))

if cat is None:
    # categoria não existe nesta versão
    pass
```

### Listar todas as categorias de modelo

```python
from Autodesk.Revit.DB import CategoryType

cats = sorted(
    [c for c in doc.Settings.Categories
     if c.CategoryType == CategoryType.Model],
    key=lambda c: c.Name
)
```

---

## Famílias e Tipos

```python
from Autodesk.Revit.DB import FamilyInstance, FamilySymbol, Family

# Coletar todas as instâncias de família
instances = FilteredElementCollector(doc).OfClass(FamilyInstance).ToElements()

# Por categoria
portas = FilteredElementCollector(doc)\
    .OfCategory(BuiltInCategory.OST_Doors)\
    .OfClass(FamilyInstance)\
    .ToElements()

# Obter tipo (FamilySymbol) e família
for inst in instances:
    tipo = doc.GetElement(inst.GetTypeId())  # FamilySymbol
    familia = tipo.Family  # Family
    nome_tipo = tipo.get_Parameter(BuiltInParameter.ALL_MODEL_TYPE_NAME).AsString()
```

### Carregar família. `LoadFamily` com `IFamilyLoadOptions`

```python
from Autodesk.Revit.DB import IFamilyLoadOptions

class _OverwriteOptions(IFamilyLoadOptions):
    def OnFamilyFound(self, familyInUse, overwriteParameterValues):
        overwriteParameterValues = True
        return True

    def OnSharedFamilyFound(self, sharedFamily, familyInUse, source, overwriteParameterValues):
        overwriteParameterValues = True
        return True

# Uso dentro da transação
opts = _OverwriteOptions()
doc.LoadFamily(path, opts)
```

### Inserir instância de família

```python
from Autodesk.Revit.DB.Structure import StructuralType

# Garantir que o symbol está ativo
if not symbol.IsActive:
    symbol.Activate()
    doc.Regenerate()

# Inserir
instance = doc.Create.NewFamilyInstance(
    posicao,           # XYZ
    symbol,            # FamilySymbol
    StructuralType.NonStructural
)
```

---

## Levels (Níveis)

```python
from Autodesk.Revit.DB import Level

levels = FilteredElementCollector(doc).OfClass(Level).ToElements()

# Ordenar por elevação
levels_sorted = sorted(levels, key=lambda l: l.Elevation)

for level in levels_sorted:
    print("{}: {:.2f}m".format(
        level.Name,
        UnitUtils.ConvertFromInternalUnits(level.Elevation, UnitTypeId.Meters)
    ))
```

---

## Abrir documento em background + copiar elementos

Permite ler tipos, materiais e padrões de qualquer `.rvt` sem abrir na interface, e copiar para o documento ativo.

```python
from Autodesk.Revit.DB import OpenOptions, DetachFromCentralOption, ModelPathUtils

# Abrir
path = ModelPathUtils.ConvertUserVisiblePathToModelPath(r"C:\biblioteca.rvt")

options = OpenOptions()
options.DetachFromCentralOption = DetachFromCentralOption.DetachAndPreserveWorksets

source_doc = app.OpenDocumentFile(path, options)
# app = __revit__.Application (não UIApplication)

# Copiar elementos para o doc ativo
with Transaction(doc, "Importar elementos") as t:
    t.Start()
    ElementTransformUtils.CopyElements(
        source_doc,          # documento de origem
        element_ids,         # ICollection[ElementId]
        doc,                 # documento de destino (ativo)
        Transform.Identity,
        CopyPasteOptions()
    )
    t.Commit()

source_doc.Close(False)  # fechar sem salvar
```

O Revit resolve dependências automaticamente. Copiar um tipo de parede traz os materiais que ele usa, mesmo que não existam no destino.

**O que pode ser copiado:** `WallType`, `FloorType`, `CeilingType`, `RoofType`, `Material` (com assets), `TextNoteType`, `DimensionType`, filtros, padrões de preenchimento, famílias de sistema e seus tipos. Qualquer coisa que o "Transfer Project Standards" nativo faz, mas com controle granular.

---

## Purge / Performance Adviser

```python
from Autodesk.Revit.DB import PerformanceAdviser, PerformanceAdviserRuleId

adviser = PerformanceAdviser.GetPerformanceAdviser()
all_rules = adviser.GetAllRuleIds()

purge_rules = List[PerformanceAdviserRuleId]()
for rule in all_rules:
    purge_rules.Add(rule)

adviser.ExecuteRules(doc, purge_rules)
```
