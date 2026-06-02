@echo off
REM NeurX Code Windows build script
REM Usage: scripts\build-windows.bat [Debug|Release]
REM
REM Requires one of:
REM   - Visual Studio 2019/2022 with Desktop C++ workload
REM   - MinGW-w64 + CMake + Ninja
REM
REM Optional:
REM   - Set QT6_DIR to your Qt installation, for example:
REM       set QT6_DIR=C:\Qt\6.7.3\msvc2022_64

setlocal EnableDelayedExpansion

set "BUILD_TYPE=%~1"
if "%BUILD_TYPE%"=="" set "BUILD_TYPE=Release"

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "PROJECT_DIR=%%~fI"
set "BUILD_DIR=%PROJECT_DIR%\build\windows-%BUILD_TYPE%"

REM Discover common Qt tool locations and add them to PATH when present.
if exist "C:\Users\Public\qt\Tools\CMake_64\bin\cmake.exe" set "PATH=C:\Users\Public\qt\Tools\CMake_64\bin;%PATH%"
if exist "C:\Users\Public\qt\Tools\Ninja\ninja.exe" set "PATH=C:\Users\Public\qt\Tools\Ninja;%PATH%"

REM Discover Qt if QT6_DIR is not set.
if not defined QT6_DIR (
    for %%V in (6.11.0 6.10.0 6.9.0 6.8.3 6.8.2 6.7.3 6.6.3 6.5.3) do (
        for %%C in (mingw_64 llvm-mingw_64 msvc2022_64 msvc2019_64) do (
            if exist "C:\Users\Public\qt\%%V\%%C\lib\cmake\Qt6\Qt6Config.cmake" (
                set "QT6_DIR=C:\Users\Public\qt\%%V\%%C"
                goto :found_qt
            )
        )
    )
    for %%V in (6.9.0 6.8.3 6.8.2 6.7.3 6.6.3 6.5.3) do (
        for %%C in (msvc2022_64 msvc2019_64 mingw_64) do (
            if exist "C:\Qt\%%V\%%C\lib\cmake\Qt6\Qt6Config.cmake" (
                set "QT6_DIR=C:\Qt\%%V\%%C"
                goto :found_qt
            )
        )
    )
    echo [windows] Warning: Qt6 not found in C:\Qt. Set QT6_DIR manually.
)

:found_qt
if defined QT6_DIR echo [windows] Using Qt: !QT6_DIR!

REM Prefer MinGW toolchains shipped with Qt when available.
if exist "C:\Users\Public\qt\Tools\mingw1310_64\bin\g++.exe" (
    set "PATH=C:\Users\Public\qt\Tools\mingw1310_64\bin;%PATH%"
    set "CMAKE_C_COMPILER=C:\Users\Public\qt\Tools\mingw1310_64\bin\gcc.exe"
    set "CMAKE_CXX_COMPILER=C:\Users\Public\qt\Tools\mingw1310_64\bin\g++.exe"
) else if exist "C:\Users\Public\qt\Tools\llvm-mingw1706_64\bin\g++.exe" (
    set "PATH=C:\Users\Public\qt\Tools\llvm-mingw1706_64\bin;%PATH%"
    set "CMAKE_C_COMPILER=C:\Users\Public\qt\Tools\llvm-mingw1706_64\bin\gcc.exe"
    set "CMAKE_CXX_COMPILER=C:\Users\Public\qt\Tools\llvm-mingw1706_64\bin\g++.exe"
)

REM Detect MSVC via vswhere, otherwise fall back to Ninja/MinGW if available.
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "GENERATOR=Ninja"
if exist "%VSWHERE%" (
    for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -property installationPath`) do (
        set "VS_PATH=%%i"
    )
    if defined VS_PATH (
        call "!VS_PATH!\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
    )
)

set "CMAKE_ARGS=-S ""%PROJECT_DIR%"" -B ""%BUILD_DIR%"" -G ""%GENERATOR%"" -DCMAKE_BUILD_TYPE=%BUILD_TYPE% -DLINK_INSIGHT=OFF -DBUILD_QDS_COMPONENTS=OFF"
if defined QT6_DIR (
    set "CMAKE_ARGS=%CMAKE_ARGS% -DCMAKE_PREFIX_PATH=""%QT6_DIR%"""
)
if defined CMAKE_C_COMPILER (
    set "CMAKE_ARGS=%CMAKE_ARGS% -DCMAKE_C_COMPILER=""%CMAKE_C_COMPILER%"" -DCMAKE_CXX_COMPILER=""%CMAKE_CXX_COMPILER%"""
)

cmake %CMAKE_ARGS%
if errorlevel 1 goto :error

cmake --build "%BUILD_DIR%" --config %BUILD_TYPE% --parallel
if errorlevel 1 goto :error

REM Bundle Qt DLLs next to the executable when windeployqt is available.
set "EXE=%BUILD_DIR%\neurx-codeApp.exe"
set "DEPLOY_DIR=%BUILD_DIR%\deploy"
set "WINDEPLOYQT="

if defined QT6_DIR (
    set "WINDEPLOYQT=%QT6_DIR%\bin\windeployqt6.exe"
    if not exist "!WINDEPLOYQT!" set "WINDEPLOYQT=%QT6_DIR%\bin\windeployqt.exe"
)

if defined WINDEPLOYQT if exist "!WINDEPLOYQT!" (
    echo [windows] Running windeployqt...
    if not exist "%DEPLOY_DIR%" mkdir "%DEPLOY_DIR%"
    copy "%EXE%" "%DEPLOY_DIR%\" >nul
    "!WINDEPLOYQT!" --qmldir "%PROJECT_DIR%" --dir "%DEPLOY_DIR%" "%DEPLOY_DIR%\neurx-codeApp.exe"
    echo.
    echo Distributable package: %DEPLOY_DIR%
) else (
    echo [windows] windeployqt not found. Skipping DLL bundling.
    echo           Set QT6_DIR to enable automatic deployment.
)

echo.
echo Build complete: %EXE%
echo Run: %EXE% [workspace-path]
echo.
set "RUN_EXE=%EXE%"
if exist "%DEPLOY_DIR%\neurx-codeApp.exe" set "RUN_EXE=%DEPLOY_DIR%\neurx-codeApp.exe"
echo Launching: %RUN_EXE% %PROJECT_DIR%
start "" "%RUN_EXE%" "%PROJECT_DIR%"
goto :eof

:error
echo.
echo BUILD FAILED. See errors above.
exit /b 1
