# Production Roadmap

This document defines the execution plan to evolve `neurx` from a minimal framework into a full-stack production platform.

## Stage 1 (Completed in this iteration)
- Runtime platform base:
  - centralized config (`neurx.platform.config`)
  - standardized errors (`neurx.platform.errors`)
  - diagnostics/doctor (`neurx.platform.diagnostics`, `neurx-doctor`)
  - logging bootstrap (`neurx.platform.logging`)
- Full-stack package scaffolding:
  - `neurx.data` with `Dataset` / `DataLoader`
  - `neurx.distributed` with env-based distributed config
  - `neurx.compile` with stable compile API boundary
- Core integration:
  - Tensor default device selection now uses runtime config
  - configurable CUDA-to-CPU fallback policy

## Stage 2 (Next)
- Data stack:
  - multiprocessing workers
  - pinned memory support
  - streaming dataset interfaces
- Training runtime:
  - callback/hook system
  - checkpoint manager (model/optimizer/scaler/runtime)
  - fault-tolerant recovery
- Observability:
  - operator latency metrics
  - structured training logs
  - runtime event tracing

## Stage 3
- Distributed training:
  - process group abstraction
  - gradient synchronization primitives
  - DDP and model-parallel integration
- Precision/runtime:
  - AMP autocast + grad scaler
  - BF16/FP16 kernel paths

## Stage 4
- Compiler/runtime:
  - graph capture and AOT lowering
  - kernel fusion and runtime scheduler
  - backend plugins (CPU/CUDA/custom accelerator)
- Serving:
  - inference runtime package
  - model export contract
  - service deployment templates

## Stage 5
- Platform operations:
  - SLA/SLO dashboards
  - release channels and compatibility policy
  - security hardening and supply-chain controls

