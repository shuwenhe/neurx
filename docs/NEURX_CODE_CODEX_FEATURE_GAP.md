# NeurX Code vs Codex Feature Gap

This document maps the most useful Codex capabilities onto the current
`neurx-code` architecture and proposes an implementation order.

It is intentionally pragmatic:

- focus on features that improve task completion rate
- reuse existing `neurx` controller / tool / workspace layers
- avoid copying Codex internals blindly when a lighter design is enough

## 1. Current NeurX Baseline

`neurx-code` already has the core skeleton of a local coding agent:

- QML desktop UI
- `AgentController` as the QML bridge
- `AgentEngine` with planner / executor / verifier objects
- provider adapters for OpenAI / Anthropic / Ollama
- tool registry with file / shell / search / patch tools
- workspace context, file tree, editor tabs, approvals

Relevant files:

- `src/bridge/AgentController.h`
- `src/bridge/AgentController.cpp`
- `src/agent/AgentEngine.h`
- `src/agent/AgentEngine.cpp`
- `src/agent/ToolRegistry.cpp`
- `docs/NEURX_CODE_CODEx_ARCHITECTURE.md`

This means NeurX is already beyond a plain chatbot. The main gap is not
"adding tools", but adding the orchestration and product layers that let the
agent sustain multi-step engineering work safely.

## 2. What Codex Adds Systemically

From the local `codex` repo, the main differentiators are:

- persistent threads and resumable task state
- structured streaming events and plan updates
- richer approval and permission controls
- terminal-like command execution lifecycle
- file-system event model and diff-oriented workflows
- skill / plugin / MCP extensibility
- embeddable SDK / app-server interfaces

These capabilities show up directly in the Codex protocol schema and SDKs:

- `Thread*`
- `TurnPlan*`
- `Permissions*`
- `CommandExec*`
- `Fs*`
- `Plugin*`
- `Skill*`
- `Mcp*`

## 3. High-Value Gaps

### 3.1 Persistent Threads and Task Resume

Codex capability:

- task threads are first-class
- turns can continue on the same thread
- sessions can be resumed later

NeurX today:

- one in-memory conversation loop
- no formal thread id
- no persisted turn state / plan / tool history

Why it matters:

- long coding tasks often require app restarts, model switching, or delayed approvals
- without persistence, NeurX loses execution context and user trust

Recommended implementation:

- add a `TaskSession` model with:
  - `sessionId`
  - message history
  - tool cards and results
  - active workspace root
  - current plan
  - latest verification state
- persist to JSON under an app-local sessions directory
- expose session list / resume / archive in `AgentController`

Suggested landing points:

- `src/agent/TaskSession.h/.cpp`
- `src/bridge/AgentController.*`
- new QML session sidebar

### 3.2 Plan Panel and Step Status

Codex capability:

- plan deltas
- step statuses
- goal tracking

NeurX today:

- prompt instructs the model to plan
- no durable plan object shown in UI
- no step state transitions

Why it matters:

- users need to see whether the agent is exploring, editing, testing, or blocked
- step visibility is one of the biggest upgrades from "chat UI" to "agent UI"

Recommended implementation:

- add a `PlanStep` structure:
  - `id`
  - `title`
  - `status` = `pending | in_progress | completed | blocked`
  - optional `detail`
- let the planner emit explicit plan updates
- render a persistent task plan panel in QML

Suggested landing points:

- `src/agent/Planner.*`
- `src/agent/AgentEngine.*`
- `content/ChatPanel.qml` or a new `content/TaskPlanPanel.qml`

### 3.3 Better Approvals and Permission Profiles

Codex capability:

- command approvals
- file-change approvals
- network approvals
- permission profiles
- session-scoped grants

NeurX today:

- binary tool approval flow
- auto-approve on/off
- no distinction between low-risk and high-risk actions

Why it matters:

- "approve tool" is too coarse once tools become more powerful
- users want a safe middle ground between constant prompts and full auto mode

Recommended implementation:

- split approval types into:
  - command execution
  - file modification
  - delete / move / rename
  - network / external API
- support scopes:
  - once
  - until task ends
  - always for this workspace
- add a lightweight permission profile object:
  - allow shell read-only
  - require approval for write
  - block destructive commands by default

Suggested landing points:

- `src/agent/Executor.*`
- `src/bridge/AgentController.*`
- `content/ToolApprovalDialog.qml`
- new `PermissionProfile` type

### 3.4 Terminal-Like Command Execution

Codex capability:

- structured command lifecycle
- output streaming
- terminal resize / terminate semantics

NeurX today:

- shell tool exists
- command lifecycle likely remains request/response oriented

Why it matters:

- build / test / lint loops are core coding-agent behavior
- users need to inspect partial output before a command completes

Recommended implementation:

- upgrade `ShellTool` to emit:
  - `started`
  - stdout delta
  - stderr delta
  - exit code
  - terminated state
- add interrupt support from UI
- keep recent command history per task session

Suggested landing points:

- `src/tools/ShellTool.*`
- `src/agent/Executor.*`
- `content/ToolCallCard.qml`

### 3.5 Diff-First Editing and Rollback

Codex capability:

- explicit file change review
- patch-oriented workflows
- safer edit audit trail

NeurX today:

- patch tool exists
- editor and workspace actions exist
- undo currently focuses on workspace operations, not full task checkpoints

Why it matters:

- patch-first editing is safer than full rewrite
- reviewability is essential once the agent edits multiple files

Recommended implementation:

- standardize agent edits around patch proposals
- show unified diff before apply
- store reversible checkpoints per task turn
- allow rollback to:
  - previous patch
  - previous turn
  - initial task state

Suggested landing points:

- `src/tools/PatchTool.*`
- `src/bridge/AgentController.*`
- new diff preview panel in QML

### 3.6 File-System Watch and Workspace Events

Codex capability:

- file read / write / metadata / watch notifications

NeurX today:

- has workspace index and file tree
- not yet structured around file change events

Why it matters:

- if external tools modify files, NeurX should detect and surface it
- file change events also help keep editor tabs and workspace summaries fresh

Recommended implementation:

- add `QFileSystemWatcher`-based workspace notifications
- refresh:
  - open document dirty state
  - file tree
  - workspace summary
  - search index

Suggested landing points:

- `src/context/WorkspaceContext.*`
- `src/context/WorkspaceIndex.*`
- `src/bridge/AgentController.*`

### 3.7 Skills / Plugins / MCP

Codex capability:

- plugins
- skills
- MCP server model
- tool discovery beyond static built-ins

NeurX today:

- tool registry is static and in-process
- no external tool source abstraction

Why it matters:

- static tools will limit NeurX quickly
- MCP is the most practical bridge to external ecosystems

Recommended implementation:

- phase 1:
  - declarative tool manifests
  - user-toggleable tool packs
- phase 2:
  - MCP client transport
  - external tool discovery
- phase 3:
  - installable "skill packs" with prompt + tool dependencies

Suggested landing points:

- `src/agent/ToolRegistry.*`
- new `src/tools/McpClient.*`
- new `src/skills/*`

### 3.8 Embeddable API / SDK Layer

Codex capability:

- TypeScript SDK
- Python SDK
- thread-based programmatic execution

NeurX today:

- desktop app only

Why it matters:

- external integrations become much easier once NeurX exposes a small stable API
- future IDE plugins, CLI frontends, or mobile companions can reuse the same agent core

Recommended implementation:

- expose a local RPC or WebSocket API:
  - start task
  - send turn
  - stream events
  - approve action
  - fetch workspace summary
- keep desktop UI as one client of that same API

Suggested landing points:

- new `src/server/*`
- bridge `AgentController` onto the same internal service interface

## 4. Feature Priority Matrix

### Tier 1: Highest ROI

Implement first:

- persistent task sessions
- visible plan panel with step status
- streaming shell output
- diff preview before patch apply
- richer approval scopes

Reason:

- these convert NeurX from "tool-augmented chat" into a usable code agent

### Tier 2: Strong Multipliers

Implement next:

- workspace file watching
- task checkpoints and rollback
- automatic verify loop for build / test / lint
- reusable permission profiles

Reason:

- these improve reliability, safety, and recovery

### Tier 3: Platform Expansion

Implement later:

- MCP tool integration
- skill/plugin layer
- local RPC / SDK
- multi-client orchestration

Reason:

- large upside, but more architectural surface area

## 5. Practical Roadmap

### Phase A: Make the Current Agent Durable

Target outcome:

- NeurX can start a task, survive restart, and resume where it left off

Deliverables:

- `TaskSession`
- session persistence
- plan sidebar
- command history per session

### Phase B: Make Execution Safer

Target outcome:

- users can review risky actions without micromanaging everything

Deliverables:

- approval categories
- diff review UI
- per-task permission scopes
- better rollback

### Phase C: Make Verification First-Class

Target outcome:

- NeurX can iterate on failures instead of stopping at first edit

Deliverables:

- verifier presets for build / test / lint
- structured command result classification
- auto-retry policy on fixable failures

### Phase D: Make the Tool System Open

Target outcome:

- NeurX is no longer limited to built-in tools

Deliverables:

- manifest-defined tools
- MCP bridge
- skill bundles

## 6. Concrete Next Steps for This Repo

If implementing immediately, the best next sequence is:

1. Add `TaskSession` persistence
2. Add `PlanStep` + task plan panel
3. Upgrade `ShellTool` to stream output
4. Make patch preview mandatory for agent edits
5. Add approval categories and scopes

That sequence fits the existing `neurx` architecture and does not require a
large rewrite.

## 7. What Not to Copy Directly

Some Codex features should be adapted, not cloned:

- full protocol breadth
  - NeurX does not need hundreds of message types on day one
- cloud-account login model
  - not necessary unless NeurX becomes a hosted platform
- plugin marketplace complexity
  - start with local manifests and MCP, not a marketplace

The right strategy is:

- copy the product principles
- simplify the system boundaries
- preserve the Qt / local-desktop strengths of NeurX

