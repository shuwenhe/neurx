.PHONY: quality-gate release-check build-command-contracts worker controller benchmark

quality-gate: check-architecture

release-check: quality-gate test-benchmark-schema
	@test -f benchmarks/result.schema.json
	@echo "Release checks passed."

build-command-contracts:
	@mkdir -p artifacts/build/commands
	@$(S_SEED_COMPILER) cmd/train/main.s artifacts/build/commands/train.ir
	@$(S_SEED_COMPILER) cmd/worker/main.s artifacts/build/commands/worker.ir
	@$(S_SEED_COMPILER) cmd/controller/main.s artifacts/build/commands/controller.ir
	@$(S_SEED_COMPILER) cmd/serve/main.s artifacts/build/commands/serve.ir
	@$(S_SEED_COMPILER) cmd/benchmark/main.s artifacts/build/commands/benchmark.ir
	@echo "Command entrypoint compilation passed."

# Compatibility entry points remain explicit until their implementations move
# under cmd/. Keeping the source path here prevents duplicate command logic.
worker: quality-gate build-command-contracts
	@echo "Worker entrypoint compiled to artifacts/build/commands/worker.ir."

controller: quality-gate build-command-contracts
	@echo "Controller entrypoint compiled to artifacts/build/commands/controller.ir."

benchmark: release-check build-command-contracts
	@echo "Benchmark entrypoint compiled to artifacts/build/commands/benchmark.ir."
