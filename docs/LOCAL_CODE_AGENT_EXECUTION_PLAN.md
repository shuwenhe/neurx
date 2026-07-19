# Local Code Agent Execution Plan

## Goal

English text 4 English text, English text `neurx` English textmainEnglish textrun, English texttruthfulEnglish text, English text coding agent.

English textextension `AI OS` English text, English texttraining, inference, English text, English text:

`English textrequest -> English text -> English text -> English text -> build/test -> English textresult`

## Non-Goals

English textphaseEnglish text, English textmainEnglish text:

- English textmodelEnglish text
- English text
- English text UI English textextension
- English texttrainingEnglish text
- English textcompile/English text
- English text AI OS English textsystemEnglish textdirectoryEnglish text

## Success Criteria

4 English text, English text:

1. `app/service/code_agent_runner.sh` English textoutputEnglish text action, English text planner stub.
2. `app/bridge/neurx_bridge.cpp` English text `read/search/write/delete/build/test` English text.
3. English textAllowedEnglish text, English text:
   - English textfile
   - build/test English text
   - failureEnglish texterrorsummary
4. destructive action English text.
5. English text agent side effect English text trace English textlogEnglish text.

## Product Boundary

English textphaseEnglish text NeurX English text:

- English text Qt app English text
- English text/English textmodelEnglish text
- English text repo-scoped coding agent runtime
- English texttoolEnglish text

English text:

- English text AI English textsystem
- completetrainingframeworkEnglish text
- completeinferenceEnglish text

## Primary Workstream

English textmainEnglish text:

`app/bridge` + `app/service` + `neurx/agent`

English text:

- `app/service/tools/*.sh` English texttoolEnglish text
- `app/bridge` English text
- `neurx/agent` English text action NameEnglish textresultEnglish text

## Execution Principles

### 1. Prefer one real loop over many partial modules

English texttruthfulEnglish text, English text.

### 2. Actions before intelligence

English text, English textmodelEnglish text.English texttruthful `write/build/test`, English text prompt English textDescription.

### 3. Repo-scoped safety first

English text, English text, English text, testEnglish textdirectoryEnglish textdirectoryEnglish text.

### 4. Observable by default

English textparameter, result, English textfailureEnglish text, English text.

## Week 1

mainEnglish text: English text, English text.

English text:

- English text action schema, English text:
  - `tool`
  - `args`
  - `approval`
  - `summary`
- English text:
  - `read_file`
  - `search_files`
  - `write_file`
  - `delete_path`
  - `run_build`
  - `run_test`
- English text action result schema, English text:
  - `ok`
  - `tool`
  - `summary`
  - `output`
  - `changed_paths`
  - `requires_approval`
- runner outputEnglish text JSON action/result envelope.

English textdirectory:

- `app/service/code_agent_runner.sh`
- `app/service/tools/`
- `app/bridge/neurx_bridge.cpp`
- `neurx/agent/`

English text:

- runner AllowedEnglish text JSON.
- bridge English text completed / requires_approval / failed / delegated.

## Week 2

mainEnglish text: English text, English text.

English text:

- `read/search/write/delete` English texttruthfulEnglish text.
- English text pending changes English text apply English text, English text.
- delete defaultRequiredEnglish text.
- English textpathEnglish text workspace root English text.
- tool output English text, English text UI/trace English text.

English text:

- English texttoolEnglish text.
- English texttoolEnglish text, English textextension.

English text:

- English textfileEnglish text, English text, English text.
- English textfileEnglish text.
- English textpath, English textpath, English textparameterEnglish texterror.

## Week 3

mainEnglish text: English text build/tests/repair loop, English text agent start"English text".

English text:

- `run_build` English text `run_test` English text.
- runner supportEnglish text `N` English text bounded repair loop.
- failureresultEnglish textgenerate.
- UI/bridge English text:
  - English textstepEnglish text
  - English text
  - build/test summary

English text:

- English textsupportEnglish text 1 English text 2 English text build/test path.
- English text.

English text:

- English textcompile/testfailureEnglish text, agent English text:
  - English text
  - English text
  - build/test
  - failuresummary
  - English text

## Week 4

mainEnglish text: safety, trace, English text `neurx/agent` alignment.

English text:

- destructive action English text.
- action trace English text, supportEnglish text replay.
- `neurx/agent` English textalignmentEnglish textresultEnglish text.
- English textconfiguration, English textconfigurationEnglish text.
- English text 3 English text 5 English text smoke tests.

English text:

- English textcompleteEnglish textmainEnglish textstepEnglish text.
- English text delete English text.
- English text app agent English text native S agent English text.

## Required Refactors

English text:

1. English text bridge English text code agent English textdefaultconfiguration.
2. English text action parsing / validation / execution, English text `neurx_bridge.cpp`.
3. English text shell tools English text, English text.
4. English text pending change English text, English textimplementationEnglish text.

## Metrics

English text:

- action JSON English textsuccessEnglish text
- English texttoolEnglish textsuccessEnglish text
- English textfileEnglish text
- build/test successEnglish text
- RequiredEnglish textfailureEnglish text
- English text/English textpathEnglish text

## Risks

### Risk 1: scope relapse

English text"English text"English text.

English text:

- English text: English text coding agent English textsuccessEnglish text.

### Risk 2: bridge becomes a god object

`neurx_bridge.cpp` English text, English textquickEnglish text.

English text:

- English text action executor English text action validator English text.

### Risk 3: shell tools are too loose

English texttoolEnglish text, English textsafetyEnglish text.

English text:

- English text JSON envelope
- English textpathEnglish text
- English text stdout/stderr English text

### Risk 4: false sense of progress from model output

modelEnglish text, English text agent English text.

English text:

- English texttruthful side effect English text build/test resultEnglish text.

## Stop Doing

English textstart, English textmainEnglish text:

- English textextension AI OS English textdirectoryEnglish text
- English text agent action English text
- English textlanguage"English text"English text patch/action
- English text

## Immediate Next Tasks

English textstepEnglish text, English text:

1. English text code agent English text `action` English text `action_result` JSON schema.
2. English text `code_agent_runner.sh` outputEnglish text schema.
3. English text `neurx_bridge.cpp` English text `read/search/write/delete`.
4. English text `build/test` English textframework.
5. English text smoke test.

## Expected Outcome

English text 4 English text, `neurx` English text"English text"English text"English textmainEnglish textactualEnglish text agent English text".
