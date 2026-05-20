param(
    [string]$Model = "qwen2.5:0.5b"
)

$ErrorActionPreference = "Stop"

function Resolve-OllamaPath {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Ollama\ollama.exe"),
        (Join-Path $env:ProgramFiles "Ollama\ollama.exe"),
        "C:\Program Files\Ollama\ollama.exe"
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return (Resolve-Path $candidate).Path
        }
    }

    $command = Get-Command ollama -ErrorAction SilentlyContinue
    if ($command -and $command.Source) {
        return $command.Source
    }

    return $null
}

function Install-Ollama {
    # Use a unique filename to avoid collisions with locked files from prior runs
    $tmpDir = Join-Path $env:TEMP "neurx-ollama"
    $installer = Join-Path $tmpDir ("OllamaSetup-" + [System.Guid]::NewGuid().ToString("N") + ".exe")

    # Remove any stale installer files from previous attempts
    if (Test-Path $tmpDir) {
        Get-ChildItem -Path $tmpDir -Filter "OllamaSetup*.exe" -ErrorAction SilentlyContinue |
            ForEach-Object {
                try { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue } catch {}
            }
    }
    New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

    Write-Host "[ollama] Downloading official Windows installer..."
    try {
        Invoke-WebRequest -Uri "https://ollama.com/download/OllamaSetup.exe" -OutFile $installer -UseBasicParsing
    } catch {
        # Fallback: use .NET WebClient (avoids some proxy/TLS issues with Invoke-WebRequest)
        Write-Host "[ollama] Invoke-WebRequest failed, retrying with WebClient..."
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile("https://ollama.com/download/OllamaSetup.exe", $installer)
    }

    Write-Host "[ollama] Running installer (silent)..."
    $process = Start-Process -FilePath $installer -ArgumentList "/SILENT", "/NORESTART" -PassThru -Wait -WindowStyle Hidden
    if ($process.ExitCode -ne 0) {
        throw "Ollama installer failed with exit code $($process.ExitCode)."
    }

    # Clean up installer after success
    try { Remove-Item $installer -Force -ErrorAction SilentlyContinue } catch {}
}

function Ensure-OllamaServer {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OllamaExe
    )

    try {
        Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 2 | Out-Null
        return
    } catch {
    }

    Write-Host "[ollama] Starting Ollama in the background..."
    Start-Process -FilePath $OllamaExe -ArgumentList "serve" -WindowStyle Hidden | Out-Null

    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 1
        try {
            Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 2 | Out-Null
            return
        } catch {
        }
    }

    throw "Ollama service did not become ready on http://127.0.0.1:11434."
}

$ollamaExe = Resolve-OllamaPath
if (-not $ollamaExe) {
    Install-Ollama
    $ollamaExe = Resolve-OllamaPath
}

if (-not $ollamaExe) {
    throw "Ollama was not found after installation."
}

Write-Host "[ollama] Using $ollamaExe"
Ensure-OllamaServer -OllamaExe $ollamaExe

Write-Host "[ollama] Pulling model $Model ..."
& $ollamaExe pull $Model
if ($LASTEXITCODE -ne 0) {
    throw "ollama pull $Model failed with exit code $LASTEXITCODE."
}

Write-Host "[ollama] Ready: $Model"
