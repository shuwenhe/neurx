# NeurX Agent Capability Gap

This note describes what `neurx/agent/*.s` currently implements, what is still missing compared with a modern GPT/Codex-style coding agent, and a practical roadmap to close the gap.

## Current State

The current NeurX agent is a lightweight local runtime with these pieces:

- runtime state, step loop, and budget tracking in [runtime.s](/c:/Users/shuwen/neurx/agent/runtime.s:1)
- deterministic task progression in [planner.s](/c:/Users/shuwen/neurx/agent/planner.s:1)
- short and long memory in [memory.s](/c:/Users/shuwen/neurx/agent/memory.s:1)
- tool registration and per-tool timeout/retry metadata in [tool_registry.s](/c:/Users/shuwen/neurx/agent/tool_registry.s:1)
- action execution and route selection in [executor.s](/c:/Users/shuwen/neurx/agent/executor.s:1)
- trace export, replay, skill synthesis, promotion, and retirement in [trace.s](/c:/Users/shuwen/neurx/agent/trace.s:1), [skill_registry.s](/c:/Users/shuwen/neurx/agent/skill_registry.s:1), and [skill_executor.s](/c:/Users/shuwen/neurx/agent/skill_executor.s:1)

It is already a real agent runtime, but it is not yet a full GPT/Codex-class general-purpose agent platform.

## What Exists Today

### Implemented

- step-by-step execution loop
- explicit plan state and task queue
- bounded execution budget with stall detection
- tool registry with enable/disable, timeout, and retry counters
- local retrieval from known files and indexes
- optional model-backed `infer` stage when a checkpoint/model path is available
- memory persistence and checkpoint restore
- skill snapshotting, replay, promotion, retirement, and activation
- trajectory export for inspection

### Partially Implemented

- `search`
  The tool is registered, but the current executor mostly emits a synthetic observation rather than performing real search.
- `write`
  The route and observation exist, but the current `executor.s` path records intent instead of actually applying file edits.
- `delete`
  The route and observation exist, but the current `executor.s` path records intent instead of actually deleting files.
- `retrieve`
  Retrieval is real, but narrow. It reads repo-local files or an index path, not a general search corpus or browser.
- `skills`
  Skill promotion and retirement exist, but skill execution is still mostly labeling and activation logic, not reusable parameterized tool programs.

## Main Differences From A GPT/Codex Agent

### 1. Decision policy

NeurX currently routes tasks with keyword heuristics in [executor.s](/c:/Users/shuwen/neurx/agent/executor.s:50).

GPT/Codex-style agents usually:

- decide actions with the model itself
- choose between tools dynamically from richer context
- revise plans from tool outcomes, not only from fixed transitions

NeurX today is primarily rule-driven, not model-driven.

### 2. Tool execution model

NeurX currently knows about tools, but several tools are only abstract actions.

GPT/Codex-style agents usually have:

- structured tool schemas
- argument validation
- real execution side effects
- tool result parsing and follow-up reasoning
- permissions and approval checkpoints

NeurX today has registry metadata and control flow, but not a full tool-calling substrate.

### 3. Environment reach

NeurX is mostly repo-local and file-local.

GPT/Codex-style agents often have:

- shell execution
- repository inspection
- browser/web access
- test/build loops
- file editing with diffs
- optional GUI/computer use

NeurX today has only a small subset of that environment reach.

### 4. Planning depth

NeurX planning is explicit but narrow: `analyze -> plan -> retrieve/infer -> verify -> finalize` with route-specific branches in [planner.s](/c:/Users/shuwen/neurx/agent/planner.s:115).

GPT/Codex-style agents typically support:

- deeper branching plans
- tool-generated subtasks
- dynamic replanning from arbitrary observations
- richer recovery after failure

NeurX today has a solid finite-state pipeline, not open-ended long-horizon planning.

### 5. Safety and control

NeurX currently has budget limits and tool disable-on-failure behavior.

GPT/Codex-style agents generally add:

- explicit approvals for destructive actions
- sandbox boundaries
- scoped filesystem/network permissions
- audit logs tied to concrete actions

NeurX today has some control signals, but not a full safety model.

## Capability Matrix

| Capability | NeurX agent today | GPT/Codex-class agent |
| --- | --- | --- |
| Step loop | Yes | Yes |
| Memory | Yes | Yes |
| Checkpoint restore | Yes | Often |
| Skill promotion/retirement | Yes | Sometimes |
| Model-driven tool choice | No | Yes |
| Real structured tool calls | Partial | Yes |
| Real file write/delete execution | No in `neurx/agent` | Yes |
| Shell/build/test execution | No in `neurx/agent` | Yes |
| Web browsing/search | No | Often |
| Parallel tool use | No | Often |
| Multimodal input/output | No | Sometimes |
| Approval and sandbox model | No | Yes |

## Highest-Priority Gaps

### P0: turn abstract tools into real tools

The fastest path to usefulness is to make `write`, `delete`, `build`, and `test` real executor-backed tools.

Target:

- `write_file(path, content)` applies repo-scoped edits
- `delete_path(path, recursive)` performs real guarded deletes
- `run_build(command)` executes builds with captured output
- `run_test(command)` executes tests with captured output

Without this, the agent is mostly describing actions instead of doing them.

### P1: introduce structured actions

Replace plain route strings and implicit task meaning with a small action schema such as:

```text
tool=write_file
args.path=app/qml/AppShell.qml
args.content=...
```

This gives the planner, runtime, and trace a stable protocol for real tool execution.

### P2: let the model choose or refine actions

Keep heuristic routing as fallback, but let a model propose:

- next task
- tool name
- tool arguments
- stop/continue decision

This is the biggest difference between the current runtime and a GPT/Codex-style agent.

### P3: add build/test/review loops

For coding work, the agent should be able to:

- inspect files
- patch files
- build
- run tests
- summarize failures
- retry with updated plan

This is where the current S agent and the app-side coding agent can converge.

### P4: add approvals and safety rails

Before destructive or expensive actions:

- require explicit approval
- restrict delete/write to approved roots
- record exact action args in trace

## Recommended Roadmap

### Phase 1: make the runtime operational

- add real `read_file`, `list_files`, `search_files`, `write_file`, `delete_path`
- add `run_build` and `run_test`
- keep heuristics, but make actions real

Outcome:
The agent becomes a practical local coding agent.

### Phase 2: add structured planning

- introduce an action object model
- record structured tool args in trace
- add validator functions for tool arguments
- make replanning depend on tool result classes

Outcome:
The runtime becomes reliable enough for longer tasks.

### Phase 3: add model-driven action selection

- feed memory, plan summary, and tool list into a model
- parse model output into a validated action object
- fallback to heuristic routing if parsing fails

Outcome:
The agent starts to behave like a true GPT-style tool-using assistant.

### Phase 4: unify with app/service code agent

- reuse `app/service/tools/*.sh` semantics
- align action names between `neurx/agent` and `app/service`
- share trace and pending-change formats

Outcome:
One agent model serves both native S workflows and the Qt app shell.

## Practical Conclusion

The current NeurX agent is not missing everything. It already has a better internal runtime shape than many throwaway demos because it includes memory, checkpoints, traces, and skill lifecycle management.

But the main missing step is important:

the runtime still needs to move from simulated or descriptive actions to real structured tool execution.

That is the shortest path from today's NeurX agent to something much closer to a GPT/Codex-style coding agent.
