# Test organization

- `unit/`: isolated module and language behavior tests
- `integration/`: interactions between two or more production domains
- `e2e/`: complete user or deployment flows
- `performance/`: throughput, memory, and numerical performance checks
- `compatibility/`: API, runtime, model, and feature compatibility gates
- `evaluation/`: model quality evaluation programs
- `fixtures/`: reusable test input
- `golden/`: reviewed expected outputs and their generator
- `reference/`: reference behavior documentation

Tests should use the narrowest level that can prove the behavior. Production
source must never import code from `tests/`.
