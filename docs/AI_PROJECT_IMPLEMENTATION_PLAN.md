# AI Project Implementation Plan for NeurX

This is the concrete follow-up to the feature roadmap. It turns the reusable
ideas from `ai/*` into a file-level plan for `neurx`.

The guiding rule is simple: every change should improve task completion for a
desktop coding agent. If a feature does not help the agent plan, edit, verify,
remember, or recover, it should stay out of the core.

## 1. Current Baseline

NeurX already has the following pieces in place:

- QML desktop UI
- `AgentController` bridge
- `AgentEngine` planning / execution / verification loop
- tool registry for file, patch, search, shell, memory, todo, and checkpoint
- workspace context and index
- persisted task session
- checkpoint preview and rollback UI

That means the next work should not be "add more tools blindly". The highest
value now is to make the agent more stateful, more explainable, and safer to
use.

## 2. Phase 1: Finish the core coding-agent loop

This phase should be the first priority.

### 2.1 Make task sessions first-class

Goal:

- resume a task after app restart
- inspect recent task state
- keep chat, todo, tool calls, and verification together

Target files:

- `src/agent/TaskSession.h`
- `src/agent/TaskSession.cpp`
- `src/bridge/AgentController.h`
- `src/bridge/AgentController.cpp`
- `content/App.qml`

Recommended work:

- add a session list view
- add "resume last session" and "archive session" actions
- persist plan steps alongside messages and todo items

### 2.2 Expand plan visibility

Goal:

- show what the agent is doing right now
- make "planning", "executing", and "verifying" obvious to the user

Target files:

- `src/agent/Planner.h`
- `src/agent/Planner.cpp`
- `src/agent/AgentEngine.h`
- `src/agent/AgentEngine.cpp`
- `content/TaskPlanPanel.qml`

Recommended work:

- add explicit plan step updates from the planner
- show statuses: `pending`, `in_progress`, `completed`, `blocked`
- sync plan status into the persisted task session

### 2.3 Strengthen edit/verify flow

Goal:

- prefer patch-based edits over full rewrites
- verify changes before the agent claims success

Target files:

- `src/tools/PatchTool.h`
- `src/tools/PatchTool.cpp`
- `src/tools/FileSystemTool.h`
- `src/tools/FileSystemTool.cpp`
- `src/agent/Executor.h`
- `src/agent/Executor.cpp`

Recommended work:

- keep patch preview as the default edit path
- make verification output explicit in the chat flow
- preserve the current checkpoint before mutating writes

### 2.4 Keep rollback visible and safe

Goal:

- make destructive actions recoverable
- show exactly what would be restored

Target files:

- `src/tools/CheckpointManager.h`
- `src/tools/CheckpointManager.cpp`
- `src/tools/CheckpointTool.h`
- `src/tools/CheckpointTool.cpp`
- `content/CheckpointRestoreDialog.qml`
- `content/MessageBubble.qml`

Recommended work:

- add richer file preview for rollback
- make rollback messages stand out in the chat stream
- preserve the current confirmation dialog before restore

## 3. Phase 2: Add durable knowledge and extensibility

This phase should come after the core loop is stable.

### 3.1 Durable memory

Goal:

- remember facts that survive a session
- let the agent query and update memory explicitly

Target files:

- `src/tools/MemoryTool.h`
- `src/tools/MemoryTool.cpp`
- `src/agent/TaskSession.h`
- `src/agent/TaskSession.cpp`
- `src/bridge/AgentController.cpp`

Recommended work:

- separate session memory from durable memory
- expose a clear UI for memory entries
- keep provenance in every stored note

### 3.2 External tool registry

Goal:

- allow plugin-like growth without hardcoding everything
- make third-party tools look like native tools

Target files:

- `src/agent/ToolRegistry.h`
- `src/agent/ToolRegistry.cpp`
- new `src/tools/*` wrappers as needed

Recommended work:

- add a manifest-driven registry for external tools
- support enable/disable and inspection
- keep permission metadata with each tool

### 3.3 Better search

Goal:

- find the right file or fact quickly
- separate discovery from reading

Target files:

- `src/tools/SearchTool.h`
- `src/tools/SearchTool.cpp`
- `src/context/WorkspaceIndex.h`
- `src/context/WorkspaceIndex.cpp`

Recommended work:

- make search results provenance-rich
- add optional web search and scraper integration
- keep code search and memory search separate

## 4. Phase 3: Broader product surface

These are valuable, but they should not block the coding-agent core.

### 4.1 Cron and reminders

Good fit if you want automated maintenance tasks.

Target files:

- new `src/tools/CronTool.*`
- `src/bridge/AgentController.*`

### 4.2 Voice and desktop companion

Good fit if you want NeurX to become a hands-free assistant.

Target files:

- new voice capture / TTS modules
- `content/App.qml`
- `src/main.cpp`

### 4.3 MCP installation and lifecycle

Good fit if you want NeurX to grow a tool ecosystem.

Target files:

- new MCP registry module
- `src/agent/ToolRegistry.*`
- `src/bridge/AgentController.*`

### 4.4 Remote or multi-channel control

Good fit only if NeurX should be controlled from outside the desktop app.

Target files:

- new local RPC layer
- `src/main.cpp`
- `src/bridge/AgentController.*`

## 5. Recommended Build Order

If the goal is to maximize useful progress, do the work in this order:

1. Session resume + plan visibility
2. Patch-first edit + verification loop
3. Checkpoint polish + rollback confidence
4. Durable memory
5. Tool extensibility
6. Search improvements
7. Cron / voice / remote surfaces

## 6. What Not To Do Yet

Avoid these until the core agent loop is solid:

- a full Dify-style workflow canvas
- a full multi-channel gateway
- a large voice-first product rewrite
- a giant plugin marketplace before the tool registry is stable

Those ideas are real, but they are product expansions, not the next best step
for `neurx`.
