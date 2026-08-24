#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

allowed_dirs=(
  .github apps artifacts assets backends benchmarks build cmd configs dataset deploy docs examples
  experimental scripts src tests tools workflows
)

failed=0
while IFS= read -r directory; do
  allowed=0
  for expected in "${allowed_dirs[@]}"; do
    if [[ "$directory" == "$expected" ]]; then
      allowed=1
      break
    fi
  done
  if (( allowed == 0 )); then
    printf 'unexpected top-level directory: %s/\n' "$directory" >&2
    failed=1
  fi
done < <(find . -mindepth 1 -maxdepth 1 -type d ! -name '.git' ! -name '.vscode' -printf '%f\n' | sort)

if rg -l 'neurx\.experimental' src --glob '*.s' >/dev/null; then
  printf 'production source must not import neurx.experimental packages\n' >&2
  failed=1
fi

required_dirs=(
  cmd/train cmd/serve cmd/worker cmd/controller cmd/benchmark
  src/core/tensor src/core/ops src/core/autograd src/core/memory src/core/contracts
  src/compiler/frontend src/compiler/ir src/compiler/pass src/compiler/lowering src/compiler/codegen
  src/runtime/executor src/runtime/dispatch src/runtime/memory src/runtime/task src/runtime/system
  src/model/registry src/model/loaders src/model/formats src/model/families
  src/training/api src/training/engine src/training/strategy src/training/optimizer
  src/training/checkpoint src/training/data src/training/pretrain src/training/posttrain
  src/inference/api src/inference/engine src/inference/scheduler src/inference/executor
  src/inference/cache src/inference/sampling src/inference/speculative src/inference/tokenizer
  src/serving/api/openai src/serving/api/admin src/serving/gateway src/serving/admission
  src/serving/protocol src/serving/router src/serving/security src/serving/lifecycle
  src/distributed/collective src/distributed/topology src/distributed/rendezvous
  src/distributed/elasticity src/distributed/fault_tolerance src/observability src/agent
  backends/api backends/common backends/cpu backends/cuda backends/cann backends/mps
  tests/contract tests/distributed tests/chaos
  benchmarks/training benchmarks/inference benchmarks/kernels benchmarks/baselines
  configs/models configs/training configs/inference configs/clusters configs/schemas
)

legacy_dirs=(
  src/inference/kv src/inference/queue src/inference/serve src/inference/serving
  src/inference/distributed src/inference/monitoring src/inference/metrics
  src/serving/cache src/serving/decode src/serving/net src/serving/network src/serving/sampling
  backends/arch/mps backends/kernel
)

for directory in "${legacy_dirs[@]}"; do
  if find "$directory" -type f -print -quit 2>/dev/null | grep -q .; then
    printf 'retired compatibility directory contains files: %s/\n' "$directory" >&2
    failed=1
  fi
done

for directory in "${required_dirs[@]}"; do
  if [[ ! -d "$directory" ]]; then
    printf 'required target-layout directory is missing: %s/\n' "$directory" >&2
    failed=1
  fi
done

required_command_entries=(cmd/train/main.s cmd/serve/main.s cmd/worker/main.s cmd/controller/main.s cmd/benchmark/main.s)
for entry in "${required_command_entries[@]}"; do
  if [[ ! -f "$entry" ]]; then
    printf 'required command entrypoint is missing: %s\n' "$entry" >&2
    failed=1
  fi
done

if rg -l '%src/|src/src/|backends/backends/' . \
  --glob '!artifacts/**' --glob '!scripts/check_layout.sh' >/dev/null; then
  printf 'malformed path prefix detected\n' >&2
  failed=1
fi

if (( failed != 0 )); then
  exit 1
fi

printf 'Repository layout checks passed.\n'
