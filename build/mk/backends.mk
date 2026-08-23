.PHONY: check-backend-boundary

check-backend-boundary:
	@test -d backends/cpu
	@test -d backends/cuda
	@test -d backends/cann
	@test -d backends/common
	@echo "Backend boundary checks passed."
