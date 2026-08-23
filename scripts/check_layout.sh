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
  src/training/api src/training/engine src/training/strategy src/inference/executor
  src/serving/api/openai src/serving/api/admin src/serving/gateway src/serving/admission
  src/distributed/collective src/distributed/topology src/distributed/rendezvous
  src/distributed/elasticity src/distributed/fault_tolerance backends/common
  tests/contract tests/distributed tests/chaos
  benchmarks/training benchmarks/inference benchmarks/kernels benchmarks/baselines
  configs/models configs/training configs/inference configs/clusters configs/schemas
)

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
