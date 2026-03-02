from __future__ import annotations

from dataclasses import dataclass

from tensor.platform.errors import ConfigurationError

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
    def __init__(self, module, options: CompileOptions):
        self.module = module
        self.options = options

    def __call__(self, *args, **kwargs):
        return self.module(*args, **kwargs)

    def __getattr__(self, name):
        return getattr(self.module, name)


def compile_module(module, options: CompileOptions | None = None):
    opts = options or CompileOptions()
    _validate_options(opts)
    # This is currently a safe no-op wrapper. It preserves module behavior
    # while keeping an explicit API boundary for future AOT/JIT backends.
    return CompiledModule(module, opts)

