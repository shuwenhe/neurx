from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_train_parallel_tp_collective_smoke():
    runtime = _load_runtime_module()

    if not runtime.supports_runtime_function("train/parallel", "new_train_parallel_state"):
        return

    state = runtime.invoke_runtime_function("train/parallel", "new_train_parallel_state", "nccl", 4, 1, -1)
    assert runtime.invoke_runtime_function("train/parallel", "train_parallel_enabled", state) is True

    reduced = runtime.invoke_runtime_function("train/parallel", "train_parallel_all_reduce_grad", state, [1.0, 2.0])
    gathered = runtime.invoke_runtime_function("train/parallel", "train_parallel_all_gather_activation", state, [5.0])

    assert reduced[0] == 4.0
    assert len(reduced) == 2
    assert len(gathered) == 4
