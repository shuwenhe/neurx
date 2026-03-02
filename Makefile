.PHONY: help install dev test cuda-test cuda-install ensure-pytest bootstrap clean

PYTHON ?= python3
PIP ?= $(PYTHON) -m pip
PYTEST ?= $(PYTHON) -m pytest
PIP_INSTALL_FLAGS ?= --no-build-isolation

help:
	@echo "Targets:"
	@echo "  install    Install in editable mode (offline-friendly)"
	@echo "  bootstrap  Upgrade build tooling in current environment"
	@echo "  dev        Same as install"
	@echo "  test       Run tests"
	@echo "  cuda-install  Build/install with CUDA (requires CUDA_HOME or CUDA_PATH)"
	@echo "  cuda-test  Run CUDA smoke test (requires CUDA build)"
	@echo "  clean      Remove build artifacts"

install: dev

bootstrap:
	$(PIP) install -U pip setuptools wheel

dev:
	$(PIP) install -e . $(PIP_INSTALL_FLAGS)

ensure-pytest:
	@$(PYTHON) -c "import pytest" >/dev/null 2>&1 || $(PIP) install pytest

test: ensure-pytest
	PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 $(PYTEST) -q

cuda-test: ensure-pytest
	PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 $(PYTEST) -q tests/test_cuda_smoke.py tests/test_cuda_reductions.py tests/test_cuda_reduction_backward.py

cuda-install:
	TENSOR_CUDA=1 $(PIP) install -e . $(PIP_INSTALL_FLAGS)

clean:
	@rm -rf build dist *.egg-info
