# Code Agent Reference Map

## Goal

English text `NeurX` English text code agent English text, English text, English text `NeurX` English textimplementation.

English textprinciple:

- English text"English text"English text
- English text"English textmainEnglish texthelpful"English text
- English text

## Primary References

English text 3 English text:

1. `Aider`
2. `OpenHands`
3. `SWE-agent`

English text:

4. `OpenCode`
5. `Continue`

## Recommendation Summary

English textranking:

1. English text `Aider`
2. English text `OpenHands`
3. English text `SWE-agent`

English text:

- `NeurX` English text agent English text, English texttruthfulEnglish text coding loop
- `Aider` English text"English texttruthfulEnglish text"
- `OpenHands` English textcompleteEnglish text agent runtime
- `SWE-agent` English text build/tests/retry/eval

## Mapping By NeurX Layer

### 1. `app/service` + `app/bridge`

English text: `Aider`

English text:

- terminal / local repo English text
- English texttruthfulEnglish text, English text
- English text, English text

English text:

- fileEnglish text
- English textfileEnglish text
- English textsummaryEnglish textoutput
- Git/worktree English textmodel
- English textrequestEnglish textpath

English text `NeurX` English textdirectory:

- `app/service/code_agent_runner.sh`
- `app/service/tools/`
- `app/bridge/neurx_bridge.cpp`

English text `NeurX` English text:

- runner English text plan, English text action
- bridge English textlanguage, English text
- English text staged/pending change English text

English text:

- English text Git patch English text
- English text UX English text

## 2. `neurx/agent` + `executor/` + `action/`

English text: `OpenHands`

English text:

- English text agent runtime
- English text, English text, English text, toolEnglish text
- English text terminal pair programmer English text

English text:

- agent runtime English text
- action orchestration
- tool execution contracts
- environment abstraction
- runEnglish textstateEnglish textmanagement
- English text observation English text

English text `NeurX` English textdirectory:

- `executor/executor.s`
- `executor/model_tool_select.s`
- `action/action_schema.s`
- `agent/runtime.s`
- `tool/workspace_tools.s`
- `tool/tool_registry.s`

English text `NeurX` English text:

- `action/tool/args/result` English text
- route English text tool English text
- planner English text, English text
- tool registry English text capability, English text UI English text prompt

English text:

- English text
- English text/English text/English textmainEnglish textsystem

## 3. `build/tests/retry/eval`

English text: `SWE-agent`

English text:

- English text UI, English text"English text"English textpipelineEnglish text
- English text `NeurX` English text, English text

English text:

- issue/task English text workspace English text
- build/test failureEnglish text
- English text
- English textsuccess/failureEnglish text
- repo task benchmark mindset

English text `NeurX` English textdirectory:

- `executor/executor.s`
- `tests/`
- `doc/LOCAL_CODE_AGENT_EXECUTION_PLAN.md`
- English text agent smoke tests / task fixtures

English text `NeurX` English text:

- English textsuccessEnglish text
- build/test outputEnglish text
- failuresummaryEnglish text memory / trace
- bounded retry loop

English text:

- English textsystemEnglish text benchmark English text
- English text

## Secondary References

### `OpenCode`

English text:

- terminal-first English text
- session/English text
- provider-agnostic configuration
- CLI/TUI English text

English text `NeurX` English text:

- English textoptimize `app/service` / `shell` / English text CLI English text
- English text, English textmainEnglish text TUI, English text

### `Continue`

English text:

- rules/checks
- source-controlled agent behavior
- CI / PR review integration

English text `NeurX` English text:

- English text agent English text PR English text, English text
- English text code agent mainEnglish text

## What NeurX Should Copy First

English textranking, English text:

1. `Aider` English text
2. `OpenHands` English text action/runtime English text
3. `SWE-agent` English text build/tests/retry English text

## What NeurX Should Not Copy Yet

English text:

1. completeEnglish text
2. English text agent
3. English text
4. English text IDE pluginEnglish text
5. English text benchmark English text

English text:

- English text
- English text coding agent English text

## Implementation Checklist

### Phase A

English text `Aider`

- English text `read/search/write/delete/build/test` English text
- English text staged/pending changes
- English textgeneratetruthfulEnglish text

### Phase B

English text `OpenHands`

- English text `runner`, `bridge`, `executor` English text action/result
- English text `tool selection`, `tool execution`, `observation` English text
- English text `neurx/agent` English text `app/service` English textalignment

### Phase C

English text `SWE-agent`

- English text build/tests/retry loop
- English text smoke tasks
- English textsuccessEnglish textstatistics

## Current Decision

English text `NeurX` English text, mainEnglish text:

- `app/service` English text `app/bridge` English text `Aider` English textmainEnglish text
- `executor/agent/action/tool` English textstepEnglish text `OpenHands` English text runtime English text
- `test` English text repair loop English text `SWE-agent` English text

English text"English text"English textstate.
