# Dockable Pane. Padrão Completo

Painel ancorado nativo do Revit (como o Properties e Project Browser). Pode ser arrastado, redimensionado, fechado e reaberto pelo menu View. Persiste durante toda a sessão do Revit.

Diferente de TaskDialog ou janela WPF flutuante, o dockable pane fica disponível enquanto o aluno trabalha no modelo. O conteúdo pode atualizar em tempo real conforme o usuário interage.

---

## A restrição fundamental. Registro obrigatório no startup

A Revit API exige que `RegisterDockablePane` seja chamado **durante o `OnStartup` do Revit**, ou seja, no momento da inicialização. Chamar isso de um pushbutton não funciona.

No pyRevit, isso se resolve com um arquivo `startup.py` na raiz da extension. O pyRevit executa esse arquivo como parte do seu próprio ciclo de inicialização, que acontece dentro do `OnStartup` do Revit.

**Consequência prática:** qualquer mudança no `startup.py` exige reiniciar o Revit. O startup só roda uma vez por sessão.

---

## Estrutura de arquivos recomendada

```
minha-extensao.extension/
├── startup.py                    ← registra o pane (obrigatório estar na raiz)
└── lib/
    └── DockablePane/
        ├── __init__.py           ← vazio
        ├── meu_pane.py           ← Provider + Control + singleton
        └── meu_pane.xaml         ← visual do painel (XAML)
```

O pushbutton que o usuário clica fica em outro lugar da extension e contém poucas linhas. Ele não registra nada, apenas mostra o painel que já foi registrado no startup.

---

## O `startup.py`

```python
# -*- coding: utf-8 -*-
import sys, os

# lib/ pode não estar no sys.path durante o startup. Adicionar manualmente.
_lib = os.path.join(os.path.dirname(__file__), "lib")
if _lib not in sys.path:
    sys.path.insert(0, _lib)

try:
    from DockablePane import meu_pane as _pane
    from pyrevit import HOST_APP
    _pane.init(HOST_APP.uiapp)
except Exception:
    import traceback
    print("[startup] Erro ao registrar pane: {}".format(traceback.format_exc()))
```

Dois pontos importantes:
- **`lib/` precisa ser adicionado manualmente** ao `sys.path`. Durante o startup do pyRevit, o caminho da lib da extension pode ainda não estar configurado.
- **Usar `HOST_APP.uiapp`** em vez de `__revit__`. A variável `__revit__` é injetada em pushbuttons, não no startup.

---

## A armadilha dos imports WPF

Esta é a parte mais crítica do padrão. Se você colocar qualquer import WPF no **nível do módulo**, vai corromper o cache de módulos do IronPython durante o startup.

```python
# NUNCA fazer no nível de módulo em código que roda no startup
from System.Windows.Threading import DispatcherTimer
from pyrevit.framework import wpf
```

O pyRevit usa internamente um módulo chamado `_wpf`. Se qualquer código tentar importá-lo antes que o pyRevit esteja pronto, ele fica em estado quebrado no cache do IronPython. Resultado: todos os pushbuttons que usam formulários WPF passam a falhar com `No module named _wpf`.

A regra é simples: **no nível do módulo, importe apenas Revit API e System básico. Todo WPF vai dentro de métodos.**

```python
# Nível de módulo. Seguro
import clr, os
clr.AddReference("RevitAPI")
clr.AddReference("RevitAPIUI")
clr.AddReference("System")

from System import Guid, TimeSpan
from Autodesk.Revit.DB import Transaction, FilteredElementCollector
from Autodesk.Revit.UI import IDockablePaneProvider, DockablePaneId

# WPF. Apenas dentro de __init__ ou métodos
class MeuControl(object):
    def __init__(self):
        clr.AddReference("WindowsBase")         # obrigatório para DispatcherTimer
        clr.AddReference("PresentationCore")
        clr.AddReference("PresentationFramework")
        from System.Windows.Markup import XamlReader
        ...
```

Note que `WindowsBase` precisa ser referenciada explicitamente. Sem ela, `System.Windows.Threading` não é encontrado.

---

## O GUID

Cada pane tem um GUID único. Deve ser **fixo e nunca mudar** depois de usado em produção. Se mudar, o Revit não associa o pane salvo pelo usuário ao novo registro.

```python
import uuid
# gerar uma vez: str(uuid.uuid4())
# colar o resultado fixo abaixo:
PANE_GUID = Guid("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx")
PANE_ID   = DockablePaneId(PANE_GUID)
```

---

## O Provider

O Revit chama `SetupDockablePane` durante a inicialização para saber o que colocar dentro do painel.

```python
class MeuProvider(IDockablePaneProvider):
    def __init__(self, control):
        self._control = control

    def SetupDockablePane(self, data):
        data.FrameworkElement = self._control.element  # qualquer FrameworkElement WPF
```

---

## O Control (conteúdo visual)

O conteúdo do pane é qualquer `FrameworkElement`. Não precisa ser `UserControl` ou `Window`.

A forma mais confiável em IronPython é carregar o XAML com `XamlReader.Load()` e acessar os elementos pelo nome via `FindName()`.

```python
class MeuControl(object):
    def __init__(self):
        clr.AddReference("WindowsBase")
        clr.AddReference("PresentationCore")
        clr.AddReference("PresentationFramework")

        from System.Windows.Markup import XamlReader
        import System.IO as _IO

        with _IO.File.OpenRead(PATH_XAML) as stream:
            self.element = XamlReader.Load(stream)

        # Referências aos elementos com x:Name no XAML
        self._meu_label = self.element.FindName("UIe_meu_label")
        self._meu_combo = self.element.FindName("UIe_meu_combo")
```

Convenção: prefixar nomes WPF com `UIe_` no XAML torna fácil distinguir o que é elemento de UI vs variável Python.

---

## Singleton para compartilhar entre startup e pushbutton

O startup cria o controle. O pushbutton precisa acessá-lo depois. Uma variável de módulo resolve isso, já que o Python cacheia módulos em `sys.modules`. Os dois acessam o mesmo objeto.

```python
# lib/DockablePane/meu_pane.py
_control = None

def get_control():
    return _control

def init(uiapp):
    global _control
    _control = MeuControl()
    uiapp.RegisterDockablePane(PANE_ID, u"Título do Painel", MeuProvider(_control))
```

---

## O XAML

O root pode ser qualquer `FrameworkElement`. **Sempre definir `Background`**. Sem ele, o painel fica transparente sobre o fundo escuro do Revit.

```xml
<StackPanel
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Background="White"
    Margin="12">

    <TextBlock x:Name="UIe_meu_label" Text="—" FontSize="22" FontWeight="Bold"/>
    <ComboBox  x:Name="UIe_meu_combo"/>

</StackPanel>
```

**Sobre elementos dinâmicos:** criar elementos via `Children.Add()` em IronPython é instável. Os elementos podem ser adicionados sem aparecer na tela.

O padrão mais confiável é pré-definir todos os elementos no XAML com `Visibility="Collapsed"` e revelá-los via Python conforme necessário.

```python
from System.Windows import Visibility
elemento = self.element.FindName("UIe_cb_0")
elemento.Content    = "Meu item"
elemento.Visibility = Visibility.Visible
```

---

## O pushbutton

```python
# -*- coding: utf-8 -*-
from DockablePane import meu_pane as _pane
from Autodesk.Revit.UI import TaskDialog

def main():
    control = _pane.get_control()
    if control is None:
        TaskDialog.Show("Aviso", "Reinicie o Revit para ativar o painel.")
        return

    control.initialize(doc, uidoc)  # passa contexto do documento atual
    pane = __revit__.GetDockablePane(_pane.PANE_ID)
    pane.Show()

main()
```

O método `initialize` é chamado a cada clique para atualizar o contexto (`doc`, `uidoc`) e repopular os controles com os dados do documento ativo.

---

## Live update com `DispatcherTimer`

Para o painel reagir à seleção do usuário em tempo real, usar `DispatcherTimer`. Roda no thread da UI, sem travar a interface.

```python
def _restart_timer(self):
    from System.Windows.Threading import DispatcherTimer  # import local
    from System import TimeSpan
    if self._timer:
        self._timer.Stop()
    self._timer = DispatcherTimer()
    self._timer.Interval = TimeSpan.FromMilliseconds(300)
    self._timer.Tick += self._on_tick
    self._timer.Start()

def _on_tick(self, sender, e):
    ids = set(self._uidoc.Selection.GetElementIds())
    if ids == self._last_ids:
        return   # nada mudou. Evita recalcular
    self._last_ids = ids
    self._update(ids)
```

---

## Cascata de eventos em ComboBox/ListBox

Ao popular um ComboBox programaticamente, `SelectionChanged` dispara para cada item. Isso pode causar cascata se o handler tentar popular outro controle.

Solução: flag `_updating`.

```python
self._updating = True
try:
    self._combo.Items.Clear()
    for item in items:
        self._combo.Items.Add(item)
    self._combo.SelectedIndex = 0
finally:
    self._updating = False

# Disparar manualmente após popular
self._on_selection_changed(None, None)

# No handler
def _on_selection_changed(self, sender, e):
    if self._updating:
        return
    # lógica normal
```

---

## `ExternalEvent` para chamar API do Revit a partir de handler WPF

Handlers de eventos WPF (cliques, seleção) rodam fora do contexto da API do Revit. Tentar abrir uma transação nesses handlers causa erro. A solução é `ExternalEvent`.

```python
from Autodesk.Revit.UI import IExternalEventHandler, ExternalEvent

class MeuHandler(IExternalEventHandler):
    def __init__(self):
        self.dados = None
        self.result = None
        self.done = False

    def Execute(self, uiapp):
        doc = uiapp.ActiveUIDocument.Document
        with Transaction(doc, "Minha operação") as t:
            t.Start()
            # usar self.dados aqui
            t.Commit()
        self.result = "ok"
        self.done = True

    def GetName(self):
        return "MeuHandler"

# No __init__ do controle
self._handler = MeuHandler()
self._event   = ExternalEvent.Create(self._handler)

# No click handler (thread WPF)
def _on_click(self, sender, e):
    self._handler.dados = "valor"
    self._handler.done = False
    self._event.Raise()
    # Raise() é assíncrono. Usar DispatcherTimer para ler self._handler.result depois
```

**`Raise()` é assíncrono.** O `Execute` roda no próximo ciclo disponível do Revit. Para capturar o resultado na UI, usar um `DispatcherTimer` curto (300 a 500 ms) que lê `handler.done` e atualiza o status.

---

## Pane que abre sozinho ao iniciar o Revit

O Revit salva o layout dos dockable panes entre sessões. Se o painel estava visível quando o Revit foi fechado, ele reabre na próxima sessão, **mesmo que `Hide()` seja chamado no `startup.py`**, porque o layout é restaurado *depois* do startup.

Solução: assinar `ViewActivated` no `init()` e esconder o pane na primeira ativação de vista, que ocorre depois do layout ser restaurado. Desinscrever imediatamente para não repetir.

```python
def init(uiapp):
    global _control
    _control = MeuControl()
    uiapp.RegisterDockablePane(PANE_ID, u"Meu Painel", MeuProvider(_control))

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

Da segunda sessão em diante o Revit salva o pane como oculto e não reabre mais.

---

## Resumo do fluxo de execução

```
Revit inicia
  → pyRevit executa startup.py
    → lib/ adicionado ao sys.path
    → módulo do pane importado (sem WPF no nível de módulo)
    → MeuControl() instanciado (WPF carregado aqui, com segurança)
    → RegisterDockablePane() registra o painel na UI do Revit
    → instância guardada no singleton (_control)

Usuário clica no pushbutton
  → módulo importado novamente (recebe a mesma instância do cache)
  → control.initialize(doc, uidoc) → popula os controles do painel
  → pane.Show() → painel aparece (ou fica em foco se já aberto)

Usuário interage com o modelo
  → DispatcherTimer dispara a cada 300ms
  → compara seleção atual com a anterior
  → se mudou, atualiza o conteúdo do painel
```

---

## Armadilhas comuns. Tabela de referência

| Sintoma | Causa | Solução |
|---|---|---|
| `No module named Threading` | Assembly `WindowsBase` não referenciada | `clr.AddReference("WindowsBase")` antes do import |
| `No module named _wpf` | Import WPF no nível de módulo durante startup | Mover todos os imports WPF para dentro de `__init__` ou métodos. Usar `XamlReader.Load()` |
| Fundo preto no painel | `FrameworkElement` sem `Background` | `Background="White"` no elemento raiz do XAML |
| Elementos dinâmicos não aparecem | `Children.Add()` instável em IronPython | Pré-definir no XAML com `Visibility="Collapsed"`, revelar via Python |
| `AttributeError: no attribute 'X'` no pushbutton | startup rodou com versão antiga do código | Reiniciar o Revit. Adicionar alias de compatibilidade temporário |
| Painel não registra | `RegisterDockablePane` chamado fora do startup | Mover para `startup.py` |
| Painel abre sozinho ao iniciar o Revit | Layout salvo restaura depois do startup | Usar `ViewActivated` para esconder após restauração |
| Filtro de seleção não filtra | `ISelectionFilter` como variável local. GC coleta | Guardar como `self._sel_filter` |
| Cascata de `SelectionChanged` ao popular ComboBox | `Items.Add` dispara o evento | Flag `_updating` que o handler verifica |
| `BitmapImage` quebra entre threads | Falta `Freeze()` | `bmp.Freeze()` após `EndInit()` |
| Path com acento falha no IronPython | String não-unicode | Prefixar com `u"..."` |
