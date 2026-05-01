from __future__ import annotations

from functools import lru_cache
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import sys


@lru_cache(maxsize=1)
def load_root_opt_package():
    root_dir = Path(__file__).resolve().parents[3] / "opt"
    init_path = root_dir / "__init__.py"
    spec = spec_from_file_location(
        "neurx_root_opt",
        init_path,
        submodule_search_locations=[str(root_dir)],
    )
    module = module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module
