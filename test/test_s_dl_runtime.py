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
        "dataset_slice",
        "dataset_take",
        "dataset_extend",
        "dataset_state_dict",
        "dataset_load_state_dict",
        "new_iterable_dataset",
        "iterable_dataset_len",
        "iterable_dataset_getitem",
        "iterable_dataset_state_dict",
        "iterable_dataset_load_state_dict",
        "new_tensor_dataset",
        "tensor_dataset_len",
        "tensor_dataset_getitem",
        "tensor_dataset_state_dict",
        "tensor_dataset_load_state_dict",
        "new_subset",
        "subset_len",
        "subset_getitem",
        "subset_state_dict",
        "subset_load_state_dict",
        "new_concat_dataset",
        "concat_dataset_len",
        "concat_dataset_getitem",
        "concat_dataset_state_dict",
        "concat_dataset_load_state_dict",
        "random_split",
        "random_split_equal",
    ):
        assert runtime.supports_runtime_function("dataset", function_name)

    for function_name in (
        "default_collate",
        "new_config",
        "set_drop_last",
        "set_shuffle",
        "new_state",
        "reset_state",
        "with_config",
        "has_next",
        "batch_count",
        "next_batch",
        "peek_batch",
        "drop_last_enabled",
        "shuffle_enabled",
        "dataloader_state_dict",
        "dataloader_load_state_dict",
    ):
        assert runtime.supports_runtime_function("dataloader", function_name)
