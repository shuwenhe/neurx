.PHONY: train check-training-boundary

# Stable product entry point. The underlying pretrain target remains compatible
# while training implementations migrate behind src/training/api.
train: pretrain-gpu

check-training-boundary:
	@test -d src/training/api
	@test -d src/training/engine
	@test -d src/training/strategy
	@echo "Training boundary checks passed."
