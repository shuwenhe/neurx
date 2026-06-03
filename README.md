# neurx-code

## LLM configuration (SiliconFlow / OpenAI-compatible)

NeurX Code supports OpenAI-compatible chat-completions endpoints (including SiliconFlow).
You can configure endpoint + API key via environment variables (recommended) so secrets are not stored in local settings.

### Quick Setup

#### macOS / Linux
```bash
# Run the interactive setup script
./scripts/setup-llm.sh
# Or:
make setup
```

#### Windows
```batch
REM Run the interactive setup script
scripts\setup-windows.bat
REM Or:
make setup
```

### Configuration Methods (Priority Order)

Configuration is checked in this order:
1. **Environment variables** (highest priority)
2. **UI Settings panel** (within the app)
3. **secrets.env file** (lowest priority)

### Environment Variables

Supported environment variables for API endpoint:

- `SILICONFLOW_API_URL` (e.g. `https://api.siliconflow.cn/v1/chat/completions`)
- `SILICONFLOW_API_BASE_URL` (e.g. `https://api.siliconflow.cn` or `https://api.siliconflow.cn/v1`)
- `OPENAI_API_URL`, `OPENAI_BASE_URL`

Supported environment variables for API key (first non-empty wins):

- `SILICONFLOW_API_KEY`
- `OPENAI_API_KEY`
- `OPENAI_COMPATIBLE_API_KEY`
- `NEURX_API_KEY`

#### Setting Environment Variables on Windows

**Option A: Command Prompt (persistent)**
```batch
setx SILICONFLOW_API_KEY "your-api-key-here"
setx SILICONFLOW_API_URL "https://api.siliconflow.cn/v1"
```

**Option B: PowerShell (persistent)**
```powershell
[Environment]::SetEnvironmentVariable("SILICONFLOW_API_KEY", "your-api-key-here", "User")
[Environment]::SetEnvironmentVariable("SILICONFLOW_API_URL", "https://api.siliconflow.cn/v1", "User")
```

After setting environment variables, **restart your terminal or IDE** for changes to take effect.

### secrets.env Configuration File

If you start the app from a GUI launcher, environment variables may not propagate. You can store secrets in:

**Location:**
- Unix/Linux/macOS: `~/.config/neurx-code/secrets.env`
- Windows: `%USERPROFILE%\.config\neurx-code\secrets.env` (typically `C:\Users\<YourUsername>\.config\neurx-code\secrets.env`)

**Format (simple dotenv):**
```env
# SiliconFlow configuration
SILICONFLOW_API_URL=https://api.siliconflow.cn/v1
SILICONFLOW_API_KEY=sk-...your-key...

# OpenAI configuration (alternative)
OPENAI_API_KEY=sk-...your-key...
OPENAI_BASE_URL=https://api.openai.com/v1
```

**Notes:**
- This file is gitignored and will not be committed
- If you provide a base URL, NeurX will normalize it to a chat-completions URL
- When environment variables are set, they are treated as runtime-only and will not persist into QSettings

### Building on Windows

```batch
REM 1. First-time setup (configure API keys)
scripts\setup-windows.bat

REM 2. Build the project
scripts\build-windows.bat Release

REM Or use make:
make setup
make windows
```

### Architecture References

See documentation files for implementation details:

- [docs/NEURX_CODE_CODEx_ARCHITECTURE.md](/home/shuwen/shuwen/ai/neurx/docs/NEURX_CODE_CODEx_ARCHITECTURE.md)
- [docs/AI_PROJECT_FEATURE_ROADMAP.md](/home/shuwen/shuwen/ai/neurx/docs/AI_PROJECT_FEATURE_ROADMAP.md)
- [docs/AI_PROJECT_IMPLEMENTATION_PLAN.md](/home/shuwen/shuwen/ai/neurx/docs/AI_PROJECT_IMPLEMENTATION_PLAN.md)
