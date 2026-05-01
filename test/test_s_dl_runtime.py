from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_dl_runtime_compiled_functions_present():
    runtime = _load_runtime_module()
    status = runtime.runtime_status()
    assert status["available"] is True
    for ir_name in ("dataset.ir", "dataloader.ir"):
        assert any(Path(path).name == ir_name for path in status["ir_files"])

    runtime_files = [Path(path).name for path in runtime.compiled_runtime_files()]
    for ir_name in ("dataset.ir", "dataloader.ir"):
        assert ir_name in runtime_files

    for function_name in (
        "new_dataset",
        "dataset_len",
        "dataset_getitem",
        "new_iterable_dataset",
        "iterable_dataset_len",
        "iterable_dataset_getitem",
        "new_tensor_dataset",
        "tensor_dataset_len",
        "tensor_dataset_getitem",
        "new_subset",
        "subset_len",
        "subset_getitem",
        "new_concat_dataset",
        "concat_dataset_len",
        "concat_dataset_getitem",
        "random_split",
    ):
        assert runtime.supports_runtime_function("dataset", function_name)

    for function_name in (
        "default_collate",
        "new_config",
        "new_state",
        "has_next",
        "next_batch",
    ):
        assert runtime.supports_runtime_function("dataloader", function_name)
