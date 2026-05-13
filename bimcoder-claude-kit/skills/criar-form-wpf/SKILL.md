---
name: criar-form-wpf
description: Cria um formulário WPF customizado pra um pushbutton pyRevit. Quando pyrevit.forms (alert, SelectFromList, ask_for_string) não basta, esta skill gera um XAML + handler Python com controles arbitrários (TextBox, ComboBox, ListBox, CheckBox, Button) e os eventos correspondentes. Aplica armadilhas conhecidas (filtro como self._x, flag _updating em ComboBox, BitmapImage.Freeze).
---

# Criar Form WPF. Formulário Customizado

Você é especialista em criar formulários WPF customizados pra scripts pyRevit. Esta skill gera um XAML + handler Python quando os formulários padrão de `pyrevit.forms` não atendem.

## Quando esta skill é acionada

- O aluno digita `/criar-form-wpf` (com descrição do form desejado)
- A skill `/planejar-plugin` identificou necessidade de UI customizada (Camada 4)
- O aluno tentou `pyrevit.forms` mas precisa de layout específico (múltiplos campos, lista + input juntos, etc.)

## NÃO use esta skill quando

- Um `forms.SelectFromList` ou `forms.ask_for_string` simples resolve. Use eles direto
- O form precisa ficar aberto enquanto o aluno trabalha no Revit. Use `/criar-dockable-pane`
- É um TaskDialog simples. Use `TaskDialog.Show` direto no script

---

## Fluxo obrigatório

### Passo 0. Carregar contexto

`references/dockable-pane-pattern.md` cobre padrões WPF + IronPython. Consulte se precisar lembrar de `XamlReader.Load()`, `FindName`, `DispatcherTimer`.

Armadilhas relevantes:
- #4 (imports WPF não no nível de módulo no startup. Em pushbutton normal, OK ter no topo)
- #6 (filtros e callbacks como `self._x`)
- #18 (cascata de SelectionChanged em ComboBox)
- #19 (BitmapImage.Freeze)
- #20 (paths com acento em IronPython)

### Passo 1. Identificar o pushbutton destino

O form é parte do `script.py` de um pushbutton. Detecte:

1. **CWD em `.pushbutton/`** → form deste pushbutton
2. **Caminho explícito** no prompt
3. **Múltiplos pushbuttons** → listar e perguntar
4. **Nenhum encontrado** → sugerir `/criar-pushbutton`

### Passo 2. Coletar especificação do form

Pergunte UMA vez (passo mais aberto, pode requerer iteração):

> "Descreva o form que você precisa. Liste os campos/controles.
>
> Exemplo: 'form com 3 inputs: ComboBox de tipo de cota, TextBox de offset em cm, CheckBox pra incluir paredes curvas. Botões Confirmar e Cancelar.'"

Extraia:
- **Título da janela**
- **Lista de campos** com tipo (TextBox, ComboBox, ListBox, CheckBox, NumericInput simulado) e label
- **Botões** (mínimo Confirmar e Cancelar, ou customizado)
- **Tamanho aproximado** (pequeno 300x200, médio 400x300, grande 500x400)

Se a descrição é vaga, pergunte UMA pergunta de refinamento:

> "Os campos têm valor padrão? E o ComboBox vai ser populado de onde (lista fixa, FilteredElementCollector, parâmetro)?"

### Passo 3. Gerar o XAML

Salve em `{pushbutton}/form.xaml` (convenção: arquivo separado do script).

Template:

```xml
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="{Titulo da Janela}"
    Height="{altura}" Width="{largura}"
    WindowStartupLocation="CenterScreen"
    ResizeMode="NoResize"
    Background="#F5F5F5">

    <StackPanel Margin="20">

        <!-- Campos gerados conforme especificacao -->
        <TextBlock Text="Tipo de cota:" FontWeight="SemiBold" Margin="0,0,0,4"/>
        <ComboBox x:Name="UIe_cb_tipo" Margin="0,0,0,12"/>

        <TextBlock Text="Offset (cm):" FontWeight="SemiBold" Margin="0,0,0,4"/>
        <TextBox x:Name="UIe_tb_offset" Text="30" Margin="0,0,0,12"/>

        <CheckBox x:Name="UIe_chk_curvas" Content="Incluir paredes curvas" Margin="0,0,0,16"/>

        <!-- Botoes -->
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="UIe_btn_confirmar" Content="Confirmar" Width="100" Height="30" Margin="0,0,8,0" Click="OnConfirmar"/>
            <Button x:Name="UIe_btn_cancelar" Content="Cancelar" Width="100" Height="30" Click="OnCancelar"/>
        </StackPanel>

    </StackPanel>
</Window>
```

Convenção: prefixar nomes WPF com `UIe_` para distinguir de variáveis Python.

### Passo 4. Gerar o handler Python

Decidir: handler INTEGRADO ao `script.py` (mais comum) ou separado em `form.py`. Padrão: integrado.

Adicione ao `script.py` existente (ou crie boilerplate se não existir):

```python
# -*- coding: utf-8 -*-
"""{Descricao do que o pushbutton faz incluindo o form}."""

__title__ = "..."
__doc__ = "..."

import os
from pyrevit import revit
from pyrevit.framework import wpf  # OK aqui (pushbutton, nao startup)

from System.Windows import Window


PATH_XAML = os.path.join(os.path.dirname(__file__), "form.xaml")


class MeuForm(Window):
    def __init__(self):
        wpf.LoadComponent(self, PATH_XAML)

        # Filtros e callbacks como self._x para nao serem coletados pelo GC
        # (armadilha 6, se for usar ISelectionFilter ou DispatcherTimer)

        # Populando o ComboBox
        self._updating = True
        try:
            self.UIe_cb_tipo.Items.Add("Tipo A")
            self.UIe_cb_tipo.Items.Add("Tipo B")
            self.UIe_cb_tipo.Items.Add("Tipo C")
            self.UIe_cb_tipo.SelectedIndex = 0
        finally:
            self._updating = False

        # Estado de saida
        self.confirmado = False
        self.tipo_selecionado = None
        self.offset_cm = None
        self.incluir_curvas = False

    def OnConfirmar(self, sender, e):
        # Coletar valores
        self.tipo_selecionado = self.UIe_cb_tipo.SelectedItem
        try:
            self.offset_cm = float(self.UIe_tb_offset.Text)
        except ValueError:
            from pyrevit import forms
            forms.alert("Offset invalido. Digite um numero.")
            return  # nao fecha
        self.incluir_curvas = self.UIe_chk_curvas.IsChecked
        self.confirmado = True
        self.Close()

    def OnCancelar(self, sender, e):
        self.confirmado = False
        self.Close()


def main():
    form = MeuForm()
    form.ShowDialog()  # modal. Bloqueia ate fechar

    if not form.confirmado:
        return  # usuario cancelou

    # Usar os valores
    tipo = form.tipo_selecionado
    offset = form.offset_cm
    incluir_curvas = form.incluir_curvas

    # ... lógica do pushbutton aqui usando os valores


if __name__ == "__main__":
    main()
```

### Passo 5. Auto-revisão dupla

Aplique as 9 regras + validação de API. Particularmente:
- Encoding UTF-8 (regra 2)
- Imports WPF em pushbutton são OK no topo. (Em startup seria proibido)
- Se há `ISelectionFilter` dentro de handler de botão, garantir `self._filter` (armadilha 6)
- Se popula ComboBox programaticamente, flag `_updating` (armadilha 18)

### Passo 6. Confirmar entrega

```
Form WPF criado: {pushbutton}

Arquivos:
  - form.xaml      (UI, {n} controles)
  - script.py      (handler integrado, {linhas} linhas)

Campos do form:
  - {Campo 1} ({tipo})
  - {Campo 2} ({tipo})
  ...

Pra testar: reinicie o Revit e clique no botao do pushbutton.
```

### Passo 7. Próximo passo

Pergunte (se o script foi só boilerplate com form):

> "Quer preencher a lógica do que acontece depois do form ser confirmado?
> 1. Sim, descreva o que fazer com os valores
> 2. Não, vou implementar depois"

Se 1, faça Edit Cirúrgica adicionando código dentro de `main()` após `if not form.confirmado: return`.

---

## O que NÃO fazer

- **Não importar WPF no nível de módulo se este script for executado pelo startup.** Em pushbutton normal, é OK.
- **Não esquecer flag `_updating`** quando popular ComboBox/ListBox programaticamente. Cascata de eventos quebra o form (armadilha 18).
- **Não armazenar `ISelectionFilter` como variável local** dentro de handler de botão. Use `self._filter` (armadilha 6).
- **Não esquecer de `Freeze()` em `BitmapImage`** se carregar ícone fora da UI thread (armadilha 19).
- **Não usar `import wpf` em `startup.py` ou módulos da `lib/` que rodam no startup.** Em scripts pushbutton é OK.
- **Não esquecer `Background` no `<Window>` se for usado dentro de DockablePane.** Pra form modal normal, herda do sistema.
