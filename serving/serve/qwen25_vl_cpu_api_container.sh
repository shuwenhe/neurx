#!/usr/bin/env bash
set -euo pipefail

container_name="qwen25-vl-7b-cpu-api"

docker rm -f "$container_name" >/dev/null 2>&1 || true

exec docker run --rm \
  --name "$container_name" \
  --publish 8004:8004 \
  --env MODEL_PATH=/model/Qwen2.5-VL-7B \
  --env MODEL_ID=Qwen2.5-VL-7B \
  --env PORT=8004 \
  --env DEVICE=cpu \
  --env ATTN_IMPLEMENTATION=eager \
  --volume /app/neurx/serving/serve/qwen25_vl_api.py:/srv/qwen25_vl_api.py:ro \
  --volume /app/neurx/artifacts/checkpoints:/model:ro \
  quay.io/ascend/vllm-ascend:nightly-main-310p \
  python /srv/qwen25_vl_api.py