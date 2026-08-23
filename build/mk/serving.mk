.PHONY: serve check-serving-boundary

serve: backend

check-serving-boundary:
	@test -d src/serving/api/openai
	@test -d src/serving/api/admin
	@test -d src/serving/gateway
	@test -d src/serving/admission
	@echo "Serving boundary checks passed."
