.PHONY: neurx-infer check-inference-boundary

neurx-infer: infer

check-inference-boundary:
	@test -d src/inference/api
	@test -f src/inference/api/contracts.s
	@test -d src/inference/engine
	@test -d src/inference/scheduler
	@test -d src/inference/executor
	@echo "Inference boundary checks passed."
