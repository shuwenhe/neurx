from ._compat import load_root_opt_package

_mod = load_root_opt_package()

for name in getattr(_mod, "__all__", []):
    globals()[name] = getattr(_mod, name)

__all__ = list(getattr(_mod, "__all__", []))
