from pathlib import Path
from importlib import util


_RUNTIME_PATH = Path(__file__).resolve().parents[3] / "runtime" / "runtime.py"
_SPEC = util.spec_from_file_location("neurx_runtime_impl", _RUNTIME_PATH)
assert _SPEC is not None and _SPEC.loader is not None
_MODULE = util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(_MODULE)

for _name in dir(_MODULE):
    if _name.startswith("_"):
        continue
    globals()[_name] = getattr(_MODULE, _name)
