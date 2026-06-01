param(
    [switch]$InstallClaude,
    [switch]$InstallCodex
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Se nenhum flag veio (ex: rodar o .ps1 direto, fora do instalador), instala os dois.
if (-not $InstallClaude -and -not $InstallCodex) {
    $InstallClaude = $true
    $InstallCodex  = $true
}

$RepoUrl     = 'https://github.com/CursoPluginspyRevit/claude-plugin.git'
$CloneTarget = Join-Path $env:USERPROFILE '.bimcoder-claude-plugin'
$PluginName  = 'bimcoder-claude-kit'

# Pastas dentro do repo clonado
$KitDir    = Join-Path $CloneTarget 'bimcoder-claude-kit'
$KitSkills = Join-Path $KitDir 'skills'
$KitRefs   = Join-Path $KitDir 'references'

# Codex (extensao VS Code e CLI compartilham esta pasta)
$CodexHome   = Join-Path $env:USERPROFILE '.codex'
$CodexSkills = Join-Path $CodexHome 'skills'

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

# ============================================================
#  Deteccao precoce: decidir se precisamos de Node
# ============================================================
$codexPresente = $false
if ($InstallCodex) {
    if ((Get-Command codex -ErrorAction SilentlyContinue) -or (Test-Path $CodexHome)) {
        $codexPresente = $true
    }
}
$vaiInstalarCodexCli = ($InstallCodex -and -not $codexPresente)
$precisaNode = ($InstallClaude -or $vaiInstalarCodexCli)

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   Instalador BIM Coder Claude Kit" -ForegroundColor Cyan
$alvo = @()
if ($InstallClaude) { $alvo += 'Claude Code' }
if ($InstallCodex)  { $alvo += 'Codex' }
Write-Host ("   Instalando para: " + ($alvo -join ' + ')) -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ============================================================
#  COMUM 1. Git (necessario para baixar o plugin do GitHub)
# ============================================================
Write-Step "[1] Verificando Git..."
if (-not (Ensure-Tool 'git' 'Git.Git' 'git' 'https://git-scm.com/download/win')) { Pause-Exit 1 }
Write-OK "Git disponivel ($((git --version) -join ''))."

# ============================================================
#  COMUM 2. Node.js LTS (so se formos instalar algum CLI via npm)
# ============================================================
if ($precisaNode) {
    Write-Step "[2] Verificando Node.js (LTS recomendado)..."
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
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "       Tentando instalar via winget (timeout: 5 minutos)..." -ForegroundColor DarkGray
            $proc = Start-Process -FilePath "winget" `
                -ArgumentList "install -e --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements" `
                -PassThru -NoNewWindow
            $saiu = $proc.WaitForExit(300000)
            if (-not $saiu) { $proc.Kill(); Write-Warn "winget nao respondeu em 5 minutos. Usando download direto..." }
            Refresh-Path
            if (Get-Command node -ErrorAction SilentlyContinue) { $nodeOk = $true }
        }

        if (-not $nodeOk) {
            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Write-Host "       Baixando Node.js 22 LTS do nodejs.org..." -ForegroundColor DarkGray
                $msiUrl  = "https://nodejs.org/dist/v22.14.0/node-v22.14.0-x64.msi"
                $msiPath = Join-Path $env:TEMP "node-lts-install.msi"
                Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -UseBasicParsing
                Write-Host "       Instalando Node.js (aguarde)..." -ForegroundColor DarkGray
                Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /quiet /norestart" -Wait
                Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
                Refresh-Path
                if (Get-Command node -ErrorAction SilentlyContinue) { $nodeOk = $true }
            } catch { Write-Warn "Falha no download direto: $_" }
        }

        if (-not $nodeOk) {
            Write-Err "Nao foi possivel instalar o Node.js automaticamente."
            Write-Host "       Instale manualmente em: https://nodejs.org/en/download (LTS 22) e rode de novo." -ForegroundColor Yellow
            Pause-Exit 1
        }
    }
    Write-OK "Node $((node --version) -join '')."
} else {
    Write-Step "[2] Node.js nao necessario (Codex ja presente e Claude nao selecionado). Pulando."
}

# ============================================================
#  COMUM 3. Baixar o plugin do GitHub (skills + references)
# ============================================================
Write-Step "[3] Baixando o BIM Coder Claude Kit do GitHub..."
Write-Host "       Destino: $CloneTarget" -ForegroundColor DarkGray
if (Test-Path (Join-Path $CloneTarget '.git')) {
    Write-Host "       Repo ja existe. Atualizando com 'git pull'..." -ForegroundColor DarkGray
    Push-Location $CloneTarget
    try { git pull --ff-only } catch { Pop-Location; Write-Err "Falha ao atualizar o repositorio."; Pause-Exit 1 }
    Pop-Location
} else {
    if (Test-Path $CloneTarget) {
        Write-Warn "Pasta de destino existe mas nao e um repo Git. Removendo..."
        Remove-Item $CloneTarget -Recurse -Force
    }
    try { git clone --depth=1 $RepoUrl $CloneTarget } catch { Write-Err "Falha ao clonar o repositorio."; Pause-Exit 1 }
}
Write-OK "Repositorio baixado em: $CloneTarget"

# ============================================================
#  CLAUDE CODE
# ============================================================
if ($InstallClaude) {
    Write-Step "=== CLAUDE CODE ==="

    Write-Host "    Configurando npm para arquitetura x64..." -ForegroundColor DarkGray
    try { npm config set arch x64 2>&1 | Out-Null } catch {}

    Write-Host "    Instalando/atualizando o Claude Code CLI (reinstala limpo)..." -ForegroundColor DarkGray
    try { npm uninstall -g "@anthropic-ai/claude-code" 2>&1 | Out-Null } catch {}
    try { npm cache clean --force 2>&1 | Out-Null } catch {}
    $npmDir = Join-Path $env:APPDATA 'npm'
    if (Test-Path $npmDir) {
        Get-ChildItem $npmDir -Filter 'claude*' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        $pkgDir = Join-Path $npmDir 'node_modules\@anthropic-ai\claude-code'
        if (Test-Path $pkgDir) { Remove-Item $pkgDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    try { npm install -g "@anthropic-ai/claude-code" } catch { Write-Err "Falha ao instalar o Claude Code CLI via npm."; Pause-Exit 1 }
    Refresh-Path

    $claudeVer = Test-ClaudeWorks
    if (-not $claudeVer) {
        Write-Err "Claude Code CLI instalou mas nao executa."
        Write-Host "  - Node Current (>=23) pode ser incompativel. Tente Node 22 LTS, reabra o terminal e rode de novo." -ForegroundColor Yellow
        Pause-Exit 1
    }
    Write-OK "Claude Code CLI funcional: $claudeVer"

    $MarketplaceManifest = Join-Path $CloneTarget '.claude-plugin\marketplace.json'
    if (-not (Test-Path $MarketplaceManifest)) {
        Write-Err "marketplace.json nao encontrado em: $MarketplaceManifest"
        Pause-Exit 1
    }

    Write-Host "    Registrando e instalando o plugin no Claude Code..." -ForegroundColor DarkGray
    claude plugin marketplace add "$CloneTarget"
    if ($LASTEXITCODE -ne 0) { Write-Err "Falha ao adicionar o marketplace local (exit $LASTEXITCODE)."; Pause-Exit 1 }
    claude plugin install "$PluginName@$PluginName"
    if ($LASTEXITCODE -ne 0) { Write-Err "Falha ao instalar o plugin (exit $LASTEXITCODE)."; Pause-Exit 1 }
    Write-OK "Plugin instalado no Claude Code."
}

# ============================================================
#  CODEX
# ============================================================
if ($InstallCodex) {
    Write-Step "=== CODEX ==="

    if ($codexPresente) {
        Write-OK "Codex ja presente (CLI no PATH ou extensao do VS Code)."
    } else {
        Write-Warn "Codex nao encontrado. Instalando o Codex CLI via npm..."
        try { npm install -g "@openai/codex" } catch {
            Write-Warn "Falha ao instalar o Codex CLI. Se voce usa a extensao do Codex no VS Code, as skills abaixo ja funcionam mesmo assim."
        }
        Refresh-Path
    }

    # Copia as skills do kit para ~/.codex/skills/, cada uma autossuficiente
    # (com as references injetadas dentro). Mesmo formato de SKILL.md do Claude.
    if (Test-Path $KitSkills) {
        New-Item -ItemType Directory -Force -Path $CodexSkills | Out-Null
        $n = 0
        foreach ($s in (Get-ChildItem $KitSkills -Directory)) {
            Copy-Item $s.FullName $CodexSkills -Recurse -Force
            $skillRefs = Join-Path (Join-Path $CodexSkills $s.Name) 'references'
            New-Item -ItemType Directory -Force -Path $skillRefs | Out-Null
            if (Test-Path $KitRefs) { Copy-Item (Join-Path $KitRefs '*') $skillRefs -Recurse -Force }
            $n++
        }
        Write-OK "$n skills BIM Coder copiadas para o Codex (~/.codex/skills/)."
    } else {
        Write-Err "Pasta de skills nao encontrada no repo clonado: $KitSkills"
        Pause-Exit 1
    }
}

# ============================================================
#  RESUMO
# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "   [OK] Instalacao concluida com sucesso!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green

if ($InstallClaude) {
    Write-Host ""
    Write-Host "CLAUDE CODE:" -ForegroundColor Cyan
    Write-Host "  1. Abra um terminal novo e rode:  claude"
    Write-Host "  2. Dentro do Claude Code, digite: /plugin  (confirme 'bimcoder-claude-kit')"
    Write-Host "  As skills aparecem como:  bimcoder-claude-kit:nome-da-skill"
}
if ($InstallCodex) {
    Write-Host ""
    Write-Host "CODEX:" -ForegroundColor Cyan
    Write-Host "  1. Abra (ou reinicie) o Codex no VS Code."
    Write-Host "  2. Digite '/' e confirme que aparecem as skills (criar-script, criar-pushbutton...)."
    if (-not $codexPresente) {
        Write-Host "  Obs: o Codex CLI foi instalado agora. Rode 'codex' uma vez e faca login antes de usar."
    }
}
Write-Host ""
Write-Host "Para atualizar no futuro, basta rodar este instalador de novo."
Pause-Exit 0
