.PHONY: train check-training-boundary

train: check-training-boundary build-command-contracts
	@echo "Training entrypoint compiled to artifacts/build/commands/train.ir."

check-training-boundary:
	@test -d src/training/api
	@test -f src/training/api/contracts.s
	@test -d src/training/engine
	@test -d src/training/strategy
	@echo "Training boundary checks passed."
