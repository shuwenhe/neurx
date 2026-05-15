# Neurx App Shell

This directory hosts the Qt-based cross-platform app shell for Neurx.

## Scope

- QML UI and event-loop shell based on Qt Quick
- Platform host integration for desktop/mobile targets
- Bridge layer that calls into Neurx core modules
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

## Directory Layout

- app: Qt app entry and top-level UI bootstrap
- bridge: ABI/FFI bridge between Qt app shell and Neurx core
- qml: Qt Quick shell views migrated into Neurx
- platform: platform-specific helpers and lifecycle wrappers
- tests: Qt shell tests
- scripts: cross-platform Qt6 setup helpers
