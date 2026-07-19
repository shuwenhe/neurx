# Codex / Claude Code Parity Plan

## Goal

English text `NeurX` English textimplementationEnglish text `Codex` English text `Claude Code` English text code agent English text, English text, English text.

English text"English text UI", English text coding agent mainEnglish text:

`English text -> English text -> English text -> safetyEnglish text -> build/test -> failureEnglish text -> resultEnglish text`

## Scope Definition

English textphaseEnglish text "implementation Codex / Claude Code English text" English text 8 English text:

1. English texttruthfulEnglish text
2. English texttoolEnglish text
3. English text
4. build/test English textfailuresummary
5. bounded repair loop
6. English text, trace, memory English text
7. English textresultEnglish text final answer
8. English text smoke task

English text:

- English text
- English textmainEnglish text
- complete IDE pluginEnglish text
- English text agent
- English text

## What Codex / Claude Code Actually Provide

English text, English textsystemEnglish text:

1. English textlanguageEnglish text.
2. English texttruthfulEnglish text, search, English text, English text, runEnglish text.
3. English text, English textRequiredEnglish textrequestEnglish text.
4. English textfailureEnglish texterror, English text, English text.
5. English textsummary, English textresultEnglish text.

English text `NeurX` English text"English text", English text"English text repo-scoped software execution agent".

## Capability Matrix

| Capability | Codex / Claude Code class | NeurX now | Gap |
| --- | --- | --- | --- |
| Structured actions | required | partially done | needs full producer/consumer unification |
| Real file IO | required | mostly done | needs stronger approval flow |
| Search over repo | required | mostly done | needs better result normalization |
| Build/test loop | required | basic | needs retry policy and task fixtures |
| Repair loop | required | partial | needs bounded automatic retry |
| Pending changes / approvals | required | partial | needs unified write/delete/apply gate |
| Session memory | required | basic | needs stronger final-answer persistence and replay |
| Trace / replay | required | partial | needs skill/runtime alignment |
| Task eval | required | weak | needs smoke tasks and success metrics |
| Multi-turn code task UX | required | partial | needs coherent app/native parity |

## NeurX Mapping

### 1. Intent and tool selection

English textdirectory:

- `executor/model_tool_select.s`
- `executor/executor.s`
- `action/action_schema.s`

English text:

- English text route/tool/action NameEnglish text
- English textrequestEnglish text
- English textlanguageEnglish text

English text:

- English textrequestEnglish text runtime English text, English textmainEnglish text

### 2. Workspace actions

English textdirectory:

- `tool/workspace_tools.s`
- `agent/workspace_search.s`
- `runtime/io/io.s`

English text:

- `read_file`
- `search_files`
- `write_file`
- `delete_path`
- `apply_patch`
- `run_build`
- `run_test`

English text:

- truthfulEnglish text
- repo-scoped
- English text observation

English text:

- English text `kind:status=...`
- English textpath, English textparameter, English textresultEnglish textstateEnglish text

### 3. Runtime orchestration

English textdirectory:

- `agent/runtime.s`
- `task/planner.s`
- `reasoning/reasoning.s`
- `reflection/reflection.s`

English text:

- runtime English textstate
- planner / reasoning / reflection / runtime English text observation parser
- English text, replan English text, tool disable English text

English text:

- blocked / failed / no_progress / ok / done English text

### 4. Answer synthesis and trace

English textdirectory:

- `agent/trace.s`
- `agent/answer_synthesizer.s`
- `agent/runtime.s`

English text:

- trace English texttruthfulEnglish text, English text `ok_flags`
- final answer English text memory, English textsuccess observation
- failure observation English text

English text:

- English textsuccess observation English text final answer
- English textsuccess observation English text

### 5. App-side code agent parity

English textdirectory:

- `app/service/code_agent_runner.sh`
- `app/bridge/neurx_bridge.cpp`
- `app/service/tools/*.sh`

English text:

- app bridge English text native S agent useEnglish text
- English text `action` / `action_result` envelope
- English text pending changes English text

English text:

- app English text native English text, English textresultEnglish text

## Required Feature Set For Parity

English text `NeurX` English text "Codex / Claude Code English text", English text, English text:

### A. Code editing loop

- English textfile
- searchEnglish text
- English textfile
- English text patch
- English textsummary

### B. Safe execution loop

- English textRequiredEnglish text
- English textRequiredEnglish text gate
- English textpathdefaultEnglish text
- English textoutputEnglish text

### C. Verification loop

- English text build
- English text test
- English textfailureoutput
- English text
- English text

### D. Result loop

- outputEnglish textfileEnglish text
- outputEnglish textresult
- outputfailureEnglish text
- outputEnglish text trace

## Phased Implementation

### Phase 1: action and observation unification

English textstate:

- English textstart

English text:

- executor producer English text
- skill/runtime replay alignment observation parser
- app/native English textresultEnglish textalignment

### Phase 2: approval and pending changes unification

English text:

- `write_file`
- `apply_patch`
- `replace_range`
- `delete_path`

English text / English text

English text `NeurX` English text `Codex / Claude Code` English text.

### Phase 3: bounded repair loop

English text:

- `run_build`
- `run_test`
- failure observation English text memory
- English text `N` English text
- English textoutput clear failure summary

### Phase 4: task fixtures and smoke evaluation

English text:

1. English textfileEnglish text
2. English textfileEnglish text
3. build failureEnglish text
4. test failureEnglish text
5. English textpathEnglish text

English text, English text `NeurX` English text `Codex / Claude Code`.

## Concrete Repo Priorities

English textextension, English text:

1. English text `agent/runtime.s`, `skill_feedback`, `trace replay` English text observation English text
2. English text app bridge English text native agent English text / English text
3. English text bounded build/test repair loop
4. English text smoke tasks English textsuccessEnglish textstatistics
5. English textmodelEnglish text UX

## Completion Standard

English text, English text `NeurX` "implementationEnglish text Codex / Claude Code English text code agent English text":

1. English texttruthfulEnglish text build/test.
2. English textfailureEnglish text.
3. English text gate.
4. app English text native S English text.
5. English text smoke tasks AllowedEnglish textsuccessEnglish text, English text.
6. final answer, trace, memory English text observation English text.

## Current Decision

English text `NeurX` English text, English text"English text Codex English text Claude Code English text", English text:

- English text
- English text execution correctness
- English textoptimizeEnglish text

English textmainEnglish text:

- `executor/`
- `agent/`
- `tool/`
- `app/bridge`
- `app/service`

English text, English text AI OS English text.
