# app/neurx

Thin application layer for deploying and running NeurX-based services.

This directory contains runtime wiring, examples, and deployment artifacts.

Structure:

- `bin/` : startup scripts (CLI entry points)
- `configs/` : example configuration files (yaml/json)
- `bridge/` : thin bridge code to platform or UI
- `deploy/` : Docker, systemd, k8s snippets
- `examples/` : app-level runnable examples
- `tests/` : smoke tests for app wiring
- `docs/` : usage and deployment docs
- `ci/` : CI job snippets for app-level tests

Rules:

- Do not implement core runtime or model logic here. Call into `core/`, `serving/`, `runtime/`, or `distributed/`.
- Keep scripts idempotent and config-driven.
Neurx - framework layer scaffold

Structure:
- `s/`: S source by module
- `bridge/`: thin C++ bridge code for GUI and runtime wiring
- `examples/`: minimal examples
- `tests/`: unit tests
- `docs/`: design docs

Goal: provide an S-first core for tensors, autodiff, IR, runtime, and ops; keep high-performance kernels in C/CUDA and expose via thin bridges.
