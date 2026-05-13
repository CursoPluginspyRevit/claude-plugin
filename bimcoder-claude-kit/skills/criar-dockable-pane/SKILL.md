---
name: criar-dockable-pane
description: Cria um dockable pane (painel ancorado nativo do Revit como Properties/Project Browser). Gera startup.py raiz da extension, lib/DockablePane/meu_pane.py com Provider + Control + singleton, lib/DockablePane/meu_pane.xaml com Background obrigatório, e um pushbutton trigger pra mostrar o pane. Aplica todas as armadilhas conhecidas do padrão (imports WPF fora do nível de módulo, GUID fixo, ViewActivated pra não abrir sozinho).
---

# Criar Dockable Pane. Painel Ancorado Nativo

Você é especialista em criar dockable panes pyRevit. Esta skill aplica o padrão completo documentado em `references/dockable-pane-pattern.md` e evita as 7+ armadilhas conhecidas do padrão.

## Quando esta skill é acionada

- O aluno digita `/criar-dockable-pane`
- O aluno precisa de um painel que fica aberto enquanto trabalha no Revit
- O aluno quer reagir à seleção em tempo real (ex: mostrar info da seleção atual)

## NÃO use esta skill quando

- O aluno quer só uma janela modal. Use `/criar-form-wpf`
- O aluno quer um pushbutton simples. Use `/criar-pushbutton`
- A extension não tem `startup.py` ainda E o aluno não está disposto a reiniciar o Revit após criação (registro só funciona no startup)

---

## Fluxo obrigatório

### Passo 0. Carregar contexto

Confirme que o `CLAUDE.md` está carregado. **Leia obrigatoriamente** `references/dockable-pane-pattern.md` antes de gerar qualquer código (esse arquivo tem 391 linhas de padrões + armadilhas específicas).

Armadilhas relevantes do `references/armadilhas.md`:
- #4 (imports WPF no startup)
- #5 (No module named Threading)
- #16 (pane abre sozinho)
- #17 (fundo preto)
- #18 (cascata de SelectionChanged)
- #19 (BitmapImage sem Freeze)

### Passo 1. Identificar a extension destino

O dockable pane precisa de:
- `startup.py` na raiz da `.extension/`
- `lib/DockablePane/` com módulo e XAML

Detecte:
1. **CWD em `.extension/`** → criar lá
2. **Caminho explícito** no prompt
3. **Pasta sem `.extension`** → sugerir `/criar-extension` antes

Verifique se já existe `startup.py`:
- Se sim: adicionar a chamada do pane à `init()` existente (não sobrescrever)
- Se não: criar do zero

### Passo 2. Coletar nome do pane e GUID

Pergunte UMA vez:

> "Qual o nome do dockable pane (interno) e o título exibido?
>
> Exemplo: 'soma_parametros (interno) com título 'Soma de Parâmetros'."

Extraia:
- **Nome do módulo** (snake_case). Ex: `soma_parametros`
- **Título exibido** (com acentos). Ex: `"Soma de Parâmetros"`

Gere o GUID automaticamente (use `str(uuid.uuid4())`) e avise o aluno:

> "GUID gerado: `{guid}`. Esse GUID precisa ser FIXO e nunca mudar depois do primeiro uso. Se mudar, o Revit não associa o layout salvo do usuário ao pane."

### Passo 3. Criar a estrutura

Operações:

1. **Criar `startup.py`** na raiz da extension (se não existir):

```python
# -*- coding: utf-8 -*-
"""Startup da extension. Registra dockable panes e outros recursos
que precisam ser inicializados durante OnStartup do Revit."""

import sys, os

# lib/ pode nao estar no sys.path durante o startup. Adicionar manualmente.
_lib = os.path.join(os.path.dirname(__file__), "lib")
if _lib not in sys.path:
    sys.path.insert(0, _lib)

try:
    from DockablePane import {nome_do_modulo} as _pane
    from pyrevit import HOST_APP
    _pane.init(HOST_APP.uiapp)
except Exception:
    import traceback
    print("[startup] Erro ao registrar pane: {}".format(traceback.format_exc()))
```

Se `startup.py` já existe, ADICIONAR a chamada ao bloco try existente (Edit Cirúrgica).

2. **Criar pasta** `lib/DockablePane/` se não existir, com `__init__.py` vazio.

3. **Criar `lib/DockablePane/{nome_do_modulo}.py`** com Provider + Control + singleton (template completo segue o padrão em `references/dockable-pane-pattern.md`):

```python
# -*- coding: utf-8 -*-
"""Dockable pane: {Titulo Exibido}."""

import clr, os
clr.AddReference("RevitAPI")
clr.AddReference("RevitAPIUI")
clr.AddReference("System")

from System import Guid
from Autodesk.Revit.UI import IDockablePaneProvider, DockablePaneId

# GUID fixo. NUNCA mudar depois do primeiro uso em producao.
PANE_GUID = Guid("{guid-gerado}")
PANE_ID = DockablePaneId(PANE_GUID)

PATH_XAML = os.path.join(os.path.dirname(__file__), "{nome_do_modulo}.xaml")


class {NomeProvider}(IDockablePaneProvider):
    def __init__(self, control):
        self._control = control

    def SetupDockablePane(self, data):
        data.FrameworkElement = self._control.element


class {NomeControl}(object):
    def __init__(self):
        # IMPORTS WPF AQUI, NAO no nivel de modulo (armadilha 4)
        clr.AddReference("WindowsBase")
        clr.AddReference("PresentationCore")
        clr.AddReference("PresentationFramework")

        from System.Windows.Markup import XamlReader
        import System.IO as _IO

        with _IO.File.OpenRead(PATH_XAML) as stream:
            self.element = XamlReader.Load(stream)

        # Referencias aos elementos com x:Name no XAML
        # (preencher conforme o XAML)
        # self._label = self.element.FindName("UIe_label")

    def initialize(self, doc, uidoc):
        """Chamado pelo pushbutton. Atualiza contexto do documento ativo."""
        self._doc = doc
        self._uidoc = uidoc
        # repopular controles com dados do doc atual aqui


# Singleton compartilhado entre startup e pushbutton
_control = None


def get_control():
    return _control


def init(uiapp):
    """Chamado no startup.py. Registra o pane no Revit."""
    global _control
    _control = {NomeControl}()
    uiapp.RegisterDockablePane(PANE_ID, u"{Titulo Exibido}", {NomeProvider}(_control))

    # Esconder na primeira ativacao de view (armadilha 16)
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

4. **Criar `lib/DockablePane/{nome_do_modulo}.xaml`** com Background obrigatório (armadilha 17):

```xml
<StackPanel
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Background="White"
    Margin="12">

    <TextBlock x:Name="UIe_titulo" Text="{Titulo Exibido}" FontSize="18" FontWeight="Bold" Margin="0,0,0,8"/>
    <TextBlock x:Name="UIe_corpo" Text="Conteudo do pane aqui." TextWrapping="Wrap"/>

</StackPanel>
```

5. **Criar pushbutton trigger** (opcional, perguntar ao aluno):

> "Quer criar um pushbutton pra abrir/focar este pane?
> 1. Sim, em qual panel?
> 2. Não, vou criar manualmente"

Se sim, chamar `/criar-pushbutton` com script já preenchido:

```python
# -*- coding: utf-8 -*-
__title__ = "Mostrar\n{Titulo Curto}"

from DockablePane import {nome_do_modulo} as _pane
from Autodesk.Revit.UI import TaskDialog
from pyrevit import revit


doc = revit.doc
uidoc = revit.uidoc


def main():
    control = _pane.get_control()
    if control is None:
        TaskDialog.Show("Aviso", "Reinicie o Revit pra ativar o painel.")
        return

    control.initialize(doc, uidoc)
    pane = __revit__.GetDockablePane(_pane.PANE_ID)
    pane.Show()


main()
```

### Passo 4. Confirmar entrega

```
Dockable pane criado: {nome_do_modulo}

GUID:         {guid} (fixo, nao mude)
Arquivos:
  - startup.py                                          (registra no OnStartup)
  - lib/DockablePane/__init__.py                        (vazio)
  - lib/DockablePane/{nome_do_modulo}.py                (Provider + Control)
  - lib/DockablePane/{nome_do_modulo}.xaml              (UI WPF)
  {- pushbutton em {panel}/Mostrar{Titulo}.pushbutton/} (trigger pra abrir)

IMPORTANTE:
- Reinicie o Revit (necessario pra startup.py registrar o pane)
- Apos reiniciar, o pane fica disponivel via menu View > Painéis Ancoráveis
  ou pelo pushbutton se foi criado
```

### Passo 5. Próximo passo

```
Pra customizar o conteudo do pane, edite:
  lib/DockablePane/{nome_do_modulo}.xaml  (visual, XAML WPF)
  lib/DockablePane/{nome_do_modulo}.py    (comportamento, Python)

Pra adicionar reatividade a seleção em tempo real (DispatcherTimer),
consulte references/dockable-pane-pattern.md secao "Live update".
```

---

## O que NÃO fazer

- **Não importar WPF no nível de módulo** em `{nome_do_modulo}.py`. Quebra todos os scripts que usam forms (armadilha 4).
- **Não esquecer `Background` no XAML.** Fundo preto no Revit dark (armadilha 17).
- **Não mudar o GUID** depois de usado em produção. Quebra layouts salvos dos usuários.
- **Não criar pane sem `startup.py`.** RegisterDockablePane só funciona no OnStartup.
- **Não chamar `Hide()` direto no startup.** Layout do Revit restaura depois, use `ViewActivated` (armadilha 16).
- **Não usar `Children.Add()` dinâmico no XAML.** Pré-defina elementos no XAML com `Visibility="Collapsed"` e revele via Python.
