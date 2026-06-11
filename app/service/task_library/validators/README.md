# Validators

Optional task-scoped validators can live here.

Current validators:

- `validate_cpp.sh`
- `validate_python.sh`
- `validate_javascript.sh`
- `validate_go.sh`

`code_agent_runner.sh` dispatches to these scripts using the `validator`
metadata in `tasks.tsv`.
