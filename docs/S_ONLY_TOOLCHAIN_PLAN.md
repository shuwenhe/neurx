# NeurX S-Only Toolchain Plan

This document defines the long-term path to a fully S-native toolchain for the NeurX repo.

## Goal

Make S the default control plane for:

- data preparation
- dataset verification
- industrial workflow execution
- compilation orchestration
- test gating
- release metadata and status reporting

Shell should become a compatibility layer, not the primary workflow.

## Current State

Already present:

- `scripts/legacy/data_clean.s`
- `scripts/legacy/data_shard.s`
- `scripts/legacy/scripts.s`
- `data/tools/verify_dataset.s`
- `scripts/legacy/industrial_ops_runner.s`
- `scripts/legacy/s_toolchain.s`

Current Makefile targets expose:

- `build-data-scripts`
- `clean-s`
- `shard-s`
- `data-pipeline-s`
- `verify-dataset-s`
- `build-industrial-ops`
- `industrial-ops`
- `toolchain-s`

Example:

- `make toolchain-s TOOLCHAIN_CMD=roadmap`
- `make toolchain-s TOOLCHAIN_CMD=status`
- `make toolchain-s TOOLCHAIN_CMD=all`

## Migration Stages

### Stage 1: Centralize S entrypoints

Keep all S-native workflow entrypoints discoverable from one place.

Deliverables:

- one top-level S CLI for toolchain status
- one roadmap / status output
- one consistent naming scheme for S targets

### Stage 2: Replace shell wrappers for data tasks

Migrate the remaining data-flow shell scripts into S modules.

Targets:

- cleaning
- sharding
- verification
- split/manifests
- corpus loading

### Stage 3: Replace shell wrappers for industrial workflows

Move DPO, RAG, governance, and dataset ops into S-native dispatch.

Targets:

- file-backed DPO runs
- corpus-backed RAG runs
- dataset governance and quality audits
- experiment/report generation

### Stage 4: Move build orchestration into S

Replace `make`-only workflow control with a small S build dispatcher.

Targets:

- compile selected modules
- run target-specific checks
- write build manifests
- export logs and artifacts

### Stage 5: Add S-native validation gates

All major workflow changes should be validated through S entrypoints.

Targets:

- dataset verification
- toolchain status
- compile smoke checks
- artifact completeness checks

### Stage 6: S-only default path

Make the S workflow the normal path used by docs, CI, and local development.

Shell remains only as fallback for legacy compatibility.

## Acceptance Criteria

- The primary docs point to S entrypoints first.
- New workflow additions land in S before shell.
- Toolchain status can be queried from a single S command.
- The repo can describe its build / data / industrial control plane without referencing shell as the default path.

## Short-Term Next Steps

1. Add S-native wrappers for the remaining shell data scripts.
2. Add a small S-native build dispatcher for compile/test tasks.
3. Replace docs that still present shell as the primary path.
4. Keep the Makefile as a thin compatibility layer until the S dispatcher is complete.
