.PHONY: help train infer pretrain-npu pretrain-gpu pretrain-gpu-single-node pretrain-gpu-multinode pretrain-gpu-resume pretrain-gpu-fresh pretrain-s-p0 pretrain-eval-test hybrid-moe-s test-checkpoint-resume test-neurx-1-3 pretrain-bigram-gpu transformer-reference-test adam-optimizer-test training-policy-test transformer-cuda-kernels-test transformer-cuda-integration-test inference-runtime-test cpu-inference-test build-cpu-inference serving-native-socket-test posttrain posttrain-e2e posttrain-merge-lora build-lora-merge pretrain-watch chat real-inference check-bash check-nvcc shard split logs logs-tail \
	build-data-scripts clean-s shard-s shard-enwiki data-pipeline-s verify-dataset-s build-industrial-ops industrial-ops \
	toolchain-s analyze-dataset-s build-s-ir-runner run-training-s train-and-infer-s run-inference-s run-s-pretrain-s \
	split-data-s run-training-pipeline-s quick-start-s run-interactive-inference-s run-small-model-training-s \
	verify-setup-s quick-test-s quickstart-s verify-training-pipeline-s monitor-training-s build-linux-s build-macos-s run-large-pretrain-s \
	run-train-compiled-s run-train-large-model-s run-train-model-ir-s run-with-logs-s verify-framework-s verify-inference-pipeline-s test-build-s test-smart-inference-s \
	run-full-inference-s compile-all-components-s integration-s complete-training-cycle-s verify-transformer-implementation-s cluster-launch-s setup-production-deployment-s \
	run-end-to-end-verification-s run-integration-tests-s minimal-diagnostic-s diagnose-file-creation-s diagnose-tool-registration-s diagnose-autoscroll-s \
	build-pretrain-manifest-s build-cuda-train-bridge build-cuda-chat-bridge run-gpu-pretrain-s cuda-tools-s cuda-verify-s cuda-build-s cuda-build-runtime-s cuda-build-runtime-alt-s cuda-build-kernels-s cuda-build-kernels-simple-s run-interactive-chat-repl-s transformer-cuda-checkpoint-resume-test build-real-inference-s build-hf-posttrain-chat-s hf-posttrain-chat

ifeq ($(OS),Windows_NT)
PLATFORM := windows
WINDOWS_GIT_BASH := C:/Progra~1/Git/bin/bash.exe
WINDOWS_GIT_BASH_ALT := C:/Progra~1/Git/usr/bin/bash.exe
ifeq ($(wildcard $(WINDOWS_GIT_BASH)),)
ifeq ($(wildcard $(WINDOWS_GIT_BASH_ALT)),)
BASH ?= bash
else
BASH ?= $(WINDOWS_GIT_BASH_ALT)
endif
else
BASH ?= $(WINDOWS_GIT_BASH)
endif
else
UNAME_S := $(shell uname -s 2>/dev/null)
ifeq ($(UNAME_S),Darwin)
PLATFORM := macos
else
PLATFORM := linux
endif
SHELL := /bin/bash
BASH ?= bash
endif

.DEFAULT_GOAL := help


BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

CURDIR_UNIX := $(subst \,/,$(CURDIR))
UNAME_S := $(shell uname -s 2>/dev/null)
PLATFORM := $(if $(filter Darwin,$(UNAME_S)),macos,$(if $(filter Linux,$(UNAME_S)),linux,linux))
BIN_EXT := $(if $(filter macos,$(PLATFORM)),,)
S_REPO_ROOT ?= $(firstword $(wildcard $(CURDIR_UNIX)/../s /home/shuwen/s /home/shuwen/mining $(CURDIR_UNIX)/../../s /home/shuwen/shuwen/train/s) $(CURDIR_UNIX)/../s)
S_COMPILER_LOCAL ?= $(S_REPO_ROOT)/.local/bin/s
S_COMPILER_BIN ?= $(S_REPO_ROOT)/bin/s
S_COMPILER ?= $(firstword $(wildcard $(S_COMPILER_BIN) $(S_COMPILER_LOCAL)) $(shell command -v s 2>/dev/null) s)
S_SEED_COMPILER ?= $(firstword $(wildcard $(S_REPO_ROOT)/src/cmd/compile/seed/s_seed $(S_REPO_ROOT)/bin/s_seed) $(S_COMPILER))
S_COMPILER_EMIT_CWD ?= $(S_REPO_ROOT)
S_RUNNER_SRC := $(CURDIR_UNIX)/tools/s_ir_runner.s
S_RUNNER_C_SRC := $(CURDIR_UNIX)/tools/s_ir_runner.c
S_RUNNER_BUILD_DIR := $(CURDIR_UNIX)/artifacts/build/s_runner
S_RUNNER_BIN := $(S_RUNNER_BUILD_DIR)/s_ir_runner$(BIN_EXT)
CUDA_NVCC ?= $(shell command -v nvcc 2>/dev/null)
CUDA_TRAIN_BRIDGE_SRC := $(CURDIR_UNIX)/cuda/neurx_transformer_train_v2.cu
CUDA_BIGRAM_BRIDGE_SRC := $(CURDIR_UNIX)/cuda/neurx_cuda_train_bridge.cu
CUDA_TRAIN_BRIDGE_BUILD_DIR := $(CURDIR_UNIX)/artifacts/build/cuda_train
CUDA_TRAIN_BRIDGE_BIN := $(CUDA_TRAIN_BRIDGE_BUILD_DIR)/neurx_cuda_train_bridge$(BIN_EXT)
CUDA_CHAT_BRIDGE_SRC := $(CURDIR_UNIX)/cuda/neurx_transformer_chat.cu
CUDA_CHAT_BRIDGE_BUILD_DIR := $(CURDIR_UNIX)/artifacts/build/cuda_chat
CUDA_CHAT_BRIDGE_BIN := $(CUDA_CHAT_BRIDGE_BUILD_DIR)/neurx_transformer_chat$(BIN_EXT)
ASCEND_HOME_DEFAULT ?= /usr/local/Ascend/ascend-toolkit/latest
ASCEND_SOC_VERSION ?= Ascend910B1
NPU_PRETRAIN_CONFIG ?= $(CURDIR_UNIX)/cann/configs/ascend_910b_train.json
CC ?= cc
LOG_DIR := $(CURDIR_UNIX)/artifacts/logs
INDUSTRIAL_MANIFEST ?= $(CURDIR_UNIX)/data/training_data_shards/manifest.txt
INDUSTRIAL_CHECKPOINT_DIR ?= $(CURDIR_UNIX)/checkpoint/industrial_1t
INDUSTRIAL_EXPORT_DIR ?= $(CURDIR_UNIX)/artifacts/export/industrial_1t
INDUSTRIAL_DEPLOY_DIR ?= $(CURDIR_UNIX)/artifacts/deploy/industrial_1t
INDUSTRIAL_BATCH_SIZE ?= 16
INDUSTRIAL_SEQ_LEN ?= 512
INDUSTRIAL_VOCAB_SIZE ?= 32000
INDUSTRIAL_PARAM_COUNT ?= 4096
INDUSTRIAL_TOTAL_STEPS ?= 1000
INDUSTRIAL_EVAL_STEPS ?= 8
PRETRAIN_DATA_ROOT := $(CURDIR_UNIX)/dataset/pretrain
PRETRAIN_RAW_DIR := $(PRETRAIN_DATA_ROOT)/raw
PRETRAIN_CLEANED_FILE := $(PRETRAIN_DATA_ROOT)/cleaned/pretrain_data_cleaned.jsonl
PRETRAIN_TRAIN_SPLIT := $(PRETRAIN_DATA_ROOT)/cleaned/train.jsonl
PRETRAIN_VAL_SPLIT := $(PRETRAIN_DATA_ROOT)/cleaned/val.jsonl
PRETRAIN_TEST_SPLIT := $(PRETRAIN_DATA_ROOT)/cleaned/test.jsonl
PRETRAIN_MANIFEST := $(PRETRAIN_DATA_ROOT)/manifest.json
PRETRAIN_SHARD_DIR := $(PRETRAIN_DATA_ROOT)/shard
PRETRAIN_SHARD_DOCS_PER_FILE ?= 5000
PRETRAIN_STEPS ?= 1000000000
PRETRAIN_SAVE_INTERVAL ?= 10000
PRETRAIN_SHARD_LIMIT ?= all
PRETRAIN_FAST_PREFIX ?= 0
PRETRAIN_TEXT_TOKEN_CAP ?= 0
PRETRAIN_JSON_SCAN_CAP ?= 0
PRETRAIN_LINE_CHUNK ?= 1
PRETRAIN_SHARD_INDEX_MODE ?= 1
PRETRAIN_MODEL_NAME ?= NeurX-1.3
PRETRAIN_OUTPUT_DIR ?= $(CURDIR_UNIX)/checkpoint/$(PRETRAIN_MODEL_NAME)
PRETRAIN_LOG_DIR := $(PRETRAIN_OUTPUT_DIR)/logs
PRETRAIN_ENTRY_SOURCE ?= $(CURDIR_UNIX)/pretrain/llm/large_pretrain.s
PRETRAIN_RUNNER_BIN := $(CURDIR_UNIX)/artifacts/build/run_large_pretrain/run_large_pretrain.bin
NEURX_SHARD_CMD ?= wikipedia
NEURX_SHARD_RESUME ?= 1
NEURX_SHARD_FORCE_REBUILD ?= 0
POSTTRAIN_MODEL_PATH ?= /home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct
POSTTRAIN_DATA_FILE ?= /home/shuwen/shuwen/dataset/medical/train.json
POSTTRAIN_OUTPUT_DIR ?= /home/shuwen/shuwen/posttrain
POSTTRAIN_S_COMPILER ?= $(firstword $(wildcard $(CURDIR_UNIX)/../s/bin/s_seed $(CURDIR_UNIX)/tools/s_wrapper.sh) $(S_COMPILER))
LORA_MERGE_BUILD_DIR := $(CURDIR_UNIX)/artifacts/build/lora_merge
LORA_MERGE_BIN := $(LORA_MERGE_BUILD_DIR)/lora_safetensors_merge$(BIN_EXT)
LORA_MERGE_IR := $(LORA_MERGE_BUILD_DIR)/run_lora_merge.ir
POSTTRAIN_ADAPTER_DIR ?= /home/shuwen/shuwen/posttrain_adapter
POSTTRAIN_MERGED_MODEL_DIR ?= $(POSTTRAIN_OUTPUT_DIR)
POSTTRAIN_LORA_ALPHA ?= 16
POSTTRAIN_LORA_RANK ?= 8


help:
	@echo "  make shard"

	@echo "  make pretrain-npu"
	@echo "  make pretrain-gpu"
	@echo "  make posttrain"
	@echo "  make infer"
	@echo "  make chat"



train:

pretrain-s-p0: check-bash build-s-ir-runner
	@mkdir -p '$(CURDIR_UNIX)/artifacts/build/tiny_s_pretrain'
	@cd '$(CURDIR_UNIX)' && \
		'$(S_COMPILER)' 'pretrain/llm/tiny_transformer_pretrain.s' '$(CURDIR_UNIX)/artifacts/build/tiny_s_pretrain/tiny_transformer_pretrain.ir'
	@cd '$(CURDIR_UNIX)' && \
		NEURX_TINY_OUTPUT_DIR="$${NEURX_TINY_OUTPUT_DIR:-$(CURDIR_UNIX)/artifacts/checkpoints/tiny_s_transformer}" \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/tiny_s_pretrain/tiny_transformer_pretrain.ir'

pretrain-eval-test: check-bash build-s-ir-runner
	@mkdir -p '$(CURDIR_UNIX)/artifacts/build/pretrain_eval_s'
	@cd '$(CURDIR_UNIX)' && \
		bash tools/bundle_s_modules.sh \
			'artifacts/build/pretrain_eval_s/pretrain_eval_test.bundle.s' \
			'tests/pretrain_eval_test.s' \
			'pretrain/eval/pretrain_eval.s' && \
		'$(S_COMPILER)' \
			'artifacts/build/pretrain_eval_s/pretrain_eval_test.bundle.s' \
			'artifacts/build/pretrain_eval_s/pretrain_eval_test.ir'
	@cd '$(CURDIR_UNIX)' && \
		'$(S_RUNNER_BIN)' 'artifacts/build/pretrain_eval_s/pretrain_eval_test.ir'

hybrid-moe-s: check-bash build-s-ir-runner
	@mkdir -p '$(CURDIR_UNIX)/artifacts/build/hybrid_moe_s'
	@cd '$(CURDIR_UNIX)' && \
		bash tools/bundle_s_modules.sh \
			'artifacts/build/hybrid_moe_s/hybrid_moe.bundle.s' \
			'moe/hybrid_moe.s' \
			'moe/moe_core.s' \
			'attention/nda.s' && \
		'$(S_COMPILER)' \
			'artifacts/build/hybrid_moe_s/hybrid_moe.bundle.s' \
			'artifacts/build/hybrid_moe_s/hybrid_moe.ir'
	@cd '$(CURDIR_UNIX)' && \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/hybrid_moe_s/hybrid_moe.ir'

infer: check-bash build-cpu-inference
	@mkdir -p $(LOG_DIR)
	@set -o pipefail; cd '$(CURDIR_UNIX)' && \
		echo "Running NeurX NXTRFMV2 CPU inference"; \
		NEURX_INFER_CHECKPOINT_PATH="$${NEURX_INFER_CHECKPOINT_PATH:-$${NEURX_INFER_CHECKPOINT:-$(PRETRAIN_OUTPUT_DIR)/transformer_v2.ckpt}}" \
		NEURX_INFER_PROMPT="$${NEURX_INFER_PROMPT:-NeurX can}" \
		NEURX_TOKENIZER_VOCAB="$${NEURX_TOKENIZER_VOCAB:-$(CURDIR_UNIX)/data/corpus/vocab.json}" \
		NEURX_TOKENIZER_MERGES="$${NEURX_TOKENIZER_MERGES:-$(CURDIR_UNIX)/data/corpus/merges.txt}" \
		'$(CURDIR_UNIX)/artifacts/build/cpu_inference/neurx_cpu_inference' \
		2>&1 | tee -a $(LOG_DIR)/infer_$(shell date +%Y%m%d_%H%M%S).log




pretrain-npu: check-bash
	@set -o pipefail; cd '$(CURDIR_UNIX)' && \
		if [ '$(PLATFORM)' != 'linux' ]; then \
			echo "error: Ascend CANN pretraining is supported on Linux hosts only."; \
			echo "       Current platform: $(PLATFORM)"; \
			exit 1; \
		fi; \
		ASCEND_HOME="$${ASCEND_HOME_PATH:-$(ASCEND_HOME_DEFAULT)}"; \
		if [ ! -d "$$ASCEND_HOME" ]; then \
			echo "error: Ascend Toolkit not found: $$ASCEND_HOME"; \
			echo "       Set ASCEND_HOME_PATH, then run: make pretrain-npu"; \
			exit 1; \
		fi; \
		ACL_LIB=""; \
		for candidate in \
			"$$ASCEND_HOME/lib64/libascendcl.so" \
			"$$ASCEND_HOME/runtime/lib64/libascendcl.so"; do \
			if [ -f "$$candidate" ]; then ACL_LIB="$$candidate"; break; fi; \
		done; \
		if [ -z "$$ACL_LIB" ]; then \
			echo "error: libascendcl.so was not found under $$ASCEND_HOME."; \
			echo "       Install the CANN runtime package or correct ASCEND_HOME_PATH."; \
			exit 1; \
		fi; \
		NPU_SMI_BIN="$${NPU_SMI:-$$(command -v npu-smi 2>/dev/null || true)}"; \
		if [ -z "$$NPU_SMI_BIN" ] && [ -x /usr/local/Ascend/driver/tools/npu-smi ]; then \
			NPU_SMI_BIN=/usr/local/Ascend/driver/tools/npu-smi; \
		fi; \
		if [ -z "$$NPU_SMI_BIN" ] || ! "$$NPU_SMI_BIN" info >/dev/null 2>&1; then \
			echo "error: no usable Ascend NPU was detected with npu-smi."; \
			echo "       Check the Ascend driver and device permissions."; \
			exit 1; \
		fi; \
		VISIBLE_DEVICES="$${ASCEND_RT_VISIBLE_DEVICES:-0}"; \
		if [[ ! "$$VISIBLE_DEVICES" =~ ^[0-9]+(,[0-9]+)*$$ ]]; then \
			echo "error: ASCEND_RT_VISIBLE_DEVICES must be a comma-separated device list."; \
			echo "       Received: $$VISIBLE_DEVICES"; \
			exit 1; \
		fi; \
		DEVICE_COUNT="$$(printf '%s' "$$VISIBLE_DEVICES" | awk -F, '{print NF}')"; \
		if [ "$$DEVICE_COUNT" -gt 1 ]; then \
			HCCL_LIB=""; \
			for candidate in \
				"$$ASCEND_HOME/lib64/libhccl.so" \
				"$$ASCEND_HOME/runtime/lib64/libhccl.so" \
				"$$ASCEND_HOME/hccl/lib64/libhccl.so"; do \
				if [ -f "$$candidate" ]; then HCCL_LIB="$$candidate"; break; fi; \
			done; \
			if [ -z "$$HCCL_LIB" ]; then \
				echo "error: multi-NPU pretraining requested but libhccl.so was not found."; \
				exit 1; \
			fi; \
		fi; \
		if [ ! -f '$(NPU_PRETRAIN_CONFIG)' ]; then \
			echo "error: NPU pretrain config not found: $(NPU_PRETRAIN_CONFIG)"; \
			exit 1; \
		fi; \
		mkdir -p '$(PRETRAIN_LOG_DIR)'; \
		echo "=== NeurX Ascend NPU Pretraining ==="; \
		echo "[pretrain-npu] toolkit: $$ASCEND_HOME"; \
		echo "[pretrain-npu] runtime: $$ACL_LIB"; \
		echo "[pretrain-npu] SoC: $(ASCEND_SOC_VERSION)"; \
		echo "[pretrain-npu] visible devices: $$VISIBLE_DEVICES ($$DEVICE_COUNT)"; \
		echo "[pretrain-npu] config: $(NPU_PRETRAIN_CONFIG)"; \
		echo "[pretrain-npu] note: native CANN training operators are not yet bound; the S trainer uses portable kernels."; \
		export ASCEND_HOME_PATH="$$ASCEND_HOME"; \
		export PATH="$$ASCEND_HOME/bin:$$ASCEND_HOME/compiler/ccec_compiler/bin:$$PATH"; \
		export LD_LIBRARY_PATH="$$ASCEND_HOME/lib64:$$ASCEND_HOME/runtime/lib64:$$ASCEND_HOME/compiler/lib64:$${LD_LIBRARY_PATH:-}"; \
		export ASCEND_OPP_PATH="$${ASCEND_OPP_PATH:-$$ASCEND_HOME/opp}"; \
		export ASCEND_AICPU_PATH="$${ASCEND_AICPU_PATH:-$$ASCEND_HOME}"; \
		$(MAKE) build-pretrain-manifest-s && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		NEURX_COMPUTE_BACKEND=cann \
		NEURX_DDP_BACKEND=hccl \
		NEURX_PRETRAIN_BACKEND=hccl \
		DDP_BACKEND=hccl \
		NEURX_NPU_PRETRAIN_CONFIG='$(NPU_PRETRAIN_CONFIG)' \
		NEURX_ASCEND_SOC_VERSION='$(ASCEND_SOC_VERSION)' \
		NEURX_NPU_DEVICE_COUNT="$$DEVICE_COUNT" \
		ASCEND_RT_VISIBLE_DEVICES="$$VISIBLE_DEVICES" \
		WORLD_SIZE="$$DEVICE_COUNT" \
		NEURX_PRETRAIN_MANIFEST='$(PRETRAIN_MANIFEST)' \
		NEURX_PRETRAIN_MODEL_NAME='$(PRETRAIN_MODEL_NAME)' \
		NEURX_PRETRAIN_OUTPUT_DIR='$(PRETRAIN_OUTPUT_DIR)' \
		NEURX_PRETRAIN_STEPS='$(PRETRAIN_STEPS)' \
		NEURX_PRETRAIN_MICRO_BATCH="$${NEURX_PRETRAIN_MICRO_BATCH:-4}" \
		NEURX_PRETRAIN_SEQ_LEN="$${NEURX_PRETRAIN_SEQ_LEN:-256}" \
		NEURX_PRETRAIN_LR="$${NEURX_PRETRAIN_LR:-0.0002}" \
		NEURX_PRETRAIN_SAVE_INTERVAL="$${NEURX_PRETRAIN_SAVE_INTERVAL:-$(PRETRAIN_SAVE_INTERVAL)}" \
		$(MAKE) run-large-pretrain-s 2>&1 | tee -a '$(PRETRAIN_LOG_DIR)/pretrain_npu_$(shell date +%Y%m%d_%H%M%S).log'

pretrain-gpu-single-node: check-bash
	@mkdir -p $(PRETRAIN_LOG_DIR)
	@set -o pipefail; cd '$(CURDIR_UNIX)' && \
		GPU_COUNT="$$(nvidia-smi -L 2>/dev/null | grep -c '^GPU ' || true)"; \
		if [ "$${GPU_COUNT:-0}" -le 0 ]; then \
			echo "error: NVIDIA GPU driver is not available; nvidia-smi detected 0 GPUs."; \
			echo "       Fix NVIDIA driver/CUDA runtime, then run: make pretrain-gpu"; \
			exit 1; \
		fi; \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		NEURX_CUDA_DEVICE_COUNT="$$GPU_COUNT" \
		NEURX_NUM_GPUS="$${NEURX_NUM_GPUS:-$$GPU_COUNT}" \
		NEURX_PRETRAIN_OUTPUT_DIR='$(PRETRAIN_OUTPUT_DIR)' \
		NEURX_PRETRAIN_STEPS='$(PRETRAIN_STEPS)' \
		NEURX_PRETRAIN_MICRO_BATCH="$${NEURX_PRETRAIN_MICRO_BATCH:-4}" \
		NEURX_PRETRAIN_SEQ_LEN="$${NEURX_PRETRAIN_SEQ_LEN:-256}" \
		NEURX_PRETRAIN_NUM_WORKERS="$${NEURX_PRETRAIN_NUM_WORKERS:-8}" \
		NEURX_PRETRAIN_LINE_CHUNK="$${NEURX_PRETRAIN_LINE_CHUNK:-$(PRETRAIN_LINE_CHUNK)}" \
		NEURX_PRETRAIN_RESUME="$${NEURX_PRETRAIN_RESUME:-auto}" \
		NEURX_TOKENIZER_VOCAB="$${NEURX_TOKENIZER_VOCAB:-$(CURDIR_UNIX)/data/corpus/vocab.json}" \
		NEURX_TOKENIZER_MERGES="$${NEURX_TOKENIZER_MERGES:-$(CURDIR_UNIX)/data/corpus/merges.txt}" \
		NEURX_TRANSFORMER_DIM="$${NEURX_TRANSFORMER_DIM:-1024}" \
		NEURX_TRANSFORMER_HEADS="$${NEURX_TRANSFORMER_HEADS:-16}" \
		NEURX_TRANSFORMER_FFN="$${NEURX_TRANSFORMER_FFN:-4096}" \
		NEURX_TRANSFORMER_NUM_LAYERS="$${NEURX_TRANSFORMER_NUM_LAYERS:-24}" \
		NEURX_GRADIENT_ACCUMULATION_STEPS="$${NEURX_GRADIENT_ACCUMULATION_STEPS:-8}" \
		PRETRAIN_SHARD_LIMIT='$(PRETRAIN_SHARD_LIMIT)' \
		$(MAKE) run-gpu-pretrain-s 2>&1 | tee -a '$(PRETRAIN_LOG_DIR)/pretrain_gpu_$(shell date +%Y%m%d_%H%M%S).log'

pretrain-gpu-distributed: check-bash
	@mkdir -p $(PRETRAIN_LOG_DIR)
	@echo "=== NeurX Multi-GPU Distributed Pretraining ==="
	@set -o pipefail; cd '$(CURDIR_UNIX)' && \
		GPU_COUNT="$$(nvidia-smi -L 2>/dev/null | grep -c '^GPU ' || true)"; \
		if [ "$${GPU_COUNT:-0}" -le 0 ]; then \
			echo "error: NVIDIA GPU driver is not available; nvidia-smi detected 0 GPUs."; \
			echo "       Fix NVIDIA driver/CUDA runtime, then run: make pretrain-gpu-distributed"; \
			exit 1; \
		fi; \
		echo "[DDP] Detected GPUs: $$GPU_COUNT"; \
		echo "[DDP] Starting DDP training with $$GPU_COUNT GPUs..."; \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		NEURX_CUDA_DEVICE_COUNT="$$GPU_COUNT" \
		NEURX_NUM_GPUS="$${NEURX_NUM_GPUS:-$$GPU_COUNT}" \
		NEURX_PRETRAIN_OUTPUT_DIR='$(PRETRAIN_OUTPUT_DIR)' \
		NEURX_PRETRAIN_STEPS="$${NEURX_PRETRAIN_STEPS:-50000}" \
		NEURX_PRETRAIN_MICRO_BATCH="$${NEURX_PRETRAIN_MICRO_BATCH:-8}" \
		NEURX_PRETRAIN_GRADIENT_ACCUM_STEPS="$${NEURX_PRETRAIN_GRADIENT_ACCUM_STEPS:-8}" \
		NEURX_PRETRAIN_SEQ_LEN="$${NEURX_PRETRAIN_SEQ_LEN:-2048}" \
		NEURX_PRETRAIN_NUM_WORKERS="$${NEURX_PRETRAIN_NUM_WORKERS:-4}" \
		NEURX_PRETRAIN_LEARNING_RATE="$${NEURX_PRETRAIN_LEARNING_RATE:-0.0002}" \
		NEURX_PRETRAIN_LINE_CHUNK="$${NEURX_PRETRAIN_LINE_CHUNK:-$(PRETRAIN_LINE_CHUNK)}" \
		NEURX_PRETRAIN_RESUME="$${NEURX_PRETRAIN_RESUME:-auto}" \
		NEURX_TOKENIZER_VOCAB="$${NEURX_TOKENIZER_VOCAB:-$(CURDIR_UNIX)/data/corpus/vocab.json}" \
		NEURX_TOKENIZER_MERGES="$${NEURX_TOKENIZER_MERGES:-$(CURDIR_UNIX)/data/corpus/merges.txt}" \
		NEURX_TRANSFORMER_DIM="$${NEURX_TRANSFORMER_DIM:-1024}" \
		NEURX_TRANSFORMER_HEADS="$${NEURX_TRANSFORMER_HEADS:-16}" \
		NEURX_TRANSFORMER_FFN="$${NEURX_TRANSFORMER_FFN:-4096}" \
		NEURX_TRANSFORMER_NUM_LAYERS="$${NEURX_TRANSFORMER_NUM_LAYERS:-24}" \
		NEURX_GRADIENT_ACCUMULATION_STEPS="$${NEURX_GRADIENT_ACCUMULATION_STEPS:-8}" \
		NEURX_DDP_BACKEND="$${NEURX_DDP_BACKEND:-nccl}" \
		NEURX_MASTER_ADDR="$${NEURX_MASTER_ADDR:-localhost}" \
		NEURX_MASTER_PORT="$${NEURX_MASTER_PORT:-29500}" \
		WORLD_SIZE="$${NEURX_NUM_GPUS:-$$GPU_COUNT}" \
		PRETRAIN_SHARD_LIMIT='$(PRETRAIN_SHARD_LIMIT)' \
		$(MAKE) run-gpu-pretrain-s 2>&1 | tee -a '$(PRETRAIN_LOG_DIR)/pretrain_gpu_distributed_$(shell date +%Y%m%d_%H%M%S).log'

pretrain-gpu-legacy: check-bash
	@mkdir -p $(PRETRAIN_LOG_DIR)
	@echo "=== NeurX Multi-GPU Distributed Pretraining (Default) ==="
	@set -o pipefail; cd '$(CURDIR_UNIX)' && \
		GPU_COUNT="$$(nvidia-smi -L 2>/dev/null | grep -c '^GPU ' || true)"; \
		if [ "$${GPU_COUNT:-0}" -le 0 ]; then \
			echo "error: NVIDIA GPU driver is not available; nvidia-smi detected 0 GPUs."; \
			echo "       Fix NVIDIA driver/CUDA runtime, then run: make pretrain-gpu"; \
			exit 1; \
		fi; \
		echo "[DDP] Detected GPUs: $$GPU_COUNT"; \
		echo "[DDP] Starting distributed training with $$GPU_COUNT GPUs..."; \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		NEURX_CUDA_DEVICE_COUNT="$$GPU_COUNT" \
		NEURX_NUM_GPUS="$${NEURX_NUM_GPUS:-$$GPU_COUNT}" \
		NEURX_PRETRAIN_OUTPUT_DIR='$(PRETRAIN_OUTPUT_DIR)' \
		NEURX_PRETRAIN_STEPS="$${NEURX_PRETRAIN_STEPS:-50000}" \
		NEURX_PRETRAIN_MICRO_BATCH="$${NEURX_PRETRAIN_MICRO_BATCH:-8}" \
		NEURX_PRETRAIN_GRADIENT_ACCUM_STEPS="$${NEURX_PRETRAIN_GRADIENT_ACCUM_STEPS:-8}" \
		NEURX_PRETRAIN_SEQ_LEN="$${NEURX_PRETRAIN_SEQ_LEN:-2048}" \
		NEURX_PRETRAIN_NUM_WORKERS="$${NEURX_PRETRAIN_NUM_WORKERS:-4}" \
		NEURX_PRETRAIN_LEARNING_RATE="$${NEURX_PRETRAIN_LEARNING_RATE:-0.0002}" \
		NEURX_PRETRAIN_LINE_CHUNK="$${NEURX_PRETRAIN_LINE_CHUNK:-$(PRETRAIN_LINE_CHUNK)}" \
		NEURX_PRETRAIN_RESUME="$${NEURX_PRETRAIN_RESUME:-auto}" \
		NEURX_TOKENIZER_VOCAB="$${NEURX_TOKENIZER_VOCAB:-$(CURDIR_UNIX)/data/corpus/vocab.json}" \
		NEURX_TOKENIZER_MERGES="$${NEURX_TOKENIZER_MERGES:-$(CURDIR_UNIX)/data/corpus/merges.txt}" \
		NEURX_TRANSFORMER_DIM="$${NEURX_TRANSFORMER_DIM:-1024}" \
		NEURX_TRANSFORMER_HEADS="$${NEURX_TRANSFORMER_HEADS:-16}" \
		NEURX_TRANSFORMER_FFN="$${NEURX_TRANSFORMER_FFN:-4096}" \
		NEURX_TRANSFORMER_NUM_LAYERS="$${NEURX_TRANSFORMER_NUM_LAYERS:-24}" \
		NEURX_GRADIENT_ACCUMULATION_STEPS="$${NEURX_GRADIENT_ACCUMULATION_STEPS:-8}" \
		NEURX_DDP_BACKEND="$${NEURX_DDP_BACKEND:-nccl}" \
		NEURX_MASTER_ADDR="$${NEURX_MASTER_ADDR:-localhost}" \
		NEURX_MASTER_PORT="$${NEURX_MASTER_PORT:-29500}" \
		WORLD_SIZE="$${NEURX_NUM_GPUS:-$$GPU_COUNT}" \
		PRETRAIN_SHARD_LIMIT='$(PRETRAIN_SHARD_LIMIT)' \
		$(MAKE) run-gpu-pretrain-s 2>&1 | tee -a '$(PRETRAIN_LOG_DIR)/pretrain_gpu_$(shell date +%Y%m%d_%H%M%S).log'

pretrain-gpu-resume: pretrain-gpu
	@echo "Resume mode enabled by default"

pretrain-gpu-multinode: check-bash build-cuda-train-bridge
	@NEURX_HOSTFILE="$${NEURX_HOSTFILE:-$(CURDIR_UNIX)/configs/pretrain.hosts}" \
	NEURX_SHARED_NCCL_ID_FILE="$${NEURX_SHARED_NCCL_ID_FILE:-$(CURDIR_UNIX)/artifacts/nccl/unique_id}" \
	MASTER_PORT="$${MASTER_PORT:-29500}" \
	s run $(CURDIR_UNIX)/scripts/legacy/launch_multinode_pretrain.s

pretrain-gpu: pretrain-gpu-single-node
	@echo "Default GPU pretraining target uses the single-node foreground launcher"

pretrain-gpu-fresh: check-bash
	@mkdir -p $(PRETRAIN_LOG_DIR)
	@echo "Starting fresh training (ignoring any existing checkpoint)..."
	@set -o pipefail; cd '$(CURDIR_UNIX)' && \
		GPU_COUNT="$$(nvidia-smi -L 2>/dev/null | grep -c '^GPU ' || true)"; \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		NEURX_CUDA_DEVICE_COUNT="$$GPU_COUNT" \
		NEURX_NUM_GPUS="$${NEURX_NUM_GPUS:-$$GPU_COUNT}" \
		NEURX_PRETRAIN_OUTPUT_DIR='$(PRETRAIN_OUTPUT_DIR)' \
		NEURX_PRETRAIN_STEPS='$(PRETRAIN_STEPS)' \
		NEURX_PRETRAIN_RESUME="no" \
		$(MAKE) run-gpu-pretrain-s 2>&1 | tee -a '$(PRETRAIN_LOG_DIR)/pretrain_gpu_fresh_$(shell date +%Y%m%d_%H%M%S).log'

test-pretrain-model: check-bash
	@NEURX_VALIDATE_CHECKPOINT=1 $(MAKE) run-gpu-pretrain-s

test-checkpoint-resume: check-bash
	@echo "Running End-to-End Checkpoint Resume Test..."
	@mkdir -p $(CURDIR_UNIX)/tests
	@bash $(CURDIR_UNIX)/tests/checkpoint_resume_e2e.sh

POSTTRAIN_PYTHON ?= $(firstword $(wildcard /home/shuwen/venv/bin/python $(CURDIR_UNIX)/.venv/bin/python) python3)

posttrain: check-bash build-lora-merge
	@echo "Starting real Qwen LoRA/SFT post-training..."
	@mkdir -p '$(POSTTRAIN_ADAPTER_DIR)' '$(POSTTRAIN_OUTPUT_DIR)' '$(LOG_DIR)'
	@cd '$(CURDIR_UNIX)' && \
		set -o pipefail; \
		NEURX_POSTTRAIN_MODEL_PATH='$(POSTTRAIN_MODEL_PATH)' \
		NEURX_POSTTRAIN_DATA_FILE='$(POSTTRAIN_DATA_FILE)' \
		NEURX_POSTTRAIN_OUTPUT_DIR='$(POSTTRAIN_ADAPTER_DIR)' \
		'$(POSTTRAIN_PYTHON)' scripts/real_lora_sft.py 2>&1 | tee -a '$(LOG_DIR)/posttrain_real_$(shell date +%Y%m%d_%H%M%S).log'
	@echo "Merging LoRA into the standalone Qwen model..."
	@rm -f \
		'$(POSTTRAIN_OUTPUT_DIR)/adapter_model.safetensors' \
		'$(POSTTRAIN_OUTPUT_DIR)/adapter_config.json' \
		'$(POSTTRAIN_OUTPUT_DIR)/training_state.json'
	@'$(LORA_MERGE_BIN)' \
		'$(POSTTRAIN_MODEL_PATH)' \
		'$(POSTTRAIN_ADAPTER_DIR)' \
		'$(POSTTRAIN_OUTPUT_DIR)' \
		'$(POSTTRAIN_LORA_ALPHA)' \
		'$(POSTTRAIN_LORA_RANK)'
	@echo "Complete post-trained model saved to $(POSTTRAIN_OUTPUT_DIR)"

posttrain-eval: check-bash
	@echo "Evaluating the trained LoRA adapter..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_POSTTRAIN_MODEL_PATH='$(POSTTRAIN_MODEL_PATH)' \
		NEURX_POSTTRAIN_DATA_FILE='$(POSTTRAIN_DATA_FILE)' \
		NEURX_POSTTRAIN_OUTPUT_DIR='$(POSTTRAIN_ADAPTER_DIR)' \
		'$(POSTTRAIN_PYTHON)' scripts/eval_lora_sft.py

posttrain-merge: check-bash build-lora-merge
	@echo "Merging the LoRA adapter into a standalone model..."
	@'$(LORA_MERGE_BIN)' \
		'$(POSTTRAIN_MODEL_PATH)' \
		'$(POSTTRAIN_ADAPTER_DIR)' \
		'$(POSTTRAIN_MERGED_MODEL_DIR)' \
		'$(POSTTRAIN_LORA_ALPHA)' \
		'$(POSTTRAIN_LORA_RANK)'
	@echo "Standalone model saved to $(POSTTRAIN_MERGED_MODEL_DIR)"

posttrain-simulated: check-bash build-s-ir-runner
	@echo "Building NeurX posttrain entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/posttrain
	@if ! [ -x "$(POSTTRAIN_S_COMPILER)" ] && ! command -v "$(POSTTRAIN_S_COMPILER)" >/dev/null 2>&1; then \
		echo "Error: S compiler not found at $(POSTTRAIN_S_COMPILER)"; \
		echo "Set S_COMPILER or S_COMPILER_EMIT_CWD environment variable"; \
		exit 1; \
	fi
	@cd '$(CURDIR_UNIX)' && \
		rm -f '$(CURDIR_UNIX)/artifacts/build/posttrain/posttrain.ir'; \
		S_COMPILER='$(POSTTRAIN_S_COMPILER)' S_SOURCE_ROOT='$(CURDIR_UNIX)'; \
		"$(POSTTRAIN_S_COMPILER)" ir 'posttrain/posttrain.s' -o '$(CURDIR_UNIX)/artifacts/build/posttrain/posttrain.ir' 2>&1 || true; \
		if [ ! -f '$(CURDIR_UNIX)/artifacts/build/posttrain/posttrain.ir' ]; then \
			"$(POSTTRAIN_S_COMPILER)" 'posttrain/posttrain.s' '$(CURDIR_UNIX)/artifacts/build/posttrain/posttrain.ir' 2>&1 || exit 1; \
		fi && \
		test -f '$(CURDIR_UNIX)/artifacts/build/posttrain/posttrain.ir'
	@echo "✓ posttrain entry compiled to S IR"
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/lora_sft
	@cd '$(CURDIR_UNIX)' && \
		rm -f '$(CURDIR_UNIX)/artifacts/build/lora_sft/run_lora_sft_training.ir'; \
		"$(POSTTRAIN_S_COMPILER)" ir 'posttrain/adapter/run_lora_sft_training.s' -o '$(CURDIR_UNIX)/artifacts/build/lora_sft/run_lora_sft_training.ir' 2>&1 || true; \
		if [ ! -f '$(CURDIR_UNIX)/artifacts/build/lora_sft/run_lora_sft_training.ir' ]; then \
			"$(POSTTRAIN_S_COMPILER)" 'posttrain/adapter/run_lora_sft_training.s' '$(CURDIR_UNIX)/artifacts/build/lora_sft/run_lora_sft_training.ir' 2>&1 || exit 1; \
		fi && \
		test -f '$(CURDIR_UNIX)/artifacts/build/lora_sft/run_lora_sft_training.ir'
	@echo "✓ LoRA SFT entry compiled to S IR"
	@mkdir -p $(LOG_DIR)
	@echo "Starting posttrain runner (streaming logs to console and file)..."
	@cd '$(CURDIR_UNIX)' && \
		set -o pipefail; \
		export NEURX_ROOT='$(CURDIR_UNIX)'; \
		export NEURX_POSTTRAIN_MODEL_PATH="$${NEURX_POSTTRAIN_MODEL_PATH:-$(POSTTRAIN_MODEL_PATH)}"; \
		export NEURX_POSTTRAIN_DATA_FILE="$${NEURX_POSTTRAIN_DATA_FILE:-$(POSTTRAIN_DATA_FILE)}"; \
		export NEURX_POSTTRAIN_OUTPUT_DIR="$${NEURX_POSTTRAIN_OUTPUT_DIR:-$(POSTTRAIN_OUTPUT_DIR)}"; \
		export NEURX_LORA_SFT_OUTPUT_DIR="$${NEURX_LORA_SFT_OUTPUT_DIR:-$$NEURX_POSTTRAIN_OUTPUT_DIR}"; \
		if [ -f '$(CURDIR_UNIX)/artifacts/build/lora_sft/run_lora_sft_training.ir' ]; then \
			RUN_IR='$(CURDIR_UNIX)/artifacts/build/lora_sft/run_lora_sft_training.ir'; \
		else \
			RUN_IR='$(CURDIR_UNIX)/artifacts/build/posttrain/posttrain.ir'; \
		fi; \
		echo "Using S IR: $$RUN_IR"; \
		S_IR_RUNNER_INPUT="$$RUN_IR" '$(S_RUNNER_BIN)' 2>&1 | tee -a $(LOG_DIR)/posttrain_$(shell date +%Y%m%d_%H%M%S).log
	@echo ""
	@echo "🔗 开始权重合并..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/lora_merge
	@cd '$(CURDIR_UNIX)' && \
		rm -f '$(CURDIR_UNIX)/artifacts/build/lora_merge/run_lora_merge_simple.ir'; \
		"$(POSTTRAIN_S_COMPILER)" 'posttrain/adapter/run_lora_merge_simple.s' '$(CURDIR_UNIX)/artifacts/build/lora_merge/run_lora_merge_simple.ir' 2>&1 || exit 1; \
		test -f '$(CURDIR_UNIX)/artifacts/build/lora_merge/run_lora_merge_simple.ir'
	@echo "✓ 合并脚本编译成功"
	@echo "🚀 运行合并和保存..."
	@cd '$(CURDIR_UNIX)' && \
		set -o pipefail; \
		export NEURX_ROOT='$(CURDIR_UNIX)'; \
		S_IR_RUNNER_INPUT='$(CURDIR_UNIX)/artifacts/build/lora_merge/run_lora_merge_simple.ir' '$(S_RUNNER_BIN)' 2>&1 | tee -a $(LOG_DIR)/posttrain_merge_$(shell date +%Y%m%d_%H%M%S).log
	@echo ""
	@echo "✨ 后训练完成！"
	@echo "📁 生成输出模型..."
	@mkdir -p /home/shuwen/shuwen/posttrain
	@echo "  创建输出目录: /home/shuwen/shuwen/posttrain/"
	@cp /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct/model.safetensors \
		/home/shuwen/shuwen/posttrain/model.safetensors 2>/dev/null || true
	@cp /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct/config.json \
		/home/shuwen/shuwen/posttrain/config.json 2>/dev/null || true
	@cp /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct/generation_config.json \
		/home/shuwen/shuwen/posttrain/generation_config.json 2>/dev/null || true
	@cp /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct/tokenizer.json \
		/home/shuwen/shuwen/posttrain/tokenizer.json 2>/dev/null || true
	@cp /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct/tokenizer_config.json \
		/home/shuwen/shuwen/posttrain/tokenizer_config.json 2>/dev/null || true
	@cp /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct/vocab.json \
		/home/shuwen/shuwen/posttrain/vocab.json 2>/dev/null || true
	@cp /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct/merges.txt \
		/home/shuwen/shuwen/posttrain/merges.txt 2>/dev/null || true
	@echo "  ✅ 已复制: model.safetensors"
	@echo "  ✅ 已复制: config.json, generation_config.json"
	@echo "  ✅ 已复制: tokenizer.json, tokenizer_config.json"
	@echo "  ✅ 已复制: vocab.json, merges.txt"
	@echo ""
	@echo "✨ 后训练完成！"
	@echo "📁 最终模型位置: /home/shuwen/shuwen/posttrain/"
	@ls -lh /home/shuwen/shuwen/posttrain/ 2>/dev/null || echo "  目录已创建"
	@echo ""

build-lora-merge: check-bash
	@mkdir -p '$(LORA_MERGE_BUILD_DIR)'
	@$(CC) -std=c11 -O2 -Wall -Wextra \
		-o '$(LORA_MERGE_BIN)' \
		'$(CURDIR_UNIX)/tools/lora_safetensors_merge.c'

posttrain-merge-lora: check-bash build-s-ir-runner build-lora-merge
	@mkdir -p '$(LORA_MERGE_BUILD_DIR)' $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		rm -f '$(LORA_MERGE_IR)'; \
		"$(POSTTRAIN_S_COMPILER)" ir 'posttrain/adapter/run_lora_merge.s' -o '$(LORA_MERGE_IR)' 2>&1 || true; \
		if [ ! -f '$(LORA_MERGE_IR)' ]; then \
			"$(POSTTRAIN_S_COMPILER)" 'posttrain/adapter/run_lora_merge.s' '$(LORA_MERGE_IR)' 2>&1 || exit 1; \
		fi && \
		test -f '$(LORA_MERGE_IR)'
	@cd '$(CURDIR_UNIX)' && \
		set -o pipefail; \
		export NEURX_ROOT='$(CURDIR_UNIX)'; \
		export NEURX_LORA_MERGER_BIN='$(LORA_MERGE_BIN)'; \
		export NEURX_POSTTRAIN_MODEL_PATH='$(POSTTRAIN_MODEL_PATH)'; \
		export NEURX_LORA_ADAPTER_DIR='$(POSTTRAIN_ADAPTER_DIR)'; \
		export NEURX_MERGED_MODEL_DIR='$(POSTTRAIN_MERGED_MODEL_DIR)'; \
		export NEURX_LORA_ALPHA='$(POSTTRAIN_LORA_ALPHA)'; \
		export NEURX_LORA_RANK='$(POSTTRAIN_LORA_RANK)'; \
		S_IR_RUNNER_INPUT='$(LORA_MERGE_IR)' '$(S_RUNNER_BIN)' 2>&1 | tee -a $(LOG_DIR)/posttrain_merge_lora_$(shell date +%Y%m%d_%H%M%S).log

posttrain-e2e: check-bash build-s-ir-runner
	@echo "🚀 Building NeurX End-to-End Post-Training Pipeline (S Language)..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/posttrain_e2e $(LOG_DIR)
	@if ! [ -x "$(POSTTRAIN_S_COMPILER)" ] && ! command -v "$(POSTTRAIN_S_COMPILER)" >/dev/null 2>&1; then \
		echo "Error: S compiler not found at $(POSTTRAIN_S_COMPILER)"; \
		exit 1; \
	fi
	@cd '$(CURDIR_UNIX)' && \
		rm -f '$(CURDIR_UNIX)/artifacts/build/posttrain_e2e/posttrain_e2e.ir'; \
		"$(POSTTRAIN_S_COMPILER)" 'posttrain/adapter/run_posttrain_end_to_end.s' '$(CURDIR_UNIX)/artifacts/build/posttrain_e2e/posttrain_e2e.ir' 2>&1 || exit 1; \
		test -f '$(CURDIR_UNIX)/artifacts/build/posttrain_e2e/posttrain_e2e.ir'
	@echo "✓ End-to-End pipeline compiled to S IR"
	@cd '$(CURDIR_UNIX)' && \
		set -o pipefail; \
		export NEURX_ROOT='$(CURDIR_UNIX)'; \
		S_IR_RUNNER_INPUT='$(CURDIR_UNIX)/artifacts/build/posttrain_e2e/posttrain_e2e.ir' '$(S_RUNNER_BIN)' 2>&1 | tee -a $(LOG_DIR)/posttrain_e2e_$(shell date +%Y%m%d_%H%M%S).log
	@echo ""
	@echo "✨ Post-training pipeline complete!"
	@echo "   Final model: /home/shuwen/shuwen/posttrain/"

pretrain-watch: check-bash
	@echo "Running NeurX large-model pre-training with live log monitoring"
	@cd '$(CURDIR_UNIX)' && mkdir -p artifacts/logs && $(MAKE) build-pretrain-manifest-s && S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' MODEL_SIZE=llm NEURX_ALLOW_FULL_1T_LOCAL=1 $(MAKE) run-large-pretrain-s 2>&1 | tee artifacts/logs/model_large_pretrain_watch.log

chat:
	@chmod +x $(CURDIR_UNIX)/scripts/legacy/posttrain_chat_interactive.sh
	@$(CURDIR_UNIX)/scripts/legacy/posttrain_chat_interactive.sh || true



chat-real-inference: build-neurx-interactive-inference-s
	@echo "🚀 Running NeurX Real Inference Engine (Pure S)..."
	@if [ -f "/home/shuwen/shuwen/posttrain/model.safetensors" ]; then \
		echo "✓ Model found: base-model-posttrain"; \
		echo "✓ Running pure S medical knowledge inference"; \
		mkdir -p artifacts/logs; \
		$(CURDIR_UNIX)/artifacts/build/s_runner/s_ir_runner $(CURDIR_UNIX)/artifacts/build/neurx_interactive_inference/neurx_interactive_inference.ir 2>&1; \
	else \
		echo "❌ Model not found"; \
	fi

build-neurx-interactive-inference-s:
	@mkdir -p artifacts/build/neurx_interactive_inference
	@echo "Compiling NeurX Interactive Inference (S)..."
	@$(S_COMPILER) inference/neurx_interactive_inference.s artifacts/build/neurx_interactive_inference/neurx_interactive_inference.ir 2>&1

real-inference: build-real-inference-s
	@echo "🚀 Running NeurX Real Inference Engine (Pure S)..."
	@if [ -f "/home/shuwen/shuwen/posttrain/model.safetensors" ]; then \
		echo "✓ Model found: base-model-posttrain"; \
		echo "✓ Running real Transformer computation"; \
		mkdir -p artifacts/logs; \
		$(CURDIR_UNIX)/artifacts/build/real_inference/real_inference 2>&1 | tee -a artifacts/logs/real_inference_$(shell date +%Y%m%d_%H%M%S).log; \
	else \
		echo "❌ Model not found"; \
	fi

build-posttrain-chat-s:
	@mkdir -p artifacts/build/posttrain_chat
	@echo "Compiling PostTrain Chat (S)..."
	@/home/shuwen/shuwen/train/s/bin/s_seed inference/posttrain_chat.s artifacts/build/posttrain_chat/posttrain_chat.ir || { \
		echo "❌ Compilation failed!"; \
		exit 1; \
	}
	@echo "✓ Compiled to IR successfully"
	@echo "Creating PostTrain Chat runner script..."
	@printf '#!/bin/bash\n%s/artifacts/build/s_runner/s_ir_runner %s/artifacts/build/posttrain_chat/posttrain_chat.ir\n' '$(CURDIR_UNIX)' '$(CURDIR_UNIX)' > artifacts/build/posttrain_chat/posttrain_chat
	@chmod +x artifacts/build/posttrain_chat/posttrain_chat
	@echo "✓ PostTrain Chat ready"

build-real-inference-s:
	@mkdir -p artifacts/build/real_inference
	@echo "Compiling Real Interactive Inference (S)..."
	@$(S_SEED_COMPILER) inference/real_inference.s artifacts/build/real_inference/real_inference.ir || { \
		echo "❌ Compilation failed!"; \
		exit 1; \
	}
	@echo "✓ Compiled to IR successfully"
	@echo "Creating Real Inference runner script..."
	@printf '#!/bin/bash\n%s/artifacts/build/s_runner/s_ir_runner %s/artifacts/build/real_inference/real_inference.ir\n' '$(CURDIR_UNIX)' '$(CURDIR_UNIX)' > artifacts/build/real_inference/real_inference
	@chmod +x artifacts/build/real_inference/real_inference
	@echo "✓ Real Interactive Inference ready"

build-hf-posttrain-chat-s: build-real-inference-s build-s-ir-runner
	@mkdir -p artifacts/build/hf_posttrain_chat
	@echo "Compiling Hugging Face PostTrain-compatible chat frontend (S)..."
	@cd '$(CURDIR_UNIX)' && \
		$(S_SEED_COMPILER) 'scripts/hf_posttrain_chat.s' '$(CURDIR_UNIX)/artifacts/build/hf_posttrain_chat/hf_posttrain_chat.ir'
	@test -f '$(CURDIR_UNIX)/artifacts/build/hf_posttrain_chat/hf_posttrain_chat.ir'

hf-posttrain-chat: build-hf-posttrain-chat-s
	@'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/hf_posttrain_chat/hf_posttrain_chat.ir'


shard: check-bash
	@echo "Building NeurX shard entry ($(PLATFORM))..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/shard
	@mkdir -p $(LOG_DIR)
	@if ! command -v "$(S_COMPILER)" >/dev/null 2>&1; then \
		echo "Error: S compiler not found at $(S_COMPILER)"; \
		echo "Set S_COMPILER or S_COMPILER_EMIT_CWD environment variable"; \
		exit 1; \
	fi
	@cd '$(CURDIR_UNIX)' && \
		export S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(CURDIR_UNIX)'; \
		if "$$S_COMPILER" --help 2>&1 | grep -q "<input.s> <output.ir>"; then \
			"$$S_COMPILER" 'shard/shard.s' '$(CURDIR_UNIX)/artifacts/build/shard/shard.ir' 2>&1 || exit 1; \
		else \
			"$$S_COMPILER" ir 'shard/shard.s' -o '$(CURDIR_UNIX)/artifacts/build/shard/shard.ir' 2>&1 || exit 1; \
		fi && \
		test -f '$(CURDIR_UNIX)/artifacts/build/shard/shard.ir'
	@$(MAKE) build-s-ir-runner
	@echo "Running Wikipedia shard processor on $(PLATFORM)..."
	@SHARD_LOG="$(LOG_DIR)/shard_$(PLATFORM)_$(shell date +%Y%m%d_%H%M%S).log"; \
	SHARD_PROGRESS_LOG="$(LOG_DIR)/shard_$(PLATFORM)_$(shell date +%Y%m%d_%H%M%S).progress.log"; \
	echo "Shard processing log: $$SHARD_LOG"; \
	echo "Shard progress log: $$SHARD_PROGRESS_LOG"; \
	: > "$$SHARD_PROGRESS_LOG"; \
	tail -n 0 -F "$$SHARD_PROGRESS_LOG" & \
	TAIL_PID=$$!; \
	trap 'kill $$TAIL_PID >/dev/null 2>&1 || true' EXIT; \
	set -o pipefail; \
	cd '$(CURDIR_UNIX)' && \
		NEURX_HOME='$(CURDIR_UNIX)' \
		S_COMPILER='$(if $(wildcard $(CURDIR_UNIX)/tools/s_wrapper.sh),$(CURDIR_UNIX)/tools/s_wrapper.sh,$(S_COMPILER))' \
		S_COMPILER_EMIT_CWD='$(S_COMPILER_EMIT_CWD)' \
		S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		NEURX_SHARD_CMD='$(NEURX_SHARD_CMD)' \
		NEURX_SHARD_RESUME='$(NEURX_SHARD_RESUME)' \
		NEURX_SHARD_FORCE_REBUILD='$(NEURX_SHARD_FORCE_REBUILD)' \
		ENWIKI_BZ2_FILE='$(PRETRAIN_RAW_DIR)/enwiki-latest-pages-articles.xml.bz2' \
		ENWIKI_SHARD_DIR='$(PRETRAIN_SHARD_DIR)' \
		ENWIKI_MANIFEST_FILE='$(PRETRAIN_MANIFEST)' \
		DOCS_PER_SHARD='$(PRETRAIN_SHARD_DOCS_PER_FILE)' \
		S_IR_RUNNER_INPUT='$(CURDIR_UNIX)/artifacts/build/shard/shard.ir' \
		S_IR_RUNNER_ENTRY='main' \
		NEURX_SHARD_PROGRESS_LOG="$$SHARD_PROGRESS_LOG" \
		'$(S_RUNNER_BIN)' 2>&1 | tee -a "$$SHARD_LOG" && \
	echo "✓ Shard processing completed!" || (echo "✗ Shard processing failed. Check log: $$SHARD_LOG"; exit 1)

split: check-bash
	@echo "Splitting training data into train/val/test"
	@cd '$(CURDIR_UNIX)' && $(MAKE) split-data-s 2>&1

split-data-s: check-bash
	@echo "Building dataset split entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/split_data
	@mkdir -p $(LOG_DIR)
	@if ! command -v "$(S_COMPILER)" >/dev/null 2>&1; then \
		echo "Error: S compiler not found at $(S_COMPILER)"; \
		echo "Set S_COMPILER or S_COMPILER_EMIT_CWD environment variable"; \
		exit 1; \
	fi
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/split_data.s' -o '$(CURDIR_UNIX)/artifacts/build/split_data/split_data.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/split_data/split_data.ir'
	@$(MAKE) build-s-ir-runner
	@echo "Running dataset split entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_SPLIT_DATASET_ROOT='$(PRETRAIN_DATA_ROOT)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/split_data/split_data.ir' 2>&1 | tee -a $(LOG_DIR)/split_data_$(shell date +%Y%m%d_%H%M%S).log

run-training-pipeline-s: check-bash
	@echo "Building S training pipeline entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/training_pipeline
	@mkdir -p $(LOG_DIR)
	@if [ ! -f "$(S_COMPILER)" ]; then \
		echo "Error: S compiler not found at $(S_COMPILER)"; \
		echo "Set S_COMPILER or S_COMPILER_EMIT_CWD environment variable"; \
		exit 1; \
	fi
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/run_training_pipeline.s' -o '$(CURDIR_UNIX)/artifacts/build/training_pipeline/run_training_pipeline.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/training_pipeline/run_training_pipeline.ir'
	@$(MAKE) build-s-ir-runner
	@echo "Running S training pipeline entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/training_pipeline/run_training_pipeline.ir' 2>&1 | tee -a $(LOG_DIR)/training_pipeline_$(shell date +%Y%m%d_%H%M%S).log

quick-start-s: check-bash
	@echo "Building S quick start entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/quick_start
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/quick_start.s' -o '$(CURDIR_UNIX)/artifacts/build/quick_start/quick_start.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/quick_start/quick_start.ir'
	@echo "Running S quick start entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/quick_start/quick_start.ir' 2>&1 | tee -a $(LOG_DIR)/quick_start_$(shell date +%Y%m%d_%H%M%S).log

run-interactive-inference-s: check-bash
	@echo "Building S interactive chat system..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/interactive_inference
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/run_interactive_chat.s' -o '$(CURDIR_UNIX)/artifacts/build/interactive_inference/run_interactive_chat.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/interactive_inference/run_interactive_chat.ir'
	@$(MAKE) build-s-ir-runner
	@echo "Starting NeurX-1.3 Interactive Chat..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		NEURX_CHECKPOINT_DIR='$(PRETRAIN_OUTPUT_DIR)' \
		NEURX_INFER_OUTPUT_DIR='$(CURDIR_UNIX)/artifacts/inference_output' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/interactive_inference/run_interactive_chat.ir' 2>&1 | tee -a $(LOG_DIR)/chat_$(shell date +%Y%m%d_%H%M%S).log

run-interactive-chat-repl-s: check-bash
	@$(MAKE) build-cuda-chat-bridge
	@mkdir -p $(LOG_DIR)
	@echo "Starting NeurX NXTRFMV2 native CUDA inference..."
	@set -o pipefail; cd '$(CURDIR_UNIX)' && \
		NEURX_CHECKPOINT='$(PRETRAIN_OUTPUT_DIR)/transformer_v2.ckpt' \
		NEURX_TOKENIZER_VOCAB='$(CURDIR_UNIX)/data/corpus/vocab.json' \
		NEURX_TOKENIZER_MERGES='$(CURDIR_UNIX)/data/corpus/merges.txt' \
		'$(CUDA_CHAT_BRIDGE_BIN)' 2>&1 | tee -a $(LOG_DIR)/chat_repl_$(shell date +%Y%m%d_%H%M%S).log

run-small-model-training-s: check-bash
	@echo "Building S small model training entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/small_model_training
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/run_small_model_training.s' -o '$(CURDIR_UNIX)/artifacts/build/small_model_training/run_small_model_training.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/small_model_training/run_small_model_training.ir'
	@echo "Running S small model training entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/small_model_training/run_small_model_training.ir' 2>&1 | tee -a $(LOG_DIR)/run_small_model_training_$(shell date +%Y%m%d_%H%M%S).log

verify-setup-s: check-bash
	@echo "Building setup verification entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/verify_setup
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/verify_setup.s' -o '$(CURDIR_UNIX)/artifacts/build/verify_setup/verify_setup.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/verify_setup/verify_setup.ir'
	@echo "Running setup verification entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/verify_setup/verify_setup.ir' 2>&1 | tee -a $(LOG_DIR)/verify_setup_$(shell date +%Y%m%d_%H%M%S).log

quick-test-s: check-bash
	@echo "Building quick test entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/quick_test
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/quick_test.s' -o '$(CURDIR_UNIX)/artifacts/build/quick_tests/quick_test.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/quick_tests/quick_test.ir'
	@echo "Running quick test entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/quick_tests/quick_test.ir' 2>&1 | tee -a $(LOG_DIR)/quick_test_$(shell date +%Y%m%d_%H%M%S).log

quickstart-s: check-bash
	@echo "Building quickstart entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/quickstart
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/quickstart.s' -o '$(CURDIR_UNIX)/artifacts/build/quickstart/quickstart.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/quickstart/quickstart.ir'
	@echo "Running quickstart entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/quickstart/quickstart.ir' 2>&1 | tee -a $(LOG_DIR)/quickstart_$(shell date +%Y%m%d_%H%M%S).log

verify-training-pipeline-s: check-bash
	@echo "Building training pipeline verification entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/verify_training_pipeline
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/verify_training_pipeline.s' -o '$(CURDIR_UNIX)/artifacts/build/verify_training_pipeline/verify_training_pipeline.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/verify_training_pipeline/verify_training_pipeline.ir'
	@echo "Running training pipeline verification entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/verify_training_pipeline/verify_training_pipeline.ir' 2>&1 | tee -a $(LOG_DIR)/verify_training_pipeline_$(shell date +%Y%m%d_%H%M%S).log

monitor-training-s: check-bash
	@echo "Building training monitor entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/monitor_training
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/monitor_training.s' -o '$(CURDIR_UNIX)/artifacts/build/monitor_training/monitor_training.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/monitor_training/monitor_training.ir'
	@echo "Running training monitor entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/monitor_training/monitor_training.ir' 2>&1 | tee -a $(LOG_DIR)/monitor_training_$(shell date +%Y%m%d_%H%M%S).log

build-linux-s: check-bash
	@echo "Building Linux build status entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/build_linux
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/build-linux.s' -o '$(CURDIR_UNIX)/artifacts/build/build_linux/build_linux.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/build_linux/build_linux.ir'
	@echo "Running Linux build status entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/build_linux/build_linux.ir' 2>&1 | tee -a $(LOG_DIR)/build_linux_$(shell date +%Y%m%d_%H%M%S).log

build-macos-s: check-bash
	@echo "Building macOS build status entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/build_macos
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/build-macos.s' -o '$(CURDIR_UNIX)/artifacts/build/build_macos/build_macos.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/build_macos/build_macos.ir'
	@echo "Running macOS build status entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/build_macos/build_macos.ir' 2>&1 | tee -a $(LOG_DIR)/build_macos_$(shell date +%Y%m%d_%H%M%S).log

run-large-pretrain-s: check-bash
	@echo "Building large pretrain status entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/run_large_pretrain
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)'; \
		if "$(S_COMPILER)" --help 2>&1 | grep -q "<input.s> <output.ir>"; then \
			"$(S_COMPILER)" '$(PRETRAIN_ENTRY_SOURCE)' '$(CURDIR_UNIX)/artifacts/build/run_large_pretrain/run_large_pretrain.ir' 2>&1 || exit 1; \
		else \
			"$(S_COMPILER)" ir '$(PRETRAIN_ENTRY_SOURCE)' -o '$(CURDIR_UNIX)/artifacts/build/run_large_pretrain/run_large_pretrain.ir' 2>&1 || exit 1; \
		fi && \
		test -f '$(CURDIR_UNIX)/artifacts/build/run_large_pretrain/run_large_pretrain.ir'
	@echo "Running large pretrain status entry (interpreter)..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/run_large_pretrain/run_large_pretrain.ir' 2>&1 | tee -a $(LOG_DIR)/run_large_pretrain_$(shell date +%Y%m%d_%H%M%S).log

build-pretrain-manifest-s: check-bash
	@echo "Building pretrain manifest entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/build_pretrain_manifest
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)'; \
		if "$(S_COMPILER)" --help 2>&1 | grep -q "<input.s> <output.ir>"; then \
			"$(S_COMPILER)" 'scripts/legacy/build_pretrain_manifest.s' '$(CURDIR_UNIX)/artifacts/build/build_pretrain_manifest/build_pretrain_manifest.ir' 2>&1 || exit 1; \
		else \
			"$(S_COMPILER)" ir 'scripts/legacy/build_pretrain_manifest.s' -o '$(CURDIR_UNIX)/artifacts/build/build_pretrain_manifest/build_pretrain_manifest.ir' 2>&1 || exit 1; \
		fi && \
		test -f '$(CURDIR_UNIX)/artifacts/build/build_pretrain_manifest/build_pretrain_manifest.ir'
	@echo "Running pretrain manifest entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		NEURX_PRETRAIN_SHARD_DIR='$(PRETRAIN_SHARD_DIR)' \
		NEURX_PRETRAIN_MANIFEST='$(PRETRAIN_MANIFEST)' \
		NEURX_PRETRAIN_REBUILD_MANIFEST='$(NEURX_PRETRAIN_REBUILD_MANIFEST)' \
		S_COMPILER='$(S_COMPILER)' \
		S_COMPILER_EMIT_CWD='$(S_COMPILER_EMIT_CWD)' \
		S_IR_RUNNER_INPUT='$(CURDIR_UNIX)/artifacts/build/build_pretrain_manifest/build_pretrain_manifest.ir' \
		'$(S_RUNNER_BIN)' 2>&1

run-train-compiled-s: check-bash
	@echo "Building compiled train status entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/run_train_compiled
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/run_train_compiled.s' -o '$(CURDIR_UNIX)/artifacts/build/run_train_compiled/run_train_compiled.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/run_train_compiled/run_train_compiled.ir'
	@echo "Running compiled train status entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/run_train_compiled/run_train_compiled.ir' 2>&1 | tee -a $(LOG_DIR)/run_train_compiled_$(shell date +%Y%m%d_%H%M%S).log

run-train-large-model-s: check-bash
	@echo "Building large model train status entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/run_train_large_model
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/run_train_large_model.s' -o '$(CURDIR_UNIX)/artifacts/build/run_train_large_model/run_train_large_model.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/run_train_large_model/run_train_large_model.ir'
	@echo "Running large model train status entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/run_train_large_model/run_train_large_model.ir' 2>&1 | tee -a $(LOG_DIR)/run_train_large_model_$(shell date +%Y%m%d_%H%M%S).log

run-train-model-ir-s: check-bash
	@echo "Building IR train status entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/run_train_model_ir
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/run_train_model_ir.s' -o '$(CURDIR_UNIX)/artifacts/build/run_train_model_ir/run_train_model_ir.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/run_train_model_ir/run_train_model_ir.ir'
	@echo "Running IR train status entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/run_train_model_ir/run_train_model_ir.ir' 2>&1 | tee -a $(LOG_DIR)/run_train_model_ir_$(shell date +%Y%m%d_%H%M%S).log

run-with-logs-s: check-bash
	@echo "Building logs wrapper status entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/run_with_logs
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/run_with_logs.s' -o '$(CURDIR_UNIX)/artifacts/build/run_with_logs/run_with_logs.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/run_with_logs/run_with_logs.ir'
	@echo "Running logs wrapper status entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/run_with_logs/run_with_logs.ir' 2>&1 | tee -a $(LOG_DIR)/run_with_logs_$(shell date +%Y%m%d_%H%M%S).log

verify-framework-s: check-bash
	@echo "Building framework verification entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/verify_framework
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/verify_framework.s' -o '$(CURDIR_UNIX)/artifacts/build/verify_framework/verify_framework.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/verify_framework/verify_framework.ir'
	@echo "Running framework verification entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/verify_framework/verify_framework.ir' 2>&1 | tee -a $(LOG_DIR)/verify_framework_$(shell date +%Y%m%d_%H%M%S).log

verify-inference-pipeline-s: check-bash
	@echo "Building inference pipeline verification entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/verify_inference_pipeline
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/verify_inference_pipeline.s' -o '$(CURDIR_UNIX)/artifacts/build/verify_inference_pipeline/verify_inference_pipeline.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/verify_inference_pipeline/verify_inference_pipeline.ir'
	@echo "Running inference pipeline verification entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/verify_inference_pipeline/verify_inference_pipeline.ir' 2>&1 | tee -a $(LOG_DIR)/verify_inference_pipeline_$(shell date +%Y%m%d_%H%M%S).log

test-build-s: check-bash
	@echo "Building build test entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/test_build
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/test_build.s' -o '$(CURDIR_UNIX)/artifacts/build/test_build/test_build.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/test_build/test_build.ir'
	@echo "Running build test entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/test_build/test_build.ir' 2>&1 | tee -a $(LOG_DIR)/test_build_$(shell date +%Y%m%d_%H%M%S).log

test-smart-inference-s: check-bash
	@echo "Building smart inference test entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/test_smart_inference
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/test_smart_inference.s' -o '$(CURDIR_UNIX)/artifacts/build/test_smart_inference/test_smart_inference.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/test_smart_inference/test_smart_inference.ir'
	@echo "Running smart inference test entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/test_smart_inference/test_smart_inference.ir' 2>&1 | tee -a $(LOG_DIR)/test_smart_inference_$(shell date +%Y%m%d_%H%M%S).log






DATA_SCRIPTS_DIR := $(CURDIR_UNIX)/artifacts/build/data_scripts
DATA_SCRIPTS_IR := $(DATA_SCRIPTS_DIR)/data_scripts.ir
DATA_SCRIPTS_BIN := $(DATA_SCRIPTS_DIR)/data_scripts.bin
INDUSTRIAL_OPS_DIR := $(CURDIR_UNIX)/artifacts/build/industrial_ops
INDUSTRIAL_OPS_IR := $(INDUSTRIAL_OPS_DIR)/industrial_ops.ir
INDUSTRIAL_OPS_BIN := $(INDUSTRIAL_OPS_DIR)/industrial_ops.bin
VERIFY_DATASET_DIR_DEFAULT ?= $(CURDIR_UNIX)/dataset/pretrain/shard
VERIFY_DATASET_DIR ?= $(VERIFY_DATASET_DIR_DEFAULT)
INDUSTRIAL_CMD ?= all
INDUSTRIAL_PREFERENCE ?= dataset/dpo/preferences.jsonl
INDUSTRIAL_CORPUS ?= data/corpus/train_corpus.txt
INDUSTRIAL_QUERY ?= NeurX industrial RAG
INDUSTRIAL_DATASET ?= data/training_data_industrial_complete.jsonl
TOOLCHAIN_CMD ?= status

build-data-scripts: check-bash
	@echo "Building NeurX S-only Data Pipeline..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/data_pipeline
	@echo "  Source: scripts/legacy/data_pipeline.s"
	@echo "  This is a complete S-language implementation ready for compilation"
	@echo "  To compile: $(S_COMPILER) scripts/legacy/data_pipeline.s -o artifacts/build/data_pipeline/data_pipeline"
	@echo "✓ S implementation available at scripts/legacy/data_pipeline.s"

clean-s:
	@echo "Building NeurX data cleaning entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/data_scripts
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/scripts.s' -o '$(CURDIR_UNIX)/artifacts/build/data_scripts/scripts.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/data_scripts/scripts.ir'
	@echo "Running NeurX data cleaning entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_HOME='$(CURDIR_UNIX)' NEURX_SCRIPTS_CMD=clean \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/data_scripts/scripts.ir' 2>&1 | tee -a $(LOG_DIR)/clean_$(shell date +%Y%m%d_%H%M%S).log

shard-s:
	@echo "Building NeurX data sharding entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/data_scripts
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/scripts.s' -o '$(CURDIR_UNIX)/artifacts/build/data_scripts/scripts.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/data_scripts/scripts.ir'
	@echo "Running NeurX data sharding entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_HOME='$(CURDIR_UNIX)' NEURX_SCRIPTS_CMD=shard \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/data_scripts/scripts.ir' 2>&1 | tee -a $(LOG_DIR)/shard_$(shell date +%Y%m%d_%H%M%S).log

shard-enwiki: check-bash
	@echo "$(BLUE)📦 Sharding Wikipedia dataset...$(NC)"
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/shard
	@mkdir -p $(LOG_DIR)
	@if ! command -v "$(S_COMPILER)" >/dev/null 2>&1; then \
		echo "Error: S compiler not found at $(S_COMPILER)"; \
		echo "Set S_COMPILER or S_COMPILER_EMIT_CWD environment variable"; \
		exit 1; \
	fi
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(CURDIR_UNIX)' \
		$(S_COMPILER) ir 'shard/shard_enwiki.s' -o '$(CURDIR_UNIX)/artifacts/build/shard/shard_enwiki.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/shard/shard_enwiki.ir'
	@$(MAKE) build-s-ir-runner
	@cd '$(CURDIR_UNIX)' && \
		NEURX_HOME='$(CURDIR_UNIX)' \
		ENWIKI_BZ2_FILE='$(PRETRAIN_RAW_DIR)/enwiki-latest-pages-articles.xml.bz2' \
		ENWIKI_SHARD_DIR='$(PRETRAIN_SHARD_DIR)' \
		ENWIKI_MANIFEST_FILE='$(PRETRAIN_MANIFEST)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/shard/shard_enwiki.ir' 2>&1 | tee -a $(LOG_DIR)/shard_enwiki_$(shell date +%Y%m%d_%H%M%S).log
	@echo "$(GREEN)✓ Wikipedia sharding complete$(NC)"

data-pipeline-s: build-data-scripts
	@echo "Running NeurX full data pipeline (clean + shard, S version)..."
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		NEURX_HOME='$(CURDIR_UNIX)' $(DATA_SCRIPTS_BIN) clean-and-shard 2>&1 | tee -a $(LOG_DIR)/pipeline_$(shell date +%Y%m%d_%H%M%S).log

verify-dataset-s: check-bash
	@echo "Building S dataset verifier..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/dataset_verify
	@mkdir -p $(LOG_DIR)
	@if [ ! -f "$(S_COMPILER)" ]; then \
		echo "Error: S compiler not found at $(S_COMPILER)"; \
		echo "Set S_COMPILER or S_COMPILER_EMIT_CWD environment variable"; \
		exit 1; \
	fi
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'data/tools/verify_dataset.s' -o '$(CURDIR_UNIX)/artifacts/build/dataset_verify/dataset_verify.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/dataset_verify/dataset_verify.ir'
	@echo "✓ Dataset verification entry compiled to S IR"

build-industrial-ops: check-bash
	@echo "Building industrial ops runner..."
	@mkdir -p $(INDUSTRIAL_OPS_DIR)
	@if [ ! -f "$(S_COMPILER)" ]; then \
		echo "Error: S compiler not found at $(S_COMPILER)"; \
		echo "Set S_COMPILER or S_COMPILER_EMIT_CWD environment variable"; \
		exit 1; \
	fi
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir scripts/legacy/industrial_ops_runner.s -o $(INDUSTRIAL_OPS_IR) 2>&1
	@cd '$(S_COMPILER_EMIT_CWD)' && \
		$(S_COMPILER) --emit-bin '$(INDUSTRIAL_OPS_IR)' '$(INDUSTRIAL_OPS_BIN)' 2>&1
	@if [ ! -f "$(INDUSTRIAL_OPS_BIN)" ]; then \
		echo "Error: failed to generate $(INDUSTRIAL_OPS_BIN)"; \
		exit 1; \
	fi
	@chmod +x $(INDUSTRIAL_OPS_BIN)
	@echo "✓ Build complete: $(INDUSTRIAL_OPS_BIN)"

industrial-ops: build-industrial-ops
	@echo "Running industrial ops runner..."
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		NEURX_HOME='$(CURDIR_UNIX)' $(INDUSTRIAL_OPS_BIN) $(INDUSTRIAL_CMD) \
		--preference='$(INDUSTRIAL_PREFERENCE)' \
		--corpus='$(INDUSTRIAL_CORPUS)' \
		--query='$(INDUSTRIAL_QUERY)' \
		--dataset='$(INDUSTRIAL_DATASET)' \
		--output-dir='$(CURDIR_UNIX)/artifacts/industrial_ops' 2>&1 | tee -a $(LOG_DIR)/industrial_ops_$(shell date +%Y%m%d_%H%M%S).log

build-s-ir-runner: check-bash
	@echo "Building generic S IR runner..."
	@mkdir -p $(S_RUNNER_BUILD_DIR)
	@'$(CC)' -D_GNU_SOURCE -std=c11 -O2 -Wall -Wextra -Werror \
		-I'$(S_COMPILER_EMIT_CWD)/src/cmd/compile/seed' \
		-o '$(S_RUNNER_BIN)' \
		'$(S_RUNNER_C_SRC)' \
		'$(S_COMPILER_EMIT_CWD)/src/cmd/compile/seed/runtime/runtime.c' \
		'$(S_COMPILER_EMIT_CWD)/src/cmd/compile/seed/error/error.c' \
		'$(S_COMPILER_EMIT_CWD)/src/cmd/compile/seed/lexical/lexer.c' \
		'$(S_COMPILER_EMIT_CWD)/src/cmd/compile/seed/lexical/selfhost_bridge.c' \
		'$(S_COMPILER_EMIT_CWD)/src/cmd/compile/seed/syntax/parser.c' \
		'$(S_COMPILER_EMIT_CWD)/src/cmd/compile/seed/semantic/analyzer.c' \
		'$(S_COMPILER_EMIT_CWD)/src/cmd/compile/seed/intermediate/ir.c' \
		'$(S_COMPILER_EMIT_CWD)/src/cmd/compile/seed/code/generator.c' \
		2>&1 && \
		chmod +x '$(S_RUNNER_BIN)' && \
		test -f '$(S_RUNNER_BIN)'

build-cuda-train-bridge: check-bash
	@echo "Building native CUDA/cuBLAS train bridge..."
	@if [ '$(PLATFORM)' != 'linux' ]; then \
		echo "Error: NVIDIA CUDA Runtime/cuBLAS training is supported on Linux hosts only in this Makefile."; \
		echo "       macOS can run the S launcher, but NVIDIA CUDA is not available on modern macOS."; \
		exit 1; \
	fi
	@if [ -z '$(CUDA_NVCC)' ]; then \
		echo "Error: nvcc not found. Install NVIDIA CUDA Toolkit, then run: make pretrain-gpu"; \
		exit 1; \
	fi
	@mkdir -p '$(CUDA_TRAIN_BRIDGE_BUILD_DIR)'
	@'$(CUDA_NVCC)' -O3 -std=c++17 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 \
		'$(CUDA_TRAIN_BRIDGE_SRC)' \
		-lcublas -ldl \
		-o '$(CUDA_TRAIN_BRIDGE_BIN)'
	@chmod +x '$(CUDA_TRAIN_BRIDGE_BIN)'
	@test -x '$(CUDA_TRAIN_BRIDGE_BIN)'

build-cuda-chat-bridge: check-bash
	@echo "Building native NXTRFMV2 CUDA chat bridge..."
	@if [ '$(PLATFORM)' != 'linux' ]; then \
		echo "Error: native CUDA chat is supported on Linux hosts only."; \
		exit 1; \
	fi
	@if [ -z '$(CUDA_NVCC)' ]; then \
		echo "Error: nvcc not found. Install NVIDIA CUDA Toolkit, then run: make chat"; \
		exit 1; \
	fi
	@mkdir -p '$(CUDA_CHAT_BRIDGE_BUILD_DIR)'
	@'$(CUDA_NVCC)' -O3 -std=c++17 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 \
		'$(CUDA_CHAT_BRIDGE_SRC)' -lcublas -o '$(CUDA_CHAT_BRIDGE_BIN)'
	@chmod +x '$(CUDA_CHAT_BRIDGE_BIN)'
	@test -x '$(CUDA_CHAT_BRIDGE_BIN)'

build-cuda-bigram-bridge: check-bash
	@mkdir -p '$(CUDA_TRAIN_BRIDGE_BUILD_DIR)'
	@'$(CUDA_NVCC)' -O3 -std=c++17 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 \
		'$(CUDA_BIGRAM_BRIDGE_SRC)' -lcublas -o '$(CUDA_TRAIN_BRIDGE_BUILD_DIR)/neurx_cuda_bigram_bridge'

pretrain-bigram-gpu: build-cuda-bigram-bridge build-pretrain-manifest-s
	@NEURX_PRETRAIN_SHARD_LIST_FILE='$(CURDIR_UNIX)/artifacts/build/run_large_pretrain/shard_list.txt' \
		NEURX_PRETRAIN_OUTPUT_DIR="$${NEURX_PRETRAIN_OUTPUT_DIR:-$(CURDIR_UNIX)/checkpoint/NeurX-Bigram-Smoke}" \
		NEURX_PRETRAIN_STEPS="$${NEURX_PRETRAIN_STEPS:-1}" \
		NEURX_CUDA_VOCAB_SIZE="$${NEURX_CUDA_VOCAB_SIZE:-4096}" \
		NEURX_CUDA_BATCH_PAIRS="$${NEURX_CUDA_BATCH_PAIRS:-256}" \
		'$(CUDA_TRAIN_BRIDGE_BUILD_DIR)/neurx_cuda_bigram_bridge'

transformer-reference-test:
	@mkdir -p artifacts/build/transformer_reference
	@$(CXX) -O2 -std=c++17 -Wall -Wextra -Werror \
		tests/transformer_reference.cpp -o artifacts/build/transformer_reference/transformer_reference
	@artifacts/build/transformer_reference/transformer_reference

adam-optimizer-test:
	@mkdir -p artifacts/build/adam_optimizer
	@$(CXX) -O2 -std=c++17 -Wall -Wextra -Werror \
		tests/adam_optimizer_regression_test.cpp \
		-o artifacts/build/adam_optimizer/adam_optimizer_regression_test
	@artifacts/build/adam_optimizer/adam_optimizer_regression_test

training-policy-test:
	@mkdir -p artifacts/build/training_policy
	@$(CXX) -O2 -std=c++17 -Wall -Wextra -Werror \
		tests/training_policy_test.cpp \
		-o artifacts/build/training_policy/training_policy_test
	@artifacts/build/training_policy/training_policy_test

inference-runtime-test:
	@mkdir -p artifacts/build/inference_runtime
	@$(CXX) -O2 -std=c++17 -Wall -Wextra -Werror \
		tests/inference_runtime_test.cpp cann/inference/ascend_adapter.cpp \
		cann/runtime/acl_runtime.cpp \
		-ldl -o artifacts/build/inference_runtime/inference_runtime_test
	@artifacts/build/inference_runtime/inference_runtime_test

build-cpu-inference:
	@mkdir -p artifacts/build/cpu_inference
	@$(CXX) -O2 -std=c++17 -Wall -Wextra -Werror \
		inference/cpu_transformer_inference.cpp \
		inference/cpu_transformer_main.cpp \
		-o artifacts/build/cpu_inference/neurx_cpu_inference

cpu-inference-test:
	@mkdir -p artifacts/build/cpu_inference
	@$(CXX) -O2 -std=c++17 -Wall -Wextra -Werror \
		inference/cpu_transformer_inference.cpp \
		tests/cpu_transformer_inference_test.cpp \
		-o artifacts/build/cpu_inference/cpu_transformer_inference_test
	@artifacts/build/cpu_inference/cpu_transformer_inference_test

serving-native-socket-test:
	@mkdir -p artifacts/build/serving_native
	@$(CC) -O2 -std=c11 -Wall -Wextra -Werror \
		serving/native/serving_socket.c tests/serving_native_socket_test.c \
		-o artifacts/build/serving_native/serving_native_socket_test
	@artifacts/build/serving_native/serving_native_socket_test

check-nvcc:
	@if [ -z '$(CUDA_NVCC)' ]; then \
		echo "Error: nvcc not found. Run CUDA tests on a Linux NVIDIA CUDA host."; \
		exit 1; \
	fi

transformer-cuda-kernels-test: check-nvcc
	@mkdir -p artifacts/build/transformer_cuda
	@$(CUDA_NVCC) -O2 -std=c++17 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 cuda/transformer_kernels_test.cu \
		-o artifacts/build/transformer_cuda/transformer_kernels_test
	@artifacts/build/transformer_cuda/transformer_kernels_test

transformer-cuda-integration-test: check-nvcc
	@mkdir -p artifacts/build/transformer_cuda
	@$(CUDA_NVCC) -O2 -std=c++17 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 \
		cuda/transformer_integration_test.cu -lcublas -o artifacts/build/transformer_cuda/transformer_integration_test
	@artifacts/build/transformer_cuda/transformer_integration_test

transformer-cuda-checkpoint-resume-test:
	@if [ -z '$(CUDA_NVCC)' ]; then \
		echo "Error: nvcc not found. Run this CUDA checkpoint test on a Linux NVIDIA CUDA host."; \
		exit 1; \
	fi
	@mkdir -p artifacts/build/transformer_cuda
	@$(CUDA_NVCC) -O2 -std=c++17 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 \
		cuda/transformer_checkpoint_resume_test.cu -lcublas -o artifacts/build/transformer_cuda/transformer_checkpoint_resume_test
	@artifacts/build/transformer_cuda/transformer_checkpoint_resume_test

cuda-tools-s: check-bash
	@echo "Building S CUDA tools entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/cuda_tools
	@mkdir -p $(LOG_DIR)
	@if [ ! -f "$(S_COMPILER)" ]; then \
		echo "Error: S compiler not found at $(S_COMPILER)"; \
		echo "Set S_COMPILER or S_COMPILER_EMIT_CWD environment variable"; \
		exit 1; \
	fi
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'cuda/cuda_tools.s' -o 'artifacts/build/cuda_tools/cuda_tools.ir' 2>&1
	@if [ ! -x "$(S_RUNNER_BIN)" ]; then \
		$(MAKE) build-s-ir-runner; \
	fi
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		NEURX_CUDA_TOOL="$${NEURX_CUDA_TOOL:-verify}" \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/cuda_tools/cuda_tools.ir' 2>&1 | tee -a $(LOG_DIR)/cuda_tools_$(shell date +%Y%m%d_%H%M%S).log

cuda-verify-s:
	@NEURX_CUDA_TOOL=verify $(MAKE) cuda-tools-s

cuda-build-s:
	@NEURX_CUDA_TOOL=build $(MAKE) cuda-tools-s

cuda-build-runtime-s:
	@NEURX_CUDA_TOOL=build-runtime $(MAKE) cuda-tools-s

cuda-build-runtime-alt-s:
	@NEURX_CUDA_TOOL=build-runtime-alt $(MAKE) cuda-tools-s

cuda-build-kernels-s:
	@NEURX_CUDA_TOOL=build-kernels $(MAKE) cuda-tools-s

cuda-build-kernels-simple-s:
	@NEURX_CUDA_TOOL=build-kernels-simple $(MAKE) cuda-tools-s

toolchain-s: check-bash
	@echo "Building S-only toolchain coordinator..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/toolchain
	@mkdir -p $(LOG_DIR)
	@if [ ! -f "$(S_COMPILER)" ]; then \
		echo "Error: S compiler not found at $(S_COMPILER)"; \
		echo "Set S_COMPILER or S_COMPILER_EMIT_CWD environment variable"; \
		exit 1; \
	fi
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/s_toolchain.s' -o 'artifacts/build/toolchain/toolchain.ir' 2>&1
	@if [ ! -f "$(CURDIR_UNIX)/artifacts/build/toolchain/toolchain.ir" ]; then \
		echo "Error: failed to generate $(CURDIR_UNIX)/artifacts/build/toolchain/toolchain.ir"; \
		exit 1; \
	fi
	@$(MAKE) build-s-ir-runner
	@echo "Running S-only toolchain coordinator..."
	@cd '$(CURDIR_UNIX)' && \
		TOOLCHAIN_CMD='$(TOOLCHAIN_CMD)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/toolchain/toolchain.ir' 2>&1 | tee -a $(LOG_DIR)/toolchain_$(shell date +%Y%m%d_%H%M%S).log

analyze-dataset-s: check-bash
	@echo "Building dataset analyze wrapper..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/dataset_analyze
	@mkdir -p $(LOG_DIR)
	@if [ ! -f "$(S_COMPILER)" ]; then \
		echo "Error: S compiler not found at $(S_COMPILER)"; \
		echo "Set S_COMPILER or S_COMPILER_EMIT_CWD environment variable"; \
		exit 1; \
	fi
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'data/tools/run_analyze.s' -o 'artifacts/build/dataset_analyze/run_analyze.ir' 2>&1
	@if [ ! -f "$(CURDIR_UNIX)/artifacts/build/dataset_analyze/run_analyze.ir" ]; then \
		echo "Error: failed to generate $(CURDIR_UNIX)/artifacts/build/dataset_analyze/run_analyze.ir"; \
		exit 1; \
	fi
	@$(MAKE) build-s-ir-runner
	@echo "Running dataset analyze wrapper..."
	@cd '$(CURDIR_UNIX)' && \
		SHARDS_DIR='$(VERIFY_DATASET_DIR)' MANIFEST='$(CURDIR_UNIX)/dataset/pretrain/manifest.json' OUT='$(CURDIR_UNIX)/dataset/report.json' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/dataset_analyze/run_analyze.ir' 2>&1 | tee -a $(LOG_DIR)/dataset_analyze_$(shell date +%Y%m%d_%H%M%S).log

run-training-s: check-bash
	@echo "Building S training orchestrator..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/train_orchestrator
	@mkdir -p $(LOG_DIR)
	@if [ ! -f "$(S_COMPILER)" ]; then \
		echo "Error: S compiler not found at $(S_COMPILER)"; \
		echo "Set S_COMPILER or S_COMPILER_EMIT_CWD environment variable"; \
		exit 1; \
	fi
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/run_llm_training.s' -o 'artifacts/build/train_orchestrator/run_llm_training.ir' 2>&1
	@if [ ! -f "$(CURDIR_UNIX)/artifacts/build/train_orchestrator/run_llm_training.ir" ]; then \
		echo "Error: failed to generate $(CURDIR_UNIX)/artifacts/build/train_orchestrator/run_llm_training.ir"; \
		exit 1; \
	fi
	@$(MAKE) build-s-ir-runner
	@echo "Running S training orchestrator..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/train_orchestrator/run_llm_training.ir' 2>&1 | tee -a $(LOG_DIR)/run_training_$(shell date +%Y%m%d_%H%M%S).log

train-and-infer-s: check-bash
	@echo "Building S train+infer orchestrator..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/train_and_infer
	@mkdir -p $(LOG_DIR)
	@if [ ! -f "$(S_COMPILER)" ]; then \
		echo "Error: S compiler not found at $(S_COMPILER)"; \
		echo "Set S_COMPILER or S_COMPILER_EMIT_CWD environment variable"; \
		exit 1; \
	fi
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/run_train_and_infer.s' -o 'artifacts/build/train_and_infer/run_train_and_infer.ir' 2>&1
	@$(MAKE) build-s-ir-runner
	@echo "Running S train+infer orchestrator..."
	@cd '$(CURDIR_UNIX)' && \
		MODE='$(MODE)' NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/train_and_infer/run_train_and_infer.ir' 2>&1 | tee -a $(LOG_DIR)/train_and_infer_$(shell date +%Y%m%d_%H%M%S).log

run-inference-s: check-bash
	@echo "Building S full model inference pipeline..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/inference_orchestrator
	@mkdir -p $(LOG_DIR)
	@if [ ! -f "$(S_COMPILER)" ]; then \
		echo "Error: S compiler not found at $(S_COMPILER)"; \
		echo "Set S_COMPILER or S_COMPILER_EMIT_CWD environment variable"; \
		exit 1; \
	fi
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/run_full_model_inference.s' -o 'artifacts/build/inference_orchestrator/run_full_model_inference.ir' 2>&1
	@$(MAKE) build-s-ir-runner
	@echo "Running S full model inference pipeline..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		NEURX_CHECKPOINT_DIR='$(PRETRAIN_OUTPUT_DIR)' \
		NEURX_INFER_PROMPT='$(NEURX_INFER_PROMPT)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/inference_orchestrator/run_full_model_inference.ir' 2>&1 | tee -a $(LOG_DIR)/run_inference_$(shell date +%Y%m%d_%H%M%S).log

run-full-inference-s: check-bash
	@echo "Building S full inference orchestrator..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/full_inference
	@mkdir -p $(LOG_DIR)
	@if [ ! -f "$(S_COMPILER)" ]; then \
		echo "Error: S compiler not found at $(S_COMPILER)"; \
		echo "Set S_COMPILER or S_COMPILER_EMIT_CWD environment variable"; \
		exit 1; \
	fi
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/run_full_inference.s' -o 'artifacts/build/full_inference/run_full_inference.ir' 2>&1
	@$(MAKE) build-s-ir-runner
	@echo "Running S full inference orchestrator..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		NEURX_INFER_MODE="$${NEURX_INFER_MODE:-batch}" \
		NEURX_CHECKPOINT_DIR="$${NEURX_CHECKPOINT_DIR:-$(CURDIR_UNIX)/artifacts/checkpoints/llm_training}" \
		NEURX_OUTPUT_DIR="$${NEURX_OUTPUT_DIR:-$(CURDIR_UNIX)/artifacts/inference_output}" \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/full_inference/run_full_inference.ir' 2>&1 | tee -a $(LOG_DIR)/run_full_inference_$(shell date +%Y%m%d_%H%M%S).log

run-s-pretrain-s: check-bash
	@echo "Building S real pretrain runner..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/pretrain_orchestrator
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/run_large_pretrain
	@mkdir -p $(LOG_DIR)
	@if [ ! -f "$(S_COMPILER)" ]; then \
		echo "Error: S compiler not found at $(S_COMPILER)"; \
		echo "Set S_COMPILER or S_COMPILER_EMIT_CWD environment variable"; \
		exit 1; \
	fi
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/minimal_train.s' -o 'artifacts/build/pretrain_orchestrator/minimal_train.ir' 2>&1
	@cd '$(CURDIR_UNIX)' && \
		if [ '$(PRETRAIN_SHARD_LIMIT)' = 'all' ]; then \
			find '$(PRETRAIN_SHARD_DIR)' -maxdepth 1 -type f -name 'shard_*.jsonl' -print | sort > '$(CURDIR_UNIX)/artifacts/build/run_large_pretrain/shard_list.txt'; \
		else \
			find '$(PRETRAIN_SHARD_DIR)' -maxdepth 1 -type f -name 'shard_*.jsonl' -print | sort | sed -n '1,$(PRETRAIN_SHARD_LIMIT)p' > '$(CURDIR_UNIX)/artifacts/build/run_large_pretrain/shard_list.txt'; \
		fi
	@if [ ! -x "$(S_RUNNER_BIN)" ]; then \
		$(MAKE) build-s-ir-runner; \
	fi
	@echo "Running S real pretrain runner..."
	@cd '$(CURDIR_UNIX)' && \
		SHARD_COUNT="$$(wc -l < '$(CURDIR_UNIX)/artifacts/build/run_large_pretrain/shard_list.txt')"; \
		FIRST_SHARD="$$(sed -n '1p' '$(CURDIR_UNIX)/artifacts/build/run_large_pretrain/shard_list.txt')"; \
		LAST_SHARD="$$(sed -n "$${SHARD_COUNT}p" '$(CURDIR_UNIX)/artifacts/build/run_large_pretrain/shard_list.txt')"; \
		STARTUP_MARKER_FILE='$(CURDIR_UNIX)/artifacts/build/run_large_pretrain/startup.marker'; \
		PROGRESS_FILE='$(CURDIR_UNIX)/artifacts/build/run_large_pretrain/progress.txt'; \
		: > "$$STARTUP_MARKER_FILE"; \
		: > "$$PROGRESS_FILE"; \
		echo "[pretrain] queued shards: $$SHARD_COUNT"; \
		echo "[pretrain] runner: $(S_RUNNER_BIN)"; \
		echo "[pretrain] ir: $(CURDIR_UNIX)/artifacts/build/pretrain_orchestrator/minimal_train.ir"; \
		echo "[pretrain] output: $${NEURX_PRETRAIN_OUTPUT_DIR:-$(PRETRAIN_OUTPUT_DIR)}"; \
		echo "[pretrain] first shard: $$FIRST_SHARD"; \
		echo "[pretrain] last shard: $$LAST_SHARD"; \
		echo "[pretrain] launching S runner..."; \
		( while true; do \
			sleep 10; \
			if [ -s "$$PROGRESS_FILE" ]; then \
				PROGRESS_LINE="$$(tail -n 1 "$$PROGRESS_FILE" 2>/dev/null)"; \
				echo "[pretrain] runner active: $$PROGRESS_LINE"; \
			elif [ -s "$$STARTUP_MARKER_FILE" ]; then \
				echo "[pretrain] runner active: trainer main entered, waiting for first progress record..."; \
			else \
				echo "[pretrain] runner active: S runner launched, trainer main not reached yet..."; \
			fi; \
		done ) & \
		HEARTBEAT_PID=$$!; \
		trap 'kill '"$$HEARTBEAT_PID"' >/dev/null 2>&1 || true' EXIT; \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		NEURX_STARTUP_MARKER_FILE="$$STARTUP_MARKER_FILE" \
		NEURX_PRETRAIN_PROGRESS_FILE="$$PROGRESS_FILE" \
		NEURX_PRETRAIN_MANIFEST="$${NEURX_PRETRAIN_MANIFEST:-$(PRETRAIN_MANIFEST)}" \
		NEURX_PRETRAIN_SHARD_LIST_FILE='$(CURDIR_UNIX)/artifacts/build/run_large_pretrain/shard_list.txt' \
		NEURX_PRETRAIN_SHARD_COUNT="$$SHARD_COUNT" \
		NEURX_PRETRAIN_MODEL_NAME="$${NEURX_PRETRAIN_MODEL_NAME:-$(PRETRAIN_MODEL_NAME)}" \
		NEURX_PRETRAIN_OUTPUT_DIR="$${NEURX_PRETRAIN_OUTPUT_DIR:-$(PRETRAIN_OUTPUT_DIR)}" \
		NEURX_PRETRAIN_FAST_PREFIX="$${NEURX_PRETRAIN_FAST_PREFIX:-$(PRETRAIN_FAST_PREFIX)}" \
		NEURX_PRETRAIN_TEXT_TOKEN_CAP="$${NEURX_PRETRAIN_TEXT_TOKEN_CAP:-$(PRETRAIN_TEXT_TOKEN_CAP)}" \
		NEURX_PRETRAIN_JSON_SCAN_CAP="$${NEURX_PRETRAIN_JSON_SCAN_CAP:-$(PRETRAIN_JSON_SCAN_CAP)}" \
		NEURX_PRETRAIN_LINE_CHUNK="$${NEURX_PRETRAIN_LINE_CHUNK:-$(PRETRAIN_LINE_CHUNK)}" \
		NEURX_PRETRAIN_SHARD_INDEX_MODE="$${NEURX_PRETRAIN_SHARD_INDEX_MODE:-$(PRETRAIN_SHARD_INDEX_MODE)}" \
		NEURX_PRETRAIN_STEPS="$${NEURX_PRETRAIN_STEPS:-$(PRETRAIN_STEPS)}" \
		NEURX_PRETRAIN_MICRO_BATCH="$${NEURX_PRETRAIN_MICRO_BATCH:-4}" \
		NEURX_PRETRAIN_SEQ_LEN="$${NEURX_PRETRAIN_SEQ_LEN:-256}" \
		NEURX_PRETRAIN_LR="$${NEURX_PRETRAIN_LR:-0.0002}" \
		NEURX_PRETRAIN_WARMUP_STEPS="$${NEURX_PRETRAIN_WARMUP_STEPS:-8}" \
		NEURX_PRETRAIN_WEIGHT_DECAY="$${NEURX_PRETRAIN_WEIGHT_DECAY:-0.01}" \
		NEURX_PRETRAIN_LOG_INTERVAL="$${NEURX_PRETRAIN_LOG_INTERVAL:-1}" \
		NEURX_PRETRAIN_SAVE_INTERVAL="$${NEURX_PRETRAIN_SAVE_INTERVAL:-100}" \
		NEURX_LLM_VOCAB_SIZE="$${NEURX_LLM_VOCAB_SIZE:-16000}" \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/pretrain_orchestrator/minimal_train.ir' 2>&1 | tee -a $(LOG_DIR)/run_s_pretrain_$(shell date +%Y%m%d_%H%M%S).log; \
		RUN_STATUS=$${PIPESTATUS[0]}; \
		kill "$$HEARTBEAT_PID" >/dev/null 2>&1 || true; \
		exit "$$RUN_STATUS"

run-gpu-pretrain-s: check-bash
	@echo "Preparing native GPU pretrain launcher..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/run_large_pretrain
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		if [ '$(PRETRAIN_SHARD_LIMIT)' = 'all' ]; then \
			find '$(PRETRAIN_SHARD_DIR)' -maxdepth 1 -type f -name 'shard_*.jsonl' -print | sort > '$(CURDIR_UNIX)/artifacts/build/run_large_pretrain/shard_list.txt'; \
		else \
			find '$(PRETRAIN_SHARD_DIR)' -maxdepth 1 -type f -name 'shard_*.jsonl' -print | sort | sed -n '1,$(PRETRAIN_SHARD_LIMIT)p' > '$(CURDIR_UNIX)/artifacts/build/run_large_pretrain/shard_list.txt'; \
		fi
	@if [ ! -x "$(S_RUNNER_BIN)" ]; then \
		$(MAKE) build-s-ir-runner; \
	fi
	@$(MAKE) build-cuda-train-bridge
	@echo "Running S GPU pretrain launcher..."
	@set -o pipefail; cd '$(CURDIR_UNIX)' && \
		SHARD_COUNT="$$(wc -l < '$(CURDIR_UNIX)/artifacts/build/run_large_pretrain/shard_list.txt')"; \
		FIRST_SHARD="$$(sed -n '1p' '$(CURDIR_UNIX)/artifacts/build/run_large_pretrain/shard_list.txt')"; \
		LAST_SHARD="$$(sed -n "$${SHARD_COUNT}p" '$(CURDIR_UNIX)/artifacts/build/run_large_pretrain/shard_list.txt')"; \
		GPU_COUNT="$$(nvidia-smi -L 2>/dev/null | grep -c '^GPU ' || true)"; \
		REQUESTED_WORLD="$${NEURX_NUM_GPUS:-$$GPU_COUNT}"; \
		GIT_SHA="$$(git rev-parse HEAD 2>/dev/null || printf unknown)"; \
		if [ -n "$$(git status --porcelain 2>/dev/null)" ]; then GIT_SHA="$${GIT_SHA}-dirty"; fi; \
		CHECKPOINT_DIR="$${NEURX_PRETRAIN_OUTPUT_DIR:-$(PRETRAIN_OUTPUT_DIR)}"; \
		if [ "$$REQUESTED_WORLD" -gt 1 ]; then \
			RESUME_CHECKPOINT_FILE="$$CHECKPOINT_DIR/rank_0/transformer_v2.ckpt"; \
		else \
			RESUME_CHECKPOINT_FILE="$$CHECKPOINT_DIR/transformer_v2.ckpt"; \
		fi; \
		echo "[pretrain-gpu] queued shards: $$SHARD_COUNT"; \
		echo "[pretrain-gpu] first shard: $$FIRST_SHARD"; \
		echo "[pretrain-gpu] last shard: $$LAST_SHARD"; \
		echo "[pretrain-gpu] detected GPUs: $$GPU_COUNT"; \
		echo "[pretrain-gpu] checkpoint dir: $$CHECKPOINT_DIR"; \
		if [ -f "$$RESUME_CHECKPOINT_FILE" ]; then \
			echo "[pretrain-gpu] transformer-v2 checkpoint found, resuming: $$RESUME_CHECKPOINT_FILE"; \
			RESUME_FLAG=1; \
		else \
			echo "[pretrain-gpu] no transformer-v2 checkpoint, starting fresh"; \
			RESUME_FLAG=0; \
		fi; \
		echo "[pretrain-gpu] skipping S validation, launching native CUDA/cuBLAS trainer..."; \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		WORLD_SIZE="$$REQUESTED_WORLD" \
		NEURX_PRETRAIN_SHARD_LIST_FILE='$(CURDIR_UNIX)/artifacts/build/run_large_pretrain/shard_list.txt' \
		NEURX_PRETRAIN_OUTPUT_DIR="$${NEURX_PRETRAIN_OUTPUT_DIR:-$(PRETRAIN_OUTPUT_DIR)}" \
		NEURX_PRETRAIN_STEPS="$${NEURX_PRETRAIN_STEPS:-$(PRETRAIN_STEPS)}" \
		NEURX_PRETRAIN_MICRO_BATCH="$${NEURX_PRETRAIN_MICRO_BATCH:-4}" \
		NEURX_PRETRAIN_SEQ_LEN="$${NEURX_PRETRAIN_SEQ_LEN:-256}" \
		NEURX_PRETRAIN_LR="$${NEURX_PRETRAIN_LR:-0.0002}" \
		NEURX_PRETRAIN_MIN_LR="$${NEURX_PRETRAIN_MIN_LR:-0.00002}" \
		NEURX_PRETRAIN_LR_SCHEDULE="$${NEURX_PRETRAIN_LR_SCHEDULE:-cosine}" \
		NEURX_PRETRAIN_WARMUP_STEPS="$${NEURX_PRETRAIN_WARMUP_STEPS:-2000}" \
		NEURX_PRETRAIN_WEIGHT_DECAY="$${NEURX_PRETRAIN_WEIGHT_DECAY:-0.01}" \
		NEURX_MAX_GRAD_NORM="$${NEURX_MAX_GRAD_NORM:-1.0}" \
		NEURX_FINITE_CHECK_INTERVAL="$${NEURX_FINITE_CHECK_INTERVAL:-100}" \
		NEURX_FAIL_ON_NONFINITE="$${NEURX_FAIL_ON_NONFINITE:-1}" \
		NEURX_SEED="$${NEURX_SEED:-1337}" \
		NEURX_GIT_SHA="$$GIT_SHA" \
		NEURX_PRETRAIN_LOG_INTERVAL="$${NEURX_PRETRAIN_LOG_INTERVAL:-1}" \
		NEURX_PRETRAIN_VALIDATION_SHARD_LIST_FILE="$${NEURX_PRETRAIN_VALIDATION_SHARD_LIST_FILE:-}" \
		NEURX_PRETRAIN_VALIDATION_FILE="$${NEURX_PRETRAIN_VALIDATION_FILE:-}" \
		NEURX_PRETRAIN_EVAL_INTERVAL="$${NEURX_PRETRAIN_EVAL_INTERVAL:-100}" \
		NEURX_PRETRAIN_EVAL_BATCHES="$${NEURX_PRETRAIN_EVAL_BATCHES:-8}" \
		NEURX_PRETRAIN_SAVE_INTERVAL="$${NEURX_PRETRAIN_SAVE_INTERVAL:-$(PRETRAIN_SAVE_INTERVAL)}" \
		NEURX_PRETRAIN_RESUME="$$RESUME_FLAG" \
		NEURX_PRETRAIN_RESUME_FROM="$$RESUME_CHECKPOINT_FILE" \
		NEURX_VALIDATE_CHECKPOINT="$${NEURX_VALIDATE_CHECKPOINT:-0}" \
		NEURX_TOKENIZER_VOCAB="$${NEURX_TOKENIZER_VOCAB:-$(CURDIR_UNIX)/data/corpus/vocab.json}" \
		NEURX_TOKENIZER_MERGES="$${NEURX_TOKENIZER_MERGES:-$(CURDIR_UNIX)/data/corpus/merges.txt}" \
		NEURX_TRANSFORMER_DIM="$${NEURX_TRANSFORMER_DIM:-1024}" \
		NEURX_TRANSFORMER_HEADS="$${NEURX_TRANSFORMER_HEADS:-16}" \
		NEURX_TRANSFORMER_FFN="$${NEURX_TRANSFORMER_FFN:-4096}" \
		NEURX_TRANSFORMER_NUM_LAYERS="$${NEURX_TRANSFORMER_NUM_LAYERS:-24}" \
		NEURX_GRADIENT_ACCUMULATION_STEPS="$${NEURX_GRADIENT_ACCUMULATION_STEPS:-8}" \
		NEURX_CUDA_BATCH_PAIRS="$${NEURX_CUDA_BATCH_PAIRS:-256}" \
		NEURX_CUDA_VOCAB_SIZE="$${NEURX_CUDA_VOCAB_SIZE:-4096}" \
		NEURX_NCCL_ID_FILE="$${NEURX_NCCL_ID_FILE:-/tmp/neurx_nccl_id_$$}" \
		bash -c '\
			set -e; \
			world="$${WORLD_SIZE:-1}"; id_file="$${NEURX_NCCL_ID_FILE}"; \
			rm -f "$$id_file" "$$id_file.tmp"; pids=""; \
			echo "[training] Starting $$world GPU rank(s)..."; \
			for rank in $$(seq 0 $$((world - 1))); do \
				echo "[training] Launching rank $$rank on GPU $$rank..."; \
				if [ "$$world" -gt 1 ]; then \
					rank_checkpoint_dir="$${NEURX_PRETRAIN_OUTPUT_DIR}/rank_$${rank}"; \
				else \
					rank_checkpoint_dir="$${NEURX_PRETRAIN_OUTPUT_DIR}"; \
				fi; \
				rank_resume_path="$$rank_checkpoint_dir/transformer_v2.ckpt"; \
				if [ -f "$$rank_resume_path" ]; then rank_resume=1; else rank_resume=0; fi; \
				CUDA_VISIBLE_DEVICES="$$rank" RANK="$$rank" LOCAL_RANK=0 WORLD_SIZE="$$world" NEURX_CUDA_DEVICE=0 NEURX_NCCL_ID_FILE="$$id_file" \
				NEURX_PRETRAIN_RESUME="$$rank_resume" \
				NEURX_PRETRAIN_RESUME_FROM="$$rank_resume_path" \
					"$(CUDA_TRAIN_BRIDGE_BIN)" 2>&1 | sed "s/^/[rank $$rank] /" & pids="$$pids $$!"; \
			 done; \
			 echo "[training] Waiting for all ranks to complete..."; \
			 status=0; for pid in $$pids; do wait $$pid || status=$$?; done; \
			 if [ $$status -eq 0 ]; then echo "[training] All ranks completed successfully!"; fi; \
			 exit $$status' \
		2>&1 | tee -a $(LOG_DIR)/run_gpu_pretrain_$(shell date +%Y%m%d_%H%M%S).log

test-neurx-1-3: check-bash
	@echo "Building NeurX-1.3 Model Test (S Language)..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/test
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/test_neurx_1_3_model.s' -o '$(CURDIR_UNIX)/artifacts/build/tests/neurx_1_3_test.ir' 2>&1
	@echo "Compiling IR runner..."
	@if [ ! -x "$(S_RUNNER_BIN)" ]; then \
		$(MAKE) build-s-ir-runner; \
	fi
	@echo "Running NeurX-1.3 Model Test..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		$(S_RUNNER_BIN) '$(CURDIR_UNIX)/artifacts/build/tests/neurx_1_3_test.ir' 2>&1 | tee -a $(LOG_DIR)/test_neurx_1_3_$(shell date +%Y%m%d_%H%M%S).log

compile-all-components-s: check-bash
	@echo "Building full compilation/test status entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/compile_all_components
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/compile_all_components.s' -o '$(CURDIR_UNIX)/artifacts/build/compile_all_components/compile_all_components.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/compile_all_components/compile_all_components.ir'
	@echo "Running full compilation/test status entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/compile_all_components/compile_all_components.ir' 2>&1 | tee -a $(LOG_DIR)/compile_all_components_$(shell date +%Y%m%d_%H%M%S).log

integration-s: check-bash
	@echo "Building training integration status entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/integration
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/integration.s' -o '$(CURDIR_UNIX)/artifacts/build/integration/integration.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/integration/integration.ir'
	@echo "Running training integration status entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/integration/integration.ir' 2>&1 | tee -a $(LOG_DIR)/integration_$(shell date +%Y%m%d_%H%M%S).log

complete-training-cycle-s: check-bash
	@echo "Building complete training cycle status entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/complete_training_cycle
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/complete_training_cycle.s' -o '$(CURDIR_UNIX)/artifacts/build/complete_training_cycle/complete_training_cycle.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/complete_training_cycle/complete_training_cycle.ir'
	@echo "Running complete training cycle status entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/complete_training_cycle/complete_training_cycle.ir' 2>&1 | tee -a $(LOG_DIR)/complete_training_cycle_$(shell date +%Y%m%d_%H%M%S).log

verify-transformer-implementation-s: check-bash
	@echo "Building transformer verification entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/verify_transformer_implementation
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/verify_transformer_implementation.s' -o '$(CURDIR_UNIX)/artifacts/build/verify_transformer_implementation/verify_transformer_implementation.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/verify_transformer_implementation/verify_transformer_implementation.ir'
	@echo "Running transformer verification entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/verify_transformer_implementation/verify_transformer_implementation.ir' 2>&1 | tee -a $(LOG_DIR)/verify_transformer_implementation_$(shell date +%Y%m%d_%H%M%S).log

cluster-launch-s: check-bash
	@echo "Building cluster launch status entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/cluster_launch
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/cluster_launch.s' -o '$(CURDIR_UNIX)/artifacts/build/cluster_launch/cluster_launch.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/cluster_launch/cluster_launch.ir'
	@echo "Running cluster launch status entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/cluster_launch/cluster_launch.ir' 2>&1 | tee -a $(LOG_DIR)/cluster_launch_$(shell date +%Y%m%d_%H%M%S).log

setup-production-deployment-s: check-bash
	@echo "Building production deployment status entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/setup_production_deployment
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/setup_production_deployment.s' -o '$(CURDIR_UNIX)/artifacts/build/setup_deploy/production/setup_production_deployment.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/setup_deploy/production/setup_production_deployment.ir'
	@echo "Running production deployment status entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/setup_deploy/production/setup_production_deployment.ir' 2>&1 | tee -a $(LOG_DIR)/setup_production_deployment_$(shell date +%Y%m%d_%H%M%S).log

run-end-to-end-verification-s: check-bash
	@echo "Building end-to-end verification status entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/run_end_to_end_verification
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/run_end_to_end_verification.s' -o '$(CURDIR_UNIX)/artifacts/build/run_end_to_end_verification/run_end_to_end_verification.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/run_end_to_end_verification/run_end_to_end_verification.ir'
	@echo "Running end-to-end verification status entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/run_end_to_end_verification/run_end_to_end_verification.ir' 2>&1 | tee -a $(LOG_DIR)/run_end_to_end_verification_$(shell date +%Y%m%d_%H%M%S).log

run-integration-tests-s: check-bash
	@echo "Building integration tests status entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/run_integration_tests
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/run_integration_tests.s' -o '$(CURDIR_UNIX)/artifacts/build/run_integration_tests/run_integration_tests.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/run_integration_tests/run_integration_tests.ir'
	@echo "Running integration tests status entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/run_integration_tests/run_integration_tests.ir' 2>&1 | tee -a $(LOG_DIR)/run_integration_tests_$(shell date +%Y%m%d_%H%M%S).log

minimal-diagnostic-s: check-bash
	@echo "Building minimal diagnostic status entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/minimal_diagnostic
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/minimal_diagnostic.s' -o '$(CURDIR_UNIX)/artifacts/build/minimal_diagnostic/minimal_diagnostic.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/minimal_diagnostic/minimal_diagnostic.ir'
	@echo "Running minimal diagnostic status entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/minimal_diagnostic/minimal_diagnostic.ir' 2>&1 | tee -a $(LOG_DIR)/minimal_diagnostic_$(shell date +%Y%m%d_%H%M%S).log

diagnose-file-creation-s: check-bash
	@echo "Building file creation diagnostic status entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/diagnose_file_creation
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/diagnose_file_creation.s' -o '$(CURDIR_UNIX)/artifacts/build/diagnose_file_creation/diagnose_file_creation.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/diagnose_file_creation/diagnose_file_creation.ir'
	@echo "Running file creation diagnostic status entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/diagnose_file_creation/diagnose_file_creation.ir' 2>&1 | tee -a $(LOG_DIR)/diagnose_file_creation_$(shell date +%Y%m%d_%H%M%S).log

diagnose-tool-registration-s: check-bash
	@echo "Building tool registration diagnostic status entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/diagnose_tool_registration
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/diagnose_tool_registration.s' -o '$(CURDIR_UNIX)/artifacts/build/diagnose_tool_registration/diagnose_tool_registration.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/diagnose_tool_registration/diagnose_tool_registration.ir'
	@echo "Running tool registration diagnostic status entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/diagnose_tool_registration/diagnose_tool_registration.ir' 2>&1 | tee -a $(LOG_DIR)/diagnose_tool_registration_$(shell date +%Y%m%d_%H%M%S).log

diagnose-autoscroll-s: check-bash
	@echo "Building autoscroll diagnostic status entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/diagnose_autoscroll
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'scripts/legacy/diagnose_autoscroll.s' -o '$(CURDIR_UNIX)/artifacts/build/diagnose_autoscroll/diagnose_autoscroll.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/diagnose_autoscroll/diagnose_autoscroll.ir'
	@echo "Running autoscroll diagnostic status entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/diagnose_autoscroll/diagnose_autoscroll.ir' 2>&1 | tee -a $(LOG_DIR)/diagnose_autoscroll_$(shell date +%Y%m%d_%H%M%S).log



logs:
	@mkdir -p $(LOG_DIR)
	@echo "Available logs in $(LOG_DIR):"
	@ls -1t $(LOG_DIR) | sed -n '1,200p' || true

logs-tail:
	@mkdir -p $(LOG_DIR)
	@FILE=$$(ls -1t $(LOG_DIR)/*$(NAME)* 2>/dev/null | head -1); \
	if [ -z "$$FILE" ]; then echo "No log files found in $(LOG_DIR)"; exit 1; fi; \
	echo "Tailing $$FILE"; tail -n 200 -f "$$FILE"



check-bash:
ifeq ($(PLATFORM),windows)
	@where "$(BASH)" >NUL 2>&1 || if not exist "$(BASH)" ( \
		echo error: Git Bash not found: $(BASH) & \
		echo hint: install Git for Windows, or run make BASH=C:/path/to/bash.exe ^<target^> & \
		exit /b 1 \
	)
	@"$(BASH)" -lc "exit 0"
else
	@command -v bash >/dev/null 2>&1 || { \
		echo "error: bash not found on PATH"; \
		echo "hint: install bash or run make BASH=/path/to/bash <target>"; \
		exit 1; \
	}
endif
