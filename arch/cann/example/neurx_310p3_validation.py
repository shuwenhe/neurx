from __future__ import annotations

import argparse
import shlex
import subprocess
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Neurx 310P3 8-card validation runner")
    parser.add_argument("--python", default="python3", help="python executable")
    parser.add_argument("--rounds", type=int, default=1, help="repeat rounds")
    parser.add_argument("--epochs", type=int, default=1)
    parser.add_argument("--steps-per-epoch", type=int, default=10)
    parser.add_argument("--batch-size", type=int, default=8)
    parser.add_argument("--master-port", type=int, default=29530)
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    script = repo_root / "cann" / "example" / "torch_npu_train_template.py"

    cmd = [
        args.python,
        "-m",
        "torch.distributed.run",
        "--nproc_per_node",
        "8",
        "--master_port",
        str(args.master_port),
        str(script),
        "--epochs",
        str(args.epochs),
        "--steps-per-epoch",
        str(args.steps_per_epoch),
        "--batch-size",
        str(args.batch_size),
        "--device",
        "npu",
    ]

    print("[310p3-validation] command:")
    print(" ".join(shlex.quote(x) for x in cmd), flush=True)

    for i in range(args.rounds):
        print(f"[310p3-validation] round {i + 1}/{args.rounds}", flush=True)
        proc = subprocess.run(cmd, cwd=str(repo_root), check=False)
        if proc.returncode != 0:
            print(f"[310p3-validation] failed in round {i + 1}, code={proc.returncode}", flush=True)
            return int(proc.returncode)

    print("[310p3-validation] success", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
