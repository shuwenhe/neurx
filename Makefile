.PHONY: help install dev test cuda-test clean

PYTHON ?= python3
PIP ?= $(PYTHON) -m pip
PYTEST ?= $(PYTHON) -m pytest

help:
	@echo "Targets:"
	@echo "  install    Install in editable mode (offline-friendly)"
	@echo "  dev        Same as install"
	@echo "  test       Run tests"
	@echo "  cuda-test  Run CUDA smoke test (requires CUDA build)"
	@echo "  clean      Remove build artifacts"

install: dev

dev:
	$(PIP) install -U pip setuptools wheel
	$(PIP) install -e . --no-build-isolation

test:
	$(PYTEST) -q

cuda-test:
	$(PYTEST) -q tests/test_cuda_smoke.py

clean:
	@rm -rf build dist *.egg-info
