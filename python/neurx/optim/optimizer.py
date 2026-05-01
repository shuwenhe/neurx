from ._compat import load_root_opt_package

_mod = load_root_opt_package()

Optimizer = _mod.Optimizer

__all__ = ["Optimizer"]
