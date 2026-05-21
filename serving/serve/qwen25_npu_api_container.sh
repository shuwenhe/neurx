#!/usr/bin/env bash
set -euo pipefail

container_name="qwen25-05b-npu-api"

docker rm -f "$container_name" >/dev/null 2>&1 || true

exec docker run --rm \
  --name "$container_name" \
  --publish 8003:8003 \
  --shm-size 32g \
  --device /dev/davinci0 \
  --device /dev/davinci1 \
  --device /dev/davinci2 \
  --device /dev/davinci3 \
  --device /dev/davinci4 \
  --device /dev/davinci5 \
  --device /dev/davinci6 \
  --device /dev/davinci7 \
  --device /dev/davinci_manager \
  --device /dev/devmm_svm \
  --device /dev/hisi_hdc \
  --env MODEL_PATH=/model/Qwen2.5-0.5B-Instruct \
  --env MODEL_ID=Qwen2.5-0.5B-Instruct \
  --env PORT=8003 \
  --env DEVICE=npu \
  --env ATTN_IMPLEMENTATION=eager \
  --volume /usr/local/dcmi:/usr/local/dcmi \
  --volume /usr/local/bin/npu-smi:/usr/local/bin/npu-smi \
  --volume /usr/local/Ascend/driver/lib64/:/usr/local/Ascend/driver/lib64/ \
  --volume /usr/local/Ascend/driver/version.info:/usr/local/Ascend/driver/version.info \
  --volume /etc/ascend_install.info:/etc/ascend_install.info \
  --volume /app/neurx/serving/serve/qwen25_cpu_api.py:/srv/qwen25_cpu_api.py:ro \
  --volume /app/neurx/artifacts/checkpoints:/model:ro \
  quay.io/ascend/vllm-ascend:nightly-main-310p \
  python /srv/qwen25_cpu_api.py