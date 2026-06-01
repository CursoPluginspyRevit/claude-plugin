; ==========================================================================
;  Instalador BIM Coder Claude Kit
;  Compilar com Inno Setup 6+ (https://jrsoftware.org/isdl.php)
;
;  Gera um .exe unico que embute Instalar-Plugin-Claude.ps1 e executa
;  durante a instalacao. Aluno recebe so o .exe e da dois cliques.
;
;  Padrao baseado no installer.iss do Setup-Plugins-pyRevit-BIM-Coder
;  (testado e funcional): ssPostInstall + ExtractTemporaryFile +
;  ProgressPage + SW_SHOWNORMAL + sem checagem rigorosa de exit code.
; ==========================================================================

#define MyAppName     "BIM Coder Claude Kit"
#define MyAppVersion  "0.2"
#define MyAppPublisher "BIM Coder"
#define MyAppURL      "https://github.com/CursoPluginspyRevit/claude-plugin"

[Setup]
; GUID fixo. Nao mudar entre versoes (Windows reconhece como atualizacao).
AppId={{540EFCD3-12AF-484C-BF9B-AB9B812ED19D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}

; Sem pasta de instalacao real. O .ps1 instala em %USERPROFILE%
CreateAppDir=no
DisableProgramGroupPage=yes
DisableDirPage=yes
DisableReadyPage=no
DisableFinishedPage=no

; Aparencia e build
WizardStyle=modern
WizardSizePercent=110
Compression=lzma2/max
SolidCompression=yes
SetupLogging=yes

; Sem desinstalador (instalacao no perfil do usuario, nao em Program Files)
Uninstallable=no
CreateUninstallRegKey=no

; Privilegios. lowest evita prompts de UAC; o .ps1 instala per-user
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0

OutputDir=output
OutputBaseFilename=Setup-BIMCoder-Claude-Kit-{#MyAppVersion}

[Languages]
Name: "br"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Messages]
br.WelcomeLabel1=Bem-vindo ao Instalador do%n{#MyAppName}
br.WelcomeLabel2=Este assistente vai instalar o plugin Claude Code do BIM Coder.%n%nO que vai acontecer:%n%n- Git, Node.js e Claude Code CLI serao verificados (e instalados via winget se faltarem).%n- O plugin sera clonado do GitHub para a sua pasta de usuario.%n- O plugin sera registrado como marketplace local no Claude Code.%n%nClique em Avancar para comecar.
br.FinishedHeadingLabel=Instalacao concluida!
br.FinishedLabel=Proximos passos:%n%n1. Abra um terminal novo (ou reinicie o VS Code).%n2. Rode o comando: claude%n3. Dentro do Claude Code, digite "/" para ver as skills.%n%nAs skills do plugin aparecem com o prefixo bimcoder-claude-kit:.

[Files]
; Embute o .ps1 dentro do .exe. SEM copia automatica para o destino.
; Usar dontcopy: Inno Setup so cola o arquivo dentro do .exe.
; A funcao [Code] vai extrair via ExtractTemporaryFile quando precisar.
Source: "Instalar-Plugin-Claude.ps1"; Flags: dontcopy

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
var
  PSScriptPath: String;
  PSCmd:        String;
  ResultCode:   Integer;
  ProgressPage: TOutputProgressWizardPage;
begin
  // ssPostInstall: roda DEPOIS que os arquivos foram extraidos
  // (mesmo padrao do installer.iss antigo que funciona)
  if CurStep <> ssPostInstall then
    Exit;

  ExtractTemporaryFile('Instalar-Plugin-Claude.ps1');
  PSScriptPath := ExpandConstant('{tmp}\Instalar-Plugin-Claude.ps1');

  // Pagina de progresso enquanto o PowerShell roda
  ProgressPage := CreateOutputProgressPage(
    'Instalando o plugin BIM Coder Claude Kit',
    'Pode levar de 2 a 10 minutos dependendo do que precisa baixar.');
  ProgressPage.Show;
  try
    ProgressPage.SetText(
      'Verificando dependencias (Git, Node, Claude CLI) e baixando o plugin do GitHub.',
      'Acompanhe o progresso na janela do PowerShell que vai abrir.');
    ProgressPage.SetProgress(40, 100);

    // PowerShell visivel (SW_SHOWNORMAL) para o aluno ver os passos 1/5, 2/5 etc.
    // -ExecutionPolicy Bypass libera o script sem mexer na policy global.
    PSCmd := '-NoProfile -ExecutionPolicy Bypass -File "' + PSScriptPath + '"';

    // NAO checamos ResultCode aqui. O instalador antigo tambem nao checa
    // (Inno pode retornar codigos negativos estranhos mesmo com PS rodando
    // OK). Se o .ps1 falhou, o aluno ve o erro na janela do PowerShell
    // e o Pause-Exit do .ps1 mantem a janela aberta para leitura.
    Exec('powershell.exe', PSCmd, '', SW_SHOWNORMAL, ewWaitUntilTerminated, ResultCode);

    ProgressPage.SetProgress(100, 100);
  finally
    ProgressPage.Hide;
  end;
end;
