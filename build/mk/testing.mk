.PHONY: check-test-layout test-api-contracts
check-test-layout:
	@test ! -d tests/neurx
	@test -d tests/unit
	@test -d tests/contract
	@test -d tests/integration
	@test -d tests/distributed
	@test -d tests/e2e
	@test -d tests/performance
	@test -d tests/compatibility
	@test -d tests/fixtures
	@test -d tests/golden
	@test -d tests/chaos
	@echo "Test layout checks passed."

test-api-contracts:
	@mkdir -p artifacts/build/contracts
	@$(S_SEED_COMPILER) src/training/api/contracts.s artifacts/build/contracts/training_api.ir
	@$(S_SEED_COMPILER) src/inference/api/contracts.s artifacts/build/contracts/inference_api.ir
	@$(S_SEED_COMPILER) tests/contract/training_api_contract_test.s artifacts/build/contracts/training_api_contract_test.ir
	@$(S_SEED_COMPILER) tests/contract/inference_api_contract_test.s artifacts/build/contracts/inference_api_contract_test.ir
	@echo "API and contract caller compilation passed (runtime module linking is not yet supported by the S CLI)."
