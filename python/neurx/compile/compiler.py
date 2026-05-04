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


def _shape_list(value) -> list[int]:
    shape = getattr(value, "shape", None)
    if shape is None:
        return []
    return [int(dim) for dim in shape]


def _scalar_text(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float, str)):
        return str(value)
    if hasattr(value, "shape"):
        shape = _shape_list(value)
        dtype = getattr(value, "dtype", None)
        dtype_text = str(dtype) if dtype is not None else "unknown"
        return f"shape={shape},dtype={dtype_text}"
    return repr(value)


def _module_signature(module) -> str:
    return module.__class__.__name__.lower()


def _local_module_params(module) -> list[str]:
    params: list[str] = []
    for name, value in module.__dict__.items():
        if name.startswith("_"):
            continue
        if hasattr(value, "requires_grad"):
            params.append(f"{name}:shape={_shape_list(value)}")
    return params


def _local_module_attrs(module) -> list[str]:
    attrs: list[str] = []
    interesting = (
        "in_features",
        "out_features",
        "input_size",
        "hidden_size",
        "embed_dim",
        "num_heads",
        "n_embd",
        "n_heads",
        "hidden_dim",
        "dropout_p",
        "dropout",
        "kernel_size",
        "stride",
        "padding",
        "dilation",
        "groups",
        "use_moe",
        "use_rmsnorm",
        "use_swiglu",
        "use_rope",
        "moe_num_experts",
        "moe_top_k",
    )
    for name in interesting:
        if hasattr(module, name):
            value = getattr(module, name)
            if isinstance(value, (bool, int, float, str, tuple, list)):
                attrs.append(f"{name}={_scalar_text(value)}")
    return attrs


def _module_capture_params(module) -> list[str]:
    params = _local_module_attrs(module)
    params.extend(_local_module_params(module))
    return params


def _capture_module_graph(
    graph: dict[str, object],
    module,
    runtime_support,
    path: str = "root",
    parent_path: str | None = None,
    seen: set[int] | None = None,
) -> None:
    if seen is None:
        seen = set()
    module_id = id(module)
    if module_id in seen:
        return
    seen.add(module_id)

    node_name = path
    op_name = _module_signature(module)
    params = _module_capture_params(module)

    graph["state"] = runtime_support.invoke_runtime_function(
        "runtime/compile",
        "compile_add_node_with_io",
        graph["state"],
        node_name,
        op_name,
        params,
        [],
        [],
    )
    if parent_path is not None:
        graph["state"] = runtime_support.invoke_runtime_function(
            "runtime/compile",
            "compile_add_edge",
            graph["state"],
            f"{parent_path}->{node_name}",
        )

    for child_name, child in getattr(module, "named_children", lambda: [])():
        child_path = f"{path}.{child_name}"
        _capture_module_graph(graph, child, runtime_support, child_path, node_name, seen)


def _build_compile_state(module, options: CompileOptions):
    try:
        from neurx.compile import runtime as runtime_support

        if not runtime_support.supports_runtime_function("runtime/compile", "new_compile_state"):
            return None
        graph = runtime_support.invoke_runtime_function(
            "runtime/compile",
            "new_compile_state",
            module.__class__.__name__.lower(),
            options.backend,
            options.mode,
        )
        graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_set_captured", graph, True)
        graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_set_fullgraph", graph, options.fullgraph)
        graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_set_dynamic", graph, options.dynamic)
        graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_set_debug", graph, options.debug)
        graph = runtime_support.invoke_runtime_function(
            "runtime/compile",
            "compile_add_cache_key",
            graph,
            f"{module.__class__.__name__.lower()}|{options.backend}|{options.mode}|fg={options.fullgraph}|dyn={options.dynamic}|dbg={options.debug}",
        )
        graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_add_input", graph, "input_0")
        graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_add_output", graph, "output_0")
        graph = {"state": graph}
        _capture_module_graph(graph, module, runtime_support)
        graph = graph["state"]
        graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_add_pass", graph, "capture")
        if options.mode == "max-autotune":
            graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_add_pass", graph, "autotune")
        if runtime_support.supports_runtime_function("runtime/compile", "compile_normalize"):
            graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_normalize", graph)
        else:
            graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_add_pass", graph, "normalize")
        if runtime_support.supports_runtime_function("runtime/compile", "compile_shape_specialize"):
            graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_shape_specialize", graph)
        else:
            graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_add_pass", graph, "shape_specialize")
        if runtime_support.supports_runtime_function("runtime/compile", "compile_fuse_linear_activation"):
            graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_fuse_linear_activation", graph)
        else:
            graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_add_pass", graph, "fuse_linear_activation")
        if options.backend == "aot":
            if runtime_support.supports_runtime_function("runtime/compile", "compile_linearize"):
                graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_linearize", graph)
            else:
                graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_add_pass", graph, "linearize")
            if runtime_support.supports_runtime_function("runtime/compile", "compile_lower_graph"):
                graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_lower_graph", graph)
            else:
                graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_add_pass", graph, "lower_graph")
            graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_add_pass", graph, "lower")
        graph = runtime_support.invoke_runtime_function(
            "runtime/compile",
            "compile_set_lowered",
            graph,
            bool(options.backend == "aot"),
        )
        graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_set_compiled", graph, bool(options.backend == "aot"))
        graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_set_executed", graph, False)

        if options.fullgraph or options.dynamic or options.mode != "default":
            graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_add_tag", graph, f"backend={options.backend}")
            graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_add_tag", graph, f"mode={options.mode}")
        if options.fullgraph or options.dynamic:
            graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_add_tag", graph, "cond")
        if options.dynamic:
            graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_add_tag", graph, "while_loop")
        if options.mode == "max-autotune":
            graph = runtime_support.invoke_runtime_function("runtime/compile", "compile_add_tag", graph, "scan")
        return graph
    except Exception:
        return None


class CompiledModule:
    def __init__(self, module, options: CompileOptions, stage_state=None, compile_state=None):
        self.module = module
        self.options = options
        self.stage_state = stage_state
        self.compile_state = compile_state

    def __call__(self, *args, **kwargs):
        result = self.module(*args, **kwargs)
        if self.stage_state is not None or self.compile_state is not None:
            try:
                from neurx.compile import runtime as runtime_support

                if runtime_support.supports_runtime_function("runtime/stage", "execute"):
                    if self.stage_state is not None:
                        self.stage_state = runtime_support.invoke_runtime_function("runtime/stage", "execute", self.stage_state)
            except Exception:
                pass
        if self.compile_state is not None:
            self.compile_state["executed"] = True
            if "execute" not in self.compile_state.setdefault("passes", []):
                self.compile_state["passes"].append("execute")
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

    @property
    def graph_ready(self) -> bool:
        return bool(self.compile_state and self.compile_state.get("ready", False))

    @property
    def graph_linearized(self) -> bool:
        return bool(self.compile_state and self.compile_state.get("linearized", False))

    @property
    def graph_node_count(self) -> int:
        return int(self.compile_state.get("node_count", 0)) if self.compile_state else 0

    @property
    def graph_edge_count(self) -> int:
        return len(self.compile_state.get("edges", [])) if self.compile_state else 0

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
            "compile_state": self.compile_state,
            "compiled": self.compiled,
            "lowered": self.lowered,
            "executed": self.executed,
            "graph_ready": self.graph_ready,
            "graph_linearized": self.graph_linearized,
            "graph_node_count": self.graph_node_count,
            "graph_edge_count": self.graph_edge_count,
        }

    def load_state_dict(self, state: dict[str, object]):
        self.stage_state = state.get("stage_state", self.stage_state)
        self.compile_state = state.get("compile_state", self.compile_state)
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
    compile_state = _build_compile_state(module, opts)
    # This remains a behavior-preserving wrapper, but it now carries
    # explicit stage metadata so future JIT/AOT backends can hook in.
    return CompiledModule(module, opts, stage_state=stage_state, compile_state=compile_state)
