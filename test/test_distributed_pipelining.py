from importlib import util
from pathlib import Path

from neurx.distributed.pipelining import (
    Schedule1F1B,
    ScheduleGPipe,
    SplitPoint,
    build_stage,
    pipe_split,
    pipeline,
)


def _load_runtime_module():
    runtime_path = Path(__file__).resolve().parents[1] / "python" / "neurx" / "compile" / "runtime.py"
    spec = util.spec_from_file_location("neurx_runtime", runtime_path)
    module = util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_distributed_pipelining_python_api_round_trip():
    assert SplitPoint.BEGINNING == "beginning"
    assert SplitPoint.END == "end"
    assert pipe_split("encoder") == "encoder"

    plan = pipeline(name="demo", num_stages=4, chunks=8, strategy="gpipe")
    plan.add_split_point("layer.3")
    stage = build_stage(plan, stage_index=1, rank=1, world_size=4, device="cpu")
    plan.add_stage(stage)

    assert int(plan.state.get("num_stages", 0)) == 4
    assert int(plan.state.get("chunks", 0)) == 8
    assert len(plan.state.get("split_points", [])) >= 1
    assert len(plan.state.get("stages", [])) >= 1

    gpipe = ScheduleGPipe(plan, stage_index=1)
    state = gpipe.step()
    assert int(state.get("step", 0)) == 1
    assert int(gpipe.stage_index) == 1

    onef1b_plan = pipeline(name="demo-1f1b", num_stages=2, chunks=4, strategy="1f1b")
    onef1b_stage = build_stage(onef1b_plan, stage_index=1, rank=1, world_size=2, device="cpu")
    onef1b = Schedule1F1B(onef1b_stage, n_microbatches=4)
    state = onef1b.step()
    assert int(state.get("step", 0)) == 1
    assert int(onef1b.total_ops) > 0


def test_distributed_pipelining_runtime_module_if_compiled():
    runtime = _load_runtime_module()
    if not runtime.supports_runtime_function("distributed/pipelining", "new_pipeline_plan"):
        return

    plan = runtime.invoke_runtime_function(
        "distributed/pipelining", "new_pipeline_plan", "demo", "gpipe", 4, 8
    )
    assert plan["name"] == "demo"
    assert plan["strategy"] == "gpipe"

    plan = runtime.invoke_runtime_function(
        "distributed/pipelining", "pipeline_add_split_point", plan, "layer.3"
    )
    assert runtime.invoke_runtime_function("distributed/pipelining", "pipeline_split_count", plan) == 1

    stage = runtime.invoke_runtime_function(
        "distributed/pipelining", "build_stage", plan, 1, 1, 4, "cpu"
    )
    assert stage["stage_index"] == 1
    assert stage["rank"] == 1
    assert runtime.invoke_runtime_function("distributed/pipelining", "pipeline_stage_is_first", stage) is False

    plan = runtime.invoke_runtime_function("distributed/pipelining", "pipeline_add_stage", plan, stage)
    assert runtime.invoke_runtime_function("distributed/pipelining", "pipeline_stage_count", plan) == 1

    sched = runtime.invoke_runtime_function("distributed/pipelining", "new_schedule_gpipe", plan)
    assert runtime.invoke_runtime_function("distributed/pipelining", "schedule_ops_count", sched) == 16
    assert runtime.invoke_runtime_function("distributed/pipelining", "schedule_current_op", sched) == "forward"

    sched = runtime.invoke_runtime_function("distributed/pipelining", "schedule_next", sched)
    assert runtime.invoke_runtime_function("distributed/pipelining", "schedule_step_index", sched) == 1

    warmup = runtime.invoke_runtime_function("distributed/pipelining", "schedule_warmup_steps", plan, 1)
    steady = runtime.invoke_runtime_function("distributed/pipelining", "schedule_steady_steps", plan, 1)
    flush = runtime.invoke_runtime_function("distributed/pipelining", "schedule_flush_steps", plan, 1)
    assert warmup >= 0
    assert steady >= 1
    assert flush >= 0

    sched_1f1b = runtime.invoke_runtime_function("distributed/pipelining", "new_schedule_1f1b", plan, 1)
    assert runtime.invoke_runtime_function("distributed/pipelining", "schedule_stage_index", sched_1f1b) == 1
    assert runtime.invoke_runtime_function("distributed/pipelining", "schedule_total_ops", sched_1f1b) == len(sched_1f1b["ops"])
