# neurx-controller

Stable distributed controller boundary. It owns job coordination and delegates
execution to runtime workers; it must not implement model or kernel logic.
Remote execution is dry-run by default and requires strict SSH host-key
verification when enabled.
See `configs/clusters/controller.example` for the environment contract.
