from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_opt_runtime_compiled_functions_present():
    runtime = _load_runtime_module()
    status = runtime.runtime_status()
    assert status["available"] is True
    for ir_name in (
        "optimizer.ir",
        "optim.ir",
        "losses.ir",
        "scheduler.ir",
        "schedulers.ir",
        "core_optim.ir",
        "optim_mvp.ir",
    ):
        assert any(Path(path).name == ir_name for path in status["ir_files"])

    runtime_files = [Path(path).name for path in runtime.compiled_runtime_files()]
    for ir_name in (
        "optimizer.ir",
        "optim.ir",
        "losses.ir",
        "scheduler.ir",
        "schedulers.ir",
        "core_optim.ir",
        "optim_mvp.ir",
    ):
        assert ir_name in runtime_files

    for function_name in (
        "new_optimizer",
        "optimizer_zero_grad",
        "optimizer_step",
        "optimizer_state_dict",
        "optimizer_load_state_dict",
    ):
        assert runtime.supports_runtime_function("optimizer", function_name)

    for function_name in (
        "new_sgd",
        "new_adam",
        "new_adamw",
        "new_rmsprop",
        "step_tensor",
        "adam_step",
        "adamw_step",
        "rmsprop_step",
        "clip_grad_norm",
    ):
        assert runtime.supports_runtime_function("optim", function_name)

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

    for function_name in (
        "new_lr_scheduler",
        "scheduler_step",
        "scheduler_state_dict",
        "scheduler_load_state_dict",
    ):
        assert runtime.supports_runtime_function("scheduler", function_name)

    for function_name in (
        "new_step_lr",
        "new_exponential_lr",
        "new_cosine_annealing_lr",
        "new_cosine_annealing_warm_restarts",
        "new_reduce_lr_on_plateau",
        "new_linear_lr",
        "new_polynomial_lr",
        "new_multiplicative_lr",
        "new_lambda_lr",
        "new_warmup_lr",
        "new_warmup_decay_lr",
        "new_step_decay_with_warmup",
        "new_cyclic_lr",
        "new_one_cycle_lr",
    ):
        assert runtime.supports_runtime_function("schedulers", function_name)

    for function_name in (
        "new_sgd",
        "new_adam",
        "new_rmsprop",
        "step_tensor",
        "adam_step",
        "rmsprop_step",
    ):
        assert runtime.supports_runtime_function("optim_mvp", function_name)
