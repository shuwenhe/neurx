from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_train_loop_with_parallel_sync_path():
    runtime = _load_runtime_module()

    if not runtime.supports_runtime_function("loop", "new_training_pipeline_state"):
        return
    if not runtime.supports_runtime_function("loop", "train_step_with_parallel"):
        return
    if not runtime.supports_runtime_function("train/parallel", "new_train_parallel_state"):
        return

    pipeline = runtime.invoke_runtime_function("loop", "new_training_pipeline_state", [1, 2, 3, 4, 5, 6], 2, 2)
    parallel = runtime.invoke_runtime_function("train/parallel", "new_train_parallel_state", "nccl", 4, 0, -1)

    stepped = runtime.invoke_runtime_function("loop", "train_step_with_parallel", pipeline, parallel)
    assert stepped["loop"]["step"] == 1
    assert stepped["last_loss"] >= 0.0

    if runtime.supports_runtime_function("loop", "train_steps_with_parallel"):
        multi = runtime.invoke_runtime_function("loop", "train_steps_with_parallel", pipeline, parallel, 2)
        assert multi["loop"]["step"] == 2
