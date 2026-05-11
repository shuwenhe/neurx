from __future__ import annotations

from typing import Any

import numpy as np

from neurx.compile import runtime as _runtime


def _as_int(value: Any, fallback: int) -> int:
    try:
        parsed = int(value)
    except Exception:
        parsed = fallback
    return parsed if parsed > 0 else fallback


def _runtime_pp_available() -> bool:
    try:
        return _runtime.supports_runtime_function("runtime/pp", "new_pipeline_parallel_state")
    except Exception:
        return False


class PipelineParallel:
    def __init__(
        self,
        model: Any,
        num_stages: int,
        strategy: str = "gpipe",
        chunks: int = 1,
        stage_id: int = 0,
        world_size: int = 1,
        rank: int = 0,
        name: str = "pipeline_parallel",
    ):
        if not callable(model):
            raise TypeError("model must be callable")
        self.model = model
        self.num_stages = _as_int(num_stages, 1)
        self.chunks = _as_int(chunks, 1)
        self.strategy = str(strategy or "gpipe")
        self.stage_id = max(0, min(int(stage_id), self.num_stages - 1))
        self.world_size = _as_int(world_size, 1)
        self.rank = max(0, min(int(rank), self.world_size - 1))
        self.name = str(name or "pipeline_parallel")
        self._runtime_pp = _runtime_pp_available()

        if self._runtime_pp:
            state = _runtime.invoke_runtime_function(
                "runtime/pp",
                "new_pipeline_parallel_state",
                self.name,
                self.strategy,
                self.num_stages,
                self.chunks,
                self.stage_id,
                self.world_size,
                self.rank,
            )
            state = _runtime.invoke_runtime_function("runtime/pp", "pp_assign_default_stage_ranks", state)
            self._state = _runtime.invoke_runtime_function("runtime/pp", "pp_prepare_schedule", state)
        else:
            self._state = {
                "name": self.name,
                "strategy": self.strategy,
                "num_stages": self.num_stages,
                "chunks": self.chunks,
                "stage_id": self.stage_id,
                "world_size": self.world_size,
                "rank": self.rank,
                "microbatch_id": 0,
                "step": 0,
                "active": True,
                "warmup_done": False,
                "flush_done": False,
                "stages": [],
                "stage_ranks": [i % self.world_size for i in range(self.num_stages)],
                "schedule": ["forward"] * self.chunks + ["backward"] * self.chunks,
            }

    def _advance(self) -> None:
        if self._runtime_pp:
            self._state = _runtime.invoke_runtime_function("runtime/pp", "pp_next_microbatch", self._state)
            return
        if not self._state.get("active", True):
            return
        next_microbatch = int(self._state.get("microbatch_id", 0)) + 1
        if next_microbatch >= self.chunks:
            next_microbatch = 0
        step = int(self._state.get("step", 0)) + 1
        self._state["microbatch_id"] = next_microbatch
        self._state["step"] = step
        self._state["warmup_done"] = step >= self.num_stages - 1
        self._state["flush_done"] = step >= (self.num_stages + 2 * self.chunks - 2)

    def _run_gpipe(self, inputs: Any, *args: Any, **kwargs: Any) -> Any:
        if not isinstance(inputs, np.ndarray) or inputs.ndim == 0:
            output = self.model(inputs, *args, **kwargs)
            self._advance()
            return output

        micro_batches = np.array_split(inputs, self.chunks, axis=0)
        outputs: list[Any] = []
        for batch in micro_batches:
            outputs.append(self.model(batch, *args, **kwargs))
            self._advance()

        if outputs and all(isinstance(item, np.ndarray) for item in outputs):
            return np.concatenate(outputs, axis=0)
        return outputs

    def forward(self, inputs: Any, *args: Any, **kwargs: Any) -> Any:
        if self.strategy == "gpipe":
            return self._run_gpipe(inputs, *args, **kwargs)
        return self._run_gpipe(inputs, *args, **kwargs)

    def __call__(self, inputs: Any, *args: Any, **kwargs: Any) -> Any:
        return self.forward(inputs, *args, **kwargs)

    def state_dict(self) -> dict[str, Any]:
        if self._runtime_pp:
            return _runtime.invoke_runtime_function("runtime/pp", "pipeline_parallel_state_dict", self._state)
        return dict(self._state)

    def load_state_dict(self, state: dict[str, Any]) -> dict[str, Any]:
        if self._runtime_pp:
            self._state = _runtime.invoke_runtime_function("runtime/pp", "pipeline_parallel_load_state_dict", self._state, state)
        else:
            self._state = dict(state)
        return self._state

    def stop(self) -> None:
        if self._runtime_pp:
            self._state = _runtime.invoke_runtime_function("runtime/pp", "pp_stop", self._state)
        else:
            self._state["active"] = False

    def resume(self) -> None:
        if self._runtime_pp:
            self._state = _runtime.invoke_runtime_function("runtime/pp", "pp_resume", self._state)
        else:
            self._state["active"] = True
