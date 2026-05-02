from importlib import util
from pathlib import Path

import numpy as np


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_lf_runtime_helper_values():
    runtime = _load_runtime_module()
    assert np.isclose(runtime.invoke_runtime_function("losses", "_mean_from_sum", 6.0, 3), 2.0)
    assert np.isclose(runtime.invoke_runtime_function("losses", "_abs", -3.5), 3.5)
