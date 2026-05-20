.PHONY: help install neurx app clean

.DEFAULT_GOAL := help

S_COMPILER ?= $(shell command -v s 2>/dev/null)

help:
	@echo "  neurx             Compile the NeurX deep learning framework to IR"
	@echo "  app               Compile and run the local Qt app"
	@echo "  install           Alias of neurx"
	@echo "  clean             Remove generated artifacts and caches"

install: neurx

neurx:
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

app:
	@mkdir -p build/logs
	@echo "Streaming NeurX runtime logs to build/logs/neurx.log"
	@bash app/run_with_llm.sh 2>&1 | tee build/logs/neurx.log

clean:
	@rm -rf build runtime/__pycache__ test/__pycache__ checkpoint.pkl
