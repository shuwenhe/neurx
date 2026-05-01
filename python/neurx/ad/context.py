from __future__ import annotations

from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[3] / "ad" / "context.py"
_SPEC = spec_from_file_location("neurx_root_ad_context", _ROOT)
_MODULE = module_from_spec(_SPEC)
assert _SPEC.loader is not None
_SPEC.loader.exec_module(_MODULE)

enable_grad = _MODULE.enable_grad
get_gradient_accumulation = _MODULE.get_gradient_accumulation
gradient_accumulation = _MODULE.gradient_accumulation
is_grad_accumulation_enabled = _MODULE.is_grad_accumulation_enabled
is_grad_enabled = _MODULE.is_grad_enabled
no_grad = _MODULE.no_grad
set_detect_anomaly = _MODULE.set_detect_anomaly
set_grad_enabled = _MODULE.set_grad_enabled
set_gradient_accumulation = _MODULE.set_gradient_accumulation

__all__ = list(_MODULE.__all__)
