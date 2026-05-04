#!/usr/bin/env python3

import argparse
import sys


def parse_args():
    parser = argparse.ArgumentParser(description="Minimal torch_npu training template")
    parser.add_argument("--epochs", type=int, default=2)
    parser.add_argument("--batch-size", type=int, default=8)
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        import torch
        import torch.nn as nn
        import torch.optim as optim
        import torch_npu  # noqa: F401
    except ImportError as exc:
        print(
            "Missing dependency for Ascend training template. "
            "Install torch and torch_npu in the target environment.",
            file=sys.stderr,
        )
        print(str(exc), file=sys.stderr)
        return 1

    if not hasattr(torch, "npu") or not torch.npu.is_available():
        print("NPU device is not available. Check CANN and torch_npu installation.", file=sys.stderr)
        return 1

    device = torch.device("npu:0")
    model = nn.Sequential(nn.Linear(16, 32), nn.ReLU(), nn.Linear(32, 4)).to(device)
    optimizer = optim.Adam(model.parameters(), lr=1e-3)
    criterion = nn.MSELoss()

    model.train()
    for epoch in range(args.epochs):
        inputs = torch.randn(args.batch_size, 16, device=device)
        targets = torch.randn(args.batch_size, 4, device=device)

        optimizer.zero_grad()
        outputs = model(inputs)
        loss = criterion(outputs, targets)
        loss.backward()
        optimizer.step()

        print(f"epoch={epoch + 1} loss={loss.item():.6f}")

    print("training template finished")
    return 0


if __name__ == "__main__":
    sys.exit(main())