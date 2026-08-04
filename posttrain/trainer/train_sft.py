

import argparse

import json

import math

import os

import random

import sys

import time

from dataclasses import asdict, dataclass

from pathlib import Path

from typing import Any, Iterator



IGNORE_INDEX = -100



@dataclass

class EncodedExample:

    input_ids: list[int]

    labels: list[int]



def env_value(name: str, default: str) -> str:

    value = os.environ.get(name)

    return value if value not in (None, "") else default



def env_bool(name: str, default: bool) -> bool:

    value = os.environ.get(name)

    if value is None:

        return default

    return value.strip().lower() in {"1", "true", "yes", "on"}



def iter_json_records(path: Path) -> Iterator[dict[str, Any]]:

    with path.open("r", encoding="utf-8") as stream:

        first = ""

        while True:

            char = stream.read(1)

            if not char:

                return

            if not char.isspace():

                first = char

                break

        stream.seek(0)

        if first != "[":

            for line_number, line in enumerate(stream, 1):

                line = line.strip()

                if not line:

                    continue

                try:

                    record = json.loads(line)

                except json.JSONDecodeError as exc:

                    raise ValueError(f"invalid JSON on line {line_number}: {exc}") from exc

                if isinstance(record, dict):

                    yield record

            return


        decoder = json.JSONDecoder()

        buffer = ""

        position = 0

        array_started = False

        eof = False

        while True:

            if position >= len(buffer) and not eof:

                buffer = stream.read(1024 * 1024)

                position = 0

                eof = not buffer

            while True:

                while position < len(buffer) and (buffer[position].isspace() or buffer[position] == ","):

                    position += 1

                if not array_started and position < len(buffer) and buffer[position] == "[":

                    array_started = True

                    position += 1

                    continue

                break

            if position < len(buffer) and buffer[position] == "]":

                return

            if eof and position >= len(buffer):

                return

            try:

                record, end = decoder.raw_decode(buffer, position)

            except json.JSONDecodeError:

                if eof:

                    raise ValueError(f"invalid JSON array in {path}")

                buffer = buffer[position:] + stream.read(1024 * 1024)

                position = 0

                eof = stream.tell() == path.stat().st_size

                continue

            position = end

            if isinstance(record, dict):

                yield record

            if position > 1024 * 1024:

                buffer = buffer[position:]

                position = 0



def choice_text(record: dict[str, Any]) -> str:

    choices = [record.get("opa"), record.get("opb"), record.get("opc"), record.get("opd")]

    choice = record.get("cop", record.get("choice"))

    if isinstance(choice, str) and choice.strip().isdigit():

        choice = int(choice.strip())

    if isinstance(choice, int) and 1 <= choice <= len(choices):

        selected = choices[choice - 1]

        if selected:

            return str(selected)

    answer = record.get("answer")

    return str(answer) if answer is not None else ""



def record_messages(record: dict[str, Any]) -> list[dict[str, str]]:

    messages = record.get("messages")

    if isinstance(messages, list) and messages:

        normalized = []

        for message in messages:

            if isinstance(message, dict) and message.get("role") and message.get("content") is not None:

                normalized.append({"role": str(message["role"]), "content": str(message["content"])})

        if normalized and normalized[-1]["role"] == "assistant":

            return normalized


    question = str(record.get("question", record.get("instruction", ""))).strip()

    extra_input = str(record.get("input", "")).strip()

    if extra_input:

        question = f"{question}\n{extra_input}" if question else extra_input

    options = []

    for label, key in zip("ABCD", ("opa", "opb", "opc", "opd")):

        value = record.get(key)

        if value not in (None, ""):

            options.append(f"{label}. {value}")

    if options:

        question = question + "\n" + "\n".join(options)


    answer = record.get("output")

    if answer in (None, ""):

        answer = choice_text(record)

        explanation = record.get("exp", record.get("explanation"))

        if explanation not in (None, ""):

            answer = f"{answer}\n\nExplanation: {explanation}" if answer else str(explanation)

    if not question or answer in (None, ""):

        return []

    return [
        {"role": "system", "content": "You are a precise medical question-answering assistant."},
        {"role": "user", "content": question},
        {"role": "assistant", "content": str(answer).strip()},
    ]



def truncate_example(input_ids: list[int], labels: list[int], max_length: int) -> EncodedExample | None:

    if len(input_ids) != len(labels):

        return None

    target_positions = [index for index, label in enumerate(labels) if label != IGNORE_INDEX]

    if not target_positions:

        return None

    response_start = target_positions[0]

    if len(input_ids) > max_length:

        response_ids = input_ids[response_start:]

        response_labels = labels[response_start:]

        if len(response_ids) >= max_length:

            input_ids = response_ids[:max_length]

            labels = response_labels[:max_length]

        else:

            prompt_budget = max_length - len(response_ids)

            input_ids = input_ids[max(0, response_start - prompt_budget):response_start] + response_ids

            labels = [IGNORE_INDEX] * min(prompt_budget, response_start) + response_labels

    return EncodedExample(input_ids=input_ids, labels=labels)



def extract_token_ids(encoded: Any) -> list[int]:

    if isinstance(encoded, dict) or hasattr(encoded, "keys"):

        encoded = encoded["input_ids"]

    if hasattr(encoded, "tolist"):

        encoded = encoded.tolist()

    if encoded and isinstance(encoded[0], list):

        encoded = encoded[0]

    return [int(value) for value in encoded]



def encode_record(tokenizer: Any, record: dict[str, Any], max_length: int) -> EncodedExample | None:

    raw_ids = record.get("input_ids")

    raw_labels = record.get("labels")

    if isinstance(raw_ids, list) and isinstance(raw_labels, list):

        try:

            input_ids = [int(value) for value in raw_ids]

            labels = [int(value) for value in raw_labels]

        except (TypeError, ValueError):

            return None

        return truncate_example(input_ids, labels, max_length)


    messages = record_messages(record)

    if not messages:

        return None

    prompt_messages = messages[:-1]

    if getattr(tokenizer, "chat_template", None):

        prompt_ids = extract_token_ids(tokenizer.apply_chat_template(
            prompt_messages, tokenize=True, add_generation_prompt=True
        ))

        full_ids = extract_token_ids(tokenizer.apply_chat_template(
            messages, tokenize=True, add_generation_prompt=False
        ))

        prefix_length = 0

        while prefix_length < min(len(prompt_ids), len(full_ids)) and prompt_ids[prefix_length] == full_ids[prefix_length]:

            prefix_length += 1

        labels = [IGNORE_INDEX] * prefix_length + full_ids[prefix_length:]

        return truncate_example(full_ids, labels, max_length)


    prompt = "\n".join(f"{item['role']}: {item['content']}" for item in prompt_messages) + "\nassistant: "

    answer = messages[-1]["content"]

    prompt_ids = tokenizer(prompt, add_special_tokens=True)["input_ids"]

    answer_ids = tokenizer(answer, add_special_tokens=False)["input_ids"]

    eos_id = getattr(tokenizer, "eos_token_id", None)

    if eos_id is not None and (not answer_ids or answer_ids[-1] != eos_id):

        answer_ids.append(eos_id)

    return truncate_example(prompt_ids + answer_ids, [IGNORE_INDEX] * len(prompt_ids) + answer_ids, max_length)



def load_examples(tokenizer: Any, path: Path, max_length: int, max_samples: int, seed: int) -> list[EncodedExample]:

    examples = []

    invalid = 0

    for record in iter_json_records(path):

        encoded = encode_record(tokenizer, record, max_length)

        if encoded is None:

            invalid += 1

            continue

        examples.append(encoded)

        if max_samples > 0 and len(examples) >= max_samples:

            break

    if not examples:

        raise RuntimeError(f"no trainable examples found in {path}; skipped {invalid} invalid records")

    random.Random(seed).shuffle(examples)

    target_tokens = sum(sum(label != IGNORE_INDEX for label in item.labels) for item in examples)

    print(f"[Data] loaded={len(examples)} skipped={invalid} target_tokens={target_tokens}", flush=True)

    return examples



def atomic_write_json(path: Path, payload: dict[str, Any]) -> None:

    temporary = path.with_suffix(path.suffix + ".tmp")

    temporary.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    temporary.replace(path)



def load_backend() -> tuple[Any, ...]:

    try:

        import torch

        from peft import LoraConfig, get_peft_model

        from transformers import AutoModelForCausalLM, AutoTokenizer, get_cosine_schedule_with_warmup

    except ImportError as exc:

        raise RuntimeError(
            "posttrain dependencies are missing; run `make posttrain-install-deps` first"
        ) from exc

    return torch, LoraConfig, get_peft_model, AutoModelForCausalLM, AutoTokenizer, get_cosine_schedule_with_warmup



def parse_args() -> argparse.Namespace:

    parser = argparse.ArgumentParser(description="LoRA supervised fine-tuning for a local Hugging Face causal LM")

    parser.add_argument("--model-path", default=env_value("NEURX_POSTTRAIN_MODEL_PATH", "/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct"))

    parser.add_argument("--data-file", default=env_value("NEURX_POSTTRAIN_DATA_FILE", "/home/shuwen/shuwen/dataset/medical/train.json"))

    parser.add_argument("--output-dir", default=env_value("NEURX_POSTTRAIN_OUTPUT_DIR", "/home/shuwen/shuwen/posttrain"))

    parser.add_argument("--epochs", type=int, default=int(env_value("NEURX_POSTTRAIN_EPOCHS", "1")))

    parser.add_argument("--batch-size", type=int, default=int(env_value("NEURX_POSTTRAIN_BATCH_SIZE", "1")))

    parser.add_argument("--gradient-accumulation", type=int, default=int(env_value("NEURX_POSTTRAIN_GRAD_ACCUM", "8")))

    parser.add_argument("--max-length", type=int, default=int(env_value("NEURX_POSTTRAIN_MAX_LENGTH", "256")))

    parser.add_argument("--max-samples", type=int, default=int(env_value("NEURX_POSTTRAIN_MAX_SAMPLES", "512")))

    parser.add_argument("--learning-rate", type=float, default=float(env_value("NEURX_POSTTRAIN_LR", "0.0002")))

    parser.add_argument("--warmup-ratio", type=float, default=float(env_value("NEURX_POSTTRAIN_WARMUP_RATIO", "0.03")))

    parser.add_argument("--weight-decay", type=float, default=float(env_value("NEURX_POSTTRAIN_WEIGHT_DECAY", "0.01")))

    parser.add_argument("--lora-rank", type=int, default=int(env_value("NEURX_POSTTRAIN_LORA_RANK", "8")))

    parser.add_argument("--lora-alpha", type=float, default=float(env_value("NEURX_POSTTRAIN_LORA_ALPHA", "16")))

    parser.add_argument("--lora-dropout", type=float, default=float(env_value("NEURX_POSTTRAIN_LORA_DROPOUT", "0.05")))

    parser.add_argument("--target-modules", default=env_value("NEURX_POSTTRAIN_TARGET_MODULES", "q_proj,k_proj,v_proj,o_proj"))

    parser.add_argument("--device", choices=("auto", "cuda", "cpu"), default=env_value("NEURX_POSTTRAIN_DEVICE", "auto"))

    parser.add_argument("--seed", type=int, default=int(env_value("NEURX_POSTTRAIN_SEED", "42")))

    parser.add_argument("--log-steps", type=int, default=int(env_value("NEURX_POSTTRAIN_LOG_STEPS", "1")))

    parser.add_argument("--merge-model", action=argparse.BooleanOptionalAction, default=env_bool("NEURX_POSTTRAIN_MERGE_MODEL", True))

    parser.add_argument("--gradient-checkpointing", action=argparse.BooleanOptionalAction, default=env_bool("NEURX_POSTTRAIN_GRADIENT_CHECKPOINTING", True))

    return parser.parse_args()



def validate_args(args: argparse.Namespace) -> tuple[Path, Path, Path]:

    model_path = Path(args.model_path).expanduser().resolve()

    data_file = Path(args.data_file).expanduser().resolve()

    output_dir = Path(args.output_dir).expanduser().resolve()

    if not (model_path / "config.json").is_file() or not (model_path / "model.safetensors").is_file():

        raise RuntimeError(f"base model is incomplete: {model_path}")

    if not data_file.is_file():

        raise RuntimeError(f"training data does not exist: {data_file}")

    if output_dir == model_path or model_path in output_dir.parents:

        raise RuntimeError("output directory must not overwrite or be nested inside the base model directory")

    for name in ("epochs", "batch_size", "gradient_accumulation", "max_length", "lora_rank"):

        if getattr(args, name) < 1:

            raise RuntimeError(f"{name.replace('_', '-')} must be positive")

    return model_path, data_file, output_dir



def train(args: argparse.Namespace) -> dict[str, Any]:

    model_path, data_file, output_dir = validate_args(args)

    torch, LoraConfig, get_peft_model, AutoModelForCausalLM, AutoTokenizer, scheduler_factory = load_backend()

    random.seed(args.seed)

    torch.manual_seed(args.seed)

    if torch.cuda.is_available():

        torch.cuda.manual_seed_all(args.seed)

    if args.device == "cuda" and not torch.cuda.is_available():

        raise RuntimeError("CUDA was requested but no CUDA device is available")

    device = "cuda" if args.device == "auto" and torch.cuda.is_available() else args.device

    if device == "auto":

        device = "cpu"

    dtype = torch.float32

    if device == "cuda":

        dtype = torch.bfloat16 if torch.cuda.is_bf16_supported() else torch.float16


    print(f"[Model] loading {model_path} on {device} with {dtype}", flush=True)

    tokenizer = AutoTokenizer.from_pretrained(model_path, local_files_only=True, use_fast=True)

    if tokenizer.pad_token_id is None:

        tokenizer.pad_token = tokenizer.eos_token

    model = AutoModelForCausalLM.from_pretrained(
        model_path,
        local_files_only=True,
        torch_dtype=dtype,
    )

    model.config.use_cache = False

    if args.gradient_checkpointing:

        model.gradient_checkpointing_enable()

        model.enable_input_require_grads()


    target_modules = [item.strip() for item in args.target_modules.split(",") if item.strip()]

    present_suffixes = {name.rsplit(".", 1)[-1] for name, _ in model.named_modules()}

    missing_targets = [name for name in target_modules if name not in present_suffixes]

    if missing_targets:

        raise RuntimeError(f"LoRA target modules not found in model: {', '.join(missing_targets)}")

    lora_config = LoraConfig(
        task_type="CAUSAL_LM",
        r=args.lora_rank,
        lora_alpha=args.lora_alpha,
        lora_dropout=args.lora_dropout,
        target_modules=target_modules,
        bias="none",
    )

    model = get_peft_model(model, lora_config)

    model.to(device)

    trainable = [(name, parameter) for name, parameter in model.named_parameters() if parameter.requires_grad]

    if not trainable:

        raise RuntimeError("PEFT did not create any trainable parameters")

    trainable_count = sum(parameter.numel() for _, parameter in trainable)

    total_count = sum(parameter.numel() for parameter in model.parameters())

    print(f"[Model] trainable={trainable_count:,} total={total_count:,} ({100 * trainable_count / total_count:.4f}%)", flush=True)


    examples = load_examples(tokenizer, data_file, args.max_length, args.max_samples, args.seed)

    batches_per_epoch = math.ceil(len(examples) / args.batch_size)

    optimizer_steps = math.ceil(batches_per_epoch / args.gradient_accumulation) * args.epochs

    warmup_steps = int(optimizer_steps * args.warmup_ratio)

    optimizer = torch.optim.AdamW(
        (parameter for _, parameter in trainable),
        lr=args.learning_rate,
        weight_decay=args.weight_decay,
    )

    scheduler = scheduler_factory(optimizer, warmup_steps, optimizer_steps)

    initial_parameters = {
        name: parameter.detach().float().cpu().clone()
        for name, parameter in trainable
    }

    losses = []

    completed_steps = 0

    maximum_gradient_norm = 0.0

    started = time.time()

    optimizer.zero_grad(set_to_none=True)


    for epoch in range(args.epochs):

        random.Random(args.seed + epoch).shuffle(examples)

        for batch_index in range(batches_per_epoch):

            items = examples[batch_index * args.batch_size:(batch_index + 1) * args.batch_size]

            max_batch_length = max(len(item.input_ids) for item in items)

            input_rows = []

            label_rows = []

            mask_rows = []

            for item in items:

                padding = max_batch_length - len(item.input_ids)

                input_rows.append(item.input_ids + [tokenizer.pad_token_id] * padding)

                label_rows.append(item.labels + [IGNORE_INDEX] * padding)

                mask_rows.append([1] * len(item.input_ids) + [0] * padding)

            batch = {
                "input_ids": torch.tensor(input_rows, dtype=torch.long, device=device),
                "labels": torch.tensor(label_rows, dtype=torch.long, device=device),
                "attention_mask": torch.tensor(mask_rows, dtype=torch.long, device=device),
            }

            use_amp = device == "cuda"

            with torch.autocast(device_type="cuda", dtype=dtype, enabled=use_amp):

                loss = model(**batch).loss

            if not torch.isfinite(loss):

                raise RuntimeError(f"non-finite loss at epoch {epoch + 1}, batch {batch_index + 1}: {loss.item()}")

            losses.append(float(loss.detach().cpu()))

            accumulation_start = (batch_index // args.gradient_accumulation) * args.gradient_accumulation

            accumulation_size = min(args.gradient_accumulation, batches_per_epoch - accumulation_start)

            (loss / accumulation_size).backward()

            should_step = (batch_index + 1) % args.gradient_accumulation == 0 or batch_index + 1 == batches_per_epoch

            if should_step:

                grad_norm = torch.nn.utils.clip_grad_norm_((parameter for _, parameter in trainable), 1.0)

                if not torch.isfinite(grad_norm):

                    raise RuntimeError(f"non-finite gradient norm at optimizer step {completed_steps + 1}")

                maximum_gradient_norm = max(maximum_gradient_norm, float(grad_norm))

                optimizer.step()

                scheduler.step()

                optimizer.zero_grad(set_to_none=True)

                completed_steps += 1

                if completed_steps % args.log_steps == 0 or completed_steps == optimizer_steps:

                    recent = losses[-accumulation_size:]

                    print(
                        f"[Train] epoch={epoch + 1}/{args.epochs} step={completed_steps}/{optimizer_steps} "
                        f"loss={sum(recent) / len(recent):.6f} grad_norm={float(grad_norm):.6f} "
                        f"lr={scheduler.get_last_lr()[0]:.8f}",
                        flush=True,
                    )


    delta = max(
        (parameter.detach().float().cpu() - initial_parameters[name]).abs().max().item()
        for name, parameter in trainable
    )

    if completed_steps == 0 or maximum_gradient_norm == 0.0 or delta == 0.0:

        raise RuntimeError("training produced no gradient or LoRA parameter update")

    output_dir.mkdir(parents=True, exist_ok=True)

    adapter_dir = output_dir / "adapter"

    adapter_dir.mkdir(parents=True, exist_ok=True)

    model.save_pretrained(adapter_dir, safe_serialization=True)

    tokenizer.save_pretrained(adapter_dir)


    if args.merge_model:

        print(f"[Save] merging adapter into {output_dir}", flush=True)

        model.config.use_cache = True

        merged_model = model.merge_and_unload(progressbar=True)

        merged_model.save_pretrained(output_dir, safe_serialization=True, max_shard_size="5GB")

        tokenizer.save_pretrained(output_dir)


    state = {
        "status": "completed",
        "base_model": str(model_path),
        "data_file": str(data_file),
        "output_dir": str(output_dir),
        "adapter_dir": str(adapter_dir),
        "merged_model": args.merge_model,
        "device": device,
        "dtype": str(dtype),
        "examples": len(examples),
        "epochs": args.epochs,
        "batch_size": args.batch_size,
        "gradient_accumulation": args.gradient_accumulation,
        "max_length": args.max_length,
        "optimizer_steps": completed_steps,
        "learning_rate": args.learning_rate,
        "lora_rank": args.lora_rank,
        "lora_alpha": args.lora_alpha,
        "target_modules": target_modules,
        "trainable_parameters": trainable_count,
        "initial_loss": losses[0],
        "final_loss": losses[-1],
        "best_loss": min(losses),
        "parameter_delta_max": delta,
        "gradient_norm_max": maximum_gradient_norm,
        "elapsed_seconds": time.time() - started,
    }

    atomic_write_json(output_dir / "training_state.json", state)

    print(f"[Save] adapter: {adapter_dir}", flush=True)

    if args.merge_model:

        print(f"[Save] merged model: {output_dir}", flush=True)

    print(f"[Done] optimizer_steps={completed_steps} parameter_delta_max={delta:.8e}", flush=True)

    return state



def main() -> int:

    try:

        state = train(parse_args())

    except Exception as exc:

        print(f"[ERROR] {exc}", file=sys.stderr, flush=True)

        return 1

    print(json.dumps(asdict(state) if hasattr(state, "__dataclass_fields__") else state, ensure_ascii=False), flush=True)

    return 0



if __name__ == "__main__":

    raise SystemExit(main())

