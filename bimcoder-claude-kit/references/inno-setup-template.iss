; ==========================================================================
;  TEMPLATE GENÉRICO. Inno Setup para Distribuição de Extension pyRevit
;  Compilar com Inno Setup 6+ (https://jrsoftware.org/isinfo.php)
;
;  Antes de compilar:
;    1. Edite as #define abaixo com os dados do seu plugin
;    2. Gere um GUID novo em https://www.guidgenerator.com/ e cole em AppId
;    3. (opcional) Adicione ícone .ico e imagens .bmp do wizard
;    4. Compile com Ctrl+F9 no Inno Setup Compiler
; ==========================================================================

; ---- CONFIGURACAO. Edite aqui --------------------------------------------
#define MyAppName "Meu Plugin"
#define MyAppVersion "1.0"
#define MyAppPublisher "Sua Empresa"
#define MyAppURL "https://github.com/SuaOrg"

; Token do GitHub com permissao de leitura (se repo privado)
; Para repos publicos, deixe vazio e remova o --token do comando mais abaixo
#define GitToken "ghp_seuTokenAqui"

#define RepoURL "https://github.com/SuaOrg/seu-repo.git"
#define Branch "main"
#define ExtensionName "NomeDaExtensao"
; --------------------------------------------------------------------------

[Setup]
; GUID unico. Gere um novo em https://www.guidgenerator.com/
AppId={{xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={userappdata}\pyRevit\GitHubAddins
DisableDirPage=yes
DisableProgramGroupPage=yes
OutputDir=output
OutputBaseFilename={#MyAppName}_Installer
; SetupIconFile=meu_icone.ico
WizardStyle=modern
WizardSizePercent=100
Compression=lzma
SolidCompression=yes
PrivilegesRequired=lowest
Uninstallable=no
CreateUninstallRegKey=no

; Imagens do wizard (descomente se tiver)
; WizardImageFile=wizard_lateral.bmp
; WizardSmallImageFile=wizard_pequeno.bmp

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Messages]
brazilianportuguese.WelcomeLabel1=Bem-vindo ao instalador do%n{#MyAppName}
brazilianportuguese.WelcomeLabel2=Este assistente ira instalar o plugin {#MyAppName} para pyRevit no seu computador.%n%nCertifique-se de que o pyRevit esta instalado antes de continuar.
brazilianportuguese.FinishedHeadingLabel=Instalacao concluida!
brazilianportuguese.FinishedLabel=O plugin {#MyAppName} foi instalado com sucesso.%n%nAbra o Revit e procure pela aba {#ExtensionName}.

[Code]
var
  ResultCode: Integer;

// Verifica se pyRevit esta no PATH
function PyRevitInstalled(): Boolean;
var
  ExitCode: Integer;
begin
  Result := Exec('cmd.exe', '/C where pyrevit', '', SW_HIDE,
                 ewWaitUntilTerminated, ExitCode) and (ExitCode = 0);
end;

// Bloqueia instalacao se pyRevit nao estiver instalado
function InitializeSetup(): Boolean;
begin
  Result := True;
  if not PyRevitInstalled() then
  begin
    MsgBox(
      'pyRevit nao foi encontrado no sistema!' + #13#10 + #13#10 +
      'Instale o pyRevit antes de continuar.' + #13#10 +
      'Download: https://github.com/pyrevitlabs/pyRevit/releases',
      mbError, MB_OK
    );
    Result := False;
  end;
end;

// Remove versao anterior da extensao
function RemoveOldExtension(): Boolean;
var
  ExtDir: String;
begin
  Result := True;
  ExtDir := ExpandConstant('{userappdata}\pyRevit\GitHubAddins\{#ExtensionName}.extension');
  if DirExists(ExtDir) then
  begin
    if not DelTree(ExtDir, True, True, True) then
    begin
      MsgBox('Nao foi possivel remover a versao anterior.' + #13#10 +
             'Feche o Revit e tente novamente.', mbError, MB_OK);
      Result := False;
    end;
  end;
end;

// Executa a instalacao
procedure CurStepChanged(CurStep: TSetupStep);
var
  Cmd: String;
  ExitCode: Integer;
begin
  if CurStep = ssInstall then
  begin
    // Ativar barra marquee (indeterminada. Fica animando ida e volta)
    WizardForm.ProgressGauge.Style := npbstMarquee;

    // Passo 1: remover versao anterior
    WizardForm.StatusLabel.Caption := 'Removendo versao anterior...';
    WizardForm.StatusLabel.Update;

    if not RemoveOldExtension() then
    begin
      WizardForm.ProgressGauge.Style := npbstNormal;
      Abort;
      Exit;
    end;

    // Passo 2: baixar e instalar via pyrevit extend
    WizardForm.StatusLabel.Caption := 'Baixando e instalando plugin... Aguarde, isso pode levar alguns minutos.';
    WizardForm.StatusLabel.Update;

    Cmd := '/C pyrevit extend ui {#ExtensionName} {#RepoURL}'
         + ' --branch {#Branch}'
         + ' --dest="%APPDATA%\pyRevit\GitHubAddins"'
         + ' --token={#GitToken}';

    if not Exec('cmd.exe', Cmd, '', SW_HIDE,
                ewWaitUntilTerminated, ExitCode) then
    begin
      WizardForm.ProgressGauge.Style := npbstNormal;
      MsgBox('Erro ao executar o comando de instalacao.', mbError, MB_OK);
      Abort;
    end
    else if ExitCode <> 0 then
    begin
      WizardForm.ProgressGauge.Style := npbstNormal;
      MsgBox('Falha na instalacao do plugin.' + #13#10 +
             'Verifique sua conexao com a internet e tente novamente.',
             mbError, MB_OK);
      Abort;
    end;

    // Restaurar barra normal ao concluir
    WizardForm.ProgressGauge.Style := npbstNormal;
    WizardForm.ProgressGauge.Position := WizardForm.ProgressGauge.Max;
  end;
end;

; ==========================================================================
; SECOES OPCIONAIS. Descomente conforme necessidade
; ==========================================================================

; [Files]
;   Copia arquivos extras junto com a instalacao.
;   Source: "meu_config.json"; DestDir: "{userappdata}\pyRevit\GitHubAddins"; Flags: ignoreversion

; [Run]
;   Executa algo apos a instalacao.
;   Filename: "notepad.exe"; Description: "Abrir notas de versao"; Flags: postinstall shellexec
