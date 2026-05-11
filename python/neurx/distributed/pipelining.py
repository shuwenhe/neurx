from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from neurx.compile import runtime as _runtime


def _available() -> bool:
    try:
        return _runtime.supports_runtime_function("distributed/pipelining", "new_pipeline_plan")
    except Exception:
        return False


class SplitPoint:
    BEGINNING = "beginning"
    END = "end"


def pipe_split(marker: str) -> str:
    if _available():
        return str(_runtime.invoke_runtime_function("distributed/pipelining", "pipe_split", marker))
    return str(marker)


@dataclass
class PipelineStage:
    state: dict[str, Any]

    @property
    def stage_index(self) -> int:
        return int(self.state.get("stage_index", 0))

    @property
    def rank(self) -> int:
        return int(self.state.get("rank", 0))


class PipelinePlan:
    def __init__(self, state: dict[str, Any]):
        self.state = dict(state)

    def add_split_point(self, split_point: str) -> "PipelinePlan":
        if _available():
            self.state = _runtime.invoke_runtime_function(
                "distributed/pipelining", "pipeline_add_split_point", self.state, split_point
            )
        else:
            self.state.setdefault("split_points", []).append(str(split_point))
        return self

    def add_stage(self, stage: PipelineStage) -> "PipelinePlan":
        if _available():
            self.state = _runtime.invoke_runtime_function(
                "distributed/pipelining", "pipeline_add_stage", self.state, stage.state
            )
        else:
            self.state.setdefault("stages", []).append(dict(stage.state))
        return self

    def with_default_stages(self, world_size: int = 1, device: str = "cpu") -> "PipelinePlan":
        if _available():
            self.state = _runtime.invoke_runtime_function(
                "distributed/pipelining", "pipeline_with_default_stages", self.state, int(world_size), str(device)
            )
        else:
            num_stages = int(self.state.get("num_stages", 1))
            stages = []
            world = max(1, int(world_size))
            for i in range(num_stages):
                stages.append(
                    {
                        "name": f"stage_{i}",
                        "stage_index": i,
                        "num_stages": num_stages,
                        "rank": i % world,
                        "world_size": world,
                        "device": device,
                        "first": i == 0,
                        "last": i == num_stages - 1,
                        "inputs": [],
                        "outputs": [],
                    }
                )
            self.state["stages"] = stages
        return self


class PipelineSchedule:
    def __init__(self, state: dict[str, Any]):
        self.state = dict(state)

    def step(self) -> dict[str, Any]:
        if _available():
            self.state = _runtime.invoke_runtime_function("distributed/pipelining", "schedule_next", self.state)
        else:
            self.state["step"] = int(self.state.get("step", 0)) + 1
        return self.state

    def state_dict(self) -> dict[str, Any]:
        if _available():
            return _runtime.invoke_runtime_function("distributed/pipelining", "schedule_state_dict", self.state)
        return dict(self.state)

    @property
    def stage_index(self) -> int:
        return int(self.state.get("stage_index", 0))

    @property
    def total_ops(self) -> int:
        return len(self.state.get("ops", []))


def _resolve_plan_and_stage_index(
    target: PipelinePlan | PipelineStage,
    stage_index: int | None,
    n_microbatches: int | None,
) -> tuple[PipelinePlan, int]:
    if isinstance(target, PipelineStage):
        inferred_chunks = max(1, int(n_microbatches or 1))
        plan = pipeline(
            name=str(target.state.get("name", "pipeline")),
            num_stages=int(target.state.get("num_stages", 1)),
            chunks=inferred_chunks,
            strategy="gpipe",
        )
        plan.add_stage(target)
        resolved_stage_index = int(target.state.get("stage_index", 0)) if stage_index is None else int(stage_index)
        return plan, resolved_stage_index
    resolved_stage_index = int(stage_index or 0)
    if n_microbatches is not None and int(target.state.get("chunks", 1)) != int(n_microbatches):
        target.state["chunks"] = max(1, int(n_microbatches))
    return target, resolved_stage_index


class ScheduleGPipe(PipelineSchedule):
    def __init__(self, target: PipelinePlan | PipelineStage, n_microbatches: int | None = None, stage_index: int | None = None):
        plan, resolved_stage_index = _resolve_plan_and_stage_index(target, stage_index, n_microbatches)
        if _available():
            state = _runtime.invoke_runtime_function(
                "distributed/pipelining", "new_schedule_gpipe", plan.state, int(resolved_stage_index)
            )
        else:
            chunks = int(plan.state.get("chunks", 1))
            state = {
                "plan": dict(plan.state),
                "stage_index": int(resolved_stage_index),
                "step": 0,
                "microbatch_id": 0,
                "ops": ["forward"] * chunks + ["backward"] * chunks,
                "warmup_done": False,
                "flush_done": False,
                "active": True,
            }
        super().__init__(state)


class Schedule1F1B(PipelineSchedule):
    def __init__(self, target: PipelinePlan | PipelineStage, n_microbatches: int | None = None, stage_index: int | None = None):
        plan, resolved_stage_index = _resolve_plan_and_stage_index(target, stage_index, n_microbatches)
        if _available():
            state = _runtime.invoke_runtime_function(
                "distributed/pipelining", "new_schedule_1f1b", plan.state, int(resolved_stage_index)
            )
        else:
            chunks = int(plan.state.get("chunks", 1))
            num_stages = int(plan.state.get("num_stages", 1))
            warmup = max(0, min(num_stages - int(resolved_stage_index) - 1, chunks - 1))
            steady = max(1, chunks - warmup)
            flush = warmup
            state = {
                "plan": dict(plan.state),
                "stage_index": int(resolved_stage_index),
                "step": 0,
                "microbatch_id": 0,
                "ops": ["forward"] * warmup + ["fwd_bwd"] * steady + ["backward"] * flush,
                "warmup_done": warmup == 0,
                "flush_done": False,
                "active": True,
            }
        super().__init__(state)


def build_stage(plan: PipelinePlan, stage_index: int, rank: int, world_size: int, device: str = "cpu") -> PipelineStage:
    if _available():
        state = _runtime.invoke_runtime_function(
            "distributed/pipelining", "build_stage", plan.state, int(stage_index), int(rank), int(world_size), str(device)
        )
    else:
        num_stages = int(plan.state.get("num_stages", 1))
        state = {
            "name": f"stage_{stage_index}",
            "stage_index": int(stage_index),
            "num_stages": num_stages,
            "rank": int(rank),
            "world_size": int(world_size),
            "device": str(device),
            "first": int(stage_index) == 0,
            "last": int(stage_index) == num_stages - 1,
            "inputs": [],
            "outputs": [],
        }
    return PipelineStage(state=state)


def pipeline(name: str, num_stages: int, chunks: int, strategy: str = "gpipe") -> PipelinePlan:
    if _available():
        state = _runtime.invoke_runtime_function(
            "distributed/pipelining", "new_pipeline_plan", str(name), str(strategy), int(num_stages), int(chunks)
        )
    else:
        state = {
            "name": str(name),
            "strategy": str(strategy),
            "num_stages": max(1, int(num_stages)),
            "chunks": max(1, int(chunks)),
            "split_points": [],
            "stages": [],
        }
    return PipelinePlan(state)
