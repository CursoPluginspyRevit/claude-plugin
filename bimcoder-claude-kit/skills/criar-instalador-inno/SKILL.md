---
name: criar-instalador-inno
description: Gera um arquivo .iss do Inno Setup pra distribuir uma extension pyRevit como instalador .exe profissional. Usa references/inno-setup-template.iss como base e personaliza com o nome da extension, token do GitHub, repo URL e branch. Suporta repo público (sem token) ou privado (com token). Inclui verificação de pyRevit instalado, remoção de versão anterior e barra de progresso animada.
---

# Criar Instalador Inno. Distribuição Profissional via .exe

Você é especialista em empacotar extensions pyRevit pra distribuição. Esta skill gera o arquivo `.iss` do Inno Setup que, depois de compilado, vira um instalador `.exe` que o aluno entrega pros clientes/colegas.

## Quando esta skill é acionada

- O aluno digita `/criar-instalador-inno`
- A extension está pronta pra distribuição comercial ou pra clientes
- O aluno quer entregar instalação 1-clique em vez de pedir clone manual

## NÃO use esta skill quando

- A extension ainda está em desenvolvimento (muda toda hora). Distribuir cedo demais
- O aluno quer só compartilhar com 1 ou 2 colegas técnicos (clone manual basta)
- A extension não tem licença comercial definida (verificar antes de distribuir publicamente)

---

## Fluxo obrigatório

### Passo 0. Carregar contexto

`references/inno-setup-template.iss` tem o template base completo (171 linhas) com:
- `[Setup]` (GUID, nome, pasta destino, visual)
- `[Languages]` (PT-BR)
- `[Messages]` (textos customizados do wizard)
- `[Code]` (Pascal Script com verificação de pyRevit, remoção de versão anterior, instalação via `pyrevit extend`)

### Passo 1. Identificar a extension destino

Detecte `.extension/`:

1. **CWD em `.extension/`** → usar esta
2. **Caminho explícito** no prompt
3. **Pasta com `.extension/` filha** → listar e perguntar
4. **Nenhuma** → sugerir `/criar-extension` antes

### Passo 2. Coletar dados do instalador

Pergunte em 3 perguntas (uma por vez):

**Pergunta 1:**

> "Dados básicos do instalador:
> - Nome do app (ex: 'BIM Coder Tools')
> - Versão (ex: '1.0.0')
> - Publisher/empresa (ex: 'BIM Coder')"

**Pergunta 2:**

> "Dados do repositório no GitHub:
> - URL completa (ex: 'https://github.com/bclabss/minha-extension.git')
> - Branch (ex: 'main')
> - Nome da extension (mesmo nome da pasta `.extension`, sem o sufixo)"

**Pergunta 3:**

> "O repositório é público ou privado?
> 1. Público (sem necessidade de token)
> 2. Privado (precisa de token do GitHub com permissão de leitura)"

Se 2, pergunte:

> "Cole o token (ghp_...). Aviso: o token vai embutido no .exe, então mesmo em binário pode ser extraído por engenharia reversa. Pra repos realmente sensíveis, considere tornar público ou usar API intermediária."

### Passo 3. Gerar GUID único do instalador

```python
import uuid
app_id = "{{" + str(uuid.uuid4()).upper() + "}"  # ex: {B8F3A1D2-7C4E-...}
```

Esse `AppId` identifica unicamente o instalador. Se for criar outro instalador no futuro pra outro app, gerar GUID novo.

### Passo 4. Personalizar o template

Leia `references/inno-setup-template.iss` e substitua as `#define`:

```iss
#define MyAppName "{nome-do-app}"
#define MyAppVersion "{versao}"
#define MyAppPublisher "{publisher}"
#define MyAppURL "{url-do-publisher}"
#define GitToken "{token-ou-vazio}"
#define RepoURL "{url-do-repo}"
#define Branch "{branch}"
#define ExtensionName "{nome-da-extension-sem-sufixo}"
```

Substitua também o `AppId={{...}` pelo GUID gerado.

Se o repo for público (sem token), remover o `--token={#GitToken}` do comando de instalação. Caso contrário, manter.

Salve como `{pasta-da-extension}/installer.iss` (ou na pasta do projeto, fora da `.extension/`).

### Passo 5. Verificar pré-requisitos do Inno Setup

Avise o aluno:

```
Pré-requisitos pra compilar o .iss:

1. Instalar o Inno Setup 6+ (gratuito):
   https://jrsoftware.org/isdl.php
   Só o desenvolvedor precisa. Usuários finais não precisam.

2. (Opcional) Personalizar visual do wizard:
   - Ícone (.ico) pro instalador: SetupIconFile=meu_icone.ico
   - Imagem lateral 164x314 .bmp: WizardImageFile=wizard_lateral.bmp
   - Imagem pequena 55x58 .bmp: WizardSmallImageFile=wizard_pequeno.bmp

3. Compilar:
   - Abrir Inno Setup Compiler
   - File > Open > selecionar installer.iss
   - Ctrl+F9 ou Build > Compile
   - Output gerado em: ./output/{nome-app}_Installer.exe
```

### Passo 6. Confirmar entrega

```
Instalador .iss criado: {nome-do-app}

Arquivo:      {caminho}/installer.iss
AppId:        {GUID gerado}
Tipo:         {publico | privado com token}
Idioma:       Portugues do Brasil

Pra compilar o .exe:
1. Instale o Inno Setup 6+ (gratuito): https://jrsoftware.org/isdl.php
2. Abra o Inno Setup Compiler
3. File > Open > installer.iss
4. Build > Compile (Ctrl+F9)
5. Output em: output/{nome-app}_Installer.exe

Pra testar antes de distribuir:
- Run > Run (F9). Roda o wizard sem instalar de verdade
- Verifica todas as telas e fluxos

Pra entregar pro usuario final:
- Envia so o .exe gerado (instalador unico, ~5MB)
- Usuario clica duas vezes, segue o wizard
- Pre-requisito do usuario final: pyRevit instalado
```

### Passo 7. Próximo passo

```
Aviso de seguranca: o token do GitHub fica embutido no .exe. Em
distribuicao publica de extension paga, considere:
- Tornar o repo publico (open-source)
- OU manter privado com proxy/API intermediaria
- OU usar criptografia do .exe (UPX, VMProtect) com cuidado

Aviso de manutencao: a cada nova versao da extension:
1. Atualizar #define MyAppVersion no installer.iss
2. Recompilar o .iss
3. Distribuir o novo .exe
4. O AppId NAO muda (Inno Setup detecta como atualizacao)
```

---

## Decisões já tomadas no template

O template em `references/inno-setup-template.iss` já decidiu:

| Decisão | Valor | Por quê |
|---|---|---|
| `PrivilegesRequired` | `lowest` | pyRevit instala em `%APPDATA%`, não precisa de admin |
| `DisableDirPage` | `yes` | Destino fixo, não faz sentido o usuário escolher |
| `Uninstallable` | `no` | Extension é removida via `pyrevit extend remove` |
| Idioma | brazilianportuguese | Público-alvo BR |
| Compressão | lzma + solid | Tamanho menor |
| Barra de progresso | marquee animada | Comando externo, progresso desconhecido |

Você pode alterar essas decisões na sua versão final do `.iss` se precisar.

---

## O que NÃO fazer

- **Não distribuir token do GitHub em texto puro.** Use Inno Setup que embute no binário.
- **Não esquecer de gerar GUID novo** pra cada app diferente. AppId duplicado causa conflito de detecção.
- **Não esquecer de incrementar MyAppVersion** a cada release. Senão Windows pode pular reinstalação.
- **Não usar `PrivilegesRequired=admin`** sem necessidade real. pyRevit não precisa.
- **Não esquecer de testar com F9** (Run sem compile) antes de distribuir o .exe.
- **Não inventar campos não suportados pelo Inno Setup.** Atenha-se ao schema do template.
