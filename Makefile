.PHONY: help train infer pretrain pretrain-watch chat check-bash shard split test-tensor-core test-tensor-core-bin

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
	@echo "  make infer"
	@echo "  make chat"
	@echo "  make shard"
	@echo "  make split"
	@echo "  make test-tensor-core"
	@echo "  make test-tensor-core-bin"

train: check-bash
	@echo "Running NeurX 1T MoE GPT-style Production Pre-training"
	@cd '$(CURDIR_UNIX)' && S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' MODEL_SIZE=1t NEURX_ALLOW_FULL_1T_LOCAL=1 bash script/run_gpt_large_pretrain.sh 2>&1



infer: check-bash
	@echo "Running NeurX inference"
	@cd '$(CURDIR_UNIX)' && bash script/demo_complete_pipeline.sh 2>&1

pretrain: check-bash
	@echo "Running GPT-Large production pre-training (alias for make train)"
	@cd '$(CURDIR_UNIX)' && S_COMPILER='$(S_COMPILER)' S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' MODEL_SIZE=1t NEURX_ALLOW_FULL_1T_LOCAL=1 bash script/run_gpt_large_pretrain.sh 2>&1

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

test-tensor-core: check-bash
	@echo "Compiling NeurX tensor core smoke tests"
	@cd '$(CURDIR_UNIX)' && mkdir -p build/tests && S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' '$(S_COMPILER)' tensor/core.s build/tests/tensor_core.ir && S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' '$(S_COMPILER)' test/test_tensor_core.s build/tests/test_tensor_core.ir && S_SOURCE_ROOT='$(S_COMPILER_EMIT_CWD)' '$(S_COMPILER)' test/test_tensor_core_runtime.s build/tests/test_tensor_core_runtime.ir

test-tensor-core-bin: test-tensor-core
	@echo "Running NeurX tensor core emitted-binary smoke tests"
	@cd '$(CURDIR_UNIX)' && chmod +x script/link_s_ir_module.sh && script/link_s_ir_module.sh build/tests/tensor_core.ir build/tests/test_tensor_core.ir neurx.tensor.core build/tests/test_tensor_core_linked.ir && (cd '$(S_COMPILER_EMIT_CWD)' && '$(S_COMPILER)' --emit-bin '$(CURDIR_UNIX)'/build/tests/test_tensor_core_linked.ir '$(CURDIR_UNIX)'/build/tests/test_tensor_core.bin) && build/tests/test_tensor_core.bin && (cd '$(S_COMPILER_EMIT_CWD)' && '$(S_COMPILER)' --emit-bin '$(CURDIR_UNIX)'/build/tests/test_tensor_core_runtime.ir '$(CURDIR_UNIX)'/build/tests/test_tensor_core_runtime.bin) && build/tests/test_tensor_core_runtime.bin



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
