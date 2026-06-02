# neurx-code

## LLM configuration (SiliconFlow / OpenAI-compatible)

NeurX Code supports OpenAI-compatible chat-completions endpoints (including SiliconFlow).
You can configure endpoint + API key via environment variables (recommended) so secrets are not stored in local settings.

Supported environment variables (first non-empty wins):

- Endpoint:
  - `SILICONFLOW_API_URL` (e.g. `https://api.siliconflow.cn/v1/chat/completions`)
  - `SILICONFLOW_API_BASE_URL` (e.g. `https://api.siliconflow.cn` or `https://api.siliconflow.cn/v1`)
  - `OPENAI_API_URL`, `OPENAI_BASE_URL`

- API key:
  - `SILICONFLOW_API_KEY`
  - `OPENAI_API_KEY`
  - `OPENAI_COMPATIBLE_API_KEY`

Notes:
- If you provide a base URL, NeurX will normalize it to a chat-completions URL.
- When these env vars are set, NeurX will treat them as runtime-only and will not persist them into QSettings.

### secrets.env (for GUI launches on macOS)

If you start the app via Finder/`open`, environment variables may not propagate. You can store secrets in:

- `~/.config/neurx-code/secrets.env`

Format is simple dotenv:

```env
SILICONFLOW_API_URL=https://api.siliconflow.cn/v1/chat/completions
SILICONFLOW_API_KEY=...your key...
```

Precedence: environment variables > Settings(UI) > secrets.env.

Architecture notes for the Codex-style agent refactor are in:

- [docs/NEURX_CODE_CODEx_ARCHITECTURE.md](/home/shuwen/shuwen/ai/neurx/docs/NEURX_CODE_CODEx_ARCHITECTURE.md)
- [docs/AI_PROJECT_FEATURE_ROADMAP.md](/home/shuwen/shuwen/ai/neurx/docs/AI_PROJECT_FEATURE_ROADMAP.md)
- [docs/AI_PROJECT_IMPLEMENTATION_PLAN.md](/home/shuwen/shuwen/ai/neurx/docs/AI_PROJECT_IMPLEMENTATION_PLAN.md)
