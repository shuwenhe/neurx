# install/desktop/install.ps1
# Install NeurX AI OS on Windows desktop / laptop
#
# Usage (PowerShell as Administrator):
#   .\install\desktop\install.ps1 [-GPU nvidia|amd|none]

param(
    [string]$GPU = "auto",
    [string]$InstallDir = "$env:LOCALAPPDATA\NeurX"
)

$ErrorActionPreference = "Stop"
$NeurxRoot = Resolve-Path "$PSScriptRoot\..\.."

# ── Auto-detect GPU ──────────────────────────────────────────────────────────
if ($GPU -eq "auto") {
    try {
        $nvsmi = & nvidia-smi --query-gpu=name --format=csv,noheader 2>$null
        if ($LASTEXITCODE -eq 0) { $GPU = "nvidia" }
    } catch {}
    if ($GPU -eq "auto") { $GPU = "none" }
}

Write-Host "=== NeurX Desktop Install (Windows) ===" -ForegroundColor Cyan
Write-Host "    GPU        : $GPU"
Write-Host "    Source     : $NeurxRoot"
Write-Host "    Install to : $InstallDir"
Write-Host ""

# ── 1. Build NeurX ───────────────────────────────────────────────────────────
Write-Host "[1/4] Building NeurX..." -ForegroundColor Yellow
Push-Location $NeurxRoot
make neurx
Pop-Location

# ── 2. Install runtime ───────────────────────────────────────────────────────
Write-Host "[2/4] Installing to $InstallDir ..." -ForegroundColor Yellow
$dirs = @("bin","lib\kernel","lib\agent","lib\tool","lib\serving","lib\memory","config\target","ir")
foreach ($d in $dirs) { New-Item -ItemType Directory -Force -Path "$InstallDir\$d" | Out-Null }

Copy-Item -Recurse -Force "$NeurxRoot\build\ir\*"        "$InstallDir\ir\"
Copy-Item -Recurse -Force "$NeurxRoot\targets\desktop\*" "$InstallDir\config\target\"
Copy-Item -Recurse -Force "$NeurxRoot\kernel\*"          "$InstallDir\lib\kernel\"
Copy-Item -Recurse -Force "$NeurxRoot\agent\*"           "$InstallDir\lib\agent\"
Copy-Item -Recurse -Force "$NeurxRoot\tool\*"            "$InstallDir\lib\tool\"
Copy-Item -Recurse -Force "$NeurxRoot\serving\*"         "$InstallDir\lib\serving\"
Copy-Item -Recurse -Force "$NeurxRoot\memory\*"          "$InstallDir\lib\memory\"

# ── 3. Write GPU config ───────────────────────────────────────────────────────
Write-Host "[3/4] Writing config..." -ForegroundColor Yellow
@"
NEURX_GPU=$GPU
NEURX_TARGET=desktop
NEURX_INSTALL=$InstallDir
"@ | Set-Content "$InstallDir\config\runtime.env"

# ── 4. Add to user PATH ──────────────────────────────────────────────────────
Write-Host "[4/4] Updating PATH..." -ForegroundColor Yellow
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*NeurX\bin*") {
    [Environment]::SetEnvironmentVariable("PATH", "$InstallDir\bin;$userPath", "User")
    Write-Host "  [ok] Added $InstallDir\bin to user PATH"
}

Write-Host ""
Write-Host "=== NeurX Windows install complete ===" -ForegroundColor Green
Write-Host "    Restart shell, then run: neurx-runtime --target desktop"
Write-Host "    GPU: $GPU"
