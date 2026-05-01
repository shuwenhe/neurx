from __future__ import annotations

from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[3] / "ad" / "function.py"
_SPEC = spec_from_file_location("neurx_root_ad_function", _ROOT)
_MODULE = module_from_spec(_SPEC)
assert _SPEC.loader is not None
_SPEC.loader.exec_module(_MODULE)

Function = _MODULE.Function

__all__ = ["Function"]
