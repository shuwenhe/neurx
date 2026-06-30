.PHONY: help install neurx s-package-index s-compile-runtime code-agent-build code-agent linux windows macos ios android harmony clean check-bash \
	app-linux app-windows app-macos app-ios app-android app-harmony \
	linux windows macos ios android harmony test test-transformer-e2e \
	train train-watch train-llm train-llm-watch train-dp train-dp-watch \
	infer infer-watch infer-interactive \
	install-robot install-auto install-desktop install-tablet install-mobile-android install-mobile-ios

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
BASH ?= bash
endif

.DEFAULT_GOAL := help

S_COMPILER_LOCAL ?= /Users/shuwen/shuwen/train/s/.local/bin/s
S_COMPILER_BIN ?= /Users/shuwen/shuwen/train/s/bin/s
S_COMPILER ?= $(firstword $(wildcard $(S_COMPILER_LOCAL) $(S_COMPILER_BIN)) s)
S_COMPILER_EMIT_CWD ?= /Users/shuwen/shuwen/train/s
CURDIR_UNIX := $(subst \,/,$(CURDIR))

help:
	@echo "  neurx             Compile the NeurX deep learning framework to IR"
	@echo "  linux             Compile and run the Linux app"
	@echo "  windows           Compile and run the Windows app"
	@echo "  macos             Compile and run the macOS app"
	@echo "  ios               Compile the iOS app (placeholder target)"
	@echo "  android           Compile the Android app (placeholder target)"
	@echo "  harmony           Compile the Harmony app (placeholder target)"
	@echo "  install           Alias of neurx"
	@echo "  code-agent-build  Build build/bin/neurx_code_agent from agent/code_agent.s"
	@echo "  code-agent        Run code agent (TASK=... optional)"
	@echo "  clean             Remove generated artifacts and caches"
	@echo "  platform          $(PLATFORM)"
	@echo "  train             Run NeurX training (run_training.sh)"
	@echo "  train-watch       Run training and tail live logs (/tmp/neurx_real_train.log)"
	@echo "  train-llm         Run LLM training with S compiler (configurable via NEURX_* env vars)"
	@echo "  train-llm-watch   Run LLM training and tail live logs"
	@echo "  train-dp          Run LLM training in data parallel mode"
	@echo "  train-dp-watch    Run data parallel training and tail live logs"
	@echo "  infer             Run LLM inference with S compiler (configurable via NEURX_* env vars)"
	@echo "  infer-watch       Run LLM inference and tail live logs"
	@echo "  infer-interactive Run interactive LLM inference REPL (supports multi-turn, sampling params)"
	@echo "  test-transformer-e2e  Compile and run transformer model smoke test"
	@echo "  test              Alias of test-transformer-e2e"
	@echo ""
	@echo "Platform install targets:"
	@echo "  install-robot     Install NeurX on Jetson Orin / RK3588 robot"
	@echo "  install-auto      Install NeurX on automotive SoC (DRIVE Orin / QNX)"
	@echo "  install-desktop   Install NeurX on Linux / macOS desktop"
	@echo "  install-tablet    Install NeurX on Android tablet via ADB"
	@echo "  install-mobile-android  Install NeurX on Android phone via ADB"
	@echo "  install-mobile-ios      Install NeurX on iPhone via Xcode"

train: check-bash
	@echo "Running NeurX training (run_training.sh)"
	@cd '$(CURDIR_UNIX)' && \
	OUT_DIR="$${NEURX_S_PRETRAIN_OUTPUT_DIR:-artifacts/checkpoints/llm_s_pretrain}"; \
	NEURX_S_PRETRAIN_OUTPUT_DIR="$$OUT_DIR" bash run_training.sh 2>&1; \
	STATUS=$$?; \
	if [ $$STATUS -eq 0 ]; then \
		echo "Training completed successfully. Checkpoints: $$OUT_DIR"; \
	else \
		echo "Training failed with exit code $$STATUS"; \
	fi; \
	exit $$STATUS

train-watch: check-bash
	@echo "Running NeurX training (run_training.sh) and tailing live logs"
	@cd '$(CURDIR_UNIX)' && \
	mkdir -p .run && \
	OUT_DIR="$${NEURX_S_PRETRAIN_OUTPUT_DIR:-artifacts/checkpoints/llm_s_pretrain}" && \
	LOG_FILE="/tmp/neurx_real_train.log" && \
	rm -f "$$LOG_FILE" && \
	NEURX_S_PRETRAIN_OUTPUT_DIR="$$OUT_DIR" bash run_training.sh 2>&1 | tee "$$LOG_FILE" & \
	TRAIN_PID=$$!; echo "$$TRAIN_PID" > .run/train_watch_pid.txt; \
	sleep 0.5; \
	echo "Tailing $$LOG_FILE (train pid: $$TRAIN_PID)"; \
	# tail until the training PID exits (GNU tail supports --pid)
	tail --pid=$$TRAIN_PID -F "$$LOG_FILE"; \
	wait $$TRAIN_PID; STATUS=$$?; \
	if [ $$STATUS -eq 0 ]; then \
		echo "Training completed successfully. Checkpoints: $$OUT_DIR"; \
	else \
		echo "Training failed with exit code $$STATUS"; \
	fi; \
	rm -f .run/train_watch_pid.txt

train-llm: check-bash
	@echo "Running LLM training with S compiler (run_llm_training_with_compiler.sh)"
	@cd '$(CURDIR_UNIX)' && \
	STEPS="$${NEURX_TOTAL_STEPS:-100}"; \
	BATCH_SIZE="$${NEURX_BATCH_SIZE:-4}"; \
	LR="$${NEURX_LR:-0.001}"; \
	SEQ_LENGTH="$${NEURX_SEQ_LENGTH:-8}"; \
	WARMUP_STEPS="$${NEURX_WARMUP_STEPS:-10}"; \
	CHECKPOINT_INTERVAL="$${NEURX_CHECKPOINT_INTERVAL:-10}"; \
	DP_MODE="$${NEURX_DP_MODE:-small}"; \
	WORLD_SIZE="$${NEURX_WORLD_SIZE:-1}"; \
	DATA_PARALLEL_SIZE="$${NEURX_DATA_PARALLEL_SIZE:-1}"; \
	TENSOR_PARALLEL_SIZE="$${NEURX_TENSOR_PARALLEL_SIZE:-1}"; \
	PIPELINE_PARALLEL_SIZE="$${NEURX_PIPELINE_PARALLEL_SIZE:-1}"; \
	MIXED_PRECISION_MODE="$${NEURX_MIXED_PRECISION_MODE:-bf16}"; \
	LOSS_SCALE="$${NEURX_LOSS_SCALE:-1.0}"; \
	export NEURX_TOTAL_STEPS="$$STEPS"; \
	export NEURX_BATCH_SIZE="$$BATCH_SIZE"; \
	export NEURX_LR="$$LR"; \
	export NEURX_SEQ_LENGTH="$$SEQ_LENGTH"; \
	export NEURX_WARMUP_STEPS="$$WARMUP_STEPS"; \
	export NEURX_CHECKPOINT_INTERVAL="$$CHECKPOINT_INTERVAL"; \
	export NEURX_DP_MODE="$$DP_MODE"; \
	export NEURX_WORLD_SIZE="$$WORLD_SIZE"; \
	export NEURX_DATA_PARALLEL_SIZE="$$DATA_PARALLEL_SIZE"; \
	export NEURX_TENSOR_PARALLEL_SIZE="$$TENSOR_PARALLEL_SIZE"; \
	export NEURX_PIPELINE_PARALLEL_SIZE="$$PIPELINE_PARALLEL_SIZE"; \
	export NEURX_MIXED_PRECISION_MODE="$$MIXED_PRECISION_MODE"; \
	export NEURX_LOSS_SCALE="$$LOSS_SCALE"; \
	bash run_llm_training_with_compiler.sh 2>&1; \
	STATUS=$$?; \
	if [ $$STATUS -eq 0 ]; then \
		echo "LLM Training completed successfully. Checkpoints: artifacts/checkpoints/llm_training/"; \
	else \
		echo "LLM Training failed with exit code $$STATUS"; \
	fi; \
	exit $$STATUS

train-llm-watch: check-bash
	@echo "Running LLM training with S compiler and tailing live logs"
	@cd '$(CURDIR_UNIX)' && \
	mkdir -p .run && \
	STEPS="$${NEURX_TOTAL_STEPS:-100}"; \
	BATCH_SIZE="$${NEURX_BATCH_SIZE:-4}"; \
	LR="$${NEURX_LR:-0.001}"; \
	SEQ_LENGTH="$${NEURX_SEQ_LENGTH:-8}"; \
	WARMUP_STEPS="$${NEURX_WARMUP_STEPS:-10}"; \
	CHECKPOINT_INTERVAL="$${NEURX_CHECKPOINT_INTERVAL:-10}"; \
	DP_MODE="$${NEURX_DP_MODE:-small}"; \
	WORLD_SIZE="$${NEURX_WORLD_SIZE:-1}"; \
	DATA_PARALLEL_SIZE="$${NEURX_DATA_PARALLEL_SIZE:-1}"; \
	TENSOR_PARALLEL_SIZE="$${NEURX_TENSOR_PARALLEL_SIZE:-1}"; \
	PIPELINE_PARALLEL_SIZE="$${NEURX_PIPELINE_PARALLEL_SIZE:-1}"; \
	MIXED_PRECISION_MODE="$${NEURX_MIXED_PRECISION_MODE:-bf16}"; \
	LOSS_SCALE="$${NEURX_LOSS_SCALE:-1.0}"; \
	LOG_FILE="/tmp/neurx_llm_train.log" && \
	rm -f "$$LOG_FILE" && \
	export NEURX_TOTAL_STEPS="$$STEPS"; \
	export NEURX_BATCH_SIZE="$$BATCH_SIZE"; \
	export NEURX_LR="$$LR"; \
	export NEURX_SEQ_LENGTH="$$SEQ_LENGTH"; \
	export NEURX_WARMUP_STEPS="$$WARMUP_STEPS"; \
	export NEURX_CHECKPOINT_INTERVAL="$$CHECKPOINT_INTERVAL"; \
	export NEURX_DP_MODE="$$DP_MODE"; \
	export NEURX_WORLD_SIZE="$$WORLD_SIZE"; \
	export NEURX_DATA_PARALLEL_SIZE="$$DATA_PARALLEL_SIZE"; \
	export NEURX_TENSOR_PARALLEL_SIZE="$$TENSOR_PARALLEL_SIZE"; \
	export NEURX_PIPELINE_PARALLEL_SIZE="$$PIPELINE_PARALLEL_SIZE"; \
	export NEURX_MIXED_PRECISION_MODE="$$MIXED_PRECISION_MODE"; \
	export NEURX_LOSS_SCALE="$$LOSS_SCALE"; \
	bash run_llm_training_with_compiler.sh 2>&1 | tee "$$LOG_FILE" & \
	TRAIN_PID=$$!; echo "$$TRAIN_PID" > .run/train_llm_watch_pid.txt; \
	sleep 0.5; \
	echo "Tailing $$LOG_FILE (train pid: $$TRAIN_PID)"; \
	tail --pid=$$TRAIN_PID -F "$$LOG_FILE"; \
	wait $$TRAIN_PID; STATUS=$$?; \
	if [ $$STATUS -eq 0 ]; then \
		echo "LLM Training completed successfully. Checkpoints: artifacts/checkpoints/llm_training/"; \
	else \
		echo "LLM Training failed with exit code $$STATUS"; \
	fi; \
	rm -f .run/train_llm_watch_pid.txt; \
	exit $$STATUS

train-dp: check-bash
	@echo "Running LLM training in data parallel mode"
	@cd '$(CURDIR_UNIX)' && \
	export NEURX_TOTAL_STEPS="$${NEURX_TOTAL_STEPS:-100}"; \
	export NEURX_BATCH_SIZE="$${NEURX_BATCH_SIZE:-4}"; \
	export NEURX_LR="$${NEURX_LR:-0.001}"; \
	export NEURX_SEQ_LENGTH="$${NEURX_SEQ_LENGTH:-8}"; \
	export NEURX_WARMUP_STEPS="$${NEURX_WARMUP_STEPS:-10}"; \
	export NEURX_CHECKPOINT_INTERVAL="$${NEURX_CHECKPOINT_INTERVAL:-10}"; \
	export NEURX_DP_MODE="$${NEURX_DP_MODE:-ddp}"; \
	export NEURX_WORLD_SIZE="$${NEURX_WORLD_SIZE:-2}"; \
	export NEURX_DATA_PARALLEL_SIZE="$${NEURX_DATA_PARALLEL_SIZE:-2}"; \
	export NEURX_TENSOR_PARALLEL_SIZE="$${NEURX_TENSOR_PARALLEL_SIZE:-1}"; \
	export NEURX_PIPELINE_PARALLEL_SIZE="$${NEURX_PIPELINE_PARALLEL_SIZE:-1}"; \
	export NEURX_MIXED_PRECISION_MODE="$${NEURX_MIXED_PRECISION_MODE:-bf16}"; \
	export NEURX_LOSS_SCALE="$${NEURX_LOSS_SCALE:-1.0}"; \
	bash run_llm_training_with_compiler.sh 2>&1; \
	STATUS=$$?; \
	if [ $$STATUS -eq 0 ]; then \
		echo "DP training completed successfully. Checkpoints: artifacts/checkpoints/llm_training/"; \
	else \
		echo "DP training failed with exit code $$STATUS"; \
	fi; \
	exit $$STATUS

train-dp-watch: check-bash
	@echo "Running LLM training in data parallel mode and tailing live logs"
	@cd '$(CURDIR_UNIX)' && \
	mkdir -p .run && \
	LOG_FILE="/tmp/neurx_llm_dp_train.log" && \
	rm -f "$$LOG_FILE" && \
	export NEURX_TOTAL_STEPS="$${NEURX_TOTAL_STEPS:-100}"; \
	export NEURX_BATCH_SIZE="$${NEURX_BATCH_SIZE:-4}"; \
	export NEURX_LR="$${NEURX_LR:-0.001}"; \
	export NEURX_SEQ_LENGTH="$${NEURX_SEQ_LENGTH:-8}"; \
	export NEURX_WARMUP_STEPS="$${NEURX_WARMUP_STEPS:-10}"; \
	export NEURX_CHECKPOINT_INTERVAL="$${NEURX_CHECKPOINT_INTERVAL:-10}"; \
	export NEURX_DP_MODE="$${NEURX_DP_MODE:-ddp}"; \
	export NEURX_WORLD_SIZE="$${NEURX_WORLD_SIZE:-2}"; \
	export NEURX_DATA_PARALLEL_SIZE="$${NEURX_DATA_PARALLEL_SIZE:-2}"; \
	export NEURX_TENSOR_PARALLEL_SIZE="$${NEURX_TENSOR_PARALLEL_SIZE:-1}"; \
	export NEURX_PIPELINE_PARALLEL_SIZE="$${NEURX_PIPELINE_PARALLEL_SIZE:-1}"; \
	export NEURX_MIXED_PRECISION_MODE="$${NEURX_MIXED_PRECISION_MODE:-bf16}"; \
	export NEURX_LOSS_SCALE="$${NEURX_LOSS_SCALE:-1.0}"; \
	bash run_llm_training_with_compiler.sh 2>&1 | tee "$$LOG_FILE" & \
	TRAIN_PID=$$!; echo "$$TRAIN_PID" > .run/train_dp_watch_pid.txt; \
	sleep 0.5; \
	echo "Tailing $$LOG_FILE (train pid: $$TRAIN_PID)"; \
	tail --pid=$$TRAIN_PID -F "$$LOG_FILE"; \
	wait $$TRAIN_PID; STATUS=$$?; \
	if [ $$STATUS -eq 0 ]; then \
		echo "DP training completed successfully. Checkpoints: artifacts/checkpoints/llm_training/"; \
	else \
		echo "DP training failed with exit code $$STATUS"; \
	fi; \
	rm -f .run/train_dp_watch_pid.txt; \
	exit $$STATUS

infer: check-bash
	@echo "Running LLM inference with S compiler (run_inference_llm.sh)"
	@cd '$(CURDIR_UNIX)' && \
	CHECKPOINT_PATH="$${NEURX_INFER_CHECKPOINT_PATH:-$${NEURX_INFER_CHECKPOINT:-artifacts/checkpoints/llm_training}}"; \
	SEED="$${NEURX_INFER_SEED:-neurx }"; \
	QUESTION="$${NEURX_INFER_QUESTION:-$${NEURX_INFER_PROMPT:-$${NEURX_INFERENCE_INPUT:-人工智能是什么？请直接回答。}}}"; \
	MAX_NEW_CHARS="$${NEURX_INFER_MAX_NEW_CHARS:-120}"; \
	VALIDATE_ONLY="$${NEURX_INFER_VALIDATE_ONLY:-}"; \
	MODEL_NAME="$${NEURX_INFER_MODEL_NAME:-llm_s}"; \
	DEVICE="$${NEURX_INFER_DEVICE:-$${NEURX_DEVICE:-cpu}}"; \
	export NEURX_INFER_CHECKPOINT="$$CHECKPOINT_PATH"; \
	export NEURX_INFER_CHECKPOINT_PATH="$$CHECKPOINT_PATH"; \
	export NEURX_INFER_SEED="$$SEED"; \
	export NEURX_INFER_QUESTION="$$QUESTION"; \
	export NEURX_INFER_PROMPT="$$QUESTION"; \
	export NEURX_INFERENCE_INPUT="$$QUESTION"; \
	export NEURX_INFER_MAX_NEW_CHARS="$$MAX_NEW_CHARS"; \
	export NEURX_INFER_VALIDATE_ONLY="$$VALIDATE_ONLY"; \
	export NEURX_INFER_MODEL_NAME="$$MODEL_NAME"; \
	export NEURX_INFER_DEVICE="$$DEVICE"; \
	export NEURX_DEVICE="$$DEVICE"; \
	bash run_inference_llm.sh 2>&1; \
	STATUS=$$?; \
	if [ $$STATUS -eq 0 ]; then \
		echo "LLM Inference completed successfully. Output: artifacts/inference_output/"; \
	else \
		echo "LLM Inference failed with exit code $$STATUS"; \
	fi; \
	exit $$STATUS

infer-watch: check-bash
	@echo "Running LLM inference with S compiler and tailing live logs"
	@cd '$(CURDIR_UNIX)' && \
	mkdir -p .run && \
	CHECKPOINT_PATH="$${NEURX_INFER_CHECKPOINT_PATH:-$${NEURX_INFER_CHECKPOINT:-artifacts/checkpoints/llm_training}}"; \
	SEED="$${NEURX_INFER_SEED:-neurx }"; \
	QUESTION="$${NEURX_INFER_QUESTION:-$${NEURX_INFER_PROMPT:-$${NEURX_INFERENCE_INPUT:-人工智能是什么？请直接回答。}}}"; \
	MAX_NEW_CHARS="$${NEURX_INFER_MAX_NEW_CHARS:-120}"; \
	VALIDATE_ONLY="$${NEURX_INFER_VALIDATE_ONLY:-}"; \
	MODEL_NAME="$${NEURX_INFER_MODEL_NAME:-llm_s}"; \
	DEVICE="$${NEURX_INFER_DEVICE:-$${NEURX_DEVICE:-cpu}}"; \
	LOG_FILE="/tmp/neurx_inference.log" && \
	rm -f "$$LOG_FILE" && \
	export NEURX_INFER_CHECKPOINT="$$CHECKPOINT_PATH"; \
	export NEURX_INFER_CHECKPOINT_PATH="$$CHECKPOINT_PATH"; \
	export NEURX_INFER_SEED="$$SEED"; \
	export NEURX_INFER_QUESTION="$$QUESTION"; \
	export NEURX_INFER_PROMPT="$$QUESTION"; \
	export NEURX_INFERENCE_INPUT="$$QUESTION"; \
	export NEURX_INFER_MAX_NEW_CHARS="$$MAX_NEW_CHARS"; \
	export NEURX_INFER_VALIDATE_ONLY="$$VALIDATE_ONLY"; \
	export NEURX_INFER_MODEL_NAME="$$MODEL_NAME"; \
	export NEURX_INFER_DEVICE="$$DEVICE"; \
	export NEURX_DEVICE="$$DEVICE"; \
	bash run_inference_llm.sh 2>&1 | tee "$$LOG_FILE" & \
	INFER_PID=$$!; echo "$$INFER_PID" > .run/infer_watch_pid.txt; \
	sleep 0.5; \
	echo "Tailing $$LOG_FILE (infer pid: $$INFER_PID)"; \
	tail --pid=$$INFER_PID -F "$$LOG_FILE"; \
	wait $$INFER_PID; STATUS=$$?; \
	if [ $$STATUS -eq 0 ]; then \
		echo "LLM Inference completed successfully. Output: artifacts/inference_output/"; \
	else \
		echo "LLM Inference failed with exit code $$STATUS"; \
	fi; \
	rm -f .run/infer_watch_pid.txt; \
	exit $$STATUS

infer-interactive: check-bash
	@echo "Running interactive LLM inference REPL (run_interactive_inference.sh)"
	@cd '$(CURDIR_UNIX)' && \
	MAX_NEW_CHARS="$${NEURX_INFER_MAX_NEW_CHARS:-$${NEURX_MAX_TOKENS:-50}}"; \
	TEMPERATURE="$${NEURX_TEMPERATURE:-0.7}"; \
	TOP_K="$${NEURX_TOP_K:-40}"; \
	TOP_P="$${NEURX_TOP_P:-0.9}"; \
	BEAM_SIZE="$${NEURX_BEAM_SIZE:-1}"; \
	CHECKPOINT_PATH="$${NEURX_INFER_CHECKPOINT_PATH:-$${NEURX_CHECKPOINT_PATH:-artifacts/checkpoints/llm_training}}"; \
	TOKENIZER_PATH="$${NEURX_INFER_TOKENIZER_PATH:-$${NEURX_TOKENIZER_PATH:-data/corpus}}"; \
	DEVICE="$${NEURX_INFER_DEVICE:-$${NEURX_DEVICE:-cpu}}"; \
	export NEURX_MAX_TOKENS="$$MAX_NEW_CHARS"; \
	export NEURX_INFER_MAX_NEW_CHARS="$$MAX_NEW_CHARS"; \
	export NEURX_TEMPERATURE="$$TEMPERATURE"; \
	export NEURX_TOP_K="$$TOP_K"; \
	export NEURX_TOP_P="$$TOP_P"; \
	export NEURX_BEAM_SIZE="$$BEAM_SIZE"; \
	export NEURX_INFER_CHECKPOINT="$$CHECKPOINT_PATH"; \
	export NEURX_INFER_CHECKPOINT_PATH="$$CHECKPOINT_PATH"; \
	export NEURX_INFER_TOKENIZER_PATH="$$TOKENIZER_PATH"; \
	export NEURX_INFER_ANSWER_MODE="chat"; \
	export NEURX_CHECKPOINT_PATH="$$CHECKPOINT_PATH"; \
	export NEURX_TOKENIZER_PATH="$$TOKENIZER_PATH"; \
	export NEURX_INFER_DEVICE="$$DEVICE"; \
	export NEURX_DEVICE="$$DEVICE"; \
	bash run_interactive_inference.sh 2>&1; \
	STATUS=$$?; \
	exit $$STATUS

train-jsonl: check-bash
	@echo "Generate train_llm_jsonl.s from data/sample.jsonl and run training"
	@cd '$(CURDIR_UNIX)' && \
	python3 tools/generate_train_llm_from_jsonl.py data/sample.jsonl && \
	NEURX_S_PRETRAIN_STEPS="${STEPS:-500}" NEURX_S_PRETRAIN_WARMUP_STEPS="${WARMUP:-50}" bash run_training.sh 2>&1; \
	STATUS=$$?; \
	if [ $$STATUS -eq 0 ]; then \
		echo "Training completed successfully. Checkpoints: $${NEURX_S_PRETRAIN_OUTPUT_DIR:-artifacts/checkpoints/llm_s_pretrain}"; \
	else \
		echo "Training failed with exit code $$STATUS"; \
	fi; \
	exit $$STATUS

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

install: neurx

test: test-transformer-e2e

test-transformer-e2e: check-bash
	@if ! command -v "$(S_COMPILER)" >/dev/null 2>&1 && [ ! -x "$(S_COMPILER)" ]; then \
		echo "error: S compiler not found or not executable: $(S_COMPILER)"; \
		echo "hint: install the S compiler in /Users/shuwen/shuwen/train/s or pass S_COMPILER=/path/to/s"; \
		exit 1; \
	fi
	@echo "Using S compiler: $$(command -v "$(S_COMPILER)" 2>/dev/null || printf '%s' "$(S_COMPILER)")"
	@mkdir -p build/tests
	@bash tools/build_transformer_e2e_bundle.sh build/tests/test_transformer_model_e2e_bundle.s
	@"$(S_COMPILER)" build/tests/test_transformer_model_e2e_bundle.s build/tests/test_transformer_model_e2e.ir
	@cd "$(S_COMPILER_EMIT_CWD)" && S_SOURCE_ROOT="$(S_COMPILER_EMIT_CWD)" "$(S_COMPILER)" --emit-bin "$(CURDIR_UNIX)/build/tests/test_transformer_model_e2e.ir" "$(CURDIR_UNIX)/build/tests/test_transformer_model_e2e.bin"
	@echo "Running build/tests/test_transformer_model_e2e.bin"
	@"$(CURDIR_UNIX)/build/tests/test_transformer_model_e2e.bin" || true

s-package-index: check-bash
	@echo "Note: S compiler does not support 'mod index' command; skipping package index generation"

code-agent-build: check-bash s-package-index
	@mkdir -p build/bin
	@if ! command -v "$(S_COMPILER)" >/dev/null 2>&1 && [ ! -x "$(S_COMPILER)" ]; then \
		echo "error: S compiler not found: $(S_COMPILER)"; exit 1; \
	fi
	@"$(S_COMPILER)" build agent/code_agent.s -o build/bin/neurx_code_agent
	@echo "built build/bin/neurx_code_agent"

code-agent:
	@TASK_TEXT="$${TASK:-$${NEURX_CODE_AGENT_TASK:-inspect agent/ and summarize the code agent architecture}}"; \
	chmod +x app/service/run_neurx_code_agent.sh 2>/dev/null || true; \
	NEURX_CODE_AGENT_FULL_AUTO="$${NEURX_CODE_AGENT_FULL_AUTO:-1}" \
	bash app/service/run_neurx_code_agent.sh --prompt "$$TASK_TEXT" --repo "$$(pwd)"

s-compile-runtime: neurx

linux: app-linux
windows: app-windows
macos: app-macos
ios: app-ios
android: app-android
harmony: app-harmony

ifeq ($(PLATFORM),windows)

s-package-index: check-bash
	@echo "Note: S compiler does not support 'mod index' command; skipping package index generation"

neurx: check-bash s-package-index
	@"$(BASH)" -lc "cd '$(CURDIR_UNIX)' && \
	if ! command -v '$(S_COMPILER)' >/dev/null 2>&1 && [ ! -x '$(S_COMPILER)' ]; then \
		echo 'error: S compiler not found or not executable: $(S_COMPILER)'; \
		echo 'hint: install the S compiler and ensure '\''s'\'' is on PATH, or pass S_COMPILER=/path/to/s'; \
		exit 1; \
	fi && \
	resolved_s=\"$$(command -v '$(S_COMPILER)' 2>/dev/null || printf '%s' '$(S_COMPILER)')\" && \
	echo \"Using S compiler: $$resolved_s\" && \
	mkdir -p build/ir && \
	for src in $$(find s ops data tensor ad engine nn opt lf train pretrain runtime distributed serving infer infer/vllm model platform compile reasoning workflows app/web -type f -name '*.s' | sort); do \
		[ -e \"$$src\" ] || continue; \
		base=$$(basename \"$$src\" .s); \
		parent=$$(basename \"$$(dirname \"$$src\")\"); \
		module=$${src%.s}; \
		if [ \"$$parent\" = \"$$base\" ]; then \
			module=$$(dirname \"$$src\"); \
		fi; \
		target_dir=$$(dirname \"$$module\"); \
		mkdir -p \"build/ir/$$target_dir\"; \
		echo \"Compiling $$src -> build/ir/$$module.ir\"; \
		if '$(S_COMPILER)' --help 2>&1 | grep -q '<input.s> <output.ir>'; then \
			'$(S_COMPILER)' \"$$src\" \"build/ir/$$module.ir\" || exit 1; \
		else \
			'$(S_COMPILER)' ir \"$$src\" -o \"build/ir/$$module.ir\" || exit 1; \
		fi; \
	done && \
	root_dir=\"$$PWD\" && \
	artifact_dir=\"$$root_dir/build/ir\" && \
	manifest_path=\"$$artifact_dir/manifest.json\" && \
	files=\"$$(cd build/ir && find . -type f -name '*.ir' | sed 's#^\\./##' | sort)\" && \
	{ \
		echo '{'; \
		echo \"  \\\"source_root\\\": \\\"$$root_dir\\\",\"; \
		echo \"  \\\"artifact_root\\\": \\\"$$artifact_dir\\\",\"; \
		echo '  \"ir_files\": ['; \
		first=1; \
		for file in $$files; do \
			if [ $$first -eq 0 ]; then printf ',\\n'; fi; \
			printf '    \"%s\"' \"$$file\"; \
			first=0; \
		done; \
		printf '\\n'; \
		echo '  ]'; \
		echo '}'; \
	} > \"$$manifest_path\" && \
	echo 'runtime manifest: build/ir/manifest.json'"

app-linux app-windows app-macos app-ios app-android app-harmony: check-bash
	@if not exist build\logs mkdir build\logs
	@echo Streaming NeurX runtime logs to build/logs/neurx.log
	@"$(BASH)" -lc "cd '$(CURDIR_UNIX)' && NEURX_APP_TARGET_PLATFORM='$(@:app-%=%)' bash app/run_with_llm.sh 2>&1 | tee build/logs/neurx.log"

clean:
	@if exist build rmdir /s /q build
	@if exist runtime\__pycache__ rmdir /s /q runtime\__pycache__
	@if exist test\__pycache__ rmdir /s /q test\__pycache__
	@if exist checkpoint.pkl del /f /q checkpoint.pkl

else

neurx: check-bash s-package-index
	@if ! command -v "$(S_COMPILER)" >/dev/null 2>&1 && [ ! -x "$(S_COMPILER)" ]; then \
		echo "error: S compiler not found or not executable: $(S_COMPILER)"; \
		echo "hint: install the S compiler and ensure 's' is on PATH, or pass S_COMPILER=/path/to/s"; \
		exit 1; \
	fi
	@resolved_s="$$(command -v "$(S_COMPILER)" 2>/dev/null || printf '%s' "$(S_COMPILER)")"; \
	echo "Using S compiler: $$resolved_s"
	@mkdir -p build/ir
	@ok=0; fail=0; failed_files=""; \
	for src in $$(find s ops data tensor ad engine nn opt lf train pretrain runtime distributed serving infer infer/vllm model platform compile reasoning workflows app/web -type f -name '*.s' 2>/dev/null | sort); do \
	    [ -e "$$src" ] || continue; \
	    base=$$(basename "$$src" .s); \
	    parent=$$(basename "$$(dirname "$$src")"); \
	    module=$${src%.s}; \
	    if [ "$$parent" = "$$base" ]; then \
	        module=$$(dirname "$$src"); \
	    fi; \
	    target_dir=$$(dirname "$$module"); \
	    mkdir -p "build/ir/$$target_dir"; \
		echo "Compiling $$src -> build/ir/$$module.ir"; \
		if "$(S_COMPILER)" ir "$$src" -o "build/ir/$$module.ir" 2>/dev/null; then \
			ok=$$((ok + 1)); \
		else \
			fail=$$((fail + 1)); \
			failed_files="$$failed_files $$src"; \
			echo "  SKIP: $$src (unsupported syntax)"; \
		fi; \
	done; \
	echo ""; \
	echo "=== Compilation summary: $$ok succeeded, $$fail skipped (of $$((ok + fail)) total) ==="; \
	if [ $$fail -gt 0 ]; then \
		echo "Skipped files:"; \
		for f in $$failed_files; do echo "  $$f"; done; \
	fi
	@root_dir="$$(pwd)"; \
	artifact_dir="$$root_dir/build/ir"; \
	manifest_path="$$artifact_dir/manifest.json"; \
	files="$$(cd build/ir && find . -type f -name '*.ir' | sed 's#^\./##' | sort)"; \
	{ \
		echo "{"; \
		echo "  \"source_root\": \"$$root_dir\","; \
		echo "  \"artifact_root\": \"$$artifact_dir\","; \
		echo "  \"ir_files\": ["; \
		first=1; \
		for file in $$files; do \
			if [ $$first -eq 0 ]; then printf ',\n'; fi; \
			printf "    \"%s\"" "$$file"; \
			first=0; \
		done; \
		printf '\n'; \
		echo "  ]"; \
		echo "}"; \
	} > "$$manifest_path"
	@echo "runtime manifest: build/ir/manifest.json"

app-linux app-windows app-macos app-ios app-android app-harmony: check-bash
	@mkdir -p build/logs
	@echo "Streaming NeurX runtime logs to build/logs/neurx.log"
	@NEURX_APP_TARGET_PLATFORM="$(@:app-%=%)" $(BASH) app/run_with_llm.sh 2>&1 | tee build/logs/neurx.log

clean:
	@rm -rf build runtime/__pycache__ test/__pycache__ checkpoint.pkl

# ── Platform install targets ─────────────────────────────────────────────────
install-robot:
	@bash install/robot/install.sh

install-auto:
	@bash install/auto/install.sh

install-desktop:
	@bash install/desktop/install.sh

install-tablet:
	@bash install/tablet/install.sh

install-mobile-android:
	@bash install/mobile/install-android.sh

install-mobile-ios:
	@bash install/mobile/install-ios.sh

endif
