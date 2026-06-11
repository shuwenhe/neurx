# Task Library

This directory stores coding-agent task definitions for the NeurX app service.

## Layout

- `tasks.tsv`: task registry used by `code_agent_runner.sh`
- `templates/`: optional per-task response templates
- `validators/`: optional per-task validation helpers

## `tasks.tsv` format

Each line uses:

```text
task_id|languages|match_terms|validator|priority|mode
```

Examples:

- `sum_series|cpp,python,javascript,go|extract_sum_upper_bound|by_language|90|local-synth`
- `even_odd|cpp,python,javascript,go|偶数,even,奇数,odd,奇偶|by_language|80|local-synth`

Fields:

- `task_id`: stable identifier
- `languages`: comma-separated supported languages
- `match_terms`: trigger terms or `extract_*` helper marker
- `validator`: validation strategy key
- `priority`: higher value means earlier preference when multiple tasks match
- `mode`: current execution mode, for example `local-synth` or later `model-loop`

## Intent

The current library is a lightweight rule table for local synthesis. It is the
migration point toward a richer task system with:

- builder metadata
- validator metadata
- priority and fallback rules
- model-loop routing policies
