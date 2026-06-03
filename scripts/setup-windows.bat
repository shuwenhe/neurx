@echo off
REM ─────────────────────────────────────────────────────────────────────────────
REM  NeurX Code — Windows LLM/API key setup script
REM  Usage: scripts\setup-windows.bat
REM
REM  This script helps configure API keys for OpenAI-compatible endpoints
REM  (SiliconFlow, OpenAI, or other compatible services) on Windows.
REM
REM  Supports three configuration methods (in priority order):
REM    1. Environment variables (persistent)
REM    2. UI Settings panel (from within the app)
REM    3. secrets.env file at ~/.config/neurx-code/secrets.env
REM ─────────────────────────────────────────────────────────────────────────────

setlocal EnableDelayedExpansion

REM Detect PowerShell for interactive prompts
set "POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

cls
echo.
echo     🚀 NeurX Code — Windows LLM Setup
echo     ==================================
echo.

REM ──────────────────────────────────────────────────────────────────────────
REM Step 1: Show current configuration
REM ──────────────────────────────────────────────────────────────────────────
echo Step 1: Checking current API configuration...
echo.

set "has_config=0"

if defined SILICONFLOW_API_KEY (
    echo   ✓ SILICONFLOW_API_KEY is set
    set "has_config=1"
)
if defined SILICONFLOW_API_URL (
    echo   ✓ SILICONFLOW_API_URL: !SILICONFLOW_API_URL!
    set "has_config=1"
)
if defined OPENAI_API_KEY (
    echo   ✓ OPENAI_API_KEY is set
    set "has_config=1"
)
if defined OPENAI_BASE_URL (
    echo   ✓ OPENAI_BASE_URL: !OPENAI_BASE_URL!
    set "has_config=1"
)
if defined OPENAI_COMPATIBLE_API_KEY (
    echo   ✓ OPENAI_COMPATIBLE_API_KEY is set
    set "has_config=1"
)
if defined NEURX_API_KEY (
    echo   ✓ NEURX_API_KEY is set
    set "has_config=1"
)

if "!has_config!"=="0" (
    echo   ⚠ No API keys configured yet
)
echo.

REM ──────────────────────────────────────────────────────────────────────────
REM Step 2: Choose configuration method
REM ──────────────────────────────────────────────────────────────────────────
echo Step 2: Choose configuration method
echo.
echo   [1] Set environment variables (persistent, recommended)
echo   [2] Create secrets.env file at %%USERPROFILE%%\.config\neurx-code\
echo   [3] Skip setup (configure manually in UI Settings)
echo.
set /p choice="Enter your choice [1-3]: "

if "!choice!"=="1" goto :config_env_vars
if "!choice!"=="2" goto :config_secrets_file
if "!choice!"=="3" goto :skip_setup
goto :config_env_vars

REM ──────────────────────────────────────────────────────────────────────────
REM Environment Variables Setup
REM ──────────────────────────────────────────────────────────────────────────
:config_env_vars
echo.
echo Step 2a: Configuring environment variables...
echo.
echo   API Provider options:
echo   [1] SiliconFlow (https://siliconflow.cn/)
echo   [2] OpenAI (https://openai.com/)
echo   [3] Other OpenAI-compatible endpoint
echo.
set /p provider="Enter provider [1-3]: "

if "!provider!"=="1" (
    set "provider_name=SiliconFlow"
    set "default_url=https://api.siliconflow.cn/v1"
    set "key_var=SILICONFLOW_API_KEY"
    set "url_var=SILICONFLOW_API_URL"
) else if "!provider!"=="2" (
    set "provider_name=OpenAI"
    set "default_url=https://api.openai.com/v1"
    set "key_var=OPENAI_API_KEY"
    set "url_var=OPENAI_BASE_URL"
) else (
    set "provider_name=OpenAI-compatible"
    set "key_var=OPENAI_COMPATIBLE_API_KEY"
    set "url_var=OPENAI_BASE_URL"
)

echo.
echo Step 2b: Enter your API key for !provider_name!
echo.
set /p api_key="Paste your API key (or press Enter to skip): "

if not "!api_key!"=="" (
    REM Use PowerShell to set persistent env var
    "%POWERSHELL%" -NoProfile -Command ^
        "[Environment]::SetEnvironmentVariable('!key_var!', '!api_key!', 'User')" >nul 2>&1
    
    if errorlevel 1 (
        echo.
        echo   ⚠ Could not set via PowerShell. Using setx instead...
        setx !key_var! "!api_key!"
    ) else (
        echo   ✓ Set !key_var! in user environment
    )
)

echo.
echo Step 2c: Enter API endpoint URL
if "!provider_name!"=="OpenAI-compatible" (
    echo   (e.g., https://api.yourendpoint.com/v1)
)
echo.
set /p api_url="Enter endpoint URL or press Enter for default: "
if "!api_url!"=="" set "api_url=!default_url!"

if not "!api_url!"=="" (
    "%POWERSHELL%" -NoProfile -Command ^
        "[Environment]::SetEnvironmentVariable('!url_var!', '!api_url!', 'User')" >nul 2>&1
    
    if errorlevel 1 (
        echo.
        echo   ⚠ Could not set via PowerShell. Using setx instead...
        setx !url_var! "!api_url!"
    ) else (
        echo   ✓ Set !url_var! in user environment
    )
)

echo.
echo   ✅ Environment variables configured!
echo.
echo   📌 IMPORTANT: Restart your terminal/IDE for changes to take effect.
echo.
goto :end

REM ──────────────────────────────────────────────────────────────────────────
REM secrets.env File Setup
REM ──────────────────────────────────────────────────────────────────────────
:config_secrets_file
echo.
echo Step 2a: Configuring secrets.env file...
echo.

set "CONFIG_DIR=%USERPROFILE%\.config\neurx-code"
set "SECRETS_FILE=!CONFIG_DIR!\secrets.env"

if not exist "!CONFIG_DIR!" (
    mkdir "!CONFIG_DIR!"
    echo   ✓ Created directory: !CONFIG_DIR!
)

echo.
echo   API Provider options:
echo   [1] SiliconFlow
echo   [2] OpenAI
echo   [3] Other OpenAI-compatible endpoint
echo.
set /p provider="Enter provider [1-3]: "

if "!provider!"=="1" (
    set "provider_name=SiliconFlow"
    set "default_url=https://api.siliconflow.cn/v1"
) else if "!provider!"=="2" (
    set "provider_name=OpenAI"
    set "default_url=https://api.openai.com/v1"
) else (
    set "provider_name=OpenAI-compatible"
    set "default_url=https://api.yourendpoint.com/v1"
)

echo.
echo Step 2b: Enter your API key
echo.
set /p api_key="Paste your API key: "

if "!api_key!"=="" (
    echo   ❌ API key cannot be empty!
    goto :config_secrets_file
)

echo.
echo Step 2c: Enter API endpoint URL
echo   (Default: !default_url!)
echo.
set /p api_url="Enter endpoint URL or press Enter for default: "
if "!api_url!"=="" set "api_url=!default_url!"

REM Create secrets.env file
(
    echo # NeurX Code Secrets Configuration
    echo # Provider: !provider_name!
    echo # Generated: %date% %time%
    echo # Gitignored - do not commit this file
    echo.
    echo SILICONFLOW_API_KEY=!api_key!
    echo SILICONFLOW_API_URL=!api_url!
    echo OPENAI_API_KEY=!api_key!
    echo OPENAI_BASE_URL=!api_url!
    echo OPENAI_COMPATIBLE_API_KEY=!api_key!
) > "!SECRETS_FILE!"

echo.
echo   ✓ Created secrets.env at: !SECRETS_FILE!
echo.
echo   📋 File contents:
echo   ─────────────────────────────────────────
type "!SECRETS_FILE!"
echo   ─────────────────────────────────────────
echo.
goto :end

REM ──────────────────────────────────────────────────────────────────────────
REM Skip Setup
REM ──────────────────────────────────────────────────────────────────────────
:skip_setup
echo.
echo   ℹ Manual configuration:
echo.
echo   1. Environment Variables (recommended for production):
echo      - Use: setx VAR_NAME "value"
echo      - Then restart your terminal
echo.
echo   2. secrets.env file:
echo      - Location: %USERPROFILE%\.config\neurx-code\secrets.env
echo      - See: secrets.env.example
echo.
echo   3. UI Settings:
echo      - Launch the app and configure in Settings panel
echo.
goto :end

REM ──────────────────────────────────────────────────────────────────────────
REM Final Instructions
REM ──────────────────────────────────────────────────────────────────────────
:end
echo.
echo ✅ Setup complete!
echo.
echo Next steps:
echo   1. If you set environment variables, restart your terminal/IDE
echo   2. Run the build: scripts\build-windows.bat Release
echo   3. Launch the app and verify API configuration in Settings
echo.
echo For troubleshooting:
echo   - Check: README.md (LLM configuration section)
echo   - Docs: docs\LLM_INTEGRATION_SUMMARY.md
echo.

endlocal
exit /b 0
