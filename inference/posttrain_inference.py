#!/usr/bin/env python3
"""Interactive inference for a locally merged NeurX post-training model."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any


DEFAULT_SYSTEM_PROMPT = (
    "You are a helpful assistant. Answer the user's question directly and accurately."
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model-dir", required=True)
    parser.add_argument("--neurx-root", default="")
    parser.add_argument("--device", choices=("auto", "cpu", "cuda"), default="auto")
    parser.add_argument("--max-new-tokens", type=int, default=128)
    parser.add_argument("--temperature", type=float, default=0.7)
    parser.add_argument("--top-p", type=float, default=0.8)
    parser.add_argument("--repetition-penalty", type=float, default=1.1)
    parser.add_argument("--system-prompt", default=DEFAULT_SYSTEM_PROMPT)
    parser.add_argument("--history-file")
    parser.add_argument("--prompt", help="Run one prompt and exit instead of starting a REPL")
    return parser.parse_args()


def validate_args(args: argparse.Namespace) -> Path:
    model_dir = Path(args.model_dir).expanduser().resolve()
    required = ("config.json", "model.safetensors", "tokenizer_config.json")
    missing = [name for name in required if not (model_dir / name).is_file()]
    if missing:
        raise RuntimeError(f"model directory is incomplete; missing: {', '.join(missing)}")
    if args.max_new_tokens < 1:
        raise RuntimeError("max-new-tokens must be positive")
    if args.temperature < 0:
        raise RuntimeError("temperature cannot be negative")
    return model_dir


def load_history(path_value: str | None) -> list[dict[str, str]]:
    if not path_value:
        return []
    path = Path(path_value).expanduser()
    if not path.is_file():
        return []
    content = path.read_text(encoding="utf-8").strip()
    if not content:
        return []
    try:
        value = json.loads(content)
    except json.JSONDecodeError:
        return [{"role": "user", "content": content}]
    if isinstance(value, dict):
        value = value.get("messages", [])
    if not isinstance(value, list):
        raise RuntimeError("history file must contain a JSON message list")
    messages: list[dict[str, str]] = []
    for item in value:
        if not isinstance(item, dict):
            continue
        role = item.get("role")
        content_value = item.get("content")
        if role in {"system", "user", "assistant"} and isinstance(content_value, str):
            messages.append({"role": role, "content": content_value})
    return messages


def resolve_device(torch: Any, requested: str) -> str:
    if requested == "cuda" and not torch.cuda.is_available():
        raise RuntimeError("CUDA was requested but no CUDA device is available")
    if requested == "auto":
        return "cuda" if torch.cuda.is_available() else "cpu"
    return requested


def load_model(model_dir: Path, requested_device: str) -> tuple[Any, Any, Any, str]:
    try:
        import torch
        from transformers import AutoModelForCausalLM, AutoTokenizer
    except ImportError as exc:
        raise RuntimeError(
            "inference dependencies are missing; run `make posttrain-install-deps` first"
        ) from exc

    device = resolve_device(torch, requested_device)
    dtype = torch.float32
    if device == "cuda":
        dtype = torch.bfloat16 if torch.cuda.is_bf16_supported() else torch.float16

    print(f"[Model] Loading tokenizer from {model_dir}", flush=True)
    tokenizer = AutoTokenizer.from_pretrained(
        model_dir, local_files_only=True, use_fast=True
    )
    if tokenizer.pad_token_id is None:
        tokenizer.pad_token = tokenizer.eos_token

    print(f"[Model] Loading merged weights on {device} with {dtype}", flush=True)
    model = AutoModelForCausalLM.from_pretrained(
        model_dir,
        local_files_only=True,
        dtype=dtype,
    )
    model.to(device)
    model.eval()
    return torch, tokenizer, model, device


def generate_reply(
    torch: Any,
    tokenizer: Any,
    model: Any,
    messages: list[dict[str, str]],
    args: argparse.Namespace,
) -> str:
    prompt = tokenizer.apply_chat_template(
        messages,
        tokenize=False,
        add_generation_prompt=True,
    )
    encoded = tokenizer(prompt, return_tensors="pt", add_special_tokens=False)
    encoded = {name: tensor.to(model.device) for name, tensor in encoded.items()}
    input_length = encoded["input_ids"].shape[1]
    do_sample = args.temperature > 0
    generation_args: dict[str, Any] = {
        **encoded,
        "max_new_tokens": args.max_new_tokens,
        "do_sample": do_sample,
        "repetition_penalty": args.repetition_penalty,
        "pad_token_id": tokenizer.pad_token_id,
        "eos_token_id": tokenizer.eos_token_id,
    }
    if do_sample:
        generation_args["temperature"] = args.temperature
        generation_args["top_p"] = args.top_p

    with torch.inference_mode():
        output_ids = model.generate(**generation_args)
    new_tokens = output_ids[0, input_length:]
    reply = tokenizer.decode(new_tokens, skip_special_tokens=True).strip()
    if not reply:
        token_ids = new_tokens.tolist()
        raise RuntimeError(
            "model generated no text "
            f"(token_ids={token_ids[:8]}); the merged checkpoint may be degenerate"
        )
    return reply


def run(args: argparse.Namespace) -> int:
    model_dir = validate_args(args)
    torch, tokenizer, model, device = load_model(model_dir, args.device)
    history = load_history(args.history_file)
    if not history or history[0].get("role") != "system":
        history.insert(0, {"role": "system", "content": args.system_prompt})

    print(f"[Ready] Real model inference: {model_dir / 'model.safetensors'}")
    print(f"[Ready] Device: {device}; max_new_tokens={args.max_new_tokens}", flush=True)

    if args.prompt is not None:
        history.append({"role": "user", "content": args.prompt})
        print(generate_reply(torch, tokenizer, model, history, args), flush=True)
        return 0

    print("Commands: /reset clears history, /exit quits.\n", flush=True)
    while True:
        try:
            user_input = input("You: ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return 0
        if not user_input:
            continue
        if user_input.lower() in {"/exit", "exit", "quit"}:
            return 0
        if user_input == "/reset":
            history = [{"role": "system", "content": args.system_prompt}]
            print("Conversation history cleared.\n")
            continue

        history.append({"role": "user", "content": user_input})
        reply = generate_reply(torch, tokenizer, model, history, args)
        history.append({"role": "assistant", "content": reply})
        print(f"\nAssistant: {reply}\n", flush=True)


def main() -> int:
    try:
        return run(parse_args())
    except RuntimeError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
