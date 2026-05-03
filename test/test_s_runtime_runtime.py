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
    assert any(Path(path).name == "stage.ir" for path in status["ir_files"])
    assert any(Path(path).name == "control.ir" for path in status["ir_files"])

    runtime_files = [Path(path).name for path in runtime.compiled_runtime_files()]
    assert "runtime.ir" in runtime_files
    assert "io.ir" in runtime_files
    assert "stage.ir" in runtime_files
    assert "control.ir" in runtime_files

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

    for function_name in (
        "new_stage_state",
        "stage_state_dict",
        "stage_load_state_dict",
        "stage_name",
        "stage_backend",
        "stage_mode",
        "stage_jit_enabled",
        "stage_lowered",
        "stage_compiled",
        "stage_executed",
        "stage_stage_count",
        "stage_param_count",
        "stage_has_stage",
        "stage_has_param",
        "stage_add_stage",
        "stage_add_param",
        "stage_set_jit_enabled",
        "stage_set_lowered",
        "stage_set_compiled",
        "stage_set_executed",
        "stage_clear_stages",
        "stage_clear_params",
        "stage_control_enabled",
        "stage_control_cond_enabled",
        "stage_control_loop_enabled",
        "stage_control_scan_enabled",
        "stage_control_iterations",
        "stage_control_branch_count",
        "stage_control_param_count",
        "stage_has_control_branch",
        "stage_has_control_param",
        "stage_add_control_branch",
        "stage_add_control_param",
        "stage_set_control_enabled",
        "stage_set_control_cond_enabled",
        "stage_set_control_loop_enabled",
        "stage_set_control_scan_enabled",
        "stage_set_control_iterations",
        "stage_clear_control_branches",
        "stage_clear_control_params",
        "stage_control_state_dict",
        "stage_to_control_state",
        "control_state_to_stage",
        "stage_to_transform_chain",
        "transform_chain_to_stage",
        "jit",
        "lower",
        "compile",
        "execute",
    ):
        assert runtime.supports_runtime_function("runtime/stage", function_name)

    for function_name in (
        "new_control_state",
        "control_state_dict",
        "control_load_state_dict",
        "control_name",
        "control_cond_enabled",
        "control_loop_enabled",
        "control_scan_enabled",
        "control_iterations",
        "control_branch_count",
        "control_param_count",
        "control_has_branch",
        "control_has_param",
        "control_add_branch",
        "control_add_param",
        "control_set_cond_enabled",
        "control_set_loop_enabled",
        "control_set_scan_enabled",
        "control_set_iterations",
        "control_clear_branches",
        "control_clear_params",
        "control_to_transform_chain",
        "transform_chain_to_control",
        "cond",
        "control_select",
        "while_loop",
        "scan_sum",
        "scan_prod",
        "scan",
    ):
        assert runtime.supports_runtime_function("runtime/control", function_name)


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


def test_s_runtime_stage_helpers_round_trip():
    runtime = _load_runtime_module()
    stage = runtime.invoke_runtime_function("runtime/stage", "new_stage_state", "demo", "eager", "default")
    assert stage["name"] == "demo"
    assert stage["backend"] == "eager"
    assert stage["mode"] == "default"
    assert stage["jit_enabled"] is False
    assert stage["lowered"] is False
    assert stage["compiled"] is False
    assert stage["executed"] is False
    assert stage["control_enabled"] is False
    assert stage["control_branches"] == []
    assert stage["control_params"] == []

    stage = runtime.invoke_runtime_function("runtime/stage", "stage_add_stage", stage, "jit")
    stage = runtime.invoke_runtime_function("runtime/stage", "stage_add_param", stage, "backend=eager")
    stage = runtime.invoke_runtime_function("runtime/stage", "stage_add_control_branch", stage, "cond")
    stage = runtime.invoke_runtime_function("runtime/stage", "stage_add_control_param", stage, "fullgraph=True")
    stage = runtime.invoke_runtime_function("runtime/stage", "stage_set_control_iterations", stage, 2)
    assert stage["stages"] == ["jit"]
    assert stage["params"] == ["backend=eager"]
    assert stage["control_enabled"] is True
    assert stage["control_cond_enabled"] is True
    assert stage["control_branches"] == ["cond"]
    assert stage["control_params"] == ["fullgraph=True"]
    assert stage["control_iterations"] == 2

    chain = runtime.invoke_runtime_function("runtime/stage", "stage_to_transform_chain", stage)
    assert chain["steps"] == ["jit"]
    assert chain["params"] == ["backend=eager"]
    assert chain["eqns"][-1]["primitive"] == "cond"
    assert chain["eqns"][-1]["params"] == ["fullgraph=True"]

    restored = runtime.invoke_runtime_function("runtime/stage", "transform_chain_to_stage", chain, "demo", "eager", "default")
    assert restored["stages"] == ["jit"]
    assert restored["params"] == ["backend=eager"]
    assert restored["jit_enabled"] is True
    assert restored["control_enabled"] is True
    assert restored["control_branches"] == ["cond"]
    assert restored["control_params"] == ["fullgraph=True"]
    assert restored["control_cond_enabled"] is True

    control = runtime.invoke_runtime_function("runtime/stage", "stage_to_control_state", stage)
    assert control["branches"] == ["cond"]
    assert control["params"] == ["fullgraph=True"]
    assert control["cond_enabled"] is True
    assert control["iterations"] == 2

    stage_from_control = runtime.invoke_runtime_function("runtime/stage", "control_state_to_stage", control, "eager", "default")
    assert stage_from_control["control_enabled"] is True
    assert stage_from_control["control_branches"] == ["cond"]
    assert stage_from_control["control_params"] == ["fullgraph=True"]

    stage = runtime.invoke_runtime_function("runtime/stage", "lower", stage)
    assert stage["lowered"] is True
    stage = runtime.invoke_runtime_function("runtime/stage", "compile", stage)
    assert stage["compiled"] is True
    stage = runtime.invoke_runtime_function("runtime/stage", "execute", stage)
    assert stage["executed"] is True


def test_s_runtime_control_helpers_round_trip():
    runtime = _load_runtime_module()
    control = runtime.invoke_runtime_function("runtime/control", "new_control_state", "demo", 4)
    assert control["name"] == "demo"
    assert control["iterations"] == 4
    assert control["cond_enabled"] is False
    assert control["loop_enabled"] is False
    assert control["scan_enabled"] is False

    control = runtime.invoke_runtime_function("runtime/control", "control_add_branch", control, "cond")
    control = runtime.invoke_runtime_function("runtime/control", "control_add_param", control, "predicate=True")
    assert control["branches"] == ["cond"]
    assert control["params"] == ["predicate=True"]

    chain = runtime.invoke_runtime_function("runtime/control", "control_to_transform_chain", control)
    assert chain["steps"] == ["cond"]
    assert chain["params"] == ["predicate=True"]

    restored = runtime.invoke_runtime_function("runtime/control", "transform_chain_to_control", chain, "demo", 4)
    assert restored["branches"] == ["cond"]
    assert restored["params"] == ["predicate=True"]
    assert restored["cond_enabled"] is True

    cond_true = {"data": [1.0, 2.0], "shape": [2], "requires_grad": False, "grad": None}
    cond_false = {"data": [3.0, 4.0], "shape": [2], "requires_grad": False, "grad": None}
    selected = runtime.invoke_runtime_function("runtime/control", "cond", control, True, cond_true, cond_false)
    assert list(selected["data"]) == [1.0, 2.0]
    selected = runtime.invoke_runtime_function("runtime/control", "control_select", control, False, cond_true, cond_false)
    assert list(selected["data"]) == [3.0, 4.0]

    scanned = runtime.invoke_runtime_function("runtime/control", "scan_sum", control, {"data": [1.0, 2.0, 3.0], "shape": [3], "requires_grad": False, "grad": None})
    assert list(scanned["data"]) == [1.0, 3.0, 6.0]

    scanned_prod = runtime.invoke_runtime_function("runtime/control", "scan_prod", control, {"data": [1.0, 2.0, 3.0], "shape": [3], "requires_grad": False, "grad": None})
    assert list(scanned_prod["data"]) == [1.0, 2.0, 6.0]

    stepped = runtime.invoke_runtime_function("runtime/control", "while_loop", control, cond_true, 3, "add")
    assert list(stepped["data"]) == [4.0, 5.0]


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
