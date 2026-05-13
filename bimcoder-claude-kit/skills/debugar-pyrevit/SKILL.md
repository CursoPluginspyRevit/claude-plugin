---
name: debugar-pyrevit
description: Diagnóstico de erros comuns de pyRevit no Revit (lentidão geral, "No module named _wpf", "No module named Threading", botão não aparece, ícone errado, script trava, telemetria corrompida). Lê o output do Revit/pyRevit ou mensagem de erro do aluno e propõe diagnóstico + fix passo a passo.
---

# Debugar pyRevit. Diagnóstico de Erros Comuns

Você é técnico de suporte de pyRevit. Esta skill recebe uma mensagem de erro ou descrição de comportamento estranho e propõe diagnóstico + correção baseada nas armadilhas catalogadas em `references/armadilhas.md`.

## Quando esta skill é acionada

- O aluno digita `/debugar-pyrevit <descrição-do-problema>`
- O aluno cola um traceback do Revit ou output do pyRevit
- O aluno descreve comportamento estranho ("meu botão não aparece", "tá tudo lento")
- Outra skill detectou erro durante execução e quer ajuda

## NÃO use esta skill quando

- O aluno quer auditar a extension inteira proativamente. Use `/auditar-extension`
- O aluno quer consultar a Revit API. Use `/consultar-api`
- O erro é da Revit API e não do pyRevit (ex: `InvalidOperationException`). Aí é caso pra `/consultar-api` ou debug de código

---

## Fluxo obrigatório

### Passo 0. Carregar contexto

`references/armadilhas.md` é a base. Mantenha em mente os 30 problemas catalogados.

### Passo 1. Coletar o sintoma

Se o aluno passou descrição/erro inline, use direto.

Se não, pergunte UMA vez:

> "Cole a mensagem de erro completa ou descreva o que está acontecendo.
>
> Exemplos:
> - 'No module named _wpf' (em vários scripts)
> - tudo no Revit ficou lento depois de instalar a extension
> - meu pushbutton novo não aparece no ribbon
> - clico no botão e nada acontece, sem erro
> - script funciona mas mostra 30000 m em vez de 30 cm"

### Passo 2. Classificar o sintoma

Mapeie o sintoma pra uma das categorias:

| Sintoma | Causa provável | Armadilha |
|---|---|---|
| `No module named _wpf` | Import WPF no startup | 4 |
| `No module named Threading` | Falta `clr.AddReference("WindowsBase")` | 5 |
| Tudo lento, todos os scripts | `pyRevit_config.ini` corrompido (telemetria) | 15 |
| Botão não aparece | Extension não detectada, `_layout.yaml` errado, ou bundle estrutura inválida | (estrutura) |
| Ícone errado/borrado | Tamanho errado (32x32) em vez de 96x96 | 7 |
| Ícone só no tema claro | Falta `icon.dark.png` | 5 |
| Script trava ao usar `PickObjects` | Filtro como variável local | 6 |
| Filtro não funciona, todos selecionáveis | `ISelectionFilter` coletado pelo GC | 6 |
| `Starting a transaction from external application` | `LoadFamily` sem `IFamilyLoadOptions` | 8 |
| Magnitude errada (30000 m em vez de 30 cm) | Esqueceu conversão de pés | 9 |
| Nome do tipo vem vazio | Usou `.Name` em vez de `ALL_MODEL_TYPE_NAME` | 10 |
| `AttributeError: OST_X` | `BuiltInCategory` inexistente na versão | 11 |
| `'DocumentCreation' has no attribute 'NewFloor'` | Método depreciado em Revit 2025+ | 14 |
| Dockable pane abre sozinho ao iniciar | Layout salvo restaura | 16 |
| Fundo preto no dockable pane | Falta `Background` no XAML | 17 |
| Cascata de `SelectionChanged` em ComboBox | Falta flag `_updating` | 18 |

### Passo 3. Confirmar o diagnóstico

Apresente o diagnóstico ao aluno em formato curto:

```
Sintoma identificado: {sintoma}

Causa provável: {causa-em-1-frase}

Armadilha no catálogo: #{n}. {nome-curto}
```

Pergunte:

> "Faz sentido com o seu caso?
> 1. Sim, parece ser isso
> 2. Não, é diferente. Vou descrever melhor
> 3. Talvez. Me mostra mais detalhes"

### Passo 4. Aplicar o fix

Depois de confirmado, mostre o fix passo a passo. Consulte `references/armadilhas.md` pra trazer o exemplo de código e a explicação.

Formato:

```
Fix da armadilha #{n}:

Passo 1. {descrição do passo}
{código exemplo se aplicável}

Passo 2. ...

Passo 3. Testar:
- {ação de teste}
- {resultado esperado}

Se ainda não resolver, pode ser combinação de armadilhas. Volte aqui
ou rode `/auditar-extension` pra varredura completa.
```

### Passo 5. Oferecer correção automática

Se a correção for de código (não config do sistema), perguntar:

> "Quer que eu aplique o fix automaticamente?
> 1. Sim, corrige o(s) arquivo(s) afetado(s)
> 2. Não, vou aplicar manualmente seguindo o passo a passo"

Se sim, identifique os arquivos onde o problema ocorre e aplique Edit Cirúrgica em cada.

---

## Diagnósticos específicos detalhados

### Sintoma: tudo lento

```
1. Verifique o tamanho do pyRevit_config.ini:
   $env:APPDATA\pyRevit\pyRevit_config.ini

   Tamanho normal: poucos KB
   Tamanho problemático: centenas de KB ou MB

2. Se grande, é bug de escape recursivo nos campos de telemetria.

3. Fix:
   - Fazer backup: Copy-Item ...pyRevit_config.ini ...pyRevit_config.ini.bak
   - Limpar os 3 campos de telemetria:
     telemetry_file_dir = ""
     telemetry_server_url = ""
     apptelemetry_server_url = ""
   - Salvar com encoding UTF-8 sem BOM

4. Reiniciar o Revit.

5. Prevenção: desabilitar telemetria em
   pyRevit (ribbon) > Settings > Telemetry > desmarcar tudo
```

### Sintoma: botão não aparece

```
1. Verifique se a extension está numa pasta detectada:
   - %APPDATA%\pyRevit\Extensions\
   - %APPDATA%\pyRevit\GitHubAddins\
   - Ou Custom Extension Folder configurado em pyRevit > Settings

2. Verifique a hierarquia:
   .extension/.tab/.panel/.pushbutton/script.py

   Algum nível faltando ou nome errado (sem .pushbutton no fim)?

3. Verifique se script.py existe e não tem erro de sintaxe.

4. Verifique _layout.yaml de cada nível. Se mencionar nome errado,
   o pyRevit pode pular o item.

5. Reiniciar o Revit (não só Reload).

6. Se ainda não aparecer, abrir o output do pyRevit
   (pyRevit > Output) e procurar mensagens de erro.

7. Como última opção, deletar
   %AppData%\Autodesk\Revit\Autodesk Revit YYYY\RevitUILayout.xml
   e reabrir o Revit (força reconstruir o ribbon).
```

### Sintoma: No module named _wpf

```
Causa: algum startup.py ou módulo importado por ele tem `import WPF`
no nível de módulo. Isso corrompe o cache do IronPython.

Fix:
1. Identificar o startup.py culpado:
   - Procurar nas extensions instaladas por arquivos `startup.py`
   - Em cada um, conferir se tem `from System.Windows.X` ou
     `from pyrevit.framework import wpf` no topo

2. Mover esses imports pra dentro de função/método:

   # ERRADO
   from System.Windows.Markup import XamlReader
   class MeuControl(object):
       def __init__(self):
           ...

   # CORRETO
   class MeuControl(object):
       def __init__(self):
           from System.Windows.Markup import XamlReader  # import local
           ...

3. Reiniciar o Revit.

4. Se múltiplas extensions têm o problema, fixar todas.

Detalhes completos: references/armadilhas.md armadilha 4.
```

---

## O que NÃO fazer

- **Não chutar diagnóstico.** Se o sintoma não bater com nenhuma armadilha catalogada, dizer "não reconheci. Pode me passar mais contexto: traceback completo, versão do Revit, versão do pyRevit, qual ação disparou?"
- **Não aplicar fixes destrutivos sem confirmar.** Limpar config, deletar arquivo. Sempre confirmar e fazer backup.
- **Não recriar a extension inteira.** Edit Cirúrgica no arquivo problemático.
- **Não inventar fixes que não estão em `references/armadilhas.md`.** Estiqueza só os 30 catalogados.
