from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_serving_serve_runtime_smoke():
    runtime = _load_runtime_module()

    if not runtime.supports_runtime_function("serving/serve/serve", "new_infer_request_state"):
        return

    request = runtime.invoke_runtime_function("serving/serve/serve", "new_infer_request_state", "req-1", "demo", 8, 16)
    response = runtime.invoke_runtime_function("serving/serve/serve", "new_infer_response_state", "req-1")
    updated = runtime.invoke_runtime_function("serving/serve/serve", "infer_response_update", response, 4, True, 200)

    assert request["request_id"] == "req-1"
    assert request["model"] == "demo"
    assert response["finished"] is False
    assert updated["output_tokens"] == 4
    assert updated["finished"] is True
