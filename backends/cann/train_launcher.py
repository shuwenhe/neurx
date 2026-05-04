#!/usr/bin/env python3

import argparse
import json
import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path


def load_config(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def detect_device_name() -> str:
    for key in (
        "ASCEND_CHIP_TYPE",
        "ASCEND_DEVICE_NAME",
        "ASCEND_SOC_NAME",
        "NPU_SOC_NAME",
        "TARGET_SOC",
    ):
        value = os.environ.get(key)
        if value:
            return value

    npu_smi = shutil.which("npu-smi")
    if not npu_smi:
        return "unknown"

    try:
        result = subprocess.run(
            [npu_smi, "info"],
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError:
        return "unknown"

    if result.returncode != 0:
        return "unknown"

    output = (result.stdout or "") + "\n" + (result.stderr or "")
    for line in output.splitlines():
        normalized = line.strip()
        upper = normalized.upper()
        if "310" in upper or "910" in upper:
            return normalized
    return "unknown"


def training_supported(device_name: str) -> bool:
    name = device_name.lower()
    return not any(token in name for token in ("310", "310p", "310p3"))


def ensure_required_paths() -> None:
    ascend_home = os.environ.get("ASCEND_HOME_PATH", "/usr/local/Ascend/ascend-toolkit/latest")
    if not Path(ascend_home).exists():
        raise RuntimeError(
            f"ASCEND_HOME_PATH does not exist: {ascend_home}. Source cann/env.sh first."
        )


def normalize_command(command_value):
    if isinstance(command_value, list):
        return [str(item) for item in command_value]
    if isinstance(command_value, str):
        return shlex.split(command_value)
    raise TypeError("train.command must be a list or string")


def apply_env(env_map: dict) -> dict:
    merged = os.environ.copy()
    for key, value in env_map.items():
        merged[str(key)] = str(value)
    return merged


def print_summary(config: dict, device_name: str) -> None:
    print("== CANN Training Launcher ==")
    print(f"name: {config.get('name', 'unnamed')}")
    print(f"mode: {config.get('mode', 'train')}")
    print(f"target.soc: {config.get('target', {}).get('soc', 'unknown')}")
    print(f"detected device: {device_name}")


def run_training(config: dict, dry_run: bool) -> int:
    ensure_required_paths()

    mode = str(config.get("mode", "train")).lower()
    device_name = detect_device_name()
    declared_target = str(config.get("target", {}).get("soc", "unknown"))
    print_summary(config, device_name)

    if mode == "train" and not training_supported(f"{declared_target} {device_name}"):
        print(
            "Refusing to start training on Ascend 310/310P/310P3. "
            "Use Ascend 910/910B for training and keep 310P3 for inference.",
            file=sys.stderr,
        )
        return 2

    train_block = config.get("train", {})
    command = normalize_command(train_block.get("command", []))
    if not command:
        raise RuntimeError("Missing train.command in config")

    workdir = Path(train_block.get("workdir", ".")).resolve()
    env = apply_env(config.get("env", {}))

    print(f"workdir: {workdir}")
    print(f"command: {' '.join(shlex.quote(part) for part in command)}")

    if dry_run:
        print("dry-run enabled, command not executed")
        return 0

    result = subprocess.run(command, cwd=workdir, env=env, check=False)
    return result.returncode


def main() -> int:
    parser = argparse.ArgumentParser(description="Launch Ascend CANN training jobs")
    parser.add_argument("--config", required=True, help="Path to JSON config file")
    parser.add_argument("--dry-run", action="store_true", help="Validate config and environment only")
    args = parser.parse_args()

    config = load_config(Path(args.config).resolve())
    return run_training(config, dry_run=args.dry_run)


if __name__ == "__main__":
    sys.exit(main())