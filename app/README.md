# Neurx App Shell

This directory hosts the Qt-based cross-platform app shell for Neurx.

## Scope

- QML UI and event-loop shell based on Qt Quick
- Platform host integration for desktop/mobile targets
- Bridge layer that calls into Neurx core modules
- Next.js web frontend for browser access
- HTTP backend routing to S-based model-facing logic
- Selectively migrated UI structure from `/app/neurx-agent/app` without copying its standalone core runtime
- Lightweight `AgentListModel` and `LogModel` adapted inside `app/bridge` for QML panels

## Suggested Build

```bash
cmake -S . -B build
cmake --build build
./build/neurx_app
```

## Environment Setup

- Linux/macOS: run `bash scripts/setup_qt_env.sh`, then `source .env.qt`
- Windows PowerShell: run `powershell -ExecutionPolicy Bypass -File .\\scripts\\setup_qt_env.ps1`

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

The same fields can also be edited from the QML app shell after launch.

## Directory Layout

- app: Qt app entry and top-level UI bootstrap
- bridge: ABI/FFI bridge between Qt app shell and Neurx core
- qml: Qt Quick shell views migrated into Neurx
- platform: platform-specific helpers and lifecycle wrappers
- frontend: Next.js browser UI for Neurx LLM access
- backend: S-based backend core and thin gateway helpers
- tests: Qt shell tests
- scripts: cross-platform Qt6 setup helpers

## App Frontend

The Next.js frontend under `app/frontend/` expects:

- `NEURX_BACKEND_URL=http://127.0.0.1:18080/neurx/api/chat`

The API route forwards chat requests to that backend URL. The URL may point to any host-level service that wraps `app/backend/serve.s`.
