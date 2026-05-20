# NeurX Code Agent Architecture

## Goal

Turn the current code assistant from a prompt/response shell into a Codex-like coding agent that can:

1. inspect the workspace
2. read and search files
3. generate code or patches
4. write changes back to the repo
5. build and test
6. retry on failures with bounded loops

## Current State

- `app/bridge/neurx_bridge.cpp`: request routing and UI bridge
- `app/service/gateway.sh`: local backend wrapper
- `app/service/code_templates.sh`: fast template fallback for trivial requests

This is enough for canned answers and simple code generation prompts, but not enough for full coding-agent behavior.

## New Runtime Layer

### `app/service/code_agent_runner.sh`

Responsibilities:

- classify code tasks
- collect local context
- decide whether a template can satisfy the request
- otherwise emit a structured plan for the next executor stage

Expected evolution:

- today: template completion or planner stub
- next: call model for structured actions
- later: orchestrate read/write/build/test loops

## Tool Layer

### `app/service/tools/read.sh`

- read a bounded file window

### `app/service/tools/search.sh`

- search workspace text with `rg`

### `app/service/tools/write.sh`

- write file content from stdin

### `app/service/tools/build.sh`

- run project build commands in a controlled workdir

### `app/service/tools/test.sh`

- run project test commands in a controlled workdir

## Execution Plan

### Phase 1

- use `code_agent_runner.sh` before `/neurx/api/chat`
- allow direct local completions for trivial code requests
- return structured planner output for all other tasks

### Phase 2

- add model-driven action JSON:
  - `read_file`
  - `search_files`
  - `write_file`
  - `run_build`
  - `run_test`

### Phase 3

- add bounded repair loop:
  - generate
  - apply
  - build/test
  - inspect errors
  - retry up to N rounds

## Bridge Contract

The Qt bridge should treat the runner as the first execution layer:

1. call `code_agent_runner.sh`
2. if it returns `status=completed`, show the response
3. if it returns `status=unhandled`, continue to model chat
4. in later versions, execute returned actions instead of raw text

## Why This Shape

- keeps UI code thin
- keeps backend shell modular
- separates templates from execution logic
- creates a clean migration path from static answers to a real coding agent
