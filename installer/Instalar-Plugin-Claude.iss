; ==========================================================================
;  Instalador BIM Coder Claude Kit
;  Compilar com Inno Setup 6+ (https://jrsoftware.org/isdl.php)
;
;  Gera um .exe unico que embute Instalar-Plugin-Claude.ps1 e executa
;  durante a instalacao. Aluno recebe so o .exe e da dois cliques.
;
;  v0.3: pagina de selecao (Tasks) -- o aluno escolhe instalar para
;  Claude Code, Codex, ou os dois. Os switches -InstallClaude / -InstallCodex
;  sao passados para o .ps1 conforme a selecao.
; ==========================================================================

#define MyAppName     "BIM Coder Claude Kit"
#define MyAppVersion  "0.3"
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

[Tasks]
; Pagina de selecao: o aluno marca o que quer. As duas vem marcadas por padrao.
Name: "claude"; Description: "Instalar Claude e seus complementos (Claude Code CLI + plugin + 16 skills)"; GroupDescription: "Escolha as ferramentas de IA para instalar:"
Name: "codex";  Description: "Instalar Codex e seus complementos (OpenAI Codex + 16 skills)"; GroupDescription: "Escolha as ferramentas de IA para instalar:"

[Messages]
br.WelcomeLabel1=Bem-vindo ao Instalador do%n{#MyAppName}
br.WelcomeLabel2=Este assistente instala as ferramentas de IA do BIM Coder para criar plugins pyRevit.%n%nNa proxima tela voce escolhe o que instalar: Claude Code, Codex, ou os dois.%n%nO que vai acontecer:%n%n- Git, Node.js e o(s) CLI(s) escolhido(s) serao verificados (e instalados se faltarem).%n- O plugin sera baixado do GitHub.%n- As 16 skills serao registradas na(s) ferramenta(s) escolhida(s).%n%nClique em Avancar para comecar.
br.FinishedHeadingLabel=Instalacao concluida!
br.FinishedLabel=Tudo pronto. Veja a janela do PowerShell para os proximos passos.%n%n- Claude Code: rode "claude", digite /plugin e confirme "bimcoder-claude-kit".%n- Codex: abra ou reinicie o Codex no VS Code e digite "/" para ver as skills.

[Files]
; Embute o .ps1 dentro do .exe. SEM copia automatica para o destino.
; A funcao [Code] extrai via ExtractTemporaryFile quando precisar.
Source: "Instalar-Plugin-Claude.ps1"; Flags: dontcopy

[Code]
// Exige que pelo menos uma das opcoes (Claude / Codex) esteja marcada.
function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = wpSelectTasks then
  begin
    if (not WizardIsTaskSelected('claude')) and (not WizardIsTaskSelected('codex')) then
    begin
      MsgBox('Selecione pelo menos uma opcao para instalar: Claude e/ou Codex.', mbError, MB_OK);
      Result := False;
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  PSScriptPath: String;
  PSCmd:        String;
  ResultCode:   Integer;
  ProgressPage: TOutputProgressWizardPage;
begin
  // ssPostInstall: roda DEPOIS que os arquivos foram extraidos
  if CurStep <> ssPostInstall then
    Exit;

  ExtractTemporaryFile('Instalar-Plugin-Claude.ps1');
  PSScriptPath := ExpandConstant('{tmp}\Instalar-Plugin-Claude.ps1');

  // Monta os switches conforme o que o aluno marcou na pagina de Tasks.
  PSCmd := '-NoProfile -ExecutionPolicy Bypass -File "' + PSScriptPath + '"';
  if WizardIsTaskSelected('claude') then
    PSCmd := PSCmd + ' -InstallClaude';
  if WizardIsTaskSelected('codex') then
    PSCmd := PSCmd + ' -InstallCodex';

  // Pagina de progresso enquanto o PowerShell roda
  ProgressPage := CreateOutputProgressPage(
    'Instalando o BIM Coder Claude Kit',
    'Pode levar de 2 a 10 minutos dependendo do que precisa baixar.');
  ProgressPage.Show;
  try
    ProgressPage.SetText(
      'Verificando dependencias e configurando as ferramentas escolhidas.',
      'Acompanhe o progresso na janela do PowerShell que vai abrir.');
    ProgressPage.SetProgress(40, 100);

    // PowerShell visivel (SW_SHOWNORMAL) para o aluno ver os passos.
    // NAO checamos ResultCode (Inno pode retornar codigos estranhos mesmo com PS OK;
    // o Pause-Exit do .ps1 mantem a janela aberta se houver erro).
    Exec('powershell.exe', PSCmd, '', SW_SHOWNORMAL, ewWaitUntilTerminated, ResultCode);

    ProgressPage.SetProgress(100, 100);
  finally
    ProgressPage.Hide;
  end;
end;
