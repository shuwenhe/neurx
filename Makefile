.PHONY: help install dev test list api api-all cuda-test cuda-install ensure-pytest bootstrap doctor clean

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
	@echo "  list       List all API feature points and one-command per-API tests"
	@echo "  api        Run one API test case. Usage: make api API=tensor.sum"
	@echo "  api-all    Run all API test cases from tools/api_test_runner.py"
	@echo "  doctor     Run runtime diagnostics"
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

list:
	PYTHONPATH=python $(PYTHON) tools/api_test_runner.py --list

api:
	@if [ -z "$(API)" ]; then \
		echo "Usage: make api API=tensor.sum"; \
		exit 2; \
	fi
	PYTHONPATH=python $(PYTHON) tools/api_test_runner.py --api "$(API)"

api-all:
	PYTHONPATH=python $(PYTHON) tools/api_test_runner.py --all

doctor:
	tensor-doctor

cuda-test: ensure-pytest
	PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 $(PYTEST) -q tests/test_cuda_smoke.py tests/test_cuda_reductions.py tests/test_cuda_reduction_backward.py

cuda-install:
	TENSOR_CUDA=1 $(PIP) install -e . $(PIP_INSTALL_FLAGS)

clean:
	@rm -rf build dist *.egg-info
