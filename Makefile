.PHONY: help install neurx s-package-index s-compile-runtime code-agent-build code-agent linux windows macos ios android harmony clean check-bash \
	app-linux app-windows app-macos app-ios app-android app-harmony \
	linux windows macos ios android harmony \
	install-robot install-auto install-desktop install-tablet install-mobile-android install-mobile-ios

ifeq ($(OS),Windows_NT)
PLATFORM := windows
WINDOWS_GIT_BASH := C:/Progra~1/Git/bin/bash.exe
WINDOWS_GIT_BASH_ALT := C:/Progra~1/Git/usr/bin/bash.exe
ifeq ($(wildcard $(WINDOWS_GIT_BASH)),)
ifeq ($(wildcard $(WINDOWS_GIT_BASH_ALT)),)
BASH ?= bash
else
BASH ?= $(WINDOWS_GIT_BASH_ALT)
endif
else
BASH ?= $(WINDOWS_GIT_BASH)
endif
else
UNAME_S := $(shell uname -s 2>/dev/null)
ifeq ($(UNAME_S),Darwin)
PLATFORM := macos
else
PLATFORM := linux
endif
BASH ?= bash
endif

.DEFAULT_GOAL := help

S_COMPILER ?= s
CURDIR_UNIX := $(subst \,/,$(CURDIR))

help:
	@echo "  neurx             Compile the NeurX deep learning framework to IR"
	@echo "  linux             Compile and run the Linux app"
	@echo "  windows           Compile and run the Windows app"
	@echo "  macos             Compile and run the macOS app"
	@echo "  ios               Compile the iOS app (placeholder target)"
	@echo "  android           Compile the Android app (placeholder target)"
	@echo "  harmony           Compile the Harmony app (placeholder target)"
	@echo "  install           Alias of neurx"
	@echo "  code-agent-build  Build build/bin/neurx_code_agent from agent/code_agent.s"
	@echo "  code-agent        Run code agent (TASK=... optional)"
	@echo "  clean             Remove generated artifacts and caches"
	@echo "  platform          $(PLATFORM)"
	@echo ""
	@echo "Platform install targets:"
	@echo "  install-robot     Install NeurX on Jetson Orin / RK3588 robot"
	@echo "  install-auto      Install NeurX on automotive SoC (DRIVE Orin / QNX)"
	@echo "  install-desktop   Install NeurX on Linux / macOS desktop"
	@echo "  install-tablet    Install NeurX on Android tablet via ADB"
	@echo "  install-mobile-android  Install NeurX on Android phone via ADB"
	@echo "  install-mobile-ios      Install NeurX on iPhone via Xcode"

check-bash:
ifeq ($(PLATFORM),windows)
	@where "$(BASH)" >NUL 2>&1 || if not exist "$(BASH)" ( \
		echo error: Git Bash not found: $(BASH) & \
		echo hint: install Git for Windows, or run make BASH=C:/path/to/bash.exe ^<target^> & \
		exit /b 1 \
	)
	@"$(BASH)" -lc "exit 0"
else
	@command -v bash >/dev/null 2>&1 || { \
		echo "error: bash not found on PATH"; \
		echo "hint: install bash or run make BASH=/path/to/bash <target>"; \
		exit 1; \
	}
endif

install: neurx

s-package-index: check-bash
	@echo "Note: S compiler does not support 'mod index' command; skipping package index generation"

code-agent-build: check-bash s-package-index
	@mkdir -p build/bin
	@if ! command -v "$(S_COMPILER)" >/dev/null 2>&1 && [ ! -x "$(S_COMPILER)" ]; then \
		echo "error: S compiler not found: $(S_COMPILER)"; exit 1; \
	fi
	@"$(S_COMPILER)" build agent/code_agent.s -o build/bin/neurx_code_agent
	@echo "built build/bin/neurx_code_agent"

code-agent:
	@TASK_TEXT="$${TASK:-$${NEURX_CODE_AGENT_TASK:-inspect agent/ and summarize the code agent architecture}}"; \
	chmod +x app/service/run_neurx_code_agent.sh 2>/dev/null || true; \
	NEURX_CODE_AGENT_FULL_AUTO="$${NEURX_CODE_AGENT_FULL_AUTO:-1}" \
	bash app/service/run_neurx_code_agent.sh --prompt "$$TASK_TEXT" --repo "$$(pwd)"

s-compile-runtime: neurx

linux: app-linux
windows: app-windows
macos: app-macos
ios: app-ios
android: app-android
harmony: app-harmony

ifeq ($(PLATFORM),windows)

s-package-index: check-bash
	@echo "Note: S compiler does not support 'mod index' command; skipping package index generation"

neurx: check-bash s-package-index
	@"$(BASH)" -lc "cd '$(CURDIR_UNIX)' && \
	if ! command -v '$(S_COMPILER)' >/dev/null 2>&1 && [ ! -x '$(S_COMPILER)' ]; then \
		echo 'error: S compiler not found or not executable: $(S_COMPILER)'; \
		echo 'hint: install the S compiler and ensure '\''s'\'' is on PATH, or pass S_COMPILER=/path/to/s'; \
		exit 1; \
	fi && \
	resolved_s=\"$$(command -v '$(S_COMPILER)' 2>/dev/null || printf '%s' '$(S_COMPILER)')\" && \
	echo \"Using S compiler: $$resolved_s\" && \
	mkdir -p build/ir && \
	for src in $$(find s ops data tensor ad engine nn opt lf train pretrain runtime distributed serving infer infer/vllm model platform compile reasoning workflows app/web -type f -name '*.s' | sort); do \
		[ -e \"$$src\" ] || continue; \
		base=$$(basename \"$$src\" .s); \
		parent=$$(basename \"$$(dirname \"$$src\")\"); \
		module=$${src%.s}; \
		if [ \"$$parent\" = \"$$base\" ]; then \
			module=$$(dirname \"$$src\"); \
		fi; \
		target_dir=$$(dirname \"$$module\"); \
		mkdir -p \"build/ir/$$target_dir\"; \
		echo \"Compiling $$src -> build/ir/$$module.ir\"; \
		if '$(S_COMPILER)' --help 2>&1 | grep -q '<input.s> <output.ir>'; then \
			'$(S_COMPILER)' \"$$src\" \"build/ir/$$module.ir\" || exit 1; \
		else \
			'$(S_COMPILER)' ir \"$$src\" -o \"build/ir/$$module.ir\" || exit 1; \
		fi; \
	done && \
	root_dir=\"$$PWD\" && \
	artifact_dir=\"$$root_dir/build/ir\" && \
	manifest_path=\"$$artifact_dir/manifest.json\" && \
	files=\"$$(cd build/ir && find . -type f -name '*.ir' | sed 's#^\\./##' | sort)\" && \
	{ \
		echo '{'; \
		echo \"  \\\"source_root\\\": \\\"$$root_dir\\\",\"; \
		echo \"  \\\"artifact_root\\\": \\\"$$artifact_dir\\\",\"; \
		echo '  \"ir_files\": ['; \
		first=1; \
		for file in $$files; do \
			if [ $$first -eq 0 ]; then printf ',\\n'; fi; \
			printf '    \"%s\"' \"$$file\"; \
			first=0; \
		done; \
		printf '\\n'; \
		echo '  ]'; \
		echo '}'; \
	} > \"$$manifest_path\" && \
	echo 'runtime manifest: build/ir/manifest.json'"

app-linux app-windows app-macos app-ios app-android app-harmony: check-bash
	@if not exist build\logs mkdir build\logs
	@echo Streaming NeurX runtime logs to build/logs/neurx.log
	@"$(BASH)" -lc "cd '$(CURDIR_UNIX)' && NEURX_APP_TARGET_PLATFORM='$(@:app-%=%)' bash app/run_with_llm.sh 2>&1 | tee build/logs/neurx.log"

clean:
	@if exist build rmdir /s /q build
	@if exist runtime\__pycache__ rmdir /s /q runtime\__pycache__
	@if exist test\__pycache__ rmdir /s /q test\__pycache__
	@if exist checkpoint.pkl del /f /q checkpoint.pkl

else

neurx: check-bash s-package-index
	@if ! command -v "$(S_COMPILER)" >/dev/null 2>&1 && [ ! -x "$(S_COMPILER)" ]; then \
		echo "error: S compiler not found or not executable: $(S_COMPILER)"; \
		echo "hint: install the S compiler and ensure 's' is on PATH, or pass S_COMPILER=/path/to/s"; \
		exit 1; \
	fi
	@resolved_s="$$(command -v "$(S_COMPILER)" 2>/dev/null || printf '%s' "$(S_COMPILER)")"; \
	echo "Using S compiler: $$resolved_s"
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
		if "$(S_COMPILER)" --help 2>&1 | grep -q "<input.s> <output.ir>"; then \
			"$(S_COMPILER)" "$$src" "build/ir/$$module.ir" || exit 1; \
		else \
			"$(S_COMPILER)" ir "$$src" -o "build/ir/$$module.ir" || exit 1; \
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

app-linux app-windows app-macos app-ios app-android app-harmony: check-bash
	@mkdir -p build/logs
	@echo "Streaming NeurX runtime logs to build/logs/neurx.log"
	@NEURX_APP_TARGET_PLATFORM="$(@:app-%=%)" $(BASH) app/run_with_llm.sh 2>&1 | tee build/logs/neurx.log

clean:
	@rm -rf build runtime/__pycache__ test/__pycache__ checkpoint.pkl

# ── Platform install targets ─────────────────────────────────────────────────
install-robot:
	@bash install/robot/install.sh

install-auto:
	@bash install/auto/install.sh

install-desktop:
	@bash install/desktop/install.sh

install-tablet:
	@bash install/tablet/install.sh

install-mobile-android:
	@bash install/mobile/install-android.sh

install-mobile-ios:
	@bash install/mobile/install-ios.sh

endif
