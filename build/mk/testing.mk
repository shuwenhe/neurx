.PHONY: check-test-layout
check-test-layout:
	@test ! -d tests/neurx
	@test -d tests/unit
	@test -d tests/integration
	@test -d tests/e2e
	@test -d tests/performance
	@test -d tests/compatibility
	@test -d tests/fixtures
	@test -d tests/golden
	@echo "Test layout checks passed."
