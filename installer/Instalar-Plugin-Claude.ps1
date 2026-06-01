$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$RepoUrl     = 'https://github.com/CursoPluginspyRevit/claude-plugin.git'
$CloneTarget = Join-Path $env:USERPROFILE '.bimcoder-claude-plugin'
$PluginName  = 'bimcoder-claude-kit'

function Write-Step($msg) { Write-Host ""; Write-Host $msg -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[!] $msg"  -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "[ERRO] $msg" -ForegroundColor Red }
function Pause-Exit($code) { Write-Host ""; Read-Host "Pressione Enter para sair"; exit $code }

function Refresh-Path {
    $sys = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $usr = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$sys;$usr"
}

function Ensure-Tool($cmdName, $wingetId, $chocoId, $manualUrl) {
    if (Get-Command $cmdName -ErrorAction SilentlyContinue) { return $true }

    Write-Warn "$cmdName nao encontrado. Tentando instalar via winget..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "       Baixando e instalando $cmdName. Isso pode levar 5 a 10 minutos." -ForegroundColor DarkGray
        Write-Host "       Aguarde sem fechar esta janela..." -ForegroundColor DarkGray
        try { winget install -e --id $wingetId --accept-source-agreements --accept-package-agreements } catch {}
        Refresh-Path
        if (Get-Command $cmdName -ErrorAction SilentlyContinue) { return $true }
    }

    if ($chocoId -and (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Warn "Tentando Chocolatey..."
        try { choco install $chocoId -y } catch {}
        Refresh-Path
        if (Get-Command $cmdName -ErrorAction SilentlyContinue) { return $true }
    }

    Write-Err "Nao foi possivel instalar $cmdName automaticamente."
    if ($manualUrl) {
        Write-Host "       Baixe manualmente em: $manualUrl" -ForegroundColor Yellow
        Write-Host "       Depois rode este instalador novamente." -ForegroundColor Yellow
    }
    return $false
}

function Test-ClaudeWorks {
    try {
        $out = & claude --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $out -and $out -notmatch 'nao e um aplicativo' -and $out -notmatch 'is not recognized') {
            return $out
        }
    } catch {}
    return $null
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   Instalador do plugin bimcoder-claude-kit (BIM Coder)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ---- 1. Git ----
Write-Step "[1/6] Verificando Git..."
if (-not (Ensure-Tool 'git' 'Git.Git' 'git' 'https://git-scm.com/download/win')) { Pause-Exit 1 }
Write-OK "Git disponivel ($((git --version) -join ''))."

# ---- 2. Node.js LTS (forcado, evita Node Current incompativel) ----
Write-Step "[2/6] Verificando Node.js (LTS recomendado)..."
$nodeOk = $false
if (Get-Command node -ErrorAction SilentlyContinue) {
    $nodeVer = (node --version).TrimStart('v')
    $major   = [int]($nodeVer.Split('.')[0])
    if ($major -ge 18 -and $major -le 22) {
        Write-OK "Node $nodeVer detectado (compativel)."
        $nodeOk = $true
    } else {
        Write-Warn "Node $nodeVer pode ser incompativel (recomendado: LTS 20 ou 22). Continuando assim mesmo."
        $nodeOk = $true
    }
}

if (-not $nodeOk) {
    # Tentativa 1: winget com timeout de 5 minutos
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "       Tentando instalar via winget (timeout: 5 minutos)..." -ForegroundColor DarkGray
        $proc = Start-Process -FilePath "winget" `
            -ArgumentList "install -e --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements" `
            -PassThru -NoNewWindow
        $saiu = $proc.WaitForExit(300000)   # 5 min em ms
        if (-not $saiu) {
            $proc.Kill()
            Write-Warn "winget nao respondeu em 5 minutos. Usando download direto..."
        }
        Refresh-Path
        if (Get-Command node -ErrorAction SilentlyContinue) { $nodeOk = $true }
    }

    # Tentativa 2: MSI direto do nodejs.org
    if (-not $nodeOk) {
        try {
            # Forcar TLS 1.2 (PowerShell 5.1 nao ativa por padrao)
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

            Write-Host "       Baixando instalador do Node.js 22 LTS diretamente do nodejs.org..." -ForegroundColor DarkGray
            $msiUrl  = "https://nodejs.org/dist/v22.14.0/node-v22.14.0-x64.msi"
            $msiPath = Join-Path $env:TEMP "node-lts-install.msi"
            Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -UseBasicParsing
            Write-Host "       Instalando Node.js (aguarde)..." -ForegroundColor DarkGray
            Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /quiet /norestart" -Wait
            Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
            Refresh-Path
            if (Get-Command node -ErrorAction SilentlyContinue) { $nodeOk = $true }
        } catch {
            Write-Warn "Falha no download direto: $_"
        }
    }

    if (-not $nodeOk) {
        Write-Err "Nao foi possivel instalar o Node.js automaticamente."
        Write-Host "       Instale manualmente em: https://nodejs.org/en/download" -ForegroundColor Yellow
        Write-Host "       Escolha 'Windows Installer (.msi)' LTS 22 e rode este instalador novamente." -ForegroundColor Yellow
        Pause-Exit 1
    }
}
Write-OK "Node $((node --version) -join '')."

# ---- 3. Configurar npm para arquitetura x64 explicita ----
Write-Step "[3/6] Configurando npm para arquitetura x64..."
try { npm config set arch x64 2>&1 | Out-Null } catch {}
Write-OK "npm configurado."

# ---- 4. Claude Code CLI (sempre reinstala limpo) ----
Write-Step "[4/6] Instalando/atualizando Claude Code CLI..."
Write-Host "       Reinstalando do zero para garantir binarios corretos." -ForegroundColor DarkGray

try { npm uninstall -g "@anthropic-ai/claude-code" 2>&1 | Out-Null } catch {}
try { npm cache clean --force 2>&1 | Out-Null } catch {}

# Limpar resquicios manuais no AppData\npm
$npmDir = Join-Path $env:APPDATA 'npm'
if (Test-Path $npmDir) {
    Get-ChildItem $npmDir -Filter 'claude*' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    $pkgDir = Join-Path $npmDir 'node_modules\@anthropic-ai\claude-code'
    if (Test-Path $pkgDir) { Remove-Item $pkgDir -Recurse -Force -ErrorAction SilentlyContinue }
}

try { npm install -g "@anthropic-ai/claude-code" } catch {
    Write-Err "Falha ao instalar o Claude Code CLI via npm."
    Pause-Exit 1
}
Refresh-Path

$claudeVer = Test-ClaudeWorks
if (-not $claudeVer) {
    Write-Err "Claude Code CLI instalou mas nao executa."
    Write-Host ""
    Write-Host "DIAGNOSTICO PROVAVEL:" -ForegroundColor Yellow
    Write-Host "  - Node Current (>=23) pode ser incompativel com o binario nativo do Claude." -ForegroundColor Yellow
    Write-Host "  - Tente fazer downgrade para Node 22 LTS:" -ForegroundColor Yellow
    Write-Host "      winget uninstall -e --id OpenJS.NodeJS" -ForegroundColor White
    Write-Host "      winget install -e --id OpenJS.NodeJS.LTS" -ForegroundColor White
    Write-Host "  - Feche e reabra o PowerShell" -ForegroundColor Yellow
    Write-Host "  - Rode este instalador novamente" -ForegroundColor Yellow
    Pause-Exit 1
}
Write-OK "Claude Code CLI funcional: $claudeVer"

# ---- 5. Clonar / atualizar repo ----
Write-Step "[5/6] Baixando o plugin do GitHub..."
Write-Host "       Destino: $CloneTarget" -ForegroundColor DarkGray
if (Test-Path (Join-Path $CloneTarget '.git')) {
    Write-Host "       Repo ja existe. Atualizando com 'git pull'..." -ForegroundColor DarkGray
    Push-Location $CloneTarget
    try { git pull --ff-only } catch {
        Pop-Location
        Write-Err "Falha ao atualizar o repositorio."
        Pause-Exit 1
    }
    Pop-Location
} else {
    if (Test-Path $CloneTarget) {
        Write-Warn "Pasta de destino existe mas nao e um repo Git. Removendo..."
        Remove-Item $CloneTarget -Recurse -Force
    }
    try { git clone --depth=1 $RepoUrl $CloneTarget } catch {
        Write-Err "Falha ao clonar o repositorio."
        Pause-Exit 1
    }
}

$MarketplaceManifest = Join-Path $CloneTarget '.claude-plugin\marketplace.json'
if (-not (Test-Path $MarketplaceManifest)) {
    Write-Err "marketplace.json nao encontrado em: $MarketplaceManifest"
    Write-Host "       O repositorio remoto pode estar desatualizado." -ForegroundColor Yellow
    Pause-Exit 1
}
Write-OK "Repositorio baixado em: $CloneTarget"

# ---- 6. Registrar e instalar o plugin no Claude Code ----
Write-Step "[6/6] Registrando e instalando no Claude Code..."

claude plugin marketplace add "$CloneTarget"
if ($LASTEXITCODE -ne 0) {
    Write-Err "Falha ao adicionar o marketplace local (exit $LASTEXITCODE)."
    Pause-Exit 1
}

claude plugin install "$PluginName@$PluginName"
if ($LASTEXITCODE -ne 0) {
    Write-Err "Falha ao instalar o plugin (exit $LASTEXITCODE)."
    Pause-Exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "   [OK] Instalacao concluida com sucesso!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Plugin instalado: $PluginName"
Write-Host "Local:            $CloneTarget"
Write-Host ""
Write-Host "Para atualizar no futuro, basta rodar este instalador de novo."
Write-Host ""
Write-Host "PROXIMOS PASSOS:" -ForegroundColor Cyan
Write-Host "  1. Abra um novo terminal e rode:  claude"
Write-Host "  2. Dentro do Claude Code, digite: /plugin"
Write-Host "  3. Confirme que aparece 'bimcoder-claude-kit' instalado."
Write-Host ""
Write-Host "As skills do plugin aparecem com o namespace:"
Write-Host "  bimcoder-claude-kit:nome-da-skill"
Pause-Exit 0
