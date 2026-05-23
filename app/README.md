# Neurx App Shell

This directory hosts the Qt-based cross-platform app shell for Neurx.

## Scope

- QML UI and event-loop shell based on Qt Quick
- Platform host integration for desktop/mobile targets
- Bridge layer that calls into Neurx core modules
- Next.js web UI for browser access
- HTTP backend routing to S-based model-facing logic
- Selectively migrated UI structure from `/app/neurx-agent/app` without copying its standalone core runtime
- Lightweight `AgentListModel` and `LogModel` adapted inside `app/bridge` for QML panels

## Suggested Build

### Quick Start with Local LLM

To run the Qt app with the local NeurX LLM backend on Linux:

```bash
make linux
```

This will:
1. Start the Node.js backend on `http://127.0.0.1:18080`
2. Build the Qt app (if needed)
3. Launch the app with LLM enabled

For other hosts, use the explicit platform target:

```bash
make windows
make macos
```

### Manual Build

```bash
cmake -S . -B build
cmake --build build
./build/neurx_app
```

## Environment Setup

- Linux/macOS: run `bash scripts/setup_qt_env.sh`, then `source .env.qt`
- Windows PowerShell: run `powershell -ExecutionPolicy Bypass -File .\\scripts\\setup_qt_env.ps1`
- On Debian/Ubuntu, the app also needs the Qt QML runtime modules used by the shell, especially `qml6-module-qtquick-templates`

See [scripts/README.md](scripts/README.md) for full examples.

## Local Model

The app shell can route agent prompts to a local model endpoint before falling back to the existing Neurx runtime.

Supported config fields:

- `NEURX_LLM_ENABLED=1`
- `NEURX_LLM_BACKEND=openai` or `ollama`
- `NEURX_LLM_BASE_URL=http://127.0.0.1:8000`
- `NEURX_LLM_MODEL=llama3.1`
- `NEURX_LLM_CHAT_PATH=/v1/chat/completions` or `/api/chat`
- `NEURX_LLM_API_KEY` for OpenAI-compatible servers that require one
- `NEURX_BACKEND_CHECKPOINT_ROOT=/home/shuwen/shuwen/neurx/artifacts/checkpoints`
- `NEURX_BACKEND_CHECKPOINT_FILE=/home/shuwen/shuwen/neurx/artifacts/checkpoints/run_20260518_001/step_0001000/latest/gpt_large_pretrain.neurx`

The same fields can also be edited from the QML app shell after launch.

If `NEURX_BACKEND_CHECKPOINT_ROOT` is set, the Qt shell discovers `.neurx` snapshots under that tree and offers them in the local model picker. When `NEURX_BACKEND_CHECKPOINT_FILE` is set, the shell prefers that checkpoint path. The agent panel no longer shows Ollama preset models when checkpoint snapshots are available.

When `run_with_llm.sh` starts the local backend, it will automatically prefer the newest `.neurx` file under `artifacts/checkpoints/` and expose it through the backend response.

## Native S Agent

The app shell also includes a `Native S` entry that runs `neurx/agent/*.s` directly through the S toolchain.

Recommended setup:

- `NEURX_S_BINARY=C:\Users\shuwen\s\bin\s.cmd` on Windows
- `NEURX_S_BINARY=/path/to/s` on Linux/macOS

When `Runtime.run_native_s_agent_async(...)`, `export_agent_skill_snapshot(...)`, or `export_agent_trajectory(...)` is triggered, the bridge will:

1. resolve `NEURX_S_BINARY`
2. compile the NeurX S runtime through `workflows/agent/common/compile_runtime.sh`
3. execute the generated temporary S runner with the same S binary

If the S binary is missing, the app returns a `runtime_exec_failed` error with the setup hint.
Set `NEURX_S_ALWAYS_COMPILE=1` if you want the bridge to re-run the S runtime compilation on every native-agent request instead of reusing the per-session cache.

## Directory Layout

- app: Qt app entry and top-level UI bootstrap
- bridge: ABI/FFI bridge between Qt app shell and Neurx core
- qml: Qt Quick shell views migrated into Neurx
- platform: platform-specific helpers and lifecycle wrappers
- web: Next.js browser UI for NeurX LLM access
- service: S-based backend core and thin gateway helpers
- tests: Qt shell tests
- scripts: cross-platform Qt6 setup helpers

## Code Agent Skeleton

The app now includes an incremental coding-agent scaffold under `app/service/`:

- `code_agent_runner.sh`: first-stage code task runner
- `code_templates.sh`: trivial code-template fallback
- `tools/read.sh`, `tools/search.sh`, `tools/write.sh`, `tools/build.sh`, `tools/test.sh`: workspace tools
- `CODE_AGENT_ARCHITECTURE.md`: migration path from prompt/response shell to coding agent

Current behavior:

- the Qt bridge tries `code_agent_runner.sh` first for code tasks
- runner-completed responses return directly to the UI
- unhandled tasks fall through to the existing model chat path

## App Web

The Next.js web app under `app/web/` expects:

- `NEURX_BACKEND_URL=http://127.0.0.1:18080/neurx/api/chat`

The API route forwards chat requests to that backend URL. The URL may point to any host-level service that wraps `app/service/serve.s`.
