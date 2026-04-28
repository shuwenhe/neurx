import multiprocessing as mp
import os
import socket

import numpy as np
import pytest



def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])



def _worker(rank: int, world_size: int, port: int, queue: "mp.Queue") -> None:
    os.environ["MASTER_ADDR"] = "127.0.0.1"
    os.environ["MASTER_PORT"] = str(port)
    os.environ["RANK"] = str(rank)
    os.environ["LOCAL_RANK"] = str(rank)
    os.environ["WORLD_SIZE"] = str(world_size)
    os.environ["TENSOR_DIST_BACKEND"] = "gloo"

    from neurx.nn import distributed as dist

    try:
        dist.init_process_group(backend="gloo")
        summed = dist.all_reduce(np.array([rank + 1], dtype=np.float32), operation="sum")
        meaned = dist.all_reduce(np.array([rank + 1], dtype=np.float32), operation="mean")
        src = np.array([42], dtype=np.int32) if rank == 0 else np.array([-1], dtype=np.int32)
        bcast = dist.broadcast(src, src=0)
        dist.barrier()
        queue.put((rank, float(summed[0]), float(meaned[0]), int(bcast[0])))
    except Exception as exc:
        queue.put((rank, "error", repr(exc)))
    finally:
        dist.destroy_process_group()


@pytest.mark.skipif(os.name == "nt", reason="uses fork-style local process group setup")
def test_distributed_collectives_gloo_two_processes() -> None:
    pytest.importorskip("torch")
    import torch.distributed as torch_dist

    if not torch_dist.is_available():
        pytest.skip("torch.distributed unavailable")

    world_size = 2
    port = _free_port()
    ctx = mp.get_context("spawn")
    queue = ctx.Queue()

    processes = [
        ctx.Process(target=_worker, args=(rank, world_size, port, queue))
        for rank in range(world_size)
    ]

    for process in processes:
        process.start()

    for process in processes:
        process.join(timeout=30)
        assert process.exitcode == 0

    results = [queue.get(timeout=2) for _ in range(world_size)]
    by_rank = {item[0]: item for item in results}

    for rank in range(world_size):
        result = by_rank[rank]
        assert len(result) == 4, f"worker failed: {result}"
        _, summed, meaned, bcast = result
        assert summed == pytest.approx(3.0)
        assert meaned == pytest.approx(1.5)
        assert bcast == 42
