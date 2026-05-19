.PHONY: help install install-local s-compile-runtime logs clean verify-layout

.DEFAULT_GOAL := s-compile-runtime

S_COMPILER ?= $(shell command -v s 2>/dev/null)

help:
	@echo "Targets:"
	@echo "  s-compile-runtime Compile all NeurX S sources to IR"
	@echo "  install-local     Alias of s-compile-runtime"
	@echo "  install           Alias of s-compile-runtime"
	@echo "  logs              Start the app and stream runtime logs to build/logs/neurx.log"
	@echo "  clean             Remove generated artifacts and caches"
	@echo "  verify-layout     Check for forbidden IR/build artifacts in source directories"

install: s-compile-runtime

install-local: s-compile-runtime

logs:
	@mkdir -p build/logs
	@echo "Streaming NeurX runtime logs to build/logs/neurx.log"
	@bash app/run_with_llm.sh 2>&1 | tee build/logs/neurx.log

s-compile-runtime:
	@if [ ! -x "$(S_COMPILER)" ]; then \
		echo "error: S compiler not found or not executable: $(S_COMPILER)"; \
		echo "hint: install the S compiler and ensure 's' is on PATH, or pass S_COMPILER=/path/to/s"; \
		exit 1; \
	fi
	@echo "Using S compiler: $(S_COMPILER)"
	@mkdir -p build/ir
	for src in $$(find s ops data tensor ad engine nn opt lf train pretrain runtime distributed serving infer infer/vllm model platform compile reasoning workflows app/web -type f -name '*.s' | sort); do \
	    [ -e "$$src" ] || continue; \
	    base=$$(basename "$$src" .s); \
	    parent=$$(basename "$$(dirname "$$src")"); \
	    module=$${src%.s}; \
	    if [ "$$parent" = "$$base" ]; then \
	        module=$$(dirname "$$src"); \
	    fi; \
	    target_dir=$$(dirname "$$module"); \
	    mkdir -p "build/ir/$$target_dir"; \
		echo "Compiling $$src -> build/ir/$$module.ir"; \
		if $(S_COMPILER) --help 2>&1 | grep -q "<input.s> <output.ir>"; then \
			$(S_COMPILER) "$$src" "build/ir/$$module.ir" || exit 1; \
		else \
			$(S_COMPILER) ir "$$src" -o "build/ir/$$module.ir" || exit 1; \
		fi; \
	done
	@root_dir="$$(pwd)"; \
	artifact_dir="$$root_dir/build/ir"; \
	manifest_path="$$artifact_dir/manifest.json"; \
	files="$$(cd build/ir && find . -type f -name '*.ir' | sed 's#^\./##' | sort)"; \
	{ \
		echo "{"; \
		echo "  \"source_root\": \"$$root_dir\","; \
		echo "  \"artifact_root\": \"$$artifact_dir\","; \
		echo "  \"ir_files\": ["; \
		first=1; \
		for file in $$files; do \
			if [ $$first -eq 0 ]; then printf ',\n'; fi; \
			printf "    \"%s\"" "$$file"; \
			first=0; \
		done; \
		printf '\n'; \
		echo "  ]"; \
		echo "}"; \
	} > "$$manifest_path"
	@echo "runtime manifest: build/ir/manifest.json"

clean:
	@rm -rf build runtime/__pycache__ test/__pycache__ checkpoint.pkl

verify-layout:
	@echo "Checking for forbidden IR/build artifacts in source directories..."
	@if find . -type f \( -name '*.ir' -a ! -path './build/*' \) | grep -q .; then \
		echo 'ERROR: Found .ir files outside build/. Please clean up.'; exit 1; \
	else \
		echo 'OK: No forbidden IR files found.'; \
	fi
