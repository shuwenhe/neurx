from __future__ import annotations

import argparse
import json
import os
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]


def _load_config(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def _is_310_like(soc: str) -> bool:
    v = soc.lower()
    return "310" in v


def _apply_env(cfg_env: dict[str, str]) -> dict[str, str]:
    env = os.environ.copy()
    for k, v in cfg_env.items():
        env[str(k)] = str(v)
    return env


def _normalize_command(raw: Any) -> list[str]:
    if isinstance(raw, list):
        return [str(x) for x in raw]
    if isinstance(raw, str):
        return shlex.split(raw)
    raise ValueError("train.command must be a list or string")


def _run(config_path: Path, dry_run: bool) -> int:
    cfg = _load_config(config_path)
    mode = str(cfg.get("mode", "train")).lower()
    if mode != "train":
        raise ValueError(f"unsupported mode: {mode}")

    target = cfg.get("target", {}) or {}
    soc = str(target.get("soc", "unknown"))
    allow_310 = bool(cfg.get("allow_train_on_310p3", False))
    if _is_310_like(soc) and not allow_310:
        raise RuntimeError(
            "config blocks training on Ascend 310/310P/310P3. "
            "Set allow_train_on_310p3=true if you really want to proceed."
        )

    train = cfg.get("train", {}) or {}
    workdir = Path(str(train.get("workdir", str(REPO_ROOT))))
    if not workdir.is_absolute():
        workdir = (REPO_ROOT / workdir).resolve()

    cmd = _normalize_command(train.get("command", []))
    if not cmd:
        raise ValueError("train.command is empty")

    env = _apply_env(cfg.get("env", {}) or {})

    print(f"[launcher] config: {config_path}")
    print(f"[launcher] target.soc: {soc}")
    print(f"[launcher] workdir: {workdir}")
    print(f"[launcher] command: {' '.join(shlex.quote(x) for x in cmd)}")
    print(f"[launcher] ASCEND_RT_VISIBLE_DEVICES={env.get('ASCEND_RT_VISIBLE_DEVICES', '')}")

    if dry_run:
        print("[launcher] dry-run complete")
        return 0

    proc = subprocess.run(cmd, cwd=str(workdir), env=env, check=False)
    return int(proc.returncode)


def main() -> int:
    parser = argparse.ArgumentParser(description="Neurx Ascend train launcher")
    parser.add_argument("--config", required=True, help="path to json config")
    parser.add_argument("--dry-run", action="store_true", help="print command and exit")
    args = parser.parse_args()

    config_path = Path(args.config).resolve()
    if not config_path.exists():
        print(f"config not found: {config_path}", file=sys.stderr)
        return 2

    try:
        return _run(config_path, args.dry_run)
    except Exception as exc:
        print(f"[launcher] error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
