.PHONY: quality-gate release-check build-command-contracts build-commands test-commands worker controller benchmark

COMMAND_IR_DIR := $(CURDIR_UNIX)/artifacts/build/commands
COMMAND_BIN_DIR := $(CURDIR_UNIX)/artifacts/bin

quality-gate: check-architecture

release-check: quality-gate test-benchmark-schema
	@test -f benchmarks/result.schema.json
	@echo "Release checks passed."

build-command-contracts:
	@mkdir -p '$(COMMAND_IR_DIR)'
	@$(S_SEED_COMPILER) src/runtime/command/command.s '$(COMMAND_IR_DIR)/command_runtime.ir'
	@$(S_SEED_COMPILER) src/training/api/contracts.s '$(COMMAND_IR_DIR)/training_api.ir'
	@$(S_SEED_COMPILER) src/serving/api/contracts.s '$(COMMAND_IR_DIR)/serving_api.ir'
	@$(S_SEED_COMPILER) cmd/train/main.s '$(COMMAND_IR_DIR)/train_main.ir'
	@$(S_SEED_COMPILER) cmd/worker/main.s '$(COMMAND_IR_DIR)/worker_main.ir'
	@$(S_SEED_COMPILER) cmd/controller/main.s '$(COMMAND_IR_DIR)/controller_main.ir'
	@$(S_SEED_COMPILER) cmd/serve/main.s '$(COMMAND_IR_DIR)/serve_main.ir'
	@$(S_SEED_COMPILER) cmd/benchmark/main.s '$(COMMAND_IR_DIR)/benchmark_main.ir'
	@echo "Command entrypoint compilation passed."

build-commands: build-command-contracts
	@mkdir -p '$(COMMAND_BIN_DIR)'
	@$(S_SEED_COMPILER) --link-ir '$(COMMAND_IR_DIR)/train.ir' '$(COMMAND_IR_DIR)/command_runtime.ir' '$(COMMAND_IR_DIR)/training_api.ir' '$(COMMAND_IR_DIR)/train_main.ir'
	@$(S_SEED_COMPILER) --link-ir '$(COMMAND_IR_DIR)/worker.ir' '$(COMMAND_IR_DIR)/command_runtime.ir' '$(COMMAND_IR_DIR)/worker_main.ir'
	@$(S_SEED_COMPILER) --link-ir '$(COMMAND_IR_DIR)/controller.ir' '$(COMMAND_IR_DIR)/command_runtime.ir' '$(COMMAND_IR_DIR)/controller_main.ir'
	@$(S_SEED_COMPILER) --link-ir '$(COMMAND_IR_DIR)/serve.ir' '$(COMMAND_IR_DIR)/command_runtime.ir' '$(COMMAND_IR_DIR)/serving_api.ir' '$(COMMAND_IR_DIR)/serve_main.ir'
	@$(S_SEED_COMPILER) --link-ir '$(COMMAND_IR_DIR)/benchmark.ir' '$(COMMAND_IR_DIR)/command_runtime.ir' '$(COMMAND_IR_DIR)/benchmark_main.ir'
	@S_SOURCE_ROOT='$(S_REPO_ROOT)' $(S_SEED_COMPILER) --emit-bin '$(COMMAND_IR_DIR)/train.ir' '$(COMMAND_BIN_DIR)/train'
	@S_SOURCE_ROOT='$(S_REPO_ROOT)' $(S_SEED_COMPILER) --emit-bin '$(COMMAND_IR_DIR)/worker.ir' '$(COMMAND_BIN_DIR)/worker'
	@S_SOURCE_ROOT='$(S_REPO_ROOT)' $(S_SEED_COMPILER) --emit-bin '$(COMMAND_IR_DIR)/controller.ir' '$(COMMAND_BIN_DIR)/controller'
	@S_SOURCE_ROOT='$(S_REPO_ROOT)' $(S_SEED_COMPILER) --emit-bin '$(COMMAND_IR_DIR)/serve.ir' '$(COMMAND_BIN_DIR)/serve'
	@S_SOURCE_ROOT='$(S_REPO_ROOT)' $(S_SEED_COMPILER) --emit-bin '$(COMMAND_IR_DIR)/benchmark.ir' '$(COMMAND_BIN_DIR)/benchmark'
	@echo "Built five linked command binaries under artifacts/bin/."

test-commands: build-commands
	@for command in train worker controller serve benchmark; do \
		set +e; '$(COMMAND_BIN_DIR)/'$$command >/dev/null 2>&1; status=$$?; set -e; \
		if [ $$status -ne 2 ]; then echo "$$command: expected exit 2, got $$status" >&2; exit 1; fi; \
	done
	@echo "Command binary runtime contract tests passed."

# Compatibility entry points remain explicit until their implementations move
# under cmd/. Keeping the source path here prevents duplicate command logic.
worker: quality-gate build-commands
	@echo "Worker binary ready at artifacts/bin/worker."

controller: quality-gate build-commands
	@echo "Controller binary ready at artifacts/bin/controller."

benchmark: release-check build-commands
	@echo "Benchmark binary ready at artifacts/bin/benchmark."
