.PHONY: serve check-serving-boundary

serve: check-serving-boundary build-commands
	@echo "Serving binary ready at artifacts/bin/serve."

check-serving-boundary:
	@test -d src/serving/api/openai
	@test -f src/serving/api/contracts.s
	@test -d src/serving/api/admin
	@test -d src/serving/gateway
	@test -d src/serving/admission
	@echo "Serving boundary checks passed."
