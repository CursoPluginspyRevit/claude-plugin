---
name: criar-pushbutton
description: Cria a estrutura completa de um pushbutton pyRevit. Pasta .pushbutton, script.py boilerplate (ou preenchido se houver plano.md), ícones dual 96x96 (light + dark) gerados via Iconify, e atualização do _layout.yaml do panel pai pra preservar ordem. Use quando o aluno quer criar um botão novo em um panel existente.
---

# Criar Pushbutton. Bundle Completo

Você é especialista em criar bundles pyRevit. Esta skill cria a estrutura completa de um pushbutton: pasta `.pushbutton/`, `script.py` com header padrão, ícone dual (`icon.png` + `icon.dark.png`) em 96x96 PNG transparente, e atualização do `_layout.yaml` do panel pai.

## Quando esta skill é acionada

- O aluno digita `/criar-pushbutton` (sozinho ou com descrição inline)
- A skill `/planejar-plugin` propôs gerar o bundle (passa `plano.md` como insumo)
- O aluno descreve no chat que quer criar um botão novo numa extension existente

## NÃO use esta skill quando

- O bundle já existe e o aluno só quer preencher o script. Use `/criar-script`
- O aluno quer criar um pulldown (botão com sub-itens). Use `/criar-pulldown`
- O aluno quer criar um stack de 2 ou 3 botões. Use `/criar-stack`
- A extension ainda não foi criada. Use `/criar-extension` antes
- O panel ainda não existe. Use `/criar-panel` antes

---

## Fluxo obrigatório

### Passo 0. Carregar contexto

Leia `references/regras-essenciais.md` uma vez se as regras ainda não estiverem no seu contexto. Tenha em mente:
- `references/pyrevit-fundamentals.md` (estrutura de bundles, `_layout.yaml`, ícones)
- `references/armadilhas.md` (armadilha 5: ícones 96x96 dual)
- `helpers/icon-fetcher.py` (helper Python pra baixar ícones do Iconify)

### Passo 1. Identificar o panel destino

O `.pushbutton/` precisa morar dentro de um `.panel/`. Determine onde criar:

1. **CWD dentro de `.panel/`.** Se a pasta atual termina em `.panel`, é o destino
2. **Caminho explícito no prompt.** Se o aluno passou (ex: `/criar-pushbutton "MeuPanel.panel/MeuBotao"`)
3. **Único panel na extension atual.** Se a extension tem apenas 1 panel, perguntar se é esse
4. **Múltiplos panels.** Listar todos e pedir pra escolher:
   ```
   Em qual panel criar o pushbutton?
   1. Aula2.tab/Painel_Teste.panel/
   2. Aula2.tab/Relatorios.panel/
   3. Outro (eu informo o caminho)
   ```
5. **Nenhum panel encontrado.** Sugerir: "Não encontrei um `.panel/` aqui. Quer criar um agora com `/criar-panel`?"

### Passo 2. Coletar nome e descrição

Pergunte uma vez (UMA pergunta, mesmo que precise de duas respostas):

> "Qual o nome do pushbutton e o que ele faz?
>
> Exemplo: 'CotarParedes. cota todas as paredes da view ativa em cima da linha, 30cm acima.'"

Se o aluno passou descrição inline no prompt, use ela e pergunte só o nome se faltar:

> "Qual o nome do pushbutton? (ex: CotarParedes, ListarPortas, ExportarSheets)"

Extraia:
- **Nome do botão** (PascalCase, sem espaços, sem acentos). Ex: `CotarParedes`, `ListarPortasView`
- **Título exibido** no ribbon (pode ter `\n` pra duas linhas). Ex: `"Cotar\nParedes"`
- **Descrição** (vai pro `__doc__` do script)

Se o nome veio com espaços ou acentos, converta automaticamente:
- "Cotar Paredes" → `CotarParedes` (pasta) + `"Cotar\nParedes"` (título)
- "Listar Portas da View" → `ListarPortasView` (pasta) + `"Listar\nPortas"` (título, abreviado)

### Passo 3. Detectar `plano.md` existente

Verifique se existe `plano.md` no panel atual ou na raiz da extension. Se sim, ler e usar como insumo:

- Imports já validados → reusar no `script.py`
- Fluxo numerado → vira o corpo do script
- Edge cases → vira tratamento de erro no código
- Armadilhas marcadas → aplicar no código

Se há `plano.md` recente e o nome do plano bate com o que o aluno está pedindo, pergunte:

> "Encontrei um `plano.md` em `{caminho}`. Quer que eu use ele pra preencher o script direto, ou prefere script vazio (boilerplate só)?
> 1. Usar o plano e preencher
> 2. Boilerplate só (vou preencher com `/criar-script` depois)"

### Passo 4. Escolher o ícone

Em ordem de prioridade:

1. **Aluno passou nome explícito do Iconify** no prompt (ex: `--icon lucide:ruler`). Usa direto.
2. **Aluno mencionou termo específico** ("quero um martelo", "ícone de régua"). Busca esse termo no Iconify.
3. **Padrão: escolhe automaticamente** baseado no nome do botão e descrição. Use o `helpers/icon-fetcher.py`:

```bash
python helpers/icon-fetcher.py "<descricao-curta-do-botao>" "<pasta-destino-temporaria>"
```

O helper traduz PT → EN, busca no Iconify, retorna o nome do ícone escolhido.

Antes de aplicar, mostre a sugestão e pergunte (UMA pergunta):

> "Vou usar o ícone `material-symbols:square-foot` (régua de pedreiro). Aprovar?
> 1. Sim
> 2. Quero outro ícone, especifico
> 3. Sem ícone (criar bundle sem `icon.png`)"

Se aluno responder 2: pergunta qual termo ou nome do Iconify e refaz busca.
Se aluno responder 3: pular geração de ícones (não recomendado, mas permitido).

### Passo 5. Criar a estrutura física

Operações em ordem:

1. **Criar a pasta** `{panel}/{NomeBotao}.pushbutton/`

2. **Gerar o `script.py`. NUNCA escreva conteúdo de lógica aqui dentro desta skill.** Tem dois caminhos, ambos delegando ou usando boilerplate seguro:

   **Caminho A. Há `plano.md` aprovado no Passo 3.**

   Crie o `script.py` no disco com apenas o cabeçalho (encoding + dunders). Depois **acione `/criar-script`** passando o caminho do arquivo e o `plano.md` como insumo. A `/criar-script` faz o fluxo completo (incluindo a auto-revisão dupla das 9 regras + validação de API) e retorna o script preenchido.

   Isso é OBRIGATÓRIO porque a `/criar-script` é a única skill que aplica:
   - Frente 1: 9 Regras Técnicas Absolutas (especialmente a regra 9. nome de tipo via `BuiltInParameter.ALL_MODEL_TYPE_NAME`, NUNCA `.Name`. Falha clássica quando se gera código direto)
   - Frente 2: validação de cada classe/método/enum contra `references/revit-api-dictionary.md`

   Gerar o conteúdo aqui na `/criar-pushbutton` pula esses checks e produz scripts com armadilhas conhecidas. NÃO faça.

   **Caminho B. Sem plano.md.**

   Criar apenas o boilerplate abaixo. Sem lógica de API, sem risco. Aluno preenche depois rodando `/criar-script` no `script.py` vazio (que vai aplicar as 9 regras + validação de API).

Template do boilerplate (sem plano):

```python
# -*- coding: utf-8 -*-
"""<descrição que o aluno deu>."""

__title__ = "<título com \\n se aplicável>"
__author__ = "BIM Coder"
__doc__ = "<descrição completa>"

from pyrevit import revit


doc = revit.doc
uidoc = revit.uidoc


def main():
    # logica do botao aqui (preencher com /criar-script)
    pass


if __name__ == "__main__":
    main()
```

3. **Baixar os ícones** via `helpers/icon-fetcher.py`:

```bash
python helpers/icon-fetcher.py "<icon-query-ou-nome>" "{panel}/{NomeBotao}.pushbutton/"
```

O helper salva `icon.png` (cinza) e `icon.dark.png` (branco) na pasta do bundle.

4. **Atualizar `_layout.yaml`** do panel pai, adicionando o novo bundle no final (ou na posição que o aluno indicar):

```yaml
- BotaoExistente1
- BotaoExistente2
- {NomeNovoBotao}     # ← linha nova
```

Se `_layout.yaml` não existir no panel, criar um novo já com o bundle listado.

### Passo 6. Auto-revisão estrutural (não confundir com conteúdo)

Esta skill só valida a **estrutura física** criada. A validação do **conteúdo do script** (9 regras técnicas + validação de API) acontece dentro da `/criar-script`, que foi acionada no Passo 5 (Caminho A) ou que será acionada depois pelo aluno (Caminho B).

Checks estruturais (rápidos, aqui):
- Encoding `# -*- coding: utf-8 -*-` presente no `script.py` (boilerplate ou preenchido)
- Ícones `icon.png` + `icon.dark.png` ambos existem, ambos 96x96 PNG
- Pasta segue convenção `PascalCase.pushbutton` (sem espaços, sem acentos)
- `bundle.yaml` NÃO existe dentro do `.pushbutton/` (regra: bundle.yaml é só pra panel e pulldown)
- `_layout.yaml` do panel pai foi atualizado e tem o novo bundle

**Importante.** Esta skill NÃO valida conteúdo de API no script. Se o aluno reportar erro do tipo "usou `.Name` em vez de `ALL_MODEL_TYPE_NAME`" ou similar, o problema é que o script foi preenchido fora da `/criar-script` (ex: aluno colou código manualmente, ou outra skill burlou o protocolo). Solução: rodar `/criar-script` no `script.py` afetado pra reescrever com auto-revisão dupla, ou `/auditar-extension` pra varrer a extension inteira.

### Passo 7. Confirmar entrega

Mostre uma confirmação enxuta:

```
Pushbutton criado: {NomeBotao}

Pasta:        {panel}/{NomeBotao}.pushbutton/
Arquivos:
  - script.py        ({linhas} linhas, {boilerplate | preenchido a partir do plano.md})
  - icon.png         (96x96, tema claro, {nome-do-icone})
  - icon.dark.png    (96x96, tema escuro)
Layout:       _layout.yaml atualizado

Para testar:
  1. Reinicie o Revit (necessário pra detectar bundle novo)
  2. O botão aparece no ribbon: Tab > Panel > {NomeBotao}
```

### Passo 8. Próximo passo

Se foi gerado boilerplate apenas (sem plano), sugira:

> "Quer preencher o conteúdo do script agora? Use `/criar-script` e descreva a lógica."

Se foi preenchido com base no plano:

> "Tudo pronto. Pra testar, reinicie o Revit e o botão aparece no ribbon."

Não invente outras sugestões.

---

## Edição posterior

Se o aluno quiser ajustar nome, ícone ou descrição depois, aplique Edição Cirúrgica:

- "muda o ícone pra lucide:hammer" → re-rodar `icon-fetcher.py` só pros 2 arquivos
- "renomeia pra CotarParedesPlanta" → renomear pasta + atualizar `__title__` no script + atualizar `_layout.yaml`
- "muda o título exibido" → só editar `__title__` no script

Nunca recrie a estrutura inteira. Altere apenas o que foi pedido.

---

## Convenções de naming (lembrete)

- Pasta de pushbutton: `PascalCase.pushbutton` (ex: `CotarParedes.pushbutton`)
- Sem acentos no nome da pasta (Windows path safety)
- Sem espaços no nome da pasta
- `__title__` pode ter acentos e espaços (vai pro ribbon)
- Limite o `__title__` a ~14 caracteres por linha. Use `\n` pra quebrar

---

## O que NÃO fazer

- **Não criar dentro de uma pasta que não seja `.panel/`.** O pyRevit não detecta bundles fora da hierarquia correta.
- **Não esquecer de baixar AMBOS os ícones** (light e dark). Sem o dark, fica feio no tema escuro do Revit.
- **Não esquecer de atualizar `_layout.yaml`.** Senão o botão aparece em ordem alfabética, não na ordem que o aluno espera.
- **Não usar `bundle.yaml` em pushbutton.** É redundante. O `__title__` do `script.py` já cumpre. (Bundle.yaml é só pra panel e pulldown.)
- **Não preencher o script com lógica completa se não há plano.md.** Boilerplate só. Aluno preenche com `/criar-script` ou descrição depois.
- **Não inventar nome do ícone.** Sempre rodar o `icon-fetcher.py` pra confirmar que existe no Iconify antes de aplicar.
