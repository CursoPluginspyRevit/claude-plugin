---
name: criar-script
description: Preenche um script.py de pushbutton pyRevit a partir de descrição em linguagem natural. Atua diretamente no arquivo alvo, não cria pastas, ícones ou bundle. Use quando o aluno já tem o pushbutton criado e quer só escrever o conteúdo do script.
---

# Criar Script. Preenche `script.py` de Pushbutton

Recebe uma descrição em linguagem natural e escreve o `script.py` completo dentro do `.pushbutton/` correto, aplicando as 9 Regras Técnicas Absolutas e o Estilo de API do kit.

## Caminho rápido (caso mais comum — siga primeiro)

Se TODAS estas condições forem verdadeiras, **gere e salve direto, sem narrar etapas, sem abrir references, sem pedir aprovação:**

- O aluno deu uma descrição clara numa frase (inline no comando ou em uma mensagem)
- O alvo é óbvio (cwd dentro de um `.pushbutton/`, ou caminho explícito, ou único `.pushbutton/` na pasta)
- O `script.py` alvo está vazio ou só com boilerplate
- A tarefa é trivial (1 ação, sem decisão do usuário, sem UI customizada)

Escreva o arquivo em UTF-8 e responda em 2 linhas: o caminho salvo + o que o script faz. Pronto. Só caia no fluxo completo abaixo quando alguma condição falhar.

> Exemplo: `/criar-script "lista as paredes da view ativa num relatório"` → salva direto e resume. Sem perguntas, sem preview.

## Quando NÃO usar

- Pushbutton ainda não existe → `/criar-pushbutton` primeiro
- Aluno quer um plano antes do código → `/planejar-plugin`
- Migrar script existente pra C# → `/migrar-csharp`

## Regras técnicas

As 9 Regras Absolutas, o Estilo de API, o critério trivial/não-trivial, o modo RevitFlow Builder e a auto-revisão estão em **`references/regras-essenciais.md`**. Leia esse arquivo UMA vez por sessão se ele ainda não estiver no seu contexto. Não dependa do `CLAUDE.md` (ele não é carregado em runtime) e não abra os references grandes a menos que precise validar uma API específica.

Estrutura padrão do script, tabela de imports e exemplos completos estão em **`reference.md`** (mesma pasta) — abra só se precisar.

---

## Fluxo completo (quando o caminho rápido não se aplica)

### 1. RevitFlow Builder?

Se a descrição tiver cabeçalho `SCRIPT PYREVIT — N ETAPAS` / linha de `====` ou ETAPAs numeradas com `API: Classe`/`API: Método`, entre no **modo RevitFlow Builder** (ver `regras-essenciais.md`): siga as ETAPAs em ordem comentando `# ETAPA N`, faça análise crítica do prompt, aplique as 9 Regras mesmo que o prompt contrarie. Pule pro passo 5.

### 2. Identificar o arquivo alvo

Em ordem de prioridade:
1. Caminho explícito no comando (`/criar-script meu-botao.pushbutton/script.py`)
2. cwd termina em `.pushbutton` → `script.py` no cwd
3. Único `.pushbutton/` na pasta → "Achei um pushbutton em `{caminho}`. É esse?"
4. Vários → liste e peça pra escolher
5. Nenhum → "Não encontrei pushbutton aqui. Crie o bundle com `/criar-pushbutton` primeiro. Quer acionar agora?"

### 3. Coletar a descrição

Se já descrita, use. Se não houver descrição: *"Descreva em uma frase o que esse script deve fazer no Revit."* Se for vaga ("um script de cotas"), faça **UMA** pergunta de refinamento — nunca encadeie perguntas.

### 4. Classificar trivial vs não-trivial

Critério em `regras-essenciais.md`. Se **não-trivial**, ofereça uma vez:

> "Essa tarefa tem várias decisões e edge cases. Recomendo planejar antes.
> 1. Planejar com `/planejar-plugin`   2. Vai direto pro código"

Se trivial ou o aluno seguir, continue.

### 5. Verificar o arquivo e o contexto

Da hierarquia de pastas, extraia: nome do pushbutton (→ `__title__`, hífens/underscores viram espaços), panel/tab/extension (úteis pro `__doc__`). Leia o `script.py` atual:
- Vazio/boilerplate → preencher.
- **Já tem código** → "O arquivo já tem código. 1. Substituir tudo  2. Estender  3. Cancelar"

### 6. Gerar o código

Aplique `regras-essenciais.md`. Estrutura, tabela de imports e exemplo de seleção+transação em `reference.md`. Imports condicionais (só o usado). Erros amigáveis via `forms.alert`, nunca `except: pass`. Conversão de unidades explícita ao exibir números.

### 7. Auto-revisão silenciosa

Frente 1 (9 Regras) + Frente 2 (validar só APIs incomuns contra `references/revit-api-dictionary.md`). Detalhes em `regras-essenciais.md`. Não narre que revisou.

### 8. Entregar

**Direto** (salvar sem preview) quando: descrição clara em 1 mensagem + alvo vazio + trivial + sem refinamento. (É o Caminho Rápido do topo.)

**Com preview** quando QUALQUER: o arquivo já tinha código, conversa em várias mensagens, houve refinamento, tarefa não-trivial seguida sem planejar, aluno pediu "mostra antes", ou houve incerteza técnica que virou comentário de atenção no código. Mostre o código e pergunte:

```
Salvar em: {caminho-relativo}
1. Aprovar e salvar   2. Quero ajustar antes   3. Cancelar
```

### 9. Salvar

Escreva em **UTF-8** (necessário pros acentos). Confirme em 1–2 linhas o que o script faz.

### 10. Próximo passo (opcional, 1 linha)

Só se relevante. Ex: sem ícone no bundle → "Quer rodar `/buscar-icone`?"; usa `Transaction` → "Pra testar: `pyRevit > Reload` antes de clicar." Não invente sugestão pra preencher.

---

## Edição cirúrgica (ajuste posterior)

Quando o aluno pedir um ajuste pontual depois de salvo ("renomeia a variável X", "muda o título"):
- Altere SOMENTE o que foi pedido. Não reescreva trechos vizinhos nem adicione melhorias não solicitadas.
- Se notar outro problema, mencione DEPOIS da entrega, em parágrafo separado, como sugestão opcional.

## O que NÃO fazer

- Não criar pastas, bundles ou ícones (isso é `/criar-pushbutton`). Esta skill só preenche o `script.py`.
- Não usar `revit.Transaction` — sempre `Transaction(doc, "...")`.
- Não esquecer `# -*- coding: utf-8 -*-` na 1ª linha.
- Não inventar nomes de `BuiltInParameter`/`BuiltInCategory` — na dúvida, `getattr` com fallback ou consulta ao dicionário.
- Não fazer mais de uma pergunta por vez. Não revelar que rodou auto-revisão.
- Não pedir aprovação no Caminho Rápido. Se as condições baterem, salve direto.
