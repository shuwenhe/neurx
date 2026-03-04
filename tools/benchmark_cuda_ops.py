#!/usr/bin/env python3
import argparse
import time
import numpy as np

from neurx import Tensor
from neurx.cuda.ops import available


def _cuda_runtime_ok():
    if not available():
        return False
    try:
        x = Tensor(np.zeros((1, 1), dtype=np.float32), device="cuda")
        _ = x + x
        return True
    except Exception:
        return False


def _sync(obj):
    if isinstance(obj, tuple):
        for v in obj:
            _sync(v)
        return
    if hasattr(obj, "to_numpy"):
        _ = obj.to_numpy()


def _bench_case(name, fn, warmup, iters):
    for _ in range(warmup):
        out = fn()
        _sync(out)
    t0 = time.perf_counter()
    for _ in range(iters):
        out = fn()
        _sync(out)
    t1 = time.perf_counter()
    avg_ms = (t1 - t0) * 1000.0 / iters
    return name, avg_ms


def main():
    p = argparse.ArgumentParser(description="CUDA op benchmark for neurx.")
    p.add_argument("--warmup", type=int, default=10)
    p.add_argument("--iters", type=int, default=50)
    p.add_argument("--batch", type=int, default=32)
    p.add_argument("--time", type=int, default=256)
    p.add_argument("--channels", type=int, default=512)
    args = p.parse_args()

    if not _cuda_runtime_ok():
        print("CUDA runtime not available.")
        return

    np.random.seed(0)
    x3 = Tensor(
        np.random.randn(args.batch, args.time, args.channels).astype(np.float32),
        device="cuda",
    )
    x2 = Tensor(
        np.random.randn(args.batch * args.time, args.channels).astype(np.float32),
        device="cuda",
    )

    cases = [
        ("sum_axis2", lambda: x3.sum(axis=2)),
        ("sum_axis1", lambda: x3.sum(axis=1)),
        ("sum_axis0", lambda: x3.sum(axis=0)),
        ("mean_axis2", lambda: x3.mean(axis=2)),
        ("mean_axis1", lambda: x3.mean(axis=1)),
        ("mean_axis0", lambda: x3.mean(axis=0)),
        ("max_axis2", lambda: x3.max(axis=2)),
        ("max_axis1", lambda: x3.max(axis=1)),
        ("max_axis0", lambda: x3.max(axis=0)),
        ("min_axis2", lambda: x3.min(axis=2)),
        ("min_axis1", lambda: x3.min(axis=1)),
        ("min_axis0", lambda: x3.min(axis=0)),
        ("argmax_axis2", lambda: x3.argmax(axis=2)),
        ("argmax_axis1", lambda: x3.argmax(axis=1)),
        ("argmax_axis0", lambda: x3.argmax(axis=0)),
        ("argmin_axis2", lambda: x3.argmin(axis=2)),
        ("argmin_axis1", lambda: x3.argmin(axis=1)),
        ("argmin_axis0", lambda: x3.argmin(axis=0)),
        ("sum2d_axis0", lambda: x2.sum(axis=0)),
        ("sum2d_axis1", lambda: x2.sum(axis=1)),
    ]

    results = []
    for name, fn in cases:
        results.append(_bench_case(name, fn, args.warmup, args.iters))

    results.sort(key=lambda x: x[1], reverse=True)
    print("name,avg_ms")
    for name, avg_ms in results:
        print(f"{name},{avg_ms:.4f}")
    print(f"slowest={results[0][0]},avg_ms={results[0][1]:.4f}")


if __name__ == "__main__":
    main()
