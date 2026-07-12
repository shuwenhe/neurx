param(
    [string]$SBin = ""
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../../../..")).Path
. (Join-Path $repoRoot "workflows/agent/common/windows_helpers.ps1")

if (-not $SBin) {
    $SBin = Resolve-SBinaryPath -RepoRoot $repoRoot
}
if (-not $SBin) {
    throw "Unable to resolve S binary. Set S_BIN or install the launcher under ~/s/bin."
}

$scriptPath = Join-Path $repoRoot "memory/memory_workflows/run/launch.s"
Invoke-BashWorkflow -RepoRoot $repoRoot -ScriptPath $scriptPath -SBinaryPath $SBin
