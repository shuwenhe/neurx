# Contract Tests

Verify stable APIs and backend contracts independently of implementation.

`make test-api-contracts` compiles API modules and callers, links their IR,
emits native test binaries, and executes positive and negative contract cases.
