#!/usr/bin/env bash
set -euo pipefail

container_name="qwen25-05b-cpu-api"

docker rm -f "$container_name" >/dev/null 2>&1 || true

exec docker run --rm \
  --name "$container_name" \
  --publish 8002:8002 \
  --env MODEL_PATH=/model/Qwen2.5-0.5B-Instruct \
  --env MODEL_ID=Qwen2.5-0.5B-Instruct \
  --env PORT=8002 \
  --volume /app/neurx/serving/serve/qwen25_cpu_api.py:/srv/qwen25_cpu_api.py:ro \
  --volume /app/neurx/artifacts/checkpoints:/model:ro \
  quay.io/ascend/vllm-ascend:nightly-main-310p \
  python /srv/qwen25_cpu_api.py