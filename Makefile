# ─────────────────────────────────────────────────────────────────────────────
#  NeurX Code — top-level Makefile
#  Cross-platform convenience wrapper over CMake.
#
#  Usage:
#    make linux          # build for Linux (current machine)
#    make mac            # build on macOS
#    make windows        # print Windows build instructions
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: linux mac windows help

BUILD_TYPE   ?= Release
PROJECT_ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

ifeq ($(OS),Windows_NT)
CORES := $(NUMBER_OF_PROCESSORS)
ifeq ($(strip $(CORES)),)
CORES := 4
endif
else
CORES := $(shell nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo 4)
endif

# ── Help (default) ───────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "    make linux            Build Release for Linux (current machine)"
	@echo "    make mac              Build Release for macOS"
	@echo "    make windows          Print Windows build instructions"
	@echo ""

# ── Linux ────────────────────────────────────────────────────────────────────
linux:
	@bash $(PROJECT_ROOT)scripts/build-linux.sh Release

# ── macOS ────────────────────────────────────────────────────────────────────
mac:
	@bash $(PROJECT_ROOT)scripts/build-macos.sh Release

# ── Windows (native — run scripts\build-windows.bat on Windows) ─────────────
# On Linux/macOS this prints the correct Windows instructions.
ifeq ($(OS),Windows_NT)
windows:
	@call scripts\\build-windows.bat $(BUILD_TYPE)
else
windows:
	@printf '\n  Windows build must be run on a Windows machine:\n'
	@printf '    scripts\\\\build-windows.bat Release\n\n'
	@printf '  Or use the GitHub Actions CI workflow:\n'
	@printf "    .github/workflows/build.yml  (see 'windows' job)\n\n"
endif
