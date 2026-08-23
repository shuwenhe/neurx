.PHONY: check-layout check-dependencies check-domain-boundaries check-architecture
check-layout:
	@bash scripts/check_layout.sh

check-dependencies:
	@bash scripts/check_dependencies.sh

check-domain-boundaries:
	@bash scripts/check_architecture.sh

check-architecture: check-layout check-compiler-layout check-dependencies check-test-layout check-domain-boundaries check-training-boundary check-inference-boundary check-serving-boundary check-backend-boundary
