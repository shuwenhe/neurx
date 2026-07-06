.PHONY: help train infer pretrain pretrain-watch chat check-bash shard split logs logs-tail

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
S_REPO_ROOT := $(CURDIR_UNIX)/../s
S_COMPILER_LOCAL ?= $(S_REPO_ROOT)/.local/bin/s
S_COMPILER_BIN ?= $(S_REPO_ROOT)/bin/s
S_COMPILER ?= $(firstword $(wildcard $(S_COMPILER_LOCAL) $(S_COMPILER_BIN)) $(shell command -v s 2>/dev/null) s)
S_COMPILER_EMIT_CWD ?= $(S_REPO_ROOT)
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
PRETRAIN_DATA_ROOT := $(CURDIR_UNIX)/data/pretrain_dataset
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
	@echo "  make chat"
	@echo "  make shard"
	@echo "  make split"



train: check-bash
	mkdir -p $(LOG_DIR); \
	cd '$(CURDIR_UNIX)' && ( \
	set -e; \
	if [ "$(MODE)" = "industrial" ]; then \
		echo "Running Industrial 1T GPT training pipeline (MODE=industrial)"; \
		mkdir -p artifacts/build/industrial_1t; \
		NEURX_1T_MANIFEST='$(CURDIR_UNIX)/data/training_data_shards/manifest.txt' NEURX_1T_CHECKPOINT_DIR='$(CURDIR_UNIX)/artifacts/checkpoints/industrial_1t' NEURX_1T_BATCH_SIZE=16 NEURX_1T_SEQ_LEN=512 NEURX_1T_VOCAB_SIZE=32000 NEURX_1T_PARAM_COUNT=4096 NEURX_1T_TOTAL_STEPS=1000 $(S_COMPILER) training/industrial_1t_training.s artifacts/build/industrial_1t/industrial_1t_training.ir 2>&1; \
		cd '$(S_COMPILER_EMIT_CWD)'; \
		$(S_COMPILER) --emit-bin '$(CURDIR_UNIX)/artifacts/build/industrial_1t/industrial_1t_training.ir' '$(CURDIR_UNIX)/artifacts/build/industrial_1t/industrial_1t_training.bin' 2>&1; \
	else \
		echo "Running NeurX 1T MoE GPT-style Production Pre-training"; \
		echo "Training data root: $(PRETRAIN_DATA_ROOT)"; \
		echo "  raw      : $(PRETRAIN_RAW_DIR)"; \
		echo "  cleaned  : $(PRETRAIN_CLEANED_FILE)"; \
		echo "  train    : $(PRETRAIN_TRAIN_SPLIT)"; \
		echo "  val      : $(PRETRAIN_VAL_SPLIT)"; \
		echo "  test     : $(PRETRAIN_TEST_SPLIT)"; \
		echo "  shard dir: $(PRETRAIN_SHARD_DIR)"; \
		echo "  manifest : $(PRETRAIN_MANIFEST)"; \
		if [ "$(SKIP_CLEAN)" = "1" ]; then \
			echo "SKIP_CLEAN=1, skipping data clean and shard generation"; \
		else \
			bash clean_data.sh; \
			bash generate_shards.sh; \
		fi; \
<<<<<<< HEAD
		NEURX_PRETRAIN_MANIFEST='$(PRETRAIN_MANIFEST)' NEURX_TRAIN_SPLIT_PATH='$(PRETRAIN_TRAIN_SPLIT)' NEURX_VAL_SPLIT_PATH='$(PRETRAIN_VAL_SPLIT)' NEURX_TEST_SPLIT_PATH='$(PRETRAIN_TEST_SPLIT)' NEURX_PRETRAIN_DATA_DIR='$(PRETRAIN_DATA_ROOT)' S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' MODEL_SIZE=1t NEURX_ALLOW_FULL_1T_LOCAL=1 bash script/run_model_large_pretrain.sh 2>&1; \
	fi
=======
		NEURX_PRETRAIN_MANIFEST='$(PRETRAIN_MANIFEST)' NEURX_TRAIN_SPLIT_PATH='$(PRETRAIN_TRAIN_SPLIT)' NEURX_VAL_SPLIT_PATH='$(PRETRAIN_VAL_SPLIT)' NEURX_TEST_SPLIT_PATH='$(PRETRAIN_TEST_SPLIT)' NEURX_PRETRAIN_DATA_DIR='$(PRETRAIN_DATA_ROOT)' S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' MODEL_SIZE=1t NEURX_ALLOW_FULL_1T_LOCAL=1 bash script/run_gpt_large_pretrain.sh 2>&1; \
	fi; \
	) 2>&1 | tee -a $(LOG_DIR)/train_$(shell date +%Y%m%d_%H%M%S).log
>>>>>>> 9e3f147 (fix:neurx)



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
		bash clean_data.sh && \
		bash generate_shards.sh && \
		NEURX_PRETRAIN_MANIFEST='$(PRETRAIN_MANIFEST)' \
		NEURX_TRAIN_SPLIT_PATH='$(PRETRAIN_TRAIN_SPLIT)' \
		NEURX_VAL_SPLIT_PATH='$(PRETRAIN_VAL_SPLIT)' \
		NEURX_TEST_SPLIT_PATH='$(PRETRAIN_TEST_SPLIT)' \
		NEURX_PRETRAIN_DATA_DIR='$(PRETRAIN_DATA_ROOT)' \
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' MODEL_SIZE=1t NEURX_ALLOW_FULL_1T_LOCAL=1 bash script/run_model_large_pretrain.sh 2>&1


pretrain-watch: check-bash
	@echo "Running NeurX large-model pre-training with live log monitoring"
	@cd '$(CURDIR_UNIX)' && mkdir -p artifacts/logs && S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' MODEL_SIZE=1t NEURX_ALLOW_FULL_1T_LOCAL=1 bash script/run_model_large_pretrain.sh 2>&1 | tee artifacts/logs/model_large_pretrain_watch.log

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
