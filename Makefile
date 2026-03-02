.PHONY: help install dev test cuda-test cuda-install clean

PYTHON ?= python3
PIP ?= $(PYTHON) -m pip
PYTEST ?= $(PYTHON) -m pytest

help:
	@echo "Targets:"
	@echo "  install    Install in editable mode (offline-friendly)"
	@echo "  dev        Same as install"
	@echo "  test       Run tests"
	@echo "  cuda-install  Build/install with CUDA (requires CUDA_HOME or CUDA_PATH)"
	@echo "  cuda-test  Run CUDA smoke test (requires CUDA build)"
	@echo "  clean      Remove build artifacts"

install: dev

dev:
	$(PIP) install -U pip setuptools wheel
	$(PIP) install -e .

test:
	$(PIP) install -U pytest
	PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 $(PYTEST) -q

cuda-test:
	$(PIP) install -U pytest
	PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 $(PYTEST) -q tests/test_cuda_smoke.py

cuda-install:
	TENSOR_CUDA=1 $(PIP) install -e .

clean:
	@rm -rf build dist *.egg-info
