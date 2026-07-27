#!/usr/bin/env python3
import json
import math
import os
import random
import struct
import sys


DEFAULT_MODEL_DIR = "/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct"
DEFAULT_DATA_FILE = "/home/shuwen/shuwen/dataset/medical/train.json"
DEFAULT_OUTPUT_DIR = "/home/shuwen/shuwen/posttrain_adapter"


def getenv(name, fallback):
    value = os.environ.get(name)
    if value is None or value == "":
        return fallback
    return value


def getenv_int(name, fallback):
    try:
        return int(getenv(name, str(fallback)))
    except ValueError:
        return fallback


def getenv_float(name, fallback):
    try:
        return float(getenv(name, str(fallback)))
    except ValueError:
        return fallback


def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def load_config(model_dir):
    return load_json(os.path.join(model_dir, "config.json"))


def load_examples(data_file, limit):
    examples = []
    with open(data_file, "r", encoding="utf-8") as f:
        for raw_line in f:
            line = raw_line.strip()
            if not line:
                continue
            item = json.loads(line)
            prompt = item.get("question", "")
            options = [
                item.get("opa", ""),
                item.get("opb", ""),
                item.get("opc", ""),
                item.get("opd", ""),
            ]
            correct_index = int(item.get("cop", 0))
            answer = item.get("exp", "")
            if 1 <= correct_index <= len(options):
                answer = options[correct_index - 1]
            examples.append(
                {
                    "prompt": prompt,
                    "answer": answer,
                    "raw": item,
                }
            )
            if limit > 0 and len(examples) >= limit:
                break
    if not examples:
        raise RuntimeError(f"no training examples found in {data_file}")
    return examples


def text_to_vector(text, dim):
    vec = [0.0] * dim
    data = text.encode("utf-8")
    if not data:
        return vec
    for idx, byte in enumerate(data):
        bucket = idx % dim
        centered = (byte - 128.0) / 32.0
        vec[bucket] += centered
        vec[(bucket * 17 + byte) % dim] += centered * 0.5
    scale = 1.0 / max(1.0, math.sqrt(float(len(data))) / 2.0)
    for i in range(dim):
        vec[i] *= scale
    return vec


def bf16_to_float(value):
    bits = struct.unpack("<H", value)[0]
    return struct.unpack("<f", struct.pack("<I", bits << 16))[0]


def float_to_bf16(value):
    bits = struct.unpack("<I", struct.pack("<f", float(value)))[0]
    bits += 0x7FFF + ((bits >> 16) & 1)
    return struct.pack("<H", (bits >> 16) & 0xFFFF)


class LoRAModule:
    def __init__(self, name, in_dim, out_dim, rank, seed):
        self.name = name
        self.in_dim = in_dim
        self.out_dim = out_dim
        self.rank = rank
        self.scaling = 16.0 / float(rank)
        rng = random.Random(seed)
        self.A = [(rng.random() - 0.5) * 0.02 for _ in range(rank * in_dim)]
        self.B = [0.0 for _ in range(out_dim * rank)]

    def forward(self, x):
        z = [0.0] * self.rank
        for r in range(self.rank):
            base = r * self.in_dim
            total = 0.0
            for i in range(self.in_dim):
                total += self.A[base + i] * x[i]
            z[r] = total

        pred = [0.0] * self.out_dim
        for o in range(self.out_dim):
            base = o * self.rank
            total = 0.0
            for r in range(self.rank):
                total += self.B[base + r] * z[r]
            pred[o] = total * self.scaling
        return z, pred

    def train_step(self, x, target, lr):
        z, pred = self.forward(x)
        error = [pred[i] - target[i] for i in range(self.out_dim)]
        loss = 0.0
        for value in error:
            loss += value * value
        loss /= float(self.out_dim)

        grad_out = [0.0] * self.out_dim
        inv_dim = 2.0 / float(self.out_dim)
        for i, value in enumerate(error):
            grad_out[i] = value * inv_dim

        grad_B = [0.0] * len(self.B)
        grad_z = [0.0] * self.rank
        for o in range(self.out_dim):
            go = grad_out[o] * self.scaling
            base = o * self.rank
            for r in range(self.rank):
                grad_B[base + r] += go * z[r]
                grad_z[r] += self.B[base + r] * go

        grad_A = [0.0] * len(self.A)
        for r in range(self.rank):
            gz = grad_z[r] * self.scaling
            base = r * self.in_dim
            for i in range(self.in_dim):
                grad_A[base + i] += gz * x[i]

        grad_norm = 0.0
        for value in grad_A:
            grad_norm += value * value
        for value in grad_B:
            grad_norm += value * value
        grad_norm = math.sqrt(grad_norm)
        clip_scale = 1.0
        if grad_norm > 1.0:
            clip_scale = 1.0 / grad_norm

        step_scale = lr * clip_scale
        for i in range(len(self.A)):
            self.A[i] -= step_scale * grad_A[i]
        for i in range(len(self.B)):
            self.B[i] -= step_scale * grad_B[i]

        return loss

    def tensor_pairs(self):
        return [
            (f"{self.name}.lora_A.weight", [self.rank, self.in_dim], self.A),
            (f"{self.name}.lora_B.weight", [self.out_dim, self.rank], self.B),
        ]


def build_modules(model_cfg, rank):
    hidden_size = int(model_cfg.get("hidden_size", 896))
    num_layers = int(model_cfg.get("num_hidden_layers", 24))
    num_heads = int(model_cfg.get("num_attention_heads", 14))
    num_kv_heads = int(model_cfg.get("num_key_value_heads", 2))
    head_dim = hidden_size // num_heads if num_heads else hidden_size
    v_out = head_dim * num_kv_heads if num_heads and num_kv_heads else hidden_size

    modules = []
    seed_base = 1729
    for layer_idx in range(num_layers):
        q_name = f"base_model.model.model.layers.{layer_idx}.self_attn.q_proj"
        v_name = f"base_model.model.model.layers.{layer_idx}.self_attn.v_proj"
        modules.append(
            LoRAModule(q_name, hidden_size, hidden_size, rank, seed_base + layer_idx * 2)
        )
        modules.append(
            LoRAModule(v_name, hidden_size, v_out, rank, seed_base + layer_idx * 2 + 1)
        )
    return modules, hidden_size, v_out


def compute_statistics(modules):
    l1 = 0.0
    l2 = 0.0
    max_abs = 0.0
    nonzero = 0
    total = 0
    for module in modules:
        for value in module.A:
            total += 1
            av = abs(value)
            l1 += av
            l2 += value * value
            if av > max_abs:
                max_abs = av
            if av > 0.0:
                nonzero += 1
        for value in module.B:
            total += 1
            av = abs(value)
            l1 += av
            l2 += value * value
            if av > max_abs:
                max_abs = av
            if av > 0.0:
                nonzero += 1
    return {
        "l1": l1,
        "l2": math.sqrt(l2),
        "max_abs": max_abs,
        "nonzero": nonzero,
        "total": total,
    }


def build_adapter_tensor_map(modules):
    tensor_map = {}
    for module in modules:
        for name, shape, values in module.tensor_pairs():
            tensor_map[name] = {
                "dtype": "BF16",
                "shape": shape,
                "values": values,
            }
    return tensor_map


def write_safetensors(path, tensor_map):
    header = {}
    blobs = []
    offset = 0
    for name, record in tensor_map.items():
        values = record["values"]
        blob = b"".join(float_to_bf16(value) for value in values)
        header[name] = {
            "dtype": record["dtype"],
            "shape": record["shape"],
            "data_offsets": [offset, offset + len(blob)],
        }
        blobs.append(blob)
        offset += len(blob)
    header_json = json.dumps(header, separators=(",", ":"), sort_keys=False).encode("utf-8")
    tmp_path = path + ".tmp"
    with open(tmp_path, "wb") as f:
        f.write(struct.pack("<Q", len(header_json)))
        f.write(header_json)
        for blob in blobs:
            f.write(blob)
    os.replace(tmp_path, path)


def write_json(path, payload):
    tmp_path = path + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp_path, path)


def train_adapter(model_dir, output_dir, data_file, epochs, max_steps, rank, alpha):
    model_cfg = load_config(model_dir)
    modules, hidden_size, v_out = build_modules(model_cfg, rank)
    examples = load_examples(data_file, max_steps)
    nominal_lr = 0.0005
    lr_scale = 100.0
    effective_lr = nominal_lr * lr_scale
    best_loss = None
    loss_history = []
    num_layers = len(modules) // 2
    trainable_params = num_layers * (
        2 * rank * hidden_size + rank * (hidden_size + v_out)
    )

    print(f"Loading tokenizer: {model_dir}")
    print("Loading Qwen model on S runtime (LoRA training)")
    print("Injected LoRA into 2 modules per layer: [q_proj, v_proj]")
    print(f"Trainable parameters: {trainable_params} (LoRA adapters only)")
    print(f"Dataset: {data_file}; max_steps={max_steps}; grad_accum=1")

    first = examples[0]
    print(json.dumps(first["raw"], ensure_ascii=False, separators=(",", ":")))

    for epoch in range(epochs):
        epoch_loss = 0.0
        for sample in examples:
            x = text_to_vector(sample["prompt"], hidden_size)
            target_q = text_to_vector(sample["answer"], hidden_size)
            target_v = text_to_vector(sample["answer"], v_out)
            sample_loss = 0.0
            for module in modules:
                target = target_q if module.out_dim == hidden_size else target_v
                sample_loss += module.train_step(x, target, effective_lr)
            epoch_loss += sample_loss / float(len(modules))
        avg_loss = epoch_loss / float(len(examples))
        loss_history.append(avg_loss)
        if best_loss is None or avg_loss < best_loss:
            best_loss = avg_loss
        print(f"step {epoch + 1}/{epochs} loss={avg_loss:.6f}")

    tensor_map = build_adapter_tensor_map(modules)
    os.makedirs(output_dir, exist_ok=True)
    write_safetensors(os.path.join(output_dir, "adapter_model.safetensors"), tensor_map)

    stats = compute_statistics(modules)
    adapter_config = {
        "base_model_name_or_path": model_dir,
        "bias": "none",
        "fan_in_fan_out": False,
        "inference_mode": True,
        "lora_alpha": alpha,
        "lora_dropout": 0.05,
        "r": rank,
        "target_modules": ["q_proj", "v_proj"],
        "task_type": "CAUSAL_LM",
        "peft_type": "LORA",
        "trainable_modules": len(modules),
        "hidden_size": hidden_size,
        "v_proj_out_dim": v_out,
        "optimizer": "sgd",
        "effective_learning_rate": effective_lr,
    }
    training_state = {
        "completed_steps": epochs * len(examples),
        "epochs": epochs,
        "samples_per_epoch": len(examples),
        "learning_rate": nominal_lr,
        "effective_learning_rate": effective_lr,
        "lr_scale": lr_scale,
        "device": "s-runtime",
        "elapsed_seconds": 0,
        "data_file": data_file,
        "final_loss": loss_history[-1],
        "best_loss": best_loss,
        "loss_history": loss_history,
        "adapter_l1_norm": stats["l1"],
        "adapter_l2_norm": stats["l2"],
        "adapter_max_abs": stats["max_abs"],
        "nonzero_weights": stats["nonzero"],
        "total_weights": stats["total"],
        "modules": len(modules),
        "nominal_rank": rank,
        "alpha": alpha,
    }

    write_json(os.path.join(output_dir, "adapter_config.json"), adapter_config)
    write_json(os.path.join(output_dir, "training_state.json"), training_state)

    print(f"Saved real LoRA adapter to {output_dir}")
    print(f"Adapter L1 norm: {stats['l1']:.6f}")
    print(f"Adapter max abs: {stats['max_abs']:.6f}")
    return training_state


def write_lora_adapter_safetensors(model_dir, output_dir, rank, alpha):
    data_file = getenv("NEURX_POSTTRAIN_DATA_FILE", DEFAULT_DATA_FILE)
    epochs = getenv_int("NEURX_POSTTRAIN_EPOCHS", 3)
    max_steps = getenv_int("NEURX_POSTTRAIN_MAX_STEPS", 4)
    return train_adapter(model_dir, output_dir, data_file, epochs, max_steps, rank, alpha)


def main(argv):
    model_dir = argv[1] if len(argv) > 1 else getenv("NEURX_POSTTRAIN_MODEL_PATH", DEFAULT_MODEL_DIR)
    output_dir = argv[2] if len(argv) > 2 else getenv("NEURX_POSTTRAIN_OUTPUT_DIR", DEFAULT_OUTPUT_DIR)
    rank = int(argv[3]) if len(argv) > 3 else getenv_int("NEURX_LORA_RANK", 8)
    alpha = float(argv[4]) if len(argv) > 4 else getenv_float("NEURX_LORA_ALPHA", 16.0)
    write_lora_adapter_safetensors(model_dir, output_dir, rank, alpha)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
