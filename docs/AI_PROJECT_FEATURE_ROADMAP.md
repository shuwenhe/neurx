# AI Project Feature Roadmap for NeurX

This document maps the useful ideas from the sibling `ai/*` projects onto `neurx`.
It is not a feature wishlist for copying everything. The goal is to isolate the
parts that materially improve NeurX as a coding agent and separate them from
larger platform features that need a different product shape.

## 1. High-Value Features NeurX Can Take Directly

These are the best candidates because they fit the current desktop code-agent
architecture without a large product rewrite.

### 1.1 Task planning and delegation

Source ideas:

- `openhuman`: `todo_write`, `spawn_subagent`, `delegate`, `ask_clarification`
- `langgraph`: stateful orchestration, human-in-the-loop, durable execution
- `codex`: thread resume, plan deltas, step status updates

What to bring into NeurX:

- durable task sessions
- explicit plan steps with statuses
- specialist subagents for research, code execution, review, and summarization
- a visible "ask clarification" path instead of silent guessing

Why this matters:

- multi-step engineering tasks are much more reliable when the agent can decompose
  work and resume it later
- the UI becomes a task workspace, not just a chat surface

### 1.2 Long-term memory

Source ideas:

- `openhuman`: Memory Tree, `recall`, `store`, `forget`
- `hermes-agent`: persistent memory, cross-session recall

What to bring into NeurX:

- session-scoped memory plus optional durable long-term memory
- searchable memory records with source provenance
- explicit "store this" / "forget this" operations

Why this matters:

- the agent can remember workspace decisions, user preferences, and recurring
  project context
- memory becomes inspectable instead of implicit prompt stuffing

### 1.3 Tooling for real code work

Source ideas:

- `openhuman`: coder tool family
- `codex`: patch-first editing, verification loops

What to bring into NeurX:

- diff-first editing as the default
- command streaming, command interruption, and command history
- tighter build/tests/lint verification loops
- better file, git, and search tool composition

Why this matters:

- the current stack is already close to this; the remaining work is mostly
  orchestration and UX

### 1.4 Checkpoints and rollback

Source ideas:

- `codex`: file change review, rollback, permission gating
- `openhuman`: durable execution, safe retries

What to bring into NeurX:

- pre-edit checkpoints
- user-visible rollback actions
- checkpoint previews before restore
- checkpoint-aware session history

Why this matters:

- safe rollback is one of the simplest ways to increase user trust in an agent

### 1.5 MCP/plugin style extensibility

Source ideas:

- `openhuman`: MCP registry
- `codex`: plugin / skill / MCP surfaces

What to bring into NeurX:

- a registry for external tools
- install / enable / disable / inspect lifecycle
- direct surfacing of tool metadata into the agent registry

Why this matters:

- it reduces the gap between "built-in tools" and "ecosystem tools"
- it lets NeurX grow without hardcoding every integration

### 1.6 Search and retrieval

Source ideas:

- `openhuman`: web search, scraper, memory retrieval
- `dify`: RAG pipeline, retrieval layering

What to bring into NeurX:

- a clear split between discovery and reading
- local code search plus optional web search
- provenance-preserving retrieval results

Why this matters:

- coding agents spend a lot of time finding the right file or reference before
  editing anything

## 2. Features Worth Adapting, Not Copying

These are useful, but NeurX should adopt them only in a reduced form.

### 2.1 Cron and scheduled runs

Source ideas:

- `openhuman`: cron jobs, scheduled agent runs

Best NeurX adaptation:

- simple reminders and scheduled maintenance tasks
- recurring verification jobs for a workspace

Why not copy wholesale:

- NeurX is a desktop app first; it does not yet need a full orchestration
  service for recurring jobs

### 2.2 Voice and desktop companion

Source ideas:

- `openhuman`: voice, screen context, pointing, desktop companion

Best NeurX adaptation:

- optional push-to-talk input
- screen-aware assistance for local apps
- voice output for confirmations and summaries

Why not copy wholesale:

- this is a separate product surface and will expand the UI/state machine

### 2.3 Messaging and gateway routing

Source ideas:

- `openclaw`: multi-channel inbox, gateway, session routing

Best NeurX adaptation:

- remote control or headless task submission only if needed
- do not turn NeurX into a full multi-channel assistant unless that is the
  product goal

Why not copy wholesale:

- it changes the product from a coding workspace into a messaging platform

### 2.4 Workflow / observability layers

Source ideas:

- `dify`: workflow canvas, prompt IDE, observability, RAG pipelines

Best NeurX adaptation:

- a lightweight task/plan visualization
- execution traces and command history
- structured debug views for tool runs

Why not copy wholesale:

- Dify is a platform, not a local code-agent desktop app

## 3. Priority Order

### Phase 1: Immediately valuable

1. Durable task sessions
2. Better plan panel and step status
3. Long-term memory and explicit recall
4. Checkpoints with visible rollback
5. Diff-first editing and verification loops

### Phase 2: High leverage

1. MCP/plugin registry
2. Command streaming and command history
3. Search/retrieval upgrades
4. Clarification prompts and task delegation

### Phase 3: Product expansion

1. Cron / scheduled runs
2. Optional voice / desktop companion features
3. More advanced workflow visualization
4. Remote or multi-channel control surface

## 4. Recommended NeurX Direction

If the goal is to make NeurX better as a coding agent, the best path is:

- keep the desktop workspace as the core product
- make planning, memory, checkpoints, and verification first-class
- add extensibility through MCP rather than hardcoded integrations
- treat voice, messaging, and scheduling as optional surfaces, not the core

That keeps the product coherent while still absorbing the best ideas from the
other projects.
