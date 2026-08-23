.PHONY: check-layout check-dependencies check-architecture
check-layout:
	@bash scripts/check_layout.sh

check-dependencies:

	@bash scripts/check_dependencies.sh

check-architecture: check-layout check-compiler-layout check-dependencies check-test-layout
