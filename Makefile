.PHONY: help install dev test test-creation test-sgd test-schedulers test-optimizers test-conv2d test-einsum test-vision test-resnet test-new-features test-scatter test-meshgrid test-scatter-gather test-serialization test-checkpoint list api api-all cuda-test cuda-install ensure-pytest bootstrap doctor cann-doctor cann-train cann-test-310p3 cann-test-npu-agnostic auto-push install-auto-push-service status-auto-push-service stop-auto-push-service clean

PYTHON ?= python3
PIP ?= $(PYTHON) -m pip
PYTEST ?= $(PYTHON) -m pytest
PIP_INSTALL_FLAGS ?= --no-build-isolation
ROUNDS ?= 3

help:
	@echo "Targets:"
	@echo "  install       Install in editable mode (offline-friendly)"
	@echo "  bootstrap     Upgrade build tooling in current environment"
	@echo "  dev           Same as install"
	@echo "  test          Run all tests"
	@echo "  test-creation Run neurx creation functions tests"
	@echo "  test-sgd      Run SGD optimizer tests"
	@echo "  test-schedulers Run learning rate scheduler tests"
	@echo "  test-optimizers Run Adam and RMSprop optimizer tests"
	@echo "  test-conv2d   Run Conv2d layer tests"
	@echo "  test-einsum   Run Einstein summation tests"
	@echo "  test-vision   Run vision transforms tests"
	@echo "  test-resnet   Run ResNet model tests"
	@echo "  test-new-features Run all new features tests (einsum, vision, resnet)"
	@echo "  test-scatter  Run scatter operations tests"
	@echo "  test-meshgrid Run meshgrid tests"
	@echo "  test-scatter-gather Run comprehensive scatter/gather/meshgrid tests"
	@echo "  test-serialization Run model serialization tests"
	@echo "  test-checkpoint Run checkpoint manager tests"
	@echo "  list          List all API feature points and one-command per-API tests"
	@echo "  api           Run one API test case. Usage: make api API=neurx.sum"
	@echo "  api-all       Run all API test cases from tools/api_test_runner.py"
	@echo "  doctor        Run runtime diagnostics"
	@echo "  cann-doctor   Validate Ascend CANN config without starting training"
	@echo "  cann-train    Launch Ascend training from cann JSON config"
	@echo "  cann-test-310p3 Run neurx + 310P3 8-card validation smoke"
	@echo "  cann-test-npu-agnostic Run backend-agnostic tests on TENSOR_DEVICE=npu"
	@echo "  auto-push     Watch repository changes and auto commit/push to GitHub"
	@echo "  install-auto-push-service Install and enable systemd auto-push service"
	@echo "  status-auto-push-service  Show systemd auto-push service status"
	@echo "  stop-auto-push-service    Stop and disable systemd auto-push service"
	@echo "  cuda-install  Build/install with CUDA (requires CUDA_HOME or CUDA_PATH)"
	@echo "  cuda-test     Run CUDA smoke test (requires CUDA build)"
	@echo "  clean         Remove build artifacts"

install: dev

bootstrap:
	$(PIP) install -U pip setuptools wheel

dev:
	$(PIP) install -e . $(PIP_INSTALL_FLAGS)

ensure-pytest:
	@$(PYTHON) -c "import pytest" >/dev/null 2>&1 || $(PIP) install pytest

test: ensure-pytest
	PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 $(PYTEST) -q

test-creation:
	PYTHONPATH=python $(PYTHON) tests/test_creation.py

test-sgd:
	PYTHONPATH=python $(PYTHON) tests/test_sgd.py

test-schedulers:
	PYTHONPATH=python $(PYTHON) tests/test_schedulers.py

test-optimizers:
	PYTHONPATH=python $(PYTHON) tests/test_adam_rmsprop.py

test-conv2d:
	PYTHONPATH=python $(PYTHON) tests/test_conv2d.py

test-einsum:
	@echo "Testing Einstein summation (einsum)..."
	@PYTHONPATH=python $(PYTHON) -c "import sys; sys.path.insert(0, 'tests'); from test_new_features import test_einsum; sys.exit(0 if test_einsum() else 1)"

test-vision:
	@echo "Testing vision transforms..."
	@PYTHONPATH=python $(PYTHON) -c "import sys; sys.path.insert(0, 'tests'); from test_new_features import test_vision_transforms; sys.exit(0 if test_vision_transforms() else 1)"

test-resnet:
	@echo "Testing ResNet models..."
	@PYTHONPATH=python $(PYTHON) -c "import sys; sys.path.insert(0, 'tests'); from test_new_features import test_resnet_models; sys.exit(0 if test_resnet_models() else 1)"

test-new-features:
	@echo "Running comprehensive tests for all new features..."
	PYTHONPATH=python $(PYTHON) tests/test_new_features.py

test-scatter:
	@echo "Testing scatter operations..."
	@PYTHONPATH=python $(PYTHON) -c "import sys; sys.path.insert(0, 'tests'); from test_scatter_gather import test_scatter, test_scatter_add; sys.exit(0 if test_scatter() and test_scatter_add() else 1)"

test-meshgrid:
	@echo "Testing meshgrid..."
	@PYTHONPATH=python $(PYTHON) -c "import sys; sys.path.insert(0, 'tests'); from test_scatter_gather import test_meshgrid; sys.exit(0 if test_meshgrid() else 1)"

test-scatter-gather:
	@echo "Running comprehensive scatter/gather/meshgrid tests..."
	PYTHONPATH=python $(PYTHON) tests/test_scatter_gather.py

test-serialization:
	@echo "Running model serialization tests..."
	PYTHONPATH=python $(PYTHON) tests/test_serialization.py

test-checkpoint:
	@echo "Running checkpoint management tests..."
	@PYTHONPATH=python $(PYTHON) -c "import sys; sys.path.insert(0, 'tests'); from test_serialization import test_model_checkpoint; sys.exit(0 if test_model_checkpoint() else 1)"

list:
	PYTHONPATH=python $(PYTHON) tools/api_test_runner.py --list

api:
	@if [ -z "$(API)" ]; then \
		echo "Usage: make api API=neurx.sum"; \
		exit 2; \
	fi
	PYTHONPATH=python $(PYTHON) tools/api_test_runner.py --api "$(API)"

api-all:
	PYTHONPATH=python $(PYTHON) tools/api_test_runner.py --all

doctor:
	PYTHONPATH=python $(PYTHON) -m neurx.cli

cann-doctor:
	@if [ -z "$(CONFIG)" ]; then \
		echo "Usage: make cann-doctor CONFIG=cann/configs/ascend_910b_train.json"; \
		exit 2; \
	fi
	$(PYTHON) cann/train_launcher.py --config $(CONFIG) --dry-run

cann-train:
	@if [ -z "$(CONFIG)" ]; then \
		echo "Usage: make cann-train CONFIG=cann/configs/ascend_910b_train.json"; \
		exit 2; \
	fi
	$(PYTHON) cann/train_launcher.py --config $(CONFIG)

cann-test-310p3:
	/usr/bin/python3 cann/examples/neurx_310p3_validation.py --python /usr/bin/python3 --rounds $(ROUNDS)

cann-test-npu-agnostic:
	NEURX_TEST_DEVICE=npu TENSOR_DEVICE=npu PYTHONPATH=python:. /usr/bin/python3 -m pytest -q $$(cat tests/npu_backend_agnostic_tests.txt)

auto-push:
	$(PYTHON) scripts/auto_push.py --repo . --remote origin

install-auto-push-service:
	bash scripts/install_auto_push_service.sh

status-auto-push-service:
	systemctl status neurx-auto-push.service --no-pager

stop-auto-push-service:
	systemctl disable --now neurx-auto-push.service

cuda-test: ensure-pytest
	PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 $(PYTEST) -q tests/test_cuda_smoke.py tests/test_cuda_reductions.py tests/test_cuda_reduction_backward.py

cuda-install:
	TENSOR_CUDA=1 $(PIP) install -e . $(PIP_INSTALL_FLAGS)

clean:
	@rm -rf build dist *.egg-info
