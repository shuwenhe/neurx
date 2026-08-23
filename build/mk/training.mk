.PHONY: train check-training-boundary

train: check-training-boundary build-commands
	@echo "Training binary ready at artifacts/bin/train."

check-training-boundary:
	@test -d src/training/api
	@test -f src/training/api/contracts.s
	@test -d src/training/engine
	@test -d src/training/strategy
	@echo "Training boundary checks passed."
