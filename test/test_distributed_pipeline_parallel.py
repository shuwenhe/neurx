import numpy as np

from neurx.distributed.pipeline import PipelineParallel


def test_pipeline_parallel_gpipe_numpy_batches():
    def model(x):
        return x + 1.0

    pp = PipelineParallel(model=model, num_stages=2, strategy="gpipe", chunks=3)
    x = np.arange(12, dtype=np.float32).reshape(6, 2)
    y = pp(x)

    assert isinstance(y, np.ndarray)
    assert y.shape == x.shape
    assert np.allclose(y, x + 1.0)

    state = pp.state_dict()
    assert int(state.get("step", 0)) >= 3
    assert int(state.get("microbatch_id", 0)) in (0, 1, 2)


def test_pipeline_parallel_stop_and_resume():
    def model(x):
        return x

    pp = PipelineParallel(model=model, num_stages=2, chunks=2)
    pp.stop()
    state = pp.state_dict()
    assert bool(state.get("active", False)) is False

    pp.resume()
    state = pp.state_dict()
    assert bool(state.get("active", False)) is True
