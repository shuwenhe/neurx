# Windows Setup Guide for NeurX Code

## Overview

This guide helps you set up OpenAI-compatible API keys on Windows for NeurX Code. The configuration supports SiliconFlow, OpenAI, and other OpenAI-compatible endpoints.

## Quick Start

### Option 1: Interactive Setup (Recommended)

Run the setup script to configure API keys interactively:

```batch
cd c:\path\to\neurx-code
scripts\setup-windows.bat
```

Or using make:

```batch
make setup
```

The script will guide you through:
1. Choosing your API provider (SiliconFlow, OpenAI, or custom)
2. Entering your API key
3. Setting up the API endpoint URL
4. Saving the configuration

### Option 2: Manual Environment Variables

#### Using Command Prompt (persistent):
```batch
setx SILICONFLOW_API_KEY "your-api-key-here"
setx SILICONFLOW_API_URL "https://api.siliconflow.cn/v1"
```

Then **restart your terminal/IDE** for changes to take effect.

#### Using PowerShell (persistent):
```powershell
[Environment]::SetEnvironmentVariable("SILICONFLOW_API_KEY", "your-key", "User")
[Environment]::SetEnvironmentVariable("SILICONFLOW_API_URL", "https://api.siliconflow.cn/v1", "User")
```

### Option 3: secrets.env File

Create or edit the file at:
```
%USERPROFILE%\.config\neurx-code\secrets.env
```

Example content (SiliconFlow):
```env
SILICONFLOW_API_KEY=sk-...your-key...
SILICONFLOW_API_URL=https://api.siliconflow.cn/v1
```

Or for OpenAI:
```env
OPENAI_API_KEY=sk-...your-key...
OPENAI_BASE_URL=https://api.openai.com/v1
```

## Supported API Providers

### SiliconFlow
- **Website**: https://siliconflow.cn/
- **API Base URL**: `https://api.siliconflow.cn/v1`
- **Environment Variables**:
  - `SILICONFLOW_API_KEY`
  - `SILICONFLOW_API_URL`

### OpenAI
- **Website**: https://openai.com/
- **API Base URL**: `https://api.openai.com/v1`
- **Environment Variables**:
  - `OPENAI_API_KEY`
  - `OPENAI_BASE_URL`

### Other OpenAI-Compatible Endpoints
- Set `OPENAI_COMPATIBLE_API_KEY` and `OPENAI_BASE_URL`

## Configuration Priority

The application checks for API configuration in this order:

1. **Environment Variables** (highest priority)
   - Checked first
   - Most secure for production

2. **UI Settings Panel** (second priority)
   - Configure within the running application
   - Settings are stored in QSettings

3. **secrets.env File** (lowest priority)
   - Fallback configuration file
   - Useful for GUI launches where environment variables don't propagate

## Build After Setup

Once API keys are configured:

```batch
REM Release build (recommended)
scripts\build-windows.bat Release

REM Or Debug build
scripts\build-windows.bat Debug

REM Or using make
make windows
```

## Complete Workflow

```batch
REM 1. Navigate to project directory
cd c:\Users\shuwen\agent\neurx-code

REM 2. Run setup script to configure API keys
scripts\setup-windows.bat

REM 3. Restart terminal for environment variables to take effect
REM    (close and reopen PowerShell/Command Prompt)

REM 4. Build the project
scripts\build-windows.bat Release

REM 5. Launch the built executable
build\windows-Release\neurx-codeApp.exe

REM 6. Verify API configuration in app Settings
REM    Settings -> LLM -> Check API Provider and Status
```

## Troubleshooting

### API Key Not Recognized
- **Restart your terminal/IDE** after setting environment variables
- Check precedence: env vars > UI settings > secrets.env
- Verify the key format starts with `sk-` (for most providers)

### secrets.env Not Loading
- Ensure file is at: `%USERPROFILE%\.config\neurx-code\secrets.env`
- Check file permissions (should be readable)
- Verify file format has no extra whitespace

### Environment Variable Not Working
- Use `echo %SILICONFLOW_API_KEY%` to verify it's set
- Check character encoding (avoid special Unicode characters)
- Try setting with `setx` for permanent persistence

### Build Fails Due to Missing Qt
- Set `QT6_DIR` environment variable manually:
  ```batch
  setx QT6_DIR "C:\Qt\6.7.3\msvc2022_64"
  ```
- Or use official Qt Installer to install Qt 6.5+

## Files Modified / Created

### New Files
- `scripts\setup-windows.bat` - Interactive setup script

### Modified Files
- `Makefile` - Added `make setup` target
- `scripts\build-windows.bat` - Added secrets.env loading
- `README.md` - Added comprehensive configuration section

## Integration with CI/CD

For GitHub Actions or other CI/CD systems:

```yaml
# Set as secrets in your CI/CD platform
SILICONFLOW_API_KEY: ${{ secrets.SILICONFLOW_API_KEY }}
SILICONFLOW_API_URL: https://api.siliconflow.cn/v1
```

Then the build script will automatically pick them up.

## References

- Original Mac setup: `scripts/setup-llm.sh`
- Configuration file template: `secrets.env.example`
- Application configuration: `neurx.config.example.toml`

## Support

For issues or questions:
1. Check [README.md](README.md) - LLM Configuration section
2. See `docs/LLM_INTEGRATION_SUMMARY.md`
3. Review `docs/TOOL_SYSTEM_SUMMARY.md`
