# Migração pyRevit para Add-in C#

Guia completo para transformar uma extension pyRevit (Python / IronPython 2.7) em um plugin nativo C# (`IExternalApplication` + `IExternalCommand`).

A migração faz sentido quando o plugin precisa:
- Distribuição sem pré-requisito do pyRevit
- Performance nativa (sem overhead do IronPython)
- Distribuição via instalador para escritórios que não usam pyRevit

Veja `inno-setup-template.iss` para distribuição via instalador Inno Setup, e este arquivo para distribuição via Add-in tradicional do Revit.

---

## 1. Estrutura do projeto Visual Studio

```
MeuPlugin/
├── MeuPlugin.sln
├── MeuPlugin/
│   ├── MeuPlugin.csproj
│   ├── App.cs                    ← IExternalApplication (startup)
│   ├── Commands/
│   │   ├── MeuComando.cs         ← IExternalCommand (cada pushbutton vira um)
│   │   └── OutroComando.cs
│   ├── Views/                    ← Formulários WPF
│   │   ├── SelectMaterials.xaml
│   │   └── SelectMaterials.xaml.cs
│   ├── Resources/
│   │   ├── icon-MeuComando.png       ← 96x96 PNG transparente
│   │   └── icon-MeuComando.dark.png
│   ├── Helpers/                  ← código compartilhado (equiv. à lib/ do pyRevit)
│   └── MeuPlugin.addin           ← Manifesto XML
```

### Equivalência pyRevit → C#

| pyRevit | C# Add-in |
|---|---|
| `.extension/` | Solution `.sln` |
| `.tab/` | `RibbonTab` (criado via código no `IExternalApplication`) |
| `.panel/` | `RibbonPanel` |
| `.pushbutton/script.py` | Classe que implementa `IExternalCommand` |
| `extension.json` | Arquivo `.addin` (manifesto XML) |
| `lib/` | Pasta `Helpers/` no projeto (todo `.cs` é compilado no mesmo assembly) |

### Manifesto `.addin`

```xml
<?xml version="1.0" encoding="utf-8"?>
<RevitAddIns>
  <AddIn Type="Application">
    <Name>Meu Plugin</Name>
    <Assembly>caminho\para\MeuPlugin.dll</Assembly>
    <FullClassName>MeuPlugin.App</FullClassName>
    <AddInId>GUID-UNICO-AQUI</AddInId>
    <VendorId>MeuVendor</VendorId>
  </AddIn>
</RevitAddIns>
```

Deploy: copiar para `%AppData%\Autodesk\Revit\Addins\{versão}\`.

### Referências obrigatórias

- `RevitAPI.dll` (DB namespace)
- `RevitAPIUI.dll` (UI namespace)
- Ambas com **`<Private>false</Private>`** (Copy Local = false). Já existem no Revit.

### Target Framework por versão

| Revit | Framework |
|---|---|
| 2021 a 2024 | .NET Framework 4.8 |
| 2025+ | .NET 8 |

### Multi-targeting (compilar para ambos em um único projeto)

No `.csproj`, usar `TargetFrameworks` (plural) e referências condicionais:

```xml
<TargetFrameworks>net48;net8.0-windows</TargetFrameworks>

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

### Deploy automático via Post-Build

Adicionar target no `.csproj` para copiar a DLL e o `.addin` direto para `%AppData%\Autodesk\Revit\Addins\{versão}\` após cada build:

```xml
<Target Name="CopyToRevitAddins" AfterTargets="Build">
  <PropertyGroup>
    <RevitYear Condition="'$(TargetFramework)' == 'net48'">2024</RevitYear>
    <RevitYear Condition="'$(TargetFramework)' == 'net8.0-windows'">2025</RevitYear>
  </PropertyGroup>
  <Copy SourceFiles="$(OutputPath)$(AssemblyName).dll"
        DestinationFolder="$(AppData)\Autodesk\Revit\Addins\$(RevitYear)" />
  <Copy SourceFiles="MeuPlugin.addin"
        DestinationFolder="$(AppData)\Autodesk\Revit\Addins\$(RevitYear)" />
</Target>
```

### Pinning de SDK com `global.json`

Se a máquina tiver .NET 10 SDK instalado, `dotnet build` pode falhar com MSB4242 (workload manifests). Criar `global.json` na raiz da solution:

```json
{
  "sdk": {
    "version": "8.0.416",
    "rollForward": "latestPatch"
  }
}
```

### `UseWindowsForms` no `.csproj`

Para usar `System.Windows.Forms.ColorDialog`, `OpenFileDialog`, etc.:

```xml
<UseWindowsForms>true</UseWindowsForms>
```

Para net48, adicionar referências explícitas:

```xml
<ItemGroup Condition="'$(TargetFramework)' == 'net48'">
  <Reference Include="System.Windows.Forms" />
  <Reference Include="System.Drawing" />
</ItemGroup>
```

---

## 2. Tradução Python → C#

### Entry points

```python
# pyRevit. script.py é executado direto
doc = __revit__.ActiveUIDocument.Document
# código roda aqui
```

```csharp
// C#. Classe implementa IExternalCommand
using Autodesk.Revit.Attributes;
using Autodesk.Revit.DB;
using Autodesk.Revit.UI;

[Transaction(TransactionMode.Manual)]
public class MeuComando : IExternalCommand
{
    public Result Execute(
        ExternalCommandData commandData,
        ref string message,
        ElementSet elements)
    {
        UIApplication uiApp = commandData.Application;
        UIDocument uidoc = uiApp.ActiveUIDocument;
        Document doc = uidoc.Document;

        // código aqui

        return Result.Succeeded;
    }
}
```

### Variáveis globais

| pyRevit | C# |
|---|---|
| `__revit__` | `commandData.Application` |
| `doc = revit.doc` | `Document doc = uidoc.Document;` |
| `uidoc = revit.uidoc` | `UIDocument uidoc = uiApp.ActiveUIDocument;` |
| `app = __revit__.Application` | `Application app = uiApp.Application;` |
| `script.exit()` | `return Result.Cancelled;` |

### Imports

```python
# pyRevit
from Autodesk.Revit.DB import FilteredElementCollector, Transaction, Material
from Autodesk.Revit.UI import TaskDialog
```

```csharp
// C#
using Autodesk.Revit.DB;
using Autodesk.Revit.UI;
using Autodesk.Revit.Attributes;
using Autodesk.Revit.ApplicationServices;  // para Application
using System.Collections.Generic;
using System.Linq;
```

### Namespaces que pegam desprevenido

| Classe | Namespace correto |
|---|---|
| `Application` | `Autodesk.Revit.ApplicationServices` (NÃO `Autodesk.Revit.DB`) |
| `Room` | `Autodesk.Revit.DB.Architecture` (NÃO `Autodesk.Revit.DB`) |
| Eventos de doc | `Autodesk.Revit.DB.Events` |
| Eventos de UI | `Autodesk.Revit.UI.Events` |

### Ambiguidade `Grid` (WPF × Revit)

```csharp
// Resolve com alias
using WpfGrid = System.Windows.Controls.Grid;

// Depois usar
WpfGrid.SetRow(label, 0);
WpfGrid.SetColumn(label, 1);
```

### FilteredElementCollector

```python
# Python
walls = FilteredElementCollector(doc).OfClass(Wall).ToElements()
materiais = FilteredElementCollector(doc).OfClass(Material).ToElements()
```

```csharp
// C#
var walls = new FilteredElementCollector(doc)
    .OfClass(typeof(Wall))
    .ToElements();

var materiais = new FilteredElementCollector(doc)
    .OfClass(typeof(Material))
    .Cast<Material>()
    .ToList();
```

### Transactions

```python
# Python
t = Transaction(doc, "Nome")
t.Start()
try:
    # operações
    t.Commit()
except:
    t.RollBack()
```

```csharp
// C#. Bloco using garante dispose
using (Transaction t = new Transaction(doc, "Nome"))
{
    t.Start();
    try
    {
        // operações
        t.Commit();
    }
    catch (Exception)
    {
        t.RollBack();
        throw;
    }
}
```

### `TransactionGroup`

```csharp
using (TransactionGroup tg = new TransactionGroup(doc, "Operação Completa"))
{
    tg.Start();

    using (Transaction t1 = new Transaction(doc, "Etapa 1"))
    {
        t1.Start();
        t1.Commit();
    }

    using (Transaction t2 = new Transaction(doc, "Etapa 2"))
    {
        t2.Start();
        t2.Commit();
    }

    tg.Assimilate();
}
```

### `SubTransaction`

```csharp
using (Transaction t = new Transaction(doc, "Criar Paredes"))
{
    t.Start();
    foreach (var item in itens)
    {
        using (SubTransaction st = new SubTransaction(doc))
        {
            st.Start();
            try
            {
                // criar parede individual
                st.Commit();
            }
            catch
            {
                st.RollBack();  // só essa falha, o resto continua
            }
        }
    }
    t.Commit();
}
```

### Listas e coleções .NET

```python
# Python
from System.Collections.Generic import List
ids = List[ElementId]()
ids.Add(mat_id)
```

```csharp
// C#
List<ElementId> ids = new List<ElementId>();
ids.Add(matId);
// Ou com inicializador
var ids = new List<ElementId> { matId };
```

---

## 3. Formulários. `pyrevit.forms` → C#

### Equivalências diretas

| pyRevit forms | C# equivalente |
|---|---|
| `forms.alert("msg")` | `TaskDialog.Show("Título", "msg")` |
| `forms.alert("msg", options=[...])` | `TaskDialog` com `CommandLinks` |
| `forms.SelectFromList.show(...)` | WPF customizado (Window + ListBox) |
| `forms.ask_for_string(...)` | WPF customizado ou InputBox |
| `forms.pick_file(...)` | `System.Windows.Forms.OpenFileDialog` |

### `TaskDialog` com opções

```csharp
TaskDialog dialog = new TaskDialog("Modo de Operação");
dialog.MainInstruction = "Escolha o modo:";
dialog.AddCommandLink(TaskDialogCommandLinkId.CommandLink1, "Opção A");
dialog.AddCommandLink(TaskDialogCommandLinkId.CommandLink2, "Opção B");

TaskDialogResult result = dialog.Show();

if (result == TaskDialogResult.CommandLink1) { /* A */ }
else if (result == TaskDialogResult.CommandLink2) { /* B */ }
```

### `ColorDialog` (System.Windows.Forms)

Para color picker, usar `System.Windows.Forms.ColorDialog`. Requer `UseWindowsForms` no `.csproj`.

```csharp
using FormsColor = System.Drawing.Color;

var dlg = new System.Windows.Forms.ColorDialog();
if (dlg.ShowDialog() == System.Windows.Forms.DialogResult.OK)
{
    FormsColor c = dlg.Color;
    byte r = c.R, g = c.G, b = c.B;
}
```

### Formulários WPF em C#

XAML praticamente idêntico ao pyRevit, mas com `x:Class`:

```xml
<Window x:Class="MeuPlugin.Views.SelectMaterials"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Selecionar Materiais" Height="500" Width="450"
        WindowStartupLocation="CenterScreen">

    <StackPanel Margin="20">
        <ListBox x:Name="UIe_listbox_materiais" Height="300"/>
        <Button x:Name="UIe_button_confirmar" Content="Confirmar"
                Click="UIE_button_confirmar"/>
    </StackPanel>
</Window>
```

Code-behind:

```csharp
namespace MeuPlugin.Views
{
    public partial class SelectMaterials : Window
    {
        public bool Confirmed { get; private set; }

        public SelectMaterials()
        {
            InitializeComponent(); // equivale ao wpf.LoadComponent
        }

        private void UIE_button_confirmar(object sender, RoutedEventArgs e)
        {
            Confirmed = true;
            Close();
        }
    }
}
```

Diferenças:
- `wpf.LoadComponent(self, path_xaml)` → `InitializeComponent()` (gerado automaticamente do XAML)
- XAML idêntico, exceto pelo `x:Class` no cabeçalho

### Output Window (equivalente a `pyrevit.output`)

C# não tem equivalente nativo. Criar WPF com `RichTextBox` + `FlowDocument`:

```csharp
var output = new OutputWindow("Título");
output.PrintTitle("Título Grande");
output.PrintSubtitle("Subtítulo");
output.Print("Texto normal");
output.PrintBold("Destaque");
output.PrintSuccess("OK. Feito.");
output.PrintError("ERRO: falhou");
output.PrintWarning("AVISO: cuidado");
output.PrintSeparator();
output.PrintTable(rows, headers);
output.SetStatus("Texto da barra inferior");
output.ShowDialog();
```

### `ISelectionFilter`

```csharp
using Autodesk.Revit.UI.Selection;

private class AreaSelectionFilter : ISelectionFilter
{
    public bool AllowElement(Element elem) => elem is Area;
    public bool AllowReference(Reference reference, XYZ position) => false;
}

// Uso
var refs = uidoc.Selection.PickObjects(
    ObjectType.Element, new AreaSelectionFilter(), "Selecione áreas");
```

---

## 4. APIs que mudaram entre versões

### `Floor.Create` substitui `doc.Create.NewFloor`

`doc.Create.NewFloor` foi removido em Revit 2025. Usar `Floor.Create` (funciona do 2022 em diante):

```csharp
// REMOVIDO em 2025+
Floor floor = doc.Create.NewFloor(profile, floorType, level, false);

// CORRETO (2022+)
CurveLoop loop = CurveLoop.Create(curves);
Floor floor = Floor.Create(doc, new List<CurveLoop> { loop }, floorType.Id, level.Id);
```

### `OverrideGraphicSettings.SurfaceTransparency` sem getter

```csharp
// NÃO EXISTE GETTER
int transp = ogs.SurfaceTransparency;  // CS1061

// Usar valor default
int transp = 20;
ogs.SetSurfaceTransparency(transp);
```

---

## 5. Ícones

| Contexto | Tamanho recomendado |
|---|---|
| pyRevit | 96x96 PNG transparente, light + dark |
| C# Add-in. Botão pequeno | 16x16 |
| C# Add-in. Botão grande | 32x32 |

Para C#, dá pra usar um único PNG 96x96 e redimensionar via código (mais flexível):

```csharp
private BitmapSource ResizeImage(BitmapSource source, int width, int height)
{
    var group = new DrawingGroup();
    RenderOptions.SetBitmapScalingMode(group, BitmapScalingMode.HighQuality);
    group.Children.Add(new ImageDrawing(source,
        new System.Windows.Rect(0, 0, width, height)));

    var target = new RenderTargetBitmap(width, height, 96, 96, PixelFormats.Pbgra32);
    var visual = new DrawingVisual();
    using (var context = visual.RenderOpen())
        context.DrawDrawing(group);
    target.Render(visual);
    return target;
}
```

### Convenção de nomes

```
Resources/
├── icon-MeuComando.png        ← light (padrão)
├── icon-MeuComando.dark.png   ← dark (opcional)
└── icon-32.png                ← fallback genérico
```

No `.csproj`, copiar todos com wildcard:

```xml
<ItemGroup>
  <None Include="Resources\*.png" CopyToOutputDirectory="PreserveNewest" />
</ItemGroup>
```

### Detecção de tema

```csharp
// Revit 2025+ via UIThemeManager (reflection)
var themeType = Type.GetType("Autodesk.Revit.UI.UIThemeManager, RevitAPIUI");
if (themeType != null)
{
    var currentProp = themeType.GetProperty("CurrentTheme",
        BindingFlags.Public | BindingFlags.Static);
    bool isDark = currentProp?.GetValue(null)?.ToString() == "Dark";
}

// Revit 2024 e anteriores. Fallback por Registry
using (var key = Registry.CurrentUser.OpenSubKey(
    @"Software\Autodesk\Revit\Autodesk Revit 2024\Scheme"))
{
    bool isDark = key?.GetValue("ColorTheme")?.ToString() == "1";
}
```

Limitação: a detecção ocorre apenas no `OnStartup`. Trocar o tema com o Revit aberto não atualiza os ícones.

---

## 6. Criação do Ribbon

No pyRevit, a estrutura de pastas cria o ribbon automaticamente. Em C#, é feito via código no `IExternalApplication`:

```csharp
using System.Reflection;
using Autodesk.Revit.UI;

public class App : IExternalApplication
{
    public Result OnStartup(UIControlledApplication app)
    {
        // 1. Criar Tab
        app.CreateRibbonTab("Meu Plugin");

        // 2. Criar Panel
        RibbonPanel panel = app.CreateRibbonPanel("Meu Plugin", "Ferramentas");

        // 3. Criar Button
        string assemblyPath = Assembly.GetExecutingAssembly().Location;

        PushButtonData btnData = new PushButtonData(
            "cmdTransferirMateriais",
            "Transferir\nMateriais",
            assemblyPath,
            "MeuPlugin.Commands.TransferirMateriais"
        );

        // Aplicar ícone
        BitmapImage icon = LoadIcon("TransferirMateriais", IsDarkTheme());
        if (icon != null)
        {
            btnData.LargeImage = ResizeImage(icon, 32, 32);
            btnData.Image      = ResizeImage(icon, 16, 16);
        }

        panel.AddItem(btnData);

        return Result.Succeeded;
    }

    public Result OnShutdown(UIControlledApplication app)
    {
        return Result.Succeeded;
    }
}
```

### `AddStackedItems`. Mínimo de 2 itens

`RibbonPanel.AddStackedItems()` aceita apenas 2 ou 3 itens. 1 item lança exceção:

```csharp
// 2 itens
panel.AddStackedItems(btn1, btn2);

// 3 itens
panel.AddStackedItems(btn1, btn2, btn3);

// 1 item. Usar AddItem
panel.AddItem(btn1);
```

---

## 7. Hooks. pyRevit → Event Handlers C#

| pyRevit hook | Evento C# |
|---|---|
| `doc-opened_hook.py` | `app.ControlledApplication.DocumentOpened` |
| `doc-closing_hook.py` | `app.ControlledApplication.DocumentClosing` |
| `doc-saved_hook.py` | `app.ControlledApplication.DocumentSaved` |
| `doc-syncing_hook.py` | `app.ControlledApplication.DocumentSynchronizingWithCentral` |
| `doc-synced_hook.py` | `app.ControlledApplication.DocumentSynchronizedWithCentral` |
| `view-activated_hook.py` | `app.ViewActivated` |
| `app-closing_hook.py` | `app.ControlledApplication.ApplicationClosing` |

Em C# todos ficam num só lugar, registrados no `OnStartup`:

```csharp
public Result OnStartup(UIControlledApplication app)
{
    app.ControlledApplication.DocumentOpened += OnDocumentOpened;
    app.ControlledApplication.DocumentSaved += OnDocumentSaved;
    app.ViewActivated += OnViewActivated;

    // criar ribbon etc.
    return Result.Succeeded;
}

public Result OnShutdown(UIControlledApplication app)
{
    // Sempre desregistrar para evitar memory leaks
    app.ControlledApplication.DocumentOpened -= OnDocumentOpened;
    app.ControlledApplication.DocumentSaved -= OnDocumentSaved;
    app.ViewActivated -= OnViewActivated;

    return Result.Succeeded;
}

private void OnDocumentOpened(object sender,
    Autodesk.Revit.DB.Events.DocumentOpenedEventArgs e)
{
    Document doc = e.Document;
    // lógica do hook
}
```

### Hook que precisa modificar o modelo. `ExternalEvent`

Eventos read-only não permitem transação direto. Usar `ExternalEvent`:

```csharp
// No OnStartup
ExternalEvent _exEvent;
MyEventHandler _handler = new MyEventHandler();
_exEvent = ExternalEvent.Create(_handler);

// No evento, disparar
private void OnDocumentOpened(object sender, DocumentOpenedEventArgs e)
{
    _handler.Doc = e.Document;
    _exEvent.Raise();
}

// Handler separado
public class MyEventHandler : IExternalEventHandler
{
    public Document Doc { get; set; }

    public void Execute(UIApplication app)
    {
        using (Transaction t = new Transaction(Doc, "Hook Action"))
        {
            t.Start();
            // modificar modelo
            t.Commit();
        }
    }

    public string GetName() => "MyEventHandler";
}
```

---

## 8. Classe base para validações comuns (licenciamento, logging)

Para aplicar lógica comum a todos os comandos (licença, logging, etc.), criar uma classe base abstrata:

```csharp
public abstract class PluginCommand : IExternalCommand
{
    public Result Execute(ExternalCommandData commandData, ref string message, ElementSet elements)
    {
        // Validação cross-cutting aqui (licença, permissões, logging)
        if (!IsAuthorized(commandData))
        {
            TaskDialog.Show("Acesso Negado", "Usuário não autorizado.");
            return Result.Failed;
        }
        return ExecuteCommand(commandData, ref message, elements);
    }

    protected virtual bool IsAuthorized(ExternalCommandData commandData) => true;

    protected abstract Result ExecuteCommand(ExternalCommandData commandData,
        ref string message, ElementSet elements);
}
```

Cada comando herda da base e implementa apenas `ExecuteCommand`. Mudança no comportamento global vai num único lugar.

Username do Revit (útil para validação por usuário):

```csharp
string username = commandData.Application.Application.Username;
```

---

## 9. Distribuição

| pyRevit | C# Add-in |
|---|---|
| Copiar pasta `.extension/` para Extensions do pyRevit | Compilar DLL + `.addin` para `%AppData%\Autodesk\Revit\Addins\{ano}\` |
| pyRevit detecta automaticamente | Revit lê `.addin` ao iniciar |

Para distribuição em produção, criar um instalador standalone (`.exe`) que detecta versões do Revit instaladas e instala em todas elas. Veja `inno-setup-template.iss` para template Inno Setup.

---

## Checklist de Migração

- [ ] Criar Solution no Visual Studio
- [ ] Configurar multi-targeting (`net48;net8.0-windows`) no `.csproj`
- [ ] Configurar referências condicionais (RevitAPI.dll, RevitAPIUI.dll) com `<Private>false</Private>`
- [ ] Criar `global.json` se necessário (pinning de SDK)
- [ ] Criar `IExternalApplication` (App.cs) com Ribbon
- [ ] Para cada `.pushbutton/script.py`. Criar classe `IExternalCommand`
- [ ] Migrar pasta `lib/`. Classes em `Helpers/` ou `Models/`
- [ ] Migrar hooks (`*_hook.py`). Event handlers no `OnStartup`
- [ ] Traduzir código Python → C# (tipagem, collectors, transactions)
- [ ] Converter `forms.alert` → `TaskDialog`
- [ ] Converter `forms.SelectFromList` / `ask_for_one_item` → WPF customizado
- [ ] Migrar XAML existente (adicionar `x:Class`, criar code-behind)
- [ ] Copiar ícones para `Resources/`
- [ ] Configurar wildcard copy no `.csproj`
- [ ] Implementar dark/light icon loading
- [ ] Adicionar `UseWindowsForms` se necessário
- [ ] Resolver ambiguidades de namespace (Grid, Room, Application)
- [ ] Verificar APIs depreciadas (`NewFloor` → `Floor.Create`)
- [ ] Criar arquivo `.addin`
- [ ] Testar build para ambos os targets
- [ ] Deploy e testar no Revit
- [ ] (Opcional) Criar instalador Inno Setup
