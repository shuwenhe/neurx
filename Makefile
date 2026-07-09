.PHONY: help train infer pretrain posttrain orpo pretrain-watch watch-auto-commit-push chat check-bash shard split logs logs-tail \
	build-data-scripts clean-s shard-s data-pipeline-s verify-dataset-s build-industrial-ops industrial-ops \
	toolchain-s analyze-dataset-s build-s-ir-runner run-training-s train-and-infer-s run-inference-s run-s-pretrain-s \
	split-data-s run-training-pipeline-s quick-start-s run-interactive-inference-s run-small-model-training-s run-sft-training-s \
	run-lora-sft-training-s
	verify-setup-s quick-test-s quickstart-s verify-training-pipeline-s monitor-training-s build-linux-s build-macos-s run-large-pretrain-s \
	run-train-compiled-s run-train-large-model-s run-train-model-ir-s run-with-logs-s verify-framework-s verify-inference-pipeline-s test-build-s test-smart-inference-s \
	compile-all-components-s integration-s complete-training-cycle-s verify-transformer-implementation-s cluster-launch-s setup-production-deployment-s \
	run-end-to-end-verification-s run-integration-tests-s minimal-diagnostic-s diagnose-file-creation-s diagnose-tool-registration-s diagnose-autoscroll-s

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

CURDIR_UNIX := $(subst \,/,$(CURDIR))
S_REPO_ROOT := $(CURDIR_UNIX)/../../../s
S_COMPILER_LOCAL ?= $(S_REPO_ROOT)/.local/bin/s
S_COMPILER_BIN ?= $(S_REPO_ROOT)/bin/s
S_COMPILER ?= $(firstword $(wildcard $(S_COMPILER_BIN) $(S_COMPILER_LOCAL)) $(shell command -v s 2>/dev/null) s)
S_COMPILER_EMIT_CWD ?= $(S_REPO_ROOT)
S_RUNNER_SRC := $(CURDIR_UNIX)/tools/s_ir_runner.s
S_RUNNER_BUILD_DIR := $(CURDIR_UNIX)/artifacts/build/s_runner
S_RUNNER_BIN := $(S_RUNNER_BUILD_DIR)/s_ir_runner
LOG_DIR := $(CURDIR_UNIX)/artifacts/logs
INDUSTRIAL_MANIFEST ?= $(CURDIR_UNIX)/data/training_data_shards/manifest.txt
INDUSTRIAL_CHECKPOINT_DIR ?= $(CURDIR_UNIX)/artifacts/checkpoints/industrial_1t
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


help:
	@echo "  make train"
	@echo "  make infer"
	@echo "  make posttrain"
	@echo "  make orpo"
	@echo "  make run-sft-training-s"
	@echo "  make run-lora-sft-training-s"
	@echo "  make watch-auto-commit-push"
	@echo "  make chat"



train: pretrain



infer: check-bash
	mkdir -p $(LOG_DIR); \
	echo "Running NeurX inference from real checkpoint"; \
	cd '$(CURDIR_UNIX)' && bash script/run_inference_llm.sh 2>&1 | tee -a $(LOG_DIR)/infer_$(shell date +%Y%m%d_%H%M%S).log

pretrain: check-bash
	@echo "Running NeurX large-model production pre-training (alias for make train)"
	@cd '$(CURDIR_UNIX)' && \
		echo "Training data root: $(PRETRAIN_DATA_ROOT)" && \
		echo "  raw      : $(PRETRAIN_RAW_DIR)" && \
		echo "  cleaned  : $(PRETRAIN_CLEANED_FILE)" && \
		echo "  train    : $(PRETRAIN_TRAIN_SPLIT)" && \
		echo "  val      : $(PRETRAIN_VAL_SPLIT)" && \
		echo "  test     : $(PRETRAIN_TEST_SPLIT)" && \
		echo "  shard dir: $(PRETRAIN_SHARD_DIR)" && \
		echo "  manifest : $(PRETRAIN_MANIFEST)" && \
			if [ -s '$(PRETRAIN_CLEANED_FILE)' ] && [ ! -s '$(PRETRAIN_TRAIN_SPLIT)' ]; then \
				echo "Existing cleaned file detected; resuming split/manifest generation"; \
				echo "Resolved command:"; \
				echo "  NEURX_RESUME_CLEANED=1 bash script/clean_data.sh"; \
				NEURX_RESUME_CLEANED=1 bash script/clean_data.sh; \
			else \
				echo "Resolved command:"; \
				echo "  bash script/clean_data.sh"; \
				bash script/clean_data.sh; \
			fi && \
			echo "Resolved command:"; \
			echo "  bash script/generate_shards.sh"; \
			bash script/generate_shards.sh; \
			echo "Resolved command:"; \
			echo "  NEURX_PRETRAIN_MANIFEST='$(PRETRAIN_MANIFEST)' NEURX_TRAIN_SPLIT_PATH='$(PRETRAIN_TRAIN_SPLIT)' NEURX_VAL_SPLIT_PATH='$(PRETRAIN_VAL_SPLIT)' NEURX_TEST_SPLIT_PATH='$(PRETRAIN_TEST_SPLIT)' NEURX_PRETRAIN_DATA_DIR='$(PRETRAIN_DATA_ROOT)' S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='$(CURDIR_UNIX)' MODEL_SIZE=llm NEURX_ALLOW_FULL_1T_LOCAL=1 bash script/run_large_pretrain.sh"; \
			NEURX_PRETRAIN_MANIFEST='$(PRETRAIN_MANIFEST)' \
			NEURX_TRAIN_SPLIT_PATH='$(PRETRAIN_TRAIN_SPLIT)' \
			NEURX_VAL_SPLIT_PATH='$(PRETRAIN_VAL_SPLIT)' \
			NEURX_TEST_SPLIT_PATH='$(PRETRAIN_TEST_SPLIT)' \
		NEURX_PRETRAIN_DATA_DIR='$(PRETRAIN_DATA_ROOT)' \
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='$(CURDIR_UNIX)/..' MODEL_SIZE=llm NEURX_ALLOW_FULL_1T_LOCAL=1 bash script/run_large_pretrain.sh 2>&1


posttrain: check-bash
	@echo "Building NeurX posttrain entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/posttrain
	@if ! command -v "$(S_COMPILER)" >/dev/null 2>&1; then \
		echo "Error: S compiler not found at $(S_COMPILER)"; \
		echo "Set S_COMPILER or S_COMPILER_EMIT_CWD environment variable"; \
		exit 1; \
	fi
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(CURDIR_UNIX)' \
		$(S_COMPILER) ir 'posttrain/posttrain.s' -o '$(CURDIR_UNIX)/artifacts/build/posttrain/posttrain.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/posttrain/posttrain.ir'
	@echo "✓ posttrain entry compiled to S IR"

orpo: check-bash
	@echo "Building NeurX ORPO alignment entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/orpo
	@if ! command -v "$(S_COMPILER)" >/dev/null 2>&1; then \
		echo "Error: S compiler not found at $(S_COMPILER)"; \
		echo "Set S_COMPILER or S_COMPILER_EMIT_CWD environment variable"; \
		exit 1; \
	fi
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(CURDIR_UNIX)' \
		$(S_COMPILER) ir 'posttrain/alignment/orpo_trainer.s' -o '$(CURDIR_UNIX)/artifacts/build/orpo/orpo_trainer.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/orpo/orpo_trainer.ir'
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(CURDIR_UNIX)' \
		$(S_COMPILER) ir 'posttrain/alignment/orpo_examples.s' -o '$(CURDIR_UNIX)/artifacts/build/orpo/orpo_examples.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/orpo/orpo_examples.ir'
	@echo "✓ ORPO trainer/examples compiled to S IR"

pretrain-watch: check-bash
	@echo "Running NeurX large-model pre-training with live log monitoring"
	@cd '$(CURDIR_UNIX)' && mkdir -p artifacts/logs && S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='$(CURDIR_UNIX)/..' MODEL_SIZE=llm NEURX_ALLOW_FULL_1T_LOCAL=1 bash script/run_large_pretrain.sh 2>&1 | tee artifacts/logs/model_large_pretrain_watch.log

watch-auto-commit-push: check-bash
	@echo "Starting local save-to-commit-and-push watcher on branch main"
	@cd '$(CURDIR_UNIX)' && bash tools/watch-auto-commit-push.sh

chat: check-bash
	mkdir -p $(LOG_DIR); \
	echo "Running NeurX interactive chat from real checkpoint"; \
	cd '$(CURDIR_UNIX)' && bash script/chat.sh 2>&1 | tee -a $(LOG_DIR)/chat_$(shell date +%Y%m%d_%H%M%S).log



shard: check-bash
	@echo "Running industrial data pipeline: clean + dedup + stratified sample + reshard"
	@cd '$(CURDIR_UNIX)' && python3 script/data_pipeline_v2.py --apply 2>&1

split: check-bash
	@echo "Splitting training data into train/val/test"
	@cd '$(CURDIR_UNIX)' && bash script/split_industrial_dataset.sh 2>&1

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
		$(S_COMPILER) ir 'script/split_data.s' -o '$(CURDIR_UNIX)/artifacts/build/split_data/split_data.ir' 2>&1 && \
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
		$(S_COMPILER) ir 'script/run_training_pipeline.s' -o '$(CURDIR_UNIX)/artifacts/build/training_pipeline/run_training_pipeline.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/quick_start.s' -o '$(CURDIR_UNIX)/artifacts/build/quick_start/quick_start.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/quick_start/quick_start.ir'
	@echo "Running S quick start entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/quick_start/quick_start.ir' 2>&1 | tee -a $(LOG_DIR)/quick_start_$(shell date +%Y%m%d_%H%M%S).log

run-interactive-inference-s: check-bash
	@echo "Building S interactive inference entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/interactive_inference
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/run_interactive_inference.s' -o '$(CURDIR_UNIX)/artifacts/build/interactive_inference/run_interactive_inference.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/interactive_inference/run_interactive_inference.ir'
	@echo "Running S interactive inference entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/interactive_inference/run_interactive_inference.ir' 2>&1 | tee -a $(LOG_DIR)/run_interactive_inference_$(shell date +%Y%m%d_%H%M%S).log

run-small-model-training-s: check-bash
	@echo "Building S small model training entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/small_model_training
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/run_small_model_training.s' -o '$(CURDIR_UNIX)/artifacts/build/small_model_training/run_small_model_training.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/small_model_training/run_small_model_training.ir'
	@echo "Running S small model training entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/small_model_training/run_small_model_training.ir' 2>&1 | tee -a $(LOG_DIR)/run_small_model_training_$(shell date +%Y%m%d_%H%M%S).log

run-sft-training-s: check-bash
	@echo "Building SFT training entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/sft_training
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/run_sft_training.s' -o '$(CURDIR_UNIX)/artifacts/build/sft_training/run_sft_training.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/sft_training/run_sft_training.ir'
	@echo "Running SFT training entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/sft_training/run_sft_training.ir' 2>&1 | tee -a $(LOG_DIR)/run_sft_training_$(shell date +%Y%m%d_%H%M%S).log

run-lora-sft-training-s: check-bash
	@echo "Building LoRA SFT training entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/lora_sft_training
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='$(CURDIR_UNIX)' \
		/home/shuwen/s/bin/s ir 'script/run_lora_sft_training.s' -o '$(CURDIR_UNIX)/artifacts/build/lora_sft_training/run_lora_sft_training.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/lora_sft_training/run_lora_sft_training.ir'
	@echo "Running LoRA SFT training entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/lora_sft_training/run_lora_sft_training.ir' 2>&1 | tee -a $(LOG_DIR)/run_lora_sft_training_$(shell date +%Y%m%d_%H%M%S).log

verify-setup-s: check-bash
	@echo "Building setup verification entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/verify_setup
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/verify_setup.s' -o '$(CURDIR_UNIX)/artifacts/build/verify_setup/verify_setup.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/quick_test.s' -o '$(CURDIR_UNIX)/artifacts/build/quick_test/quick_test.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/quick_test/quick_test.ir'
	@echo "Running quick test entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/quick_test/quick_test.ir' 2>&1 | tee -a $(LOG_DIR)/quick_test_$(shell date +%Y%m%d_%H%M%S).log

quickstart-s: check-bash
	@echo "Building quickstart entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/quickstart
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/quickstart.s' -o '$(CURDIR_UNIX)/artifacts/build/quickstart/quickstart.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/verify_training_pipeline.s' -o '$(CURDIR_UNIX)/artifacts/build/verify_training_pipeline/verify_training_pipeline.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/monitor_training.s' -o '$(CURDIR_UNIX)/artifacts/build/monitor_training/monitor_training.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/build-linux.s' -o '$(CURDIR_UNIX)/artifacts/build/build_linux/build_linux.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/build-macos.s' -o '$(CURDIR_UNIX)/artifacts/build/build_macos/build_macos.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/run_large_pretrain.s' -o '$(CURDIR_UNIX)/artifacts/build/run_large_pretrain/run_large_pretrain.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/run_large_pretrain/run_large_pretrain.ir'
	@echo "Running large pretrain status entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/run_large_pretrain/run_large_pretrain.ir' 2>&1 | tee -a $(LOG_DIR)/run_large_pretrain_$(shell date +%Y%m%d_%H%M%S).log

run-train-compiled-s: check-bash
	@echo "Building compiled train status entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/run_train_compiled
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/run_train_compiled.s' -o '$(CURDIR_UNIX)/artifacts/build/run_train_compiled/run_train_compiled.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/run_train_large_model.s' -o '$(CURDIR_UNIX)/artifacts/build/run_train_large_model/run_train_large_model.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/run_train_model_ir.s' -o '$(CURDIR_UNIX)/artifacts/build/run_train_model_ir/run_train_model_ir.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/run_with_logs.s' -o '$(CURDIR_UNIX)/artifacts/build/run_with_logs/run_with_logs.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/verify_framework.s' -o '$(CURDIR_UNIX)/artifacts/build/verify_framework/verify_framework.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/verify_inference_pipeline.s' -o '$(CURDIR_UNIX)/artifacts/build/verify_inference_pipeline/verify_inference_pipeline.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/test_build.s' -o '$(CURDIR_UNIX)/artifacts/build/test_build/test_build.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/test_smart_inference.s' -o '$(CURDIR_UNIX)/artifacts/build/test_smart_inference/test_smart_inference.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/test_smart_inference/test_smart_inference.ir'
	@echo "Running smart inference test entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/test_smart_inference/test_smart_inference.ir' 2>&1 | tee -a $(LOG_DIR)/test_smart_inference_$(shell date +%Y%m%d_%H%M%S).log


# ============================================================================
# S Language Data Processing Scripts (NEW)
# ============================================================================

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
	@echo "  Source: script/data_pipeline.s"
	@echo "  This is a complete S-language implementation ready for compilation"
	@echo "  To compile: $(S_COMPILER) script/data_pipeline.s -o artifacts/build/data_pipeline/data_pipeline"
	@echo "✓ S implementation available at script/data_pipeline.s"

clean-s: 
	@echo "Building NeurX data cleaning entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/data_scripts
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/scripts.s' -o '$(CURDIR_UNIX)/artifacts/build/data_scripts/scripts.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/scripts.s' -o '$(CURDIR_UNIX)/artifacts/build/data_scripts/scripts.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/data_scripts/scripts.ir'
	@echo "Running NeurX data sharding entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_HOME='$(CURDIR_UNIX)' NEURX_SCRIPTS_CMD=shard \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/data_scripts/scripts.ir' 2>&1 | tee -a $(LOG_DIR)/shard_$(shell date +%Y%m%d_%H%M%S).log

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
		$(S_COMPILER) ir 'dataset/verify_dataset.s' -o '$(CURDIR_UNIX)/artifacts/build/dataset_verify/dataset_verify.ir' 2>&1 && \
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
		$(S_COMPILER) script/industrial_ops_runner.s $(INDUSTRIAL_OPS_IR) 2>&1
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
	@cd '$(CURDIR_UNIX)' && \
		'$(S_COMPILER)' ir '$(S_RUNNER_SRC)' -o '$(S_RUNNER_BUILD_DIR)/s_ir_runner.ir' 2>&1 && \
		printf '%s\n' \
			'#!/usr/bin/env bash' \
			'set -euo pipefail' \
			'' \
			'if [ "$$#" -lt 1 ] || [ "$$#" -gt 2 ]; then' \
			'    echo "usage: s_ir_runner <input.ir> [entry]" >&2' \
			'    exit 2' \
			'fi' \
			'' \
			'S_IR_RUNNER_INPUT="$$1" S_IR_RUNNER_ENTRY="$${2:-main}" exec '\''$(S_COMPILER)'\'' run '\''$(S_RUNNER_SRC)'\''' > '$(S_RUNNER_BIN)' && \
		chmod +x '$(S_RUNNER_BIN)' && \
		test -f '$(S_RUNNER_BIN)'

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
		$(S_COMPILER) ir 'script/s_toolchain.s' -o 'artifacts/build/toolchain/toolchain.ir' 2>&1
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
		$(S_COMPILER) ir 'dataset/run_analyze.s' -o 'artifacts/build/dataset_analyze/run_analyze.ir' 2>&1
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
		$(S_COMPILER) ir 'script/run_llm_training.s' -o 'artifacts/build/train_orchestrator/run_llm_training.ir' 2>&1
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
		$(S_COMPILER) ir 'script/run_train_and_infer.s' -o 'artifacts/build/train_and_infer/run_train_and_infer.ir' 2>&1
	@$(MAKE) build-s-ir-runner
	@echo "Running S train+infer orchestrator..."
	@cd '$(CURDIR_UNIX)' && \
		MODE='$(MODE)' NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/train_and_infer/run_train_and_infer.ir' 2>&1 | tee -a $(LOG_DIR)/train_and_infer_$(shell date +%Y%m%d_%H%M%S).log

run-inference-s: check-bash
	@echo "Building S inference orchestrator..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/inference_orchestrator
	@mkdir -p $(LOG_DIR)
	@if [ ! -f "$(S_COMPILER)" ]; then \
		echo "Error: S compiler not found at $(S_COMPILER)"; \
		echo "Set S_COMPILER or S_COMPILER_EMIT_CWD environment variable"; \
		exit 1; \
	fi
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'script/run_inference_llm.s' -o 'artifacts/build/inference_orchestrator/run_inference_llm.ir' 2>&1
	@$(MAKE) build-s-ir-runner
	@echo "Running S inference orchestrator..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/inference_orchestrator/run_inference_llm.ir' 2>&1 | tee -a $(LOG_DIR)/run_inference_$(shell date +%Y%m%d_%H%M%S).log

run-s-pretrain-s: check-bash
	@echo "Building S pretrain orchestrator..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/pretrain_orchestrator
	@mkdir -p $(LOG_DIR)
	@if [ ! -f "$(S_COMPILER)" ]; then \
		echo "Error: S compiler not found at $(S_COMPILER)"; \
		echo "Set S_COMPILER or S_COMPILER_EMIT_CWD environment variable"; \
		exit 1; \
	fi
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' \
		$(S_COMPILER) ir 'script/run_s_pretrain.s' -o 'artifacts/build/pretrain_orchestrator/run_s_pretrain.ir' 2>&1
	@if [ ! -x "$(S_RUNNER_BIN)" ]; then \
		$(MAKE) build-s-ir-runner; \
	fi
	@echo "Running S pretrain orchestrator..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/pretrain_orchestrator/run_s_pretrain.ir' 2>&1 | tee -a $(LOG_DIR)/run_s_pretrain_$(shell date +%Y%m%d_%H%M%S).log

compile-all-components-s: check-bash
	@echo "Building full compilation/test status entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/compile_all_components
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/compile_all_components.s' -o '$(CURDIR_UNIX)/artifacts/build/compile_all_components/compile_all_components.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/integration.s' -o '$(CURDIR_UNIX)/artifacts/build/integration/integration.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/complete_training_cycle.s' -o '$(CURDIR_UNIX)/artifacts/build/complete_training_cycle/complete_training_cycle.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/verify_transformer_implementation.s' -o '$(CURDIR_UNIX)/artifacts/build/verify_transformer_implementation/verify_transformer_implementation.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/cluster_launch.s' -o '$(CURDIR_UNIX)/artifacts/build/cluster_launch/cluster_launch.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/setup_production_deployment.s' -o '$(CURDIR_UNIX)/artifacts/build/setup_production_deployment/setup_production_deployment.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/setup_production_deployment/setup_production_deployment.ir'
	@echo "Running production deployment status entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/setup_production_deployment/setup_production_deployment.ir' 2>&1 | tee -a $(LOG_DIR)/setup_production_deployment_$(shell date +%Y%m%d_%H%M%S).log

run-end-to-end-verification-s: check-bash
	@echo "Building end-to-end verification status entry..."
	@mkdir -p $(CURDIR_UNIX)/artifacts/build/run_end_to_end_verification
	@mkdir -p $(LOG_DIR)
	@cd '$(CURDIR_UNIX)' && \
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/run_end_to_end_verification.s' -o '$(CURDIR_UNIX)/artifacts/build/run_end_to_end_verification/run_end_to_end_verification.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/run_integration_tests.s' -o '$(CURDIR_UNIX)/artifacts/build/run_integration_tests/run_integration_tests.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/minimal_diagnostic.s' -o '$(CURDIR_UNIX)/artifacts/build/minimal_diagnostic/minimal_diagnostic.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/diagnose_file_creation.s' -o '$(CURDIR_UNIX)/artifacts/build/diagnose_file_creation/diagnose_file_creation.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/diagnose_tool_registration.s' -o '$(CURDIR_UNIX)/artifacts/build/diagnose_tool_registration/diagnose_tool_registration.ir' 2>&1 && \
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
		S_COMPILER='/home/shuwen/s/bin/s' S_SOURCE_ROOT='/home/shuwen/s' \
		/home/shuwen/s/bin/s ir 'script/diagnose_autoscroll.s' -o '$(CURDIR_UNIX)/artifacts/build/diagnose_autoscroll/diagnose_autoscroll.ir' 2>&1 && \
		test -f '$(CURDIR_UNIX)/artifacts/build/diagnose_autoscroll/diagnose_autoscroll.ir'
	@echo "Running autoscroll diagnostic status entry..."
	@cd '$(CURDIR_UNIX)' && \
		NEURX_ROOT='$(CURDIR_UNIX)' \
		'$(S_RUNNER_BIN)' '$(CURDIR_UNIX)/artifacts/build/diagnose_autoscroll/diagnose_autoscroll.ir' 2>&1 | tee -a $(LOG_DIR)/diagnose_autoscroll_$(shell date +%Y%m%d_%H%M%S).log


# Logs helper targets
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
