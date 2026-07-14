# NeurX Code Codex-Style Architecture

This document describes the target architecture for turning `neurx-code` from a tool-capable chat app into a Codex-style code agent.

## 1. Current State

The project already has the basic execution chain:

- `QML UI` -> `AgentController` -> `AgentEngine` -> `LLMProvider` -> `Tools`
- Tool execution exists for:
  - file operations
  - shell commands
  - search
- Provider adapters already exist for:
  - OpenAI
  - Anthropic
  - Ollama

That is enough for a chatbot with tools, but not yet enough for a robust code agent.

## 2. What Codex-Style Requires

The missing architecture layers are:

1. Workspace understanding
2. Patch-based editing
3. Plan / execute / verify loop
4. Safety and rollback
5. Persistent task memory
6. Stronger provider normalization
7. Rich review UI

## 3. Target Layering

```text
┌──────────────────────────────────────────────────────────────┐
│ UI Layer                                                     │
│  QML views, diff preview, approval dialogs, task panel       │
└──────────────────────────────────────────────────────────────┘
                           │
┌──────────────────────────────────────────────────────────────┐
│ Controller Layer                                             │
│  AgentController, UI state, workspace binding, approvals     │
└──────────────────────────────────────────────────────────────┘
                           │
┌──────────────────────────────────────────────────────────────┐
│ Agent Orchestration Layer                                    │
│  Planner, executor, verifier, retry policy, turn state      │
└──────────────────────────────────────────────────────────────┘
                           │
┌──────────────────────────────────────────────────────────────┐
│ Workspace Intelligence Layer                                 │
│  file index, symbol index, git state, recent files, search   │
└──────────────────────────────────────────────────────────────┘
                           │
┌──────────────────────────────────────────────────────────────┐
│ Tool Layer                                                   │
│  file tools, patch tools, shell tools, search tools, tests   │
└──────────────────────────────────────────────────────────────┘
                           │
┌──────────────────────────────────────────────────────────────┐
│ Provider Layer                                               │
│  OpenAI / Anthropic / Ollama adapters and protocol mapping   │
└──────────────────────────────────────────────────────────────┘
```

## 4. Proposed Module Split

### 4.1 App Layer

Keep only startup and QML bootstrapping here.

Recommended contents:

- `main.cpp`
- Qt environment setup
- engine/controller wiring

### 4.2 Controller Layer

Owns UI-facing state and delegates into the agent engine.

Responsibilities:

- current provider/model
- workspace path
- message list
- tool approval state
- streaming text state
- bridging to QML

### 4.3 Agent Layer

This is the core of the coding agent.

Split into:

- `Planner`
  - decides what to do next
  - converts user intent into steps
- `Executor`
  - performs tool calls
  - manages tool approvals
- `Verifier`
  - runs tests
  - evaluates command output
  - decides whether the change is done
- `TurnManager`
  - keeps track of a single task turn
  - retries and iteration limits

Current `AgentEngine` is doing all of this at once. That works for now, but it should be split.

### 4.4 Workspace Layer

This layer should provide structured project context.

Recommended contents:

- repository root
- git branch and status
- recent files
- file metadata cache
- symbol index
- optional semantic index

Your existing `WorkspaceContext` is the right place to grow this.

### 4.5 Tool Layer

Current tools should be extended into a more Codex-like set:

- `file_system`
  - read file
  - write file
  - list directory
  - create / delete / move
- `patch`
  - preview diff
  - apply diff
  - revert checkpoint
- `search`
  - grep search
  - find files
  - semantic search
- `run_command`
  - build
  - test
  - lint
  - git status / diff / checkout operations

The important difference is that the agent should prefer `patch` over full file rewrites.

### 4.6 Provider Layer

Each model provider should be normalized into one internal contract.

The internal contract should represent:

- streamed text deltas
- streamed tool calls
- final assistant message
- stop reason
- token usage
- provider errors

That lets the agent loop stay provider-agnostic.

## 5. Recommended Repository Layout

```text
neurx-code/
  src/
    app/
      main.cpp
      AppBootstrap.cpp
      AppBootstrap.h
    controller/
      AgentController.cpp
      AgentController.h
    agent/
      AgentEngine.cpp
      AgentEngine.h
      Planner.cpp
      Planner.h
      Executor.cpp
      Executor.h
      Verifier.cpp
      Verifier.h
    workspace/
      WorkspaceContext.cpp
      WorkspaceContext.h
      WorkspaceIndex.cpp
      WorkspaceIndex.h
    llm/
      LLMProvider.cpp
      LLMProvider.h
      providers/
        OpenAIProvider.cpp
        AnthropicProvider.cpp
        OllamaProvider.cpp
    tools/
      BaseTool.h
      ToolRegistry.cpp
      ToolRegistry.h
      FileSystemTool.cpp
      ShellTool.cpp
      SearchTool.cpp
      PatchTool.cpp
      TestTool.cpp
    ui/
      QmlBridge types only
  docs/
    NEURX_CODE_CODEx_ARCHITECTURE.md
```

This does not need to be implemented all at once. It is the target shape.

## 6. CMake Target Split

Recommended CMake refactor:

- `neurx_core`
  - agent, workspace, tools, llm
- `neurx_ui`
  - controller and QML bridge
- `neurx-codeApp`
  - app entry point

Why:

- faster incremental builds
- cleaner dependencies
- easier unit testing
- clearer ownership boundaries

## 7. Priority Order

If you want the shortest path to Codex-like behavior, implement in this order:

1. Patch-based editing and diff preview
2. Workspace indexing and file metadata cache
3. Planner / executor / verifier split
4. Checkpoint and rollback support
5. Test-result driven repair loop
6. Persistent task memory
7. UI review panels

## 8. Practical Minimum

The smallest version that feels like Codex needs:

- file tree and search
- patch application
- shell execution
- tool approval
- git-aware rollback
- auto-run tests after edits
- retry loop when tests fail

Without those, the app remains a generic agent chat client.

