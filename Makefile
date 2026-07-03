.PHONY: help train infer pretrain pretrain-watch chat check-bash shard split

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
	@echo "  make print-data-info"

.PHONY: print-data-info
print-data-info: check-bash
	@bash script/print_training_data_info.sh

train: check-bash print-data-info
	@echo "Running NeurX 1T MoE GPT-style Production Pre-training"
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
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' MODEL_SIZE=1t NEURX_ALLOW_FULL_1T_LOCAL=1 bash script/run_gpt_large_pretrain.sh 2>&1



infer: check-bash
	@echo "Running NeurX inference"
	@cd '$(CURDIR_UNIX)' && bash script/demo_complete_pipeline.sh 2>&1

pretrain: check-bash
	@echo "Running GPT-Large production pre-training (alias for make train)"
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
		S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' MODEL_SIZE=1t NEURX_ALLOW_FULL_1T_LOCAL=1 bash script/run_gpt_large_pretrain.sh 2>&1

pretrain-watch: check-bash
	@echo "Running GPT-Large pre-training with live log monitoring"
	@cd '$(CURDIR_UNIX)' && mkdir -p artifacts/logs && S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' MODEL_SIZE=1t NEURX_ALLOW_FULL_1T_LOCAL=1 bash script/run_gpt_large_pretrain.sh 2>&1 | tee artifacts/logs/gpt_large_pretrain_watch.log

chat: check-bash
	@cd '$(CURDIR_UNIX)' && bash script/chat.sh



shard: check-bash
	@echo "Running industrial data pipeline: clean + dedup + stratified sample + reshard"
	@cd '$(CURDIR_UNIX)' && python3 script/data_pipeline_v2.py --apply 2>&1

split: check-bash
	@echo "Splitting training data into train/val/test"
	@cd '$(CURDIR_UNIX)' && bash script/split_industrial_dataset.sh 2>&1



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
