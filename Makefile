.PHONY: help train infer pretrain pretrain-watch train-7b train-70b chat check-bash shard split

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
	@echo "  make train"
	@echo "  make train-70b"
	@echo "  make infer"
	@echo "  make chat"
	@echo "  make shard"
	@echo "  make split"

train: check-bash
	@echo "Running NeurX GPT-Large Production Pre-training"
	@cd '$(CURDIR_UNIX)' && NEURX_PRETRAIN_GENERATE_ONLY=1 bash script/run_gpt_large_pretrain.sh 2>&1 && bash production_deployment/launch_plan.sh 2>&1

train-7b: check-bash
	@echo "Running NeurX 7B training from configs/7b_training.json"
	@cd '$(CURDIR_UNIX)' && bash LAUNCH_7B_TRAINING.sh 2>&1

train-70b: check-bash
	@echo "Running NeurX 70B training from configs/70b_training.json"
	@cd '$(CURDIR_UNIX)' && bash LAUNCH_70B_TRAINING.sh 2>&1



infer: check-bash
	@echo "Running NeurX inference"
	@cd '$(CURDIR_UNIX)' && bash script/demo_complete_pipeline.sh 2>&1

pretrain: check-bash
	@echo "Running GPT-Large production pre-training (alias for make train)"
	@cd '$(CURDIR_UNIX)' && NEURX_PRETRAIN_GENERATE_ONLY=1 bash script/run_gpt_large_pretrain.sh 2>&1 && bash production_deployment/launch_plan.sh 2>&1

pretrain-watch: check-bash
	@echo "Running GPT-Large pre-training with live log monitoring"
	@cd '$(CURDIR_UNIX)' && mkdir -p artifacts/logs && NEURX_PRETRAIN_GENERATE_ONLY=1 bash script/run_gpt_large_pretrain.sh 2>&1 | tee artifacts/logs/gpt_large_pretrain_watch.log && bash production_deployment/launch_plan.sh 2>&1 | tee -a artifacts/logs/gpt_large_pretrain_watch.log

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
