#!/usr/bin/env python3
import json
import os
from pathlib import Path

import torch
from safetensors.torch import load_file
from transformers import AutoModelForCausalLM, AutoTokenizer

from real_lora_sft import format_example, inject_lora


def first_record(path):
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            if line.strip():
                return json.loads(line)
    raise ValueError(f"dataset is empty: {path}")


def load_adapter(model, adapter_dir, config):
    inject_lora(
        model,
        set(config["target_modules"]),
        int(config["r"]),
        float(config["lora_alpha"]),
        0.0,
    )
    state = load_file(str(adapter_dir / "adapter_model.safetensors"))
    parameters = dict(model.named_parameters())
    loaded = 0
    with torch.no_grad():
        for saved_name, value in state.items():
            name = saved_name.removeprefix("base_model.model.").replace(".lora_A.weight", ".lora_A").replace(".lora_B.weight", ".lora_B")
            if name not in parameters:
                raise KeyError(f"adapter tensor has no matching model parameter: {saved_name}")
            parameters[name].copy_(value.to(parameters[name].device, parameters[name].dtype))
            loaded += 1
    return loaded


def main():
    model_path = Path(os.environ["NEURX_POSTTRAIN_MODEL_PATH"])
    data_file = Path(os.environ["NEURX_POSTTRAIN_DATA_FILE"])
    adapter_dir = Path(os.environ["NEURX_POSTTRAIN_OUTPUT_DIR"])
    config_path = adapter_dir / "adapter_config.json"
    weights_path = adapter_dir / "adapter_model.safetensors"
    if not config_path.is_file() or not weights_path.is_file():
        raise FileNotFoundError(f"LoRA adapter not found in {adapter_dir}; run make posttrain first")

    config = json.loads(config_path.read_text(encoding="utf-8"))
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    dtype = torch.float16 if device.type == "cuda" else torch.float32
    tokenizer = AutoTokenizer.from_pretrained(model_path, local_files_only=True)
    model = AutoModelForCausalLM.from_pretrained(model_path, local_files_only=True, dtype=dtype)
    loaded = load_adapter(model, adapter_dir, config)
    model.to(device).eval()

    prompt, expected = format_example(first_record(data_file))
    messages = [{"role": "user", "content": prompt}]
    text = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
    inputs = tokenizer(text, return_tensors="pt").to(device)
    max_new_tokens = int(os.environ.get("NEURX_POSTTRAIN_EVAL_MAX_NEW_TOKENS", "64"))
    with torch.inference_mode():
        output = model.generate(**inputs, max_new_tokens=max_new_tokens, do_sample=False)
    generated = tokenizer.decode(output[0, inputs["input_ids"].shape[1]:], skip_special_tokens=True)

    print(f"Adapter tensors loaded: {loaded}")
    print(f"Device: {device}")
    print(f"Prompt: {prompt}")
    print(f"Expected: {expected}")
    print(f"Generated: {generated}")


if __name__ == "__main__":
    main()
