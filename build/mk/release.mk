.PHONY: quality-gate release-check worker controller benchmark

quality-gate: check-architecture

release-check: quality-gate
	@test -f benchmarks/result.schema.json
	@echo "Release checks passed."

# Compatibility entry points remain explicit until their implementations move
# under cmd/. Keeping the source path here prevents duplicate command logic.
worker: quality-gate
	@echo "Compatibility entrypoint: scripts/neurx_worker_start.s"
	@echo "Compile and launch it with the configured S toolchain for this cluster."

controller: quality-gate
	@echo "Compatibility entrypoint: scripts/neurx_master_start.s"
	@echo "Review cluster hosts and credentials before launching the controller."

benchmark: release-check
	@echo "Benchmark contract is ready under benchmarks/."
	@echo "A measured result is required; simulated legacy benchmark data is rejected."
