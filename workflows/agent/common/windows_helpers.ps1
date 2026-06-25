function Resolve-SBinaryPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $candidates = @()

    if ($env:S_BIN) {
        $candidates += $env:S_BIN
    }

    foreach ($name in @("s", "s.cmd", "s.exe")) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd -and $cmd.Source) {
            $candidates += $cmd.Source
        }
    }

    if ($env:S_ROOT) {
        $candidates += @(
            (Join-Path $env:S_ROOT "bin\\s.cmd"),
            (Join-Path $env:S_ROOT "bin\\s.exe"),
            (Join-Path $env:S_ROOT "bin\\s")
        )
    }

    $homeDir = [Environment]::GetFolderPath("UserProfile")
    $candidates += @(
        (Join-Path $homeDir "s\\bin\\s.cmd"),
        (Join-Path $homeDir "s\\bin\\s.exe"),
        (Join-Path $homeDir "s\\bin\\s"),
        (Join-Path $RepoRoot "..\\s\\bin\\s.cmd"),
        (Join-Path $RepoRoot "..\\s\\bin\\s.exe"),
        (Join-Path $RepoRoot "..\\s\\bin\\s")
    )

    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path $candidate)) {
            return (Resolve-Path $candidate).Path
        }
    }

    return $null
}

function Resolve-GitBashPath {
    $candidates = @(
        "C:\\Program Files\\Git\\bin\\bash.exe",
        "C:\\Program Files\\Git\\usr\\bin\\bash.exe",
        "C:\\Progra~1\\Git\\bin\\bash.exe",
        "C:\\Progra~1\\Git\\usr\\bin\\bash.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return (Resolve-Path $candidate).Path
        }
    }

    $cmd = Get-Command bash -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd -and $cmd.Source) {
        return $cmd.Source
    }

    throw "Git Bash not found. Install Git for Windows or put bash.exe on PATH."
}

function Convert-ToBashPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ($Path -match '^/[A-Za-z]/') {
        return $Path
    }

    $resolved = (Resolve-Path $Path).Path
    $normalized = $resolved -replace '\\', '/'
    if ($normalized -match '^([A-Za-z]):/(.*)$') {
        return "/$($matches[1].ToLower())/$($matches[2])"
    }
    return $normalized
}

function Quote-ForBash {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $replacement = "'" + '"' + "'" + '"' + "'"
    return "'" + $Value.Replace("'", $replacement) + "'"
}

function Invoke-BashWorkflow {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        [string[]]$Arguments = @(),
        [string]$SBinaryPath
    )

    $bashExe = Resolve-GitBashPath
    $repoBash = Convert-ToBashPath $RepoRoot
    $scriptBash = Convert-ToBashPath $ScriptPath

    $scriptCommand = "$(Quote-ForBash $scriptBash)"
    foreach ($arg in $Arguments) {
        $scriptCommand += " $(Quote-ForBash $arg)"
    }

    $command = "cd $(Quote-ForBash $repoBash) && export S_BIN=$(Quote-ForBash (Convert-ToBashPath $SBinaryPath)) && $scriptCommand"

    & $bashExe -lc $command
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
