# Code Agent Action Schema

## Goal

English text `app/service/code_agent_runner.sh`, `app/bridge/` English text `neurx/agent/` English text.

English textphaseEnglish text:

- English text
- English textresult
- English text
- English textsummary

## Runner Envelope

runner English text JSON object.

English text:

- `protocol_version`: English text `neurx.code_agent.v1`
- `status`: `completed`, `unhandled`, `requires_approval`, `failed`
- `mode`: English text `template`, `planner`, `model-loop-cpp`
- `summary`: English text bridge/UI English textsummary
- `response`: English textresult; English text
- `plan`: English text; English textstepEnglish text
- `file_context`: English textfileEnglish textsummary
- `actions`: action English text
- `action_results`: action result English text
- `prompt`
- `file_path`
- `repo_root`

## Action Object

English text action English text:

- `tool`: English text
- `args`: JSON object
- `summary`: English textsummary
- `requires_approval`: English textRequiredEnglish text

English text:

- `read_file`
- `search_files`
- `write_file`
- `delete_path`
- `run_build`
- `run_test`

example:

```json
{
  "tool": "read_file",
  "args": {
    "path": "app/bridge/neurx_bridge.cpp",
    "start_line": 1,
    "line_count": 120
  },
  "summary": "Read the target file before planning edits.",
  "requires_approval": false
}
```

## Action Result Object

English text action result English text:

- `ok`: English text
- `tool`: English text
- `summary`: English textresultsummary
- `output`: English textoutputEnglish text
- `changed_paths`: pathEnglish text
- `requires_approval`: English text

example:

```json
{
  "ok": true,
  "tool": "generate_completion",
  "summary": "Returned a validated standalone Python program.",
  "output": "print(\"hello\")",
  "changed_paths": [],
  "requires_approval": false
}
```

## Current Use

### `completed`

- `response` English text
- `action_results` English text runner English textsummary

### `unhandled`

- `response` English text
- `actions` English textstepEnglish text
- `plan` English text `file_context` English textuse

### `requires_approval`

- `actions` English text `requires_approval=true`
- bridge/UI English textprompt, English text

## Compatibility

English text:

- `plan` English text `file_context` English text
- `response` English text completed English text
- English text `actions` English text `action_results`

## Constraints

- English textpathdefaultEnglish text repo-scoped
- destructive action English text `requires_approval=true`
- `output` English text `file_context` English text
