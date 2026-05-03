from __future__ import annotations

from dataclasses import dataclass

from neurx.platform.errors import ConfigurationError

_VALID_BACKENDS = {"eager", "aot"}
_VALID_MODES = {"default", "reduce-overhead", "max-autotune"}


@dataclass(frozen=True)
class CompileOptions:
    backend: str = "eager"
    mode: str = "default"
    fullgraph: bool = False
    dynamic: bool = False
    debug: bool = False


def _validate_options(options: CompileOptions) -> None:
    if options.backend not in _VALID_BACKENDS:
        raise ConfigurationError(f"compile backend must be one of {_VALID_BACKENDS}, got {options.backend!r}")
    if options.mode not in _VALID_MODES:
        raise ConfigurationError(f"compile mode must be one of {_VALID_MODES}, got {options.mode!r}")


class CompiledModule:
    def __init__(self, module, options: CompileOptions, stage_state=None):
        self.module = module
        self.options = options
        self.stage_state = stage_state

    def __call__(self, *args, **kwargs):
        result = self.module(*args, **kwargs)
        if self.stage_state is not None:
            try:
                from neurx.compile import runtime as runtime_support

                if runtime_support.supports_runtime_function("runtime/stage", "execute"):
                    self.stage_state = runtime_support.invoke_runtime_function("runtime/stage", "execute", self.stage_state)
            except Exception:
                pass
        return result

    def __getattr__(self, name):
        return getattr(self.module, name)

    @property
    def backend(self) -> str:
        return self.options.backend

    @property
    def mode(self) -> str:
        return self.options.mode

    @property
    def compiled(self) -> bool:
        return bool(self.stage_state and self.stage_state.get("compiled", False))

    @property
    def lowered(self) -> bool:
        return bool(self.stage_state and self.stage_state.get("lowered", False))

    @property
    def executed(self) -> bool:
        return bool(self.stage_state and self.stage_state.get("executed", False))

    def state_dict(self) -> dict[str, object]:
        return {
            "module": self.module.__class__.__name__.lower(),
            "options": {
                "backend": self.options.backend,
                "mode": self.options.mode,
                "fullgraph": self.options.fullgraph,
                "dynamic": self.options.dynamic,
                "debug": self.options.debug,
            },
            "stage_state": self.stage_state,
            "compiled": self.compiled,
            "lowered": self.lowered,
            "executed": self.executed,
        }

    def load_state_dict(self, state: dict[str, object]):
        self.stage_state = state.get("stage_state", self.stage_state)
        return self


def _build_stage_state(module, options: CompileOptions):
    try:
        from neurx.compile import runtime as runtime_support

        if not runtime_support.supports_runtime_function("runtime/stage", "new_stage_state"):
            return None
        stage = runtime_support.invoke_runtime_function(
            "runtime/stage",
            "new_stage_state",
            module.__class__.__name__.lower(),
            options.backend,
            options.mode,
        )
        stage = runtime_support.invoke_runtime_function("runtime/stage", "stage_add_param", stage, f"backend={options.backend}")
        stage = runtime_support.invoke_runtime_function("runtime/stage", "stage_add_param", stage, f"mode={options.mode}")
        stage = runtime_support.invoke_runtime_function("runtime/stage", "stage_add_param", stage, f"fullgraph={options.fullgraph}")
        stage = runtime_support.invoke_runtime_function("runtime/stage", "stage_add_param", stage, f"dynamic={options.dynamic}")
        stage = runtime_support.invoke_runtime_function("runtime/stage", "stage_add_param", stage, f"debug={options.debug}")
        control_enabled = options.fullgraph or options.dynamic or options.mode != "default"
        if control_enabled:
            stage = runtime_support.invoke_runtime_function("runtime/stage", "stage_set_control_enabled", stage, True)
            stage = runtime_support.invoke_runtime_function("runtime/stage", "stage_add_control_param", stage, f"backend={options.backend}")
            stage = runtime_support.invoke_runtime_function("runtime/stage", "stage_add_control_param", stage, f"mode={options.mode}")
            stage = runtime_support.invoke_runtime_function("runtime/stage", "stage_add_control_param", stage, f"fullgraph={options.fullgraph}")
            stage = runtime_support.invoke_runtime_function("runtime/stage", "stage_add_control_param", stage, f"dynamic={options.dynamic}")
            stage = runtime_support.invoke_runtime_function("runtime/stage", "stage_add_control_param", stage, f"debug={options.debug}")
            if options.fullgraph or options.dynamic:
                stage = runtime_support.invoke_runtime_function("runtime/stage", "stage_set_control_cond_enabled", stage, True)
                stage = runtime_support.invoke_runtime_function("runtime/stage", "stage_add_control_branch", stage, "cond")
            if options.dynamic:
                stage = runtime_support.invoke_runtime_function("runtime/stage", "stage_set_control_loop_enabled", stage, True)
                stage = runtime_support.invoke_runtime_function("runtime/stage", "stage_add_control_branch", stage, "while_loop")
                stage = runtime_support.invoke_runtime_function("runtime/stage", "stage_set_control_iterations", stage, 1)
            if options.mode == "max-autotune":
                stage = runtime_support.invoke_runtime_function("runtime/stage", "stage_set_control_scan_enabled", stage, True)
                stage = runtime_support.invoke_runtime_function("runtime/stage", "stage_add_control_branch", stage, "scan")
        stage = runtime_support.invoke_runtime_function("runtime/stage", "jit", stage)
        if options.backend == "aot":
            stage = runtime_support.invoke_runtime_function("runtime/stage", "compile", stage)
        return stage
    except Exception:
        return None


def compile_module(module, options: CompileOptions | None = None):
    opts = options or CompileOptions()
    _validate_options(opts)
    stage_state = _build_stage_state(module, opts)
    # This remains a behavior-preserving wrapper, but it now carries
    # explicit stage metadata so future JIT/AOT backends can hook in.
    return CompiledModule(module, opts, stage_state=stage_state)
