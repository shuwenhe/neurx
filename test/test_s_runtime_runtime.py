from importlib import util
from pathlib import Path


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_s_runtime_compiled_functions_present():
    runtime = _load_runtime_module()
    status = runtime.runtime_status()
    assert status["available"] is True
    assert status["ready"] is True
    assert any(Path(path).name == "runtime.ir" for path in status["ir_files"])
    assert any(Path(path).name == "io.ir" for path in status["ir_files"])

    runtime_files = [Path(path).name for path in runtime.compiled_runtime_files()]
    assert "runtime.ir" in runtime_files
    assert "io.ir" in runtime_files

    for function_name in (
        "new_runtime_state",
        "runtime_state_dict",
        "runtime_state_load_state_dict",
        "runtime_available",
        "ops_runtime_enabled",
        "runtime_artifact_root",
        "runtime_ir_files",
        "runtime_ir_count",
        "runtime_has_ir_files",
        "runtime_is_ready",
        "runtime_ir_paths",
        "runtime_status",
    ):
        assert runtime.supports_runtime_function("runtime", function_name)


def test_s_runtime_state_helpers_round_trip():
    runtime = _load_runtime_module()
    state = {
        "available": True,
        "ops_backend_enabled": True,
        "artifact_root": "/tmp/ir",
        "ir_files": ["ops.ir", "tensor.ir"],
    }
    other = {
        "available": False,
        "ops_backend_enabled": False,
        "artifact_root": "/var/ir",
        "ir_files": ["runtime.ir"],
    }

    assert runtime.invoke_runtime_function("runtime", "runtime_state_dict", state) is state
    assert runtime.invoke_runtime_function("runtime", "runtime_state_load_state_dict", state, other) is other
    assert runtime.invoke_runtime_function("runtime", "runtime_available", state) is True
    assert runtime.invoke_runtime_function("runtime", "ops_runtime_enabled", state) is True
    assert runtime.invoke_runtime_function("runtime", "runtime_artifact_root", state) == "/tmp/ir"
    assert runtime.invoke_runtime_function("runtime", "runtime_ir_files", state) is state["ir_files"]
    assert runtime.invoke_runtime_function("runtime", "runtime_ir_count", state) == 2
    assert runtime.invoke_runtime_function("runtime", "runtime_has_ir_files", state) is True
    assert runtime.invoke_runtime_function("runtime", "runtime_is_ready", state) is True
    assert runtime.invoke_runtime_function("runtime", "runtime_ir_paths", state) is state["ir_files"]
    assert runtime.invoke_runtime_function("runtime", "runtime_status", state) is state


def test_s_runtime_io_env_and_json_helpers(tmp_path, monkeypatch):
    runtime = _load_runtime_module()
    text_path = tmp_path / "runtime.txt"
    json_path = tmp_path / "runtime.json"
    monkeypatch.setenv("NEURX_RUNTIME_TEST_TOKEN", "ready")

    assert runtime.invoke_runtime_function("runtime", "runtime_write_text_file", str(text_path), "hello") is None
    assert runtime.invoke_runtime_function("runtime", "runtime_file_exists", str(text_path)) is True
    assert runtime.invoke_runtime_function("runtime", "runtime_read_text_file", str(text_path)) == "hello"

    assert runtime.invoke_runtime_function("runtime", "runtime_append_text_file", str(text_path), " world") is None
    assert runtime.invoke_runtime_function("runtime", "runtime_read_text_file", str(text_path)) == "hello world"

    assert runtime.invoke_runtime_function("runtime", "runtime_env_has", "NEURX_RUNTIME_TEST_TOKEN") is True
    assert runtime.invoke_runtime_function("runtime", "runtime_env_get", "NEURX_RUNTIME_TEST_TOKEN", "missing") == "ready"
    assert runtime.invoke_runtime_function("runtime", "runtime_env_get", "NEURX_RUNTIME_UNKNOWN", "missing") == "missing"

    payload = {"name": "neurx", "enabled": True, "count": 3}
    io_module = "runtime/io"

    for function_name in (
        "runtime_read_text_file",
        "runtime_write_text_file",
        "runtime_append_text_file",
        "runtime_file_exists",
        "runtime_env_get",
        "runtime_env_has",
        "runtime_json_parse",
        "runtime_json_stringify",
        "runtime_read_json_file",
        "runtime_write_json_file",
    ):
        assert runtime.supports_runtime_function(io_module, function_name)

    parsed = runtime.invoke_runtime_function(io_module, "runtime_json_parse", '{"name":"neurx","enabled":true,"count":3}')
    assert parsed == payload
    assert runtime.invoke_runtime_function(io_module, "runtime_json_stringify", payload) == '{"name": "neurx", "enabled": true, "count": 3}'

    assert runtime.invoke_runtime_function(io_module, "runtime_write_json_file", str(json_path), payload) is None
    assert runtime.invoke_runtime_function(io_module, "runtime_read_json_file", str(json_path)) == payload
