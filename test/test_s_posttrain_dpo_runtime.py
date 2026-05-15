from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_posttrain_dpo_numeric_and_pipeline_step():
    runtime = _load_runtime_module()

    if not runtime.supports_runtime_function("posttrain/dpo/dpo_state", "new_default_dpo_state"):
        return

    for function_name in (
        "new_default_dpo_state",
        "new_dpo_state",
        "dpo_state_dict",
        "dpo_load_state_dict",
    ):
        assert runtime.supports_runtime_function("posttrain/dpo/dpo_state", function_name)

    for function_name in (
        "dpo_margin",
        "dpo_loss_from_margin",
        "dpo_pair_loss",
    ):
        assert runtime.supports_runtime_function("posttrain/dpo/dpo_loss", function_name)

    for function_name in (
        "dpo_step",
        "dpo_step_result_state_dict",
        "dpo_step_result_load_state_dict",
    ):
        assert runtime.supports_runtime_function("posttrain/dpo/dpo_step", function_name)

    dpo = runtime.invoke_runtime_function("posttrain/dpo/dpo_state", "new_default_dpo_state")

    good = runtime.invoke_runtime_function(
        "posttrain/dpo/dpo_step",
        "dpo_step",
        dpo,
        -0.20,
        -1.00,
        -0.30,
        -0.90,
    )
    bad = runtime.invoke_runtime_function(
        "posttrain/dpo/dpo_step",
        "dpo_step",
        dpo,
        -1.20,
        -0.20,
        -0.90,
        -0.30,
    )

    assert good["reward_margin"] > bad["reward_margin"]
    assert good["loss"] < bad["loss"]

    if runtime.supports_runtime_function("posttrain", "new_default_posttrain_pipeline") and runtime.supports_runtime_function("posttrain", "posttrain_step_with_dpo"):
        state = runtime.invoke_runtime_function(
            "posttrain",
            "new_default_posttrain_pipeline",
            "demo",
            "preference",
            "reward-demo",
            "run-demo",
            "/tmp",
        )
        next_state = runtime.invoke_runtime_function(
            "posttrain",
            "posttrain_step_with_dpo",
            state,
            dpo,
            -0.20,
            -1.00,
            -0.30,
            -0.90,
            4,
        )
        assert next_state["loop"]["global_step"] == 1
        assert next_state["metrics"]["step"] == 1
        assert next_state["metrics"]["policy_loss"] >= 0.0
