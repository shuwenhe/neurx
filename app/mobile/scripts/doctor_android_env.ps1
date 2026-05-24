param(
    [switch]$SetCurrentSession
)

$ErrorActionPreference = 'Stop'

function Test-PathLeaf([string]$Path) {
    return [bool]($Path -and (Test-Path -LiteralPath $Path))
}

function Resolve-SdkRoot {
    $candidates = @(
        $env:ANDROID_SDK_ROOT,
        $env:ANDROID_HOME,
        (Join-Path $env:LOCALAPPDATA 'Android\Sdk'),
        'C:\Users\shuwen\AppData\Local\Android\Sdk',
        'C:\Android\Sdk',
        'C:\Android\android-sdk'
    )

    foreach ($candidate in $candidates) {
        if (Test-PathLeaf $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    return $null
}

function Resolve-Adb {
    param([string]$SdkRoot)

    $candidates = @(
        (Get-Command adb.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
        (Get-Command adb -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue)
    ) | Where-Object { $_ }

    foreach ($candidate in $candidates) {
        if (Test-PathLeaf $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    if ($SdkRoot) {
        $sdkAdb = Join-Path $SdkRoot 'platform-tools\adb.exe'
        if (Test-PathLeaf $sdkAdb) {
            return (Resolve-Path -LiteralPath $sdkAdb).Path
        }
    }

    return $null
}

function Resolve-NdkRoot {
    param([string]$SdkRoot)

    $candidates = @(
        $env:ANDROID_NDK_ROOT,
        $env:NDK_ROOT,
        'C:\Users\shuwen\AppData\Local\Android\Sdk\ndk',
        'C:\Android\Sdk\ndk'
    )

    foreach ($candidate in $candidates) {
        if (Test-PathLeaf $candidate) {
            if ((Join-Path $candidate 'build\cmake\android.toolchain.cmake') -and (Test-Path -LiteralPath (Join-Path $candidate 'build\cmake\android.toolchain.cmake'))) {
                return (Resolve-Path -LiteralPath $candidate).Path
            }
        }
    }

    if ($SdkRoot) {
        $ndkRoot = Join-Path $SdkRoot 'ndk'
        if (Test-PathLeaf $ndkRoot) {
            $latest = Get-ChildItem -LiteralPath $ndkRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1
            if ($latest) {
                $toolchain = Join-Path $latest.FullName 'build\cmake\android.toolchain.cmake'
                if (Test-Path -LiteralPath $toolchain) {
                    return (Resolve-Path -LiteralPath $latest.FullName).Path
                }
            }
        }
    }

    return $null
}

function Resolve-QtAndroidDir {
    $candidates = @(
        $env:Qt6_ANDROID_DIR,
        $env:Qt6_DIR,
        'C:\Users\Public\qt\6.11.0\android_arm64_v8a\lib\cmake\Qt6',
        'C:\Users\Public\qt\6.10.0\android_arm64_v8a\lib\cmake\Qt6',
        'C:\Users\Public\qt\6.9.0\android_arm64_v8a\lib\cmake\Qt6',
        'C:\Users\Public\qt\6.8.0\android_arm64_v8a\lib\cmake\Qt6'
    )

    foreach ($candidate in $candidates) {
        if (-not $candidate) {
            continue
        }
        if (Test-PathLeaf (Join-Path $candidate 'Qt6Config.cmake')) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    return $null
}

$sdkRoot = Resolve-SdkRoot
$adbPath = Resolve-Adb -SdkRoot $sdkRoot
$ndkRoot = Resolve-NdkRoot -SdkRoot $sdkRoot
$qtAndroidDir = Resolve-QtAndroidDir

Write-Host 'Android environment check'
Write-Host '------------------------'
$sdkRootText = if ($sdkRoot) { $sdkRoot } else { '<missing>' }
$adbPathText = if ($adbPath) { $adbPath } else { '<missing>' }
$ndkRootText = if ($ndkRoot) { $ndkRoot } else { '<missing>' }
$qtAndroidDirText = if ($qtAndroidDir) { $qtAndroidDir } else { '<missing>' }
Write-Host ("SDK root      : " + $sdkRootText)
Write-Host ("adb           : " + $adbPathText)
Write-Host ("NDK root      : " + $ndkRootText)
Write-Host ("Qt Android dir: " + $qtAndroidDirText)
Write-Host ''
Write-Host 'Required packages'
Write-Host '  platform-tools'
Write-Host '  platforms;android-34'
Write-Host '  build-tools;34.0.0'
Write-Host '  ndk;27.2.12479018'
Write-Host '  cmdline-tools;latest'
Write-Host ''

if ($SetCurrentSession) {
    if ($sdkRoot) { $env:ANDROID_SDK_ROOT = $sdkRoot; $env:ANDROID_HOME = $sdkRoot }
    if ($ndkRoot) { $env:ANDROID_NDK_ROOT = $ndkRoot; $env:NDK_ROOT = $ndkRoot }
    if ($qtAndroidDir) { $env:Qt6_ANDROID_DIR = $qtAndroidDir }
    if ($adbPath) {
        $adbDir = Split-Path -Parent $adbPath
        if ($env:Path -notmatch [regex]::Escape($adbDir)) {
            $env:Path = "$adbDir;$env:Path"
        }
    }
    Write-Host 'Current PowerShell session updated.'
}

if (-not $sdkRoot -or -not $adbPath -or -not $ndkRoot -or -not $qtAndroidDir) {
    Write-Host ''
    Write-Host 'Suggested next steps'
    Write-Host '  1. Install Android SDK command-line tools and platform-tools.'
    Write-Host '  2. Install NDK 27.2.12479018.'
    Write-Host '  3. Install Qt Android for arm64-v8a.'
    Write-Host '  4. Re-run this script with -SetCurrentSession after installing.'
}
