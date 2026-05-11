from __future__ import annotations

import argparse
import os
import time
from typing import Tuple

import torch
import torch.nn as nn
import torch.optim as optim


try:
    import torch_npu  # noqa: F401
    HAS_TORCH_NPU = True
except Exception:
    HAS_TORCH_NPU = False


def _dist_info() -> Tuple[int, int, int]:
    rank = int(os.environ.get("RANK", "0"))
    local_rank = int(os.environ.get("LOCAL_RANK", "0"))
    world_size = int(os.environ.get("WORLD_SIZE", "1"))
    return rank, local_rank, world_size


def _resolve_device(prefer: str, local_rank: int) -> torch.device:
    p = prefer.lower().strip()
    if p == "npu" and HAS_TORCH_NPU and hasattr(torch, "npu") and torch.npu.is_available():
        return torch.device(f"npu:{local_rank}")
    if p == "cuda" and torch.cuda.is_available():
        return torch.device(f"cuda:{local_rank}")
    return torch.device("cpu")


def _init_distributed(device: torch.device, world_size: int, rank: int) -> bool:
    if world_size <= 1:
        return False
    if torch.distributed.is_initialized():
        return True
    backend = "gloo"
    if device.type == "npu":
        backend = "hccl"
    elif device.type == "cuda":
        backend = "nccl"
    torch.distributed.init_process_group(backend=backend, rank=rank, world_size=world_size)
    return True


def _cleanup_distributed() -> None:
    if torch.distributed.is_available() and torch.distributed.is_initialized():
        torch.distributed.destroy_process_group()


def main() -> int:
    parser = argparse.ArgumentParser(description="Minimal distributed training template for Ascend")
    parser.add_argument("--epochs", type=int, default=1)
    parser.add_argument("--steps-per-epoch", type=int, default=20)
    parser.add_argument("--batch-size", type=int, default=8)
    parser.add_argument("--input-dim", type=int, default=64)
    parser.add_argument("--hidden-dim", type=int, default=128)
    parser.add_argument("--num-classes", type=int, default=10)
    parser.add_argument("--lr", type=float, default=1e-3)
    parser.add_argument("--device", type=str, default="npu")
    args = parser.parse_args()

    rank, local_rank, world_size = _dist_info()
    device = _resolve_device(args.device, local_rank)

    if device.type == "npu":
        torch.npu.set_device(device)
    elif device.type == "cuda":
        torch.cuda.set_device(device)

    distributed = _init_distributed(device, world_size, rank)

    model = nn.Sequential(
        nn.Linear(args.input_dim, args.hidden_dim),
        nn.ReLU(),
        nn.Linear(args.hidden_dim, args.num_classes),
    ).to(device)

    if distributed:
        if device.type in {"cuda", "npu"}:
            model = nn.parallel.DistributedDataParallel(model, device_ids=[local_rank], output_device=local_rank)
        else:
            model = nn.parallel.DistributedDataParallel(model)

    criterion = nn.CrossEntropyLoss().to(device)
    optimizer = optim.Adam(model.parameters(), lr=args.lr)

    torch.manual_seed(42 + rank)

    start = time.time()
    for epoch in range(args.epochs):
        running = 0.0
        for _ in range(args.steps_per_epoch):
            x = torch.randn(args.batch_size, args.input_dim, device=device)
            y = torch.randint(0, args.num_classes, (args.batch_size,), device=device)

            optimizer.zero_grad(set_to_none=True)
            logits = model(x)
            loss = criterion(logits, y)
            loss.backward()
            optimizer.step()
            running += float(loss.detach().item())

        if rank == 0:
            avg_loss = running / max(args.steps_per_epoch, 1)
            print(f"[train] epoch={epoch + 1}/{args.epochs} world_size={world_size} device={device} avg_loss={avg_loss:.6f}", flush=True)

    if rank == 0:
        elapsed = time.time() - start
        print(f"[train] done in {elapsed:.2f}s", flush=True)

    _cleanup_distributed()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
