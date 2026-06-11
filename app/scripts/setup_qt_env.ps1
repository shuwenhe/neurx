param(
    [string]$Qt6Dir = "",
    [switch]$Persist
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$QtRootDir = Split-Path -Parent $ScriptDir
$ProjectRoot = Split-Path -Parent $QtRootDir

function Write-Status($Message) {
    Write-Host "[qt-setup] $Message"
}

function Find-Qt6Dir {
    if ($Qt6Dir -and (Test-Path $Qt6Dir)) {
        return (Resolve-Path $Qt6Dir).Path
    }

    if ($env:Qt6_DIR -and (Test-Path $env:Qt6_DIR)) {
        return (Resolve-Path $env:Qt6_DIR).Path
    }

    $candidates = @(
        "C:\\Qt",
        "C:\\Program Files\\Qt",
        "D:\\Qt"
    )

    foreach ($base in $candidates) {
        if (-not (Test-Path $base)) { continue }
        $match = Get-ChildItem -Path $base -Directory -Recurse -Filter Qt6 -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($match) {
            return $match.FullName
        }
    }

    return ""
}

$resolvedQt6Dir = Find-Qt6Dir
if (-not $resolvedQt6Dir) {
    Write-Status "Qt6_DIR not found. Install Qt6 first, then rerun with -Qt6Dir <path-to-Qt6Config-dir>."
    exit 1
}

$cmakePrefix = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $resolvedQt6Dir))

$env:Qt6_DIR = $resolvedQt6Dir
$env:CMAKE_PREFIX_PATH = $cmakePrefix
$env:NEURX_ROOT = $ProjectRoot

if ($Persist) {
    setx Qt6_DIR "$resolvedQt6Dir" | Out-Null
    setx CMAKE_PREFIX_PATH "$cmakePrefix" | Out-Null
    setx NEURX_ROOT "$ProjectRoot" | Out-Null
    Write-Status "Persisted Qt6_DIR, CMAKE_PREFIX_PATH, and NEURX_ROOT via setx."
}

Write-Status "Qt6_DIR=$resolvedQt6Dir"
Write-Status "CMAKE_PREFIX_PATH=$cmakePrefix"
Write-Status "NEURX_ROOT=$ProjectRoot"
Write-Status "Now run: cmake -S $QtRootDir -B $QtRootDir/build"
