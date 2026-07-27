#!/usr/bin/env python3
import json
import math
import os
import struct
import sys


DEFAULT_BASE_DIR = "/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct"
DEFAULT_ADAPTER_DIR = "/home/shuwen/shuwen/posttrain_adapter"
DEFAULT_OUTPUT_DIR = "/home/shuwen/shuwen/posttrain"
SAMPLE_TENSOR = "model.layers.0.self_attn.q_proj.weight"


def getenv(name, fallback):
    value = os.environ.get(name)
    if value is None or value == "":
        return fallback
    return value


def read_header(path):
    with open(path, "rb") as f:
        header_len = struct.unpack("<Q", f.read(8))[0]
        header = json.loads(f.read(header_len))
    return header, 8 + header_len


def bf16_to_float(raw):
    bits = struct.unpack("<H", raw)[0]
    return struct.unpack("<f", struct.pack("<I", bits << 16))[0]


def read_tensor(path, tensor_name):
    header, data_base = read_header(path)
    if tensor_name not in header:
        raise KeyError(f"missing tensor {tensor_name} in {path}")
    meta = header[tensor_name]
    begin, end = meta["data_offsets"]
    with open(path, "rb") as f:
        f.seek(data_base + begin)
        raw = f.read(end - begin)
    dtype = meta["dtype"]
    values = []
    if dtype == "BF16":
        for i in range(0, len(raw), 2):
            values.append(bf16_to_float(raw[i : i + 2]))
    elif dtype == "F16":
        for i in range(0, len(raw), 2):
            bits = struct.unpack("<H", raw[i : i + 2])[0]
            sign = (bits & 0x8000) << 16
            exp = (bits >> 10) & 0x1F
            mant = bits & 0x03FF
            if exp == 0:
                if mant == 0:
                    values.append(struct.unpack("<f", struct.pack("<I", sign))[0])
                    continue
                while (mant & 0x0400) == 0:
                    mant <<= 1
                    exp -= 1
                exp += 1
                mant &= 0x03FF
            elif exp == 31:
                values.append(struct.unpack("<f", struct.pack("<I", sign | 0x7F800000 | (mant << 13)))[0])
                continue
            exp = exp + (127 - 15)
            values.append(
                struct.unpack("<f", struct.pack("<I", sign | (exp << 23) | (mant << 13)))[0]
            )
    elif dtype == "F32":
        for i in range(0, len(raw), 4):
            values.append(struct.unpack("<f", raw[i : i + 4])[0])
    else:
        raise ValueError(f"unsupported dtype {dtype} in {path}")
    return values


def tensor_l1(path):
    header, data_base = read_header(path)
    total = 0.0
    for name, meta in header.items():
        if name == "__metadata__":
            continue
        begin, end = meta["data_offsets"]
        with open(path, "rb") as f:
            f.seek(data_base + begin)
            raw = f.read(end - begin)
        dtype = meta["dtype"]
        if dtype == "BF16" or dtype == "F16":
            step = 2
            for i in range(0, len(raw), step):
                if dtype == "BF16":
                    value = bf16_to_float(raw[i : i + 2])
                else:
                    bits = struct.unpack("<H", raw[i : i + 2])[0]
                    sign = (bits & 0x8000) << 16
                    exp = (bits >> 10) & 0x1F
                    mant = bits & 0x03FF
                    if exp == 0:
                        if mant == 0:
                            value = struct.unpack("<f", struct.pack("<I", sign))[0]
                        else:
                            while (mant & 0x0400) == 0:
                                mant <<= 1
                                exp -= 1
                            exp += 1
                            mant &= 0x03FF
                            exp = exp + (127 - 15)
                            value = struct.unpack(
                                "<f", struct.pack("<I", sign | (exp << 23) | (mant << 13))
                            )[0]
                    elif exp == 31:
                        value = struct.unpack(
                            "<f", struct.pack("<I", sign | 0x7F800000 | (mant << 13))
                        )[0]
                    else:
                        exp = exp + (127 - 15)
                        value = struct.unpack(
                            "<f", struct.pack("<I", sign | (exp << 23) | (mant << 13))
                        )[0]
                total += abs(value)
        elif dtype == "F32":
            for i in range(0, len(raw), 4):
                total += abs(struct.unpack("<f", raw[i : i + 4])[0])
        else:
            raise ValueError(f"unsupported dtype {dtype} in {path}")
    return total


def load_training_state(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def main(argv):
    base_dir = argv[1] if len(argv) > 1 else getenv("NEURX_POSTTRAIN_MODEL_PATH", DEFAULT_BASE_DIR)
    adapter_dir = argv[2] if len(argv) > 2 else getenv("NEURX_POSTTRAIN_OUTPUT_DIR", DEFAULT_ADAPTER_DIR)
    output_dir = argv[3] if len(argv) > 3 else getenv("NEURX_MERGED_MODEL_DIR", DEFAULT_OUTPUT_DIR)

    adapter_file = os.path.join(adapter_dir, "adapter_model.safetensors")
    merged_file = os.path.join(output_dir, "model.safetensors")
    training_state_file = os.path.join(adapter_dir, "training_state.json")

    if not os.path.exists(adapter_file):
        print(f"error: missing adapter file: {adapter_file}", file=sys.stderr)
        return 1

    adapter_l1 = tensor_l1(adapter_file)
    if adapter_l1 <= 1e-6:
        print(f"error: adapter L1 norm too small: {adapter_l1:.6e}", file=sys.stderr)
        return 1

    state = {}
    if os.path.exists(training_state_file):
        state = load_training_state(training_state_file)
        loss_history = state.get("loss_history", [])
        if loss_history and isinstance(loss_history, list):
            print(
                f"training loss: start={loss_history[0]:.6f} final={loss_history[-1]:.6f}"
            )
        if state.get("adapter_l1_norm", 0.0) <= 1e-6:
            print("error: training_state reports zero adapter norm", file=sys.stderr)
            return 1

    print(f"adapter L1 norm: {adapter_l1:.6f}")

    if os.path.exists(merged_file):
        base_tensor = read_tensor(os.path.join(base_dir, "model.safetensors"), SAMPLE_TENSOR)
        merged_tensor = read_tensor(merged_file, SAMPLE_TENSOR)
        if not base_tensor or not merged_tensor:
            print("error: failed to read sample tensors for merge verification", file=sys.stderr)
            return 1
        delta = merged_tensor[0] - base_tensor[0]
        max_delta = 0.0
        count = min(len(base_tensor), len(merged_tensor))
        for i in range(count):
            value = abs(merged_tensor[i] - base_tensor[i])
            if value > max_delta:
                max_delta = value
        print(f"sample tensor delta: {delta:.6e}")
        print(f"sample tensor max abs delta: {max_delta:.6e}")
        if max_delta <= 1e-6:
            print("error: merged tensor delta too small", file=sys.stderr)
            return 1

    print("posttrain adapter verification passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
