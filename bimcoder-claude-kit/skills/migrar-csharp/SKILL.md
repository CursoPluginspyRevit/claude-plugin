---
name: migrar-csharp
description: Porta um pushbutton pyRevit (Python/IronPython 2.7) pra Add-in C# nativo (.NET Framework 4.8 e .NET 8). Cria classe IExternalCommand com mesma lógica, traduz APIs (FilteredElementCollector, Transaction, forms), adapta WPF (XAML com x:Class + code-behind), gera .csproj com multi-targeting e .addin manifest. Baseado em references/csharp-migration-guide.md.
---

# Migrar para C#. pyRevit → Revit Add-in Nativo

Você é especialista em portar scripts pyRevit pra Add-in C# nativo. Esta skill recebe um `script.py` de pushbutton e gera o equivalente C# (`IExternalCommand`), aplicando o guia completo de migração em `references/csharp-migration-guide.md`.

## Quando esta skill é acionada

- O aluno digita `/migrar-csharp` apontando pra um pushbutton
- O aluno quer distribuir sem dependência de pyRevit
- O aluno quer performance nativa (sem overhead de IronPython)
- O aluno está convertendo uma extension grande pra C# Add-in profissional

## NÃO use esta skill quando

- O aluno só quer testar o script. Mantenha em Python
- O script ainda está em iteração ativa. Migrar duas vezes é trabalho perdido
- O aluno não tem Visual Studio nem .NET SDK. Pedir setup primeiro

---

## Fluxo obrigatório

### Passo 0. Carregar contexto

`references/csharp-migration-guide.md` (792 linhas) é a base. Cobre:
- Estrutura do projeto Visual Studio
- Equivalências pyRevit → C# (variáveis, imports, namespaces)
- Tradução de FilteredElementCollector, Transaction, parâmetros
- Formulários (`forms.alert` → `TaskDialog`, `SelectFromList` → WPF custom)
- APIs que mudaram entre versões (Floor.Create, etc.)
- Ícones (16x16 + 32x32 redimensionados de 96x96)
- Criação do Ribbon via código
- Hooks → Event Handlers
- Classe base para licenciamento
- Distribuição

Armadilhas C# específicas:
- #23 (AddStackedItems mínimo 2)
- #24 (OverrideGraphicSettings.SurfaceTransparency sem getter)
- #25 (multi-targeting com RevitAPI.dll de versões diferentes)
- #26 (Application em Autodesk.Revit.ApplicationServices)
- #27 (ambiguidade Grid WPF × Revit)
- #28 (Revit trava a DLL)

### Passo 1. Identificar o pushbutton fonte

Detecte o `.pushbutton/` a migrar. Aceita:
- `/migrar-csharp` em CWD que termina em `.pushbutton`
- Caminho explícito no prompt
- Lista de pushbuttons da extension se múltiplos

### Passo 2. Coletar configurações do projeto C#

Pergunte UMA vez (depois 2 follow-ups condicionais):

> "Configuração do projeto C#:
> - Nome do projeto (ex: 'BIMCoderTools.Cmd.CotarParedes')
> - Versões do Revit alvo (ex: '2024, 2025, 2026' ou só uma)"

Extraia:
- **Namespace base** (PascalCase, ex: `BIMCoderTools.Commands`)
- **Versões alvo** → mapeia pra Target Frameworks:
  - 2021-2024 → `net48`
  - 2025+ → `net8.0-windows`

Follow-up se houver formulário WPF no script Python:

> "O script Python tem formulário customizado (WPF). Quer:
> 1. Migrar o XAML também (gerar .xaml + .xaml.cs no projeto C#)
> 2. Trocar por TaskDialog padrão (mais simples, menos customização)
> 3. Cancelar a migração"

Follow-up se houver `LoadFamily`, eventos ou hooks:

> "O script usa hooks/eventos. Confirma que deve migrar pra IExternalApplication + event handlers em C#?
> 1. Sim
> 2. Não, deixa só o IExternalCommand básico"

### Passo 3. Estrutura do projeto C# alvo

Decidir onde criar:

1. **Projeto C# já existe** (o aluno indica caminho): adicionar nova classe ao projeto
2. **Projeto não existe**: criar estrutura mínima do zero

Estrutura mínima:

```
{NomeProjeto}/
├── {NomeProjeto}.sln
├── {NomeProjeto}/
│   ├── {NomeProjeto}.csproj         (multi-target)
│   ├── App.cs                       (IExternalApplication com Ribbon)
│   ├── Commands/
│   │   └── {NomeComando}.cs         (a classe migrada)
│   ├── Resources/
│   │   ├── icon-16.png
│   │   └── icon-32.png
│   ├── Views/                       (se tem WPF)
│   └── {NomeProjeto}.addin          (manifesto)
└── global.json                       (pinning do SDK)
```

### Passo 4. Traduzir o script.py → C#

Leia o `script.py` original e traduza linha por linha aplicando as equivalências:

| pyRevit | C# |
|---|---|
| `__revit__` | `commandData.Application` |
| `doc = revit.doc` | `Document doc = uidoc.Document;` |
| `Transaction(doc, "X")` | `new Transaction(doc, "X")` em bloco `using` |
| `FilteredElementCollector(doc).OfClass(Wall)` | `new FilteredElementCollector(doc).OfClass(typeof(Wall))` |
| `forms.alert("msg")` | `TaskDialog.Show("Titulo", "msg")` |
| `param.AsDouble()` | `param.AsDouble()` (mesmo) |
| `List[ElementId]([id])` | `new List<ElementId> { id }` |

Template do arquivo `{NomeComando}.cs`:

```csharp
using System;
using System.Collections.Generic;
using System.Linq;
using Autodesk.Revit.Attributes;
using Autodesk.Revit.DB;
using Autodesk.Revit.UI;
using Autodesk.Revit.ApplicationServices;

namespace {NomeProjeto}.Commands
{
    [Transaction(TransactionMode.Manual)]
    public class {NomeComando} : IExternalCommand
    {
        public Result Execute(
            ExternalCommandData commandData,
            ref string message,
            ElementSet elements)
        {
            UIApplication uiApp = commandData.Application;
            UIDocument uidoc = uiApp.ActiveUIDocument;
            Document doc = uidoc.Document;

            try
            {
                // Logica migrada do Python aqui
                {logica-migrada}

                return Result.Succeeded;
            }
            catch (Exception ex)
            {
                TaskDialog.Show("Erro", ex.Message);
                return Result.Failed;
            }
        }
    }
}
```

Aplique os 8 ajustes principais:
1. Imports `using` em vez de Python imports
2. Tipagem explícita (`string`, `Document`, `List<X>`)
3. `Transaction` em bloco `using` em vez de `try/except`
4. `Cast<Material>()` antes de `.ToList()` se quiser tipo específico
5. `forms.alert` → `TaskDialog.Show`
6. Mudar `doc.Create.NewFloor` → `Floor.Create` se mira Revit 2025+
7. Resolver ambiguidades de namespace (Grid, Application, Room)
8. `ISelectionFilter` como classe interna (não closure)

### Passo 5. Gerar arquivos de suporte do projeto

Se o projeto não existir, gerar também:

1. **`{NomeProjeto}.csproj`** com multi-targeting:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFrameworks>{net48 ou net8.0-windows ou ambos}</TargetFrameworks>
    <LangVersion>latest</LangVersion>
    <UseWPF>{true se tem form WPF}</UseWPF>
  </PropertyGroup>
  <ItemGroup>
    <!-- Referencias condicionais conforme versao -->
  </ItemGroup>
</Project>
```

2. **`App.cs`** com IExternalApplication + criação de ribbon:

```csharp
public class App : IExternalApplication
{
    public Result OnStartup(UIControlledApplication app)
    {
        app.CreateRibbonTab("{NomeTab}");
        RibbonPanel panel = app.CreateRibbonPanel("{NomeTab}", "{NomePanel}");
        string asm = System.Reflection.Assembly.GetExecutingAssembly().Location;

        PushButtonData btnData = new PushButtonData(
            "cmd{NomeComando}",
            "{Titulo}",
            asm,
            "{NomeProjeto}.Commands.{NomeComando}"
        );
        panel.AddItem(btnData);

        return Result.Succeeded;
    }

    public Result OnShutdown(UIControlledApplication app) => Result.Succeeded;
}
```

3. **`{NomeProjeto}.addin`**:

```xml
<?xml version="1.0" encoding="utf-8"?>
<RevitAddIns>
  <AddIn Type="Application">
    <Name>{NomeProjeto}</Name>
    <Assembly>{caminho}\{NomeProjeto}.dll</Assembly>
    <FullClassName>{NomeProjeto}.App</FullClassName>
    <AddInId>{GUID-gerado}</AddInId>
    <VendorId>{VendorId}</VendorId>
  </AddIn>
</RevitAddIns>
```

4. **`global.json`** (pinning SDK pra evitar MSB4242):

```json
{
    "sdk": {
        "version": "8.0.416",
        "rollForward": "latestPatch"
    }
}
```

### Passo 6. Migrar WPF se aplicável

Se o Python tinha `form.xaml`:

1. Copiar `form.xaml` pra `Views/{NomeForm}.xaml`
2. Adicionar `x:Class="{NomeProjeto}.Views.{NomeForm}"` no `<Window>`
3. Gerar `Views/{NomeForm}.xaml.cs` com `partial class` e `InitializeComponent()`
4. Migrar handlers Python pra eventos C#

### Passo 7. Confirmar entrega

```
Migração para C# concluída: {NomeComando}

Estrutura criada:
  {NomeProjeto}/
  ├── {NomeProjeto}.sln
  ├── {NomeProjeto}/
  │   ├── {NomeProjeto}.csproj      ({frameworks})
  │   ├── App.cs                    (Ribbon)
  │   ├── Commands/{NomeComando}.cs ({linhas-cs} linhas)
  │   ├── {NomeProjeto}.addin       (manifesto)
  │   {└── Views/{Form}.xaml + .xaml.cs}
  └── global.json

Pra compilar e testar:
  cd {NomeProjeto}
  dotnet build {NomeProjeto}/{NomeProjeto}.csproj -c Release

  DLL gerada em: bin/Release/{framework}/{NomeProjeto}.dll
  .addin esperado em: %AppData%\Autodesk\Revit\Addins\{ano}\

Atencao: o Revit trava a DLL enquanto carregada. Feche o Revit antes
de recompilar (armadilha 28).
```

### Passo 8. Próximo passo

```
Proximos passos sugeridos:
1. Compile e teste no Revit antes de migrar outros comandos
2. Pra distribuir como instalador profissional, use o template de
   instalador C# (diferente do Inno Setup pyRevit): veja
   references/csharp-migration-guide.md secao 'Instalador standalone'
3. Pra migrar outros pushbuttons da mesma extension, rode
   /migrar-csharp em cada um. Vou adicionar como novo comando ao
   mesmo projeto.
```

---

## O que NÃO fazer

- **Não migrar antes de validar.** Pushbutton Python ainda em iteração ativa: migrar é trabalho perdido.
- **Não esquecer `<Private>false</Private>`** nas referências de `RevitAPI.dll`. Senão dá conflito.
- **Não esquecer de mudar `doc.Create.NewFloor` → `Floor.Create`** se mira Revit 2025+.
- **Não ignorar ambiguidade de `Grid`** se o arquivo usa `Autodesk.Revit.DB` e `System.Windows.Controls` juntos. Use alias.
- **Não esquecer `using Autodesk.Revit.ApplicationServices`** se usa `Application`.
- **Não criar `.addin` com `AppInId` duplicado** se for adicionar a um projeto existente. Use o mesmo `AppInId` do projeto.
- **Não esquecer de testar com Revit fechado.** A DLL fica travada se o Revit está aberto.
