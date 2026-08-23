# Contract Tests

Verify stable APIs and backend contracts independently of implementation.

`make test-api-contracts` compiles both API modules and contract callers. Runtime
execution will become mandatory when the S CLI supports linking imported IR
modules.
