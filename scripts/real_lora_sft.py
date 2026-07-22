#!/usr/bin/env python3
import json
import math
import os
import random
import time
from pathlib import Path

import torch
from safetensors.torch import save_file
from torch import nn
from transformers import AutoModelForCausalLM, AutoTokenizer


class LoRALinear(nn.Module):
    def __init__(self, base, rank, alpha, dropout):
        super().__init__()
        self.base = base
        self.rank = rank
        self.scaling = alpha / rank
        self.dropout = nn.Dropout(dropout)
        self.lora_A = nn.Parameter(torch.empty(rank, base.in_features))
        self.lora_B = nn.Parameter(torch.zeros(base.out_features, rank))
        nn.init.kaiming_uniform_(self.lora_A, a=math.sqrt(5))
        for parameter in self.base.parameters():
            parameter.requires_grad = False

    def forward(self, inputs):
        base_output = self.base(inputs)
        adapter_inputs = self.dropout(inputs).to(self.lora_A.dtype)
        adapter = torch.nn.functional.linear(adapter_inputs, self.lora_A)
        adapter = torch.nn.functional.linear(adapter, self.lora_B)
        return base_output + adapter.to(base_output.dtype) * self.scaling


def env_int(name, default):
    return int(os.environ.get(name, str(default)))


def env_float(name, default):
    return float(os.environ.get(name, str(default)))


def iter_records(path, seed):
    rng = random.Random(seed)
    while True:
        with path.open("r", encoding="utf-8") as handle:
            buffer = []
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                buffer.append(json.loads(line))
                if len(buffer) >= 1024:
                    rng.shuffle(buffer)
                    yield from buffer
                    buffer.clear()
            rng.shuffle(buffer)
            yield from buffer


def format_example(record):
    options = [record.get("opa"), record.get("opb"), record.get("opc"), record.get("opd")]
    option_lines = []
    for index, option in enumerate(options):
        if option:
            option_lines.append(f"{chr(65 + index)}. {option}")
    question = str(record.get("question", "")).strip()
    prompt = question
    if option_lines:
        prompt += "\n" + "\n".join(option_lines)
    answer_index = int(record.get("cop", 0) or 0) - 1
    answer = options[answer_index] if 0 <= answer_index < len(options) else ""
    explanation = str(record.get("exp", "")).strip()
    response = f"Answer: {answer}" if answer else "Answer:"
    if explanation:
        response += f"\nExplanation: {explanation}"
    return prompt, response


def encode_example(tokenizer, record, max_length):
    prompt, response = format_example(record)
    prompt_messages = [{"role": "user", "content": prompt}]
    full_messages = prompt_messages + [{"role": "assistant", "content": response}]
    prompt_text = tokenizer.apply_chat_template(prompt_messages, tokenize=False, add_generation_prompt=True)
    full_text = tokenizer.apply_chat_template(full_messages, tokenize=False, add_generation_prompt=False)
    prompt_ids = tokenizer(prompt_text, add_special_tokens=False)["input_ids"]
    full_ids = tokenizer(full_text, add_special_tokens=False, truncation=True, max_length=max_length)["input_ids"]
    if len(full_ids) < 2:
        return None
    prompt_length = min(len(prompt_ids), len(full_ids) - 1)
    labels = [-100] * prompt_length + full_ids[prompt_length:]
    return torch.tensor([full_ids], dtype=torch.long), torch.tensor([labels], dtype=torch.long)


def inject_lora(model, target_names, rank, alpha, dropout):
    replaced = []
    for module_name, module in list(model.named_modules()):
        for child_name, child in list(module.named_children()):
            if child_name in target_names and isinstance(child, nn.Linear):
                setattr(module, child_name, LoRALinear(child, rank, alpha, dropout))
                replaced.append(f"{module_name}.{child_name}".lstrip("."))
    if not replaced:
        raise RuntimeError(f"no target modules found: {sorted(target_names)}")
    return replaced


def save_adapter(model, output_dir, config):
    state = {}
    for name, parameter in model.named_parameters():
        if parameter.requires_grad and (name.endswith("lora_A") or name.endswith("lora_B")):
            key = "base_model.model." + name.replace(".lora_A", ".lora_A.weight").replace(".lora_B", ".lora_B.weight")
            state[key] = parameter.detach().cpu().contiguous()
    save_file(state, str(output_dir / "adapter_model.safetensors"))
    (output_dir / "adapter_config.json").write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")


def main():
    model_path = Path(os.environ["NEURX_POSTTRAIN_MODEL_PATH"])
    data_file = Path(os.environ["NEURX_POSTTRAIN_DATA_FILE"])
    output_dir = Path(os.environ["NEURX_POSTTRAIN_OUTPUT_DIR"])
    python_seed = env_int("NEURX_POSTTRAIN_SEED", 42)
    max_steps = env_int("NEURX_POSTTRAIN_MAX_STEPS", 10)
    max_length = env_int("NEURX_POSTTRAIN_MAX_LENGTH", 256)
    grad_accum = env_int("NEURX_POSTTRAIN_GRAD_ACCUM", 4)
    rank = env_int("NEURX_LORA_RANK", 8)
    alpha = env_float("NEURX_LORA_ALPHA", 16.0)
    dropout = env_float("NEURX_LORA_DROPOUT", 0.05)
    learning_rate = env_float("NEURX_POSTTRAIN_LR", 2e-4)
    target_names = set(filter(None, os.environ.get("NEURX_LORA_TARGETS", "q_proj,v_proj").split(",")))

    if not model_path.is_dir():
        raise FileNotFoundError(f"model directory not found: {model_path}")
    if not data_file.is_file():
        raise FileNotFoundError(f"training data not found: {data_file}")
    if max_steps <= 0 or max_length <= 0 or grad_accum <= 0:
        raise ValueError("max steps, sequence length, and gradient accumulation must be positive")

    random.seed(python_seed)
    torch.manual_seed(python_seed)
    torch.set_num_threads(env_int("NEURX_POSTTRAIN_CPU_THREADS", min(12, os.cpu_count() or 1)))
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    dtype = torch.float16 if device.type == "cuda" else torch.float32
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Loading tokenizer: {model_path}", flush=True)
    tokenizer = AutoTokenizer.from_pretrained(model_path, local_files_only=True)
    if tokenizer.pad_token_id is None:
        tokenizer.pad_token_id = tokenizer.eos_token_id
    print(f"Loading Qwen model on {device} ({dtype})", flush=True)
    model = AutoModelForCausalLM.from_pretrained(model_path, local_files_only=True, dtype=dtype)
    model.config.use_cache = False
    for parameter in model.parameters():
        parameter.requires_grad = False
    replaced = inject_lora(model, target_names, rank, alpha, dropout)
    model.to(device)
    model.train()

    trainable = [parameter for parameter in model.parameters() if parameter.requires_grad]
    trainable_count = sum(parameter.numel() for parameter in trainable)
    total_count = sum(parameter.numel() for parameter in model.parameters())
    print(f"Injected LoRA into {len(replaced)} modules: {sorted(target_names)}", flush=True)
    print(f"Trainable parameters: {trainable_count:,} / {total_count:,} ({100 * trainable_count / total_count:.4f}%)", flush=True)
    print(f"Dataset: {data_file}; max_steps={max_steps}; max_length={max_length}; grad_accum={grad_accum}", flush=True)

    optimizer = torch.optim.AdamW(trainable, lr=learning_rate)
    records = iter_records(data_file, python_seed)
    optimizer.zero_grad(set_to_none=True)
    started = time.time()
    micro_step = 0
    completed_steps = 0
    running_loss = 0.0
    while completed_steps < max_steps:
        encoded = encode_example(tokenizer, next(records), max_length)
        if encoded is None:
            continue
        input_ids, labels = encoded
        input_ids = input_ids.to(device)
        labels = labels.to(device)
        outputs = model(input_ids=input_ids, labels=labels)
        loss = outputs.loss / grad_accum
        loss.backward()
        running_loss += outputs.loss.detach().float().item()
        micro_step += 1
        if micro_step % grad_accum != 0:
            continue
        torch.nn.utils.clip_grad_norm_(trainable, 1.0)
        optimizer.step()
        optimizer.zero_grad(set_to_none=True)
        completed_steps += 1
        average_loss = running_loss / grad_accum
        running_loss = 0.0
        elapsed = time.time() - started
        print(f"step {completed_steps}/{max_steps} loss={average_loss:.6f} elapsed={elapsed:.1f}s", flush=True)

    adapter_config = {
        "base_model_name_or_path": str(model_path),
        "bias": "none",
        "fan_in_fan_out": False,
        "inference_mode": True,
        "lora_alpha": alpha,
        "lora_dropout": dropout,
        "r": rank,
        "target_modules": sorted(target_names),
        "task_type": "CAUSAL_LM",
        "peft_type": "LORA",
    }
    save_adapter(model, output_dir, adapter_config)
    tokenizer.save_pretrained(output_dir)
    training_state = {
        "completed_steps": completed_steps,
        "max_length": max_length,
        "gradient_accumulation": grad_accum,
        "learning_rate": learning_rate,
        "device": str(device),
        "elapsed_seconds": time.time() - started,
        "data_file": str(data_file),
    }
    (output_dir / "training_state.json").write_text(json.dumps(training_state, indent=2) + "\n", encoding="utf-8")
    print(f"Saved real LoRA adapter to {output_dir}", flush=True)


if __name__ == "__main__":
    main()
