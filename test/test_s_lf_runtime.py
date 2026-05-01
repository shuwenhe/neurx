from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_lf_runtime_compiled_functions_present():
    runtime = _load_runtime_module()
    status = runtime.runtime_status()
    assert status["available"] is True
    assert any(Path(path).name == "losses.ir" for path in status["ir_files"])

    runtime_files = [Path(path).name for path in runtime.compiled_runtime_files()]
    assert "losses.ir" in runtime_files

    for function_name in (
        "cross_entropy_loss",
        "bce_loss",
        "bce_with_logits_loss",
        "l1_loss",
        "mse_loss",
        "smooth_l1_loss",
        "kl_div_loss",
        "nll_loss",
        "huber_loss",
        "poisson_nll_loss",
        "ctc_loss",
        "margin_ranking_loss",
        "triplet_margin_loss",
    ):
        assert runtime.supports_runtime_function("losses", function_name)
