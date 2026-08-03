#!/usr/bin/env python3

import argparse
import json
import math
import os
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

from trainer.train_sft import IGNORE_INDEX, encode_record, env_value, iter_json_records


OPTION_KEYS = ("opa", "opb", "opc", "opd")
OPTION_LABELS = ("A", "B", "C", "D")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Compare base and post-trained models on medical multiple-choice data")
    parser.add_argument("--data-file", default=env_value("NEURX_POSTTRAIN_EVAL_DATA", "/home/shuwen/shuwen/dataset/medical/test.json"))
    parser.add_argument("--base-model", default=env_value("NEURX_POSTTRAIN_MODEL_PATH", "/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct"))
    parser.add_argument("--posttrain-model", default=env_value("NEURX_POSTTRAIN_OUTPUT_DIR", "/home/shuwen/shuwen/posttrain"))
    parser.add_argument("--output-dir", default=env_value("NEURX_POSTTRAIN_EVAL_OUTPUT", "/home/shuwen/shuwen/posttrain/evaluation"))
    parser.add_argument("--max-samples", type=int, default=int(env_value("NEURX_POSTTRAIN_EVAL_MAX_SAMPLES", "256")))
    parser.add_argument("--max-length", type=int, default=int(env_value("NEURX_POSTTRAIN_EVAL_MAX_LENGTH", "256")))
    parser.add_argument("--batch-size", type=int, default=int(env_value("NEURX_POSTTRAIN_EVAL_BATCH_SIZE", "4")))
    parser.add_argument("--device", choices=("auto", "cuda", "cpu"), default=env_value("NEURX_POSTTRAIN_DEVICE", "auto"))
    return parser.parse_args()


def load_backend() -> tuple[Any, Any, Any]:
    try:
        import torch
        from transformers import AutoModelForCausalLM, AutoTokenizer
    except ImportError as exc:
        raise RuntimeError("evaluation dependencies are missing; run `make posttrain-install-deps`") from exc
    return torch, AutoModelForCausalLM, AutoTokenizer


def load_records(path: Path, max_samples: int) -> list[dict[str, Any]]:
    records = []
    for record in iter_json_records(path):
        if all(record.get(key) not in (None, "") for key in OPTION_KEYS) and record.get("question"):
            records.append(record)
        if max_samples > 0 and len(records) >= max_samples:
            break
    if not records:
        raise RuntimeError(f"no multiple-choice records found in {path}")
    return records


def candidate_examples(tokenizer: Any, records: list[dict[str, Any]], max_length: int) -> list[Any]:
    examples = []
    for record in records:
        for key in OPTION_KEYS:
            candidate = dict(record)
            candidate["output"] = str(record[key])
            encoded = encode_record(tokenizer, candidate, max_length)
            if encoded is None:
                raise RuntimeError(f"failed to encode record {record.get('id', '<unknown>')} option {key}")
            examples.append(encoded)
    return examples


def resolve_device(torch: Any, requested: str) -> tuple[str, Any]:
    if requested == "cuda" and not torch.cuda.is_available():
        raise RuntimeError("CUDA was requested but no CUDA device is available")
    device = "cuda" if requested == "auto" and torch.cuda.is_available() else requested
    if device == "auto":
        device = "cpu"
    dtype = torch.float32
    if device == "cuda":
        dtype = torch.bfloat16 if torch.cuda.is_bf16_supported() else torch.float16
    return device, dtype


def score_model(
    model_path: Path,
    tokenizer: Any,
    examples: list[Any],
    batch_size: int,
    device: str,
    dtype: Any,
    torch: Any,
    model_factory: Any,
) -> list[dict[str, float]]:
    print(f"[Eval] loading {model_path}", flush=True)
    model = model_factory.from_pretrained(model_path, local_files_only=True, torch_dtype=dtype)
    model.to(device)
    model.eval()
    scores = []
    started = time.time()
    with torch.inference_mode():
        for offset in range(0, len(examples), batch_size):
            items = examples[offset:offset + batch_size]
            width = max(len(item.input_ids) for item in items)
            input_rows = []
            label_rows = []
            mask_rows = []
            for item in items:
                padding = width - len(item.input_ids)
                input_rows.append(item.input_ids + [tokenizer.pad_token_id] * padding)
                label_rows.append(item.labels + [IGNORE_INDEX] * padding)
                mask_rows.append([1] * len(item.input_ids) + [0] * padding)
            input_ids = torch.tensor(input_rows, dtype=torch.long, device=device)
            labels = torch.tensor(label_rows, dtype=torch.long, device=device)
            attention_mask = torch.tensor(mask_rows, dtype=torch.long, device=device)
            use_amp = device == "cuda"
            with torch.autocast(device_type="cuda", dtype=dtype, enabled=use_amp):
                logits = model(input_ids=input_ids, attention_mask=attention_mask).logits[:, :-1, :]
            shifted_labels = labels[:, 1:]
            for row in range(len(items)):
                valid = shifted_labels[row] != IGNORE_INDEX
                targets = shifted_labels[row][valid]
                if targets.numel() == 0:
                    raise RuntimeError("candidate contains no scoreable response tokens")
                selected = logits[row][valid].float()
                token_log_probs = selected.gather(1, targets.unsqueeze(1)).squeeze(1) - selected.logsumexp(dim=1)
                scores.append({
                    "sum_log_probability": float(token_log_probs.sum().cpu()),
                    "mean_log_probability": float(token_log_probs.mean().cpu()),
                    "tokens": int(targets.numel()),
                })
            completed_questions = min(len(examples), offset + len(items)) // 4
            if completed_questions and completed_questions % 25 == 0:
                print(f"[Eval] {model_path.name}: {completed_questions}/{len(examples) // 4} questions", flush=True)
    print(f"[Eval] {model_path.name} completed in {time.time() - started:.1f}s", flush=True)
    del model
    if device == "cuda":
        torch.cuda.empty_cache()
    return scores


def softmax_confidence(values: list[float], selected: int) -> float:
    maximum = max(values)
    weights = [math.exp(value - maximum) for value in values]
    return weights[selected] / sum(weights)


def prediction_from_scores(scores: list[dict[str, float]]) -> tuple[int, float, float]:
    values = [item["mean_log_probability"] for item in scores]
    order = sorted(range(4), key=lambda index: values[index], reverse=True)
    selected = order[0]
    return selected, softmax_confidence(values, selected), values[order[0]] - values[order[1]]


def labeled_answer(record: dict[str, Any]) -> int | None:
    value = record.get("cop", record.get("choice"))
    if isinstance(value, str) and value.strip().isdigit():
        value = int(value.strip())
    if isinstance(value, int) and 1 <= value <= 4:
        return value - 1
    return None


def build_report(
    records: list[dict[str, Any]],
    base_scores: list[dict[str, float]],
    posttrain_scores: list[dict[str, float]],
    data_file: Path,
    base_model: Path,
    posttrain_model: Path,
) -> dict[str, Any]:
    details = []
    changed = 0
    labeled = 0
    base_correct = 0
    posttrain_correct = 0
    subject_totals = Counter()
    subject_changes = Counter()
    base_distribution = Counter()
    posttrain_distribution = Counter()
    for index, record in enumerate(records):
        start = index * 4
        base_group = base_scores[start:start + 4]
        posttrain_group = posttrain_scores[start:start + 4]
        base_prediction, base_confidence, base_margin = prediction_from_scores(base_group)
        posttrain_prediction, posttrain_confidence, posttrain_margin = prediction_from_scores(posttrain_group)
        answer = labeled_answer(record)
        subject = str(record.get("subject_name") or "Unknown")
        is_changed = base_prediction != posttrain_prediction
        changed += int(is_changed)
        subject_totals[subject] += 1
        subject_changes[subject] += int(is_changed)
        base_distribution[OPTION_LABELS[base_prediction]] += 1
        posttrain_distribution[OPTION_LABELS[posttrain_prediction]] += 1
        if answer is not None:
            labeled += 1
            base_correct += int(base_prediction == answer)
            posttrain_correct += int(posttrain_prediction == answer)
        details.append({
            "id": record.get("id"),
            "question": record["question"],
            "subject": subject,
            "choices": {label: record[key] for label, key in zip(OPTION_LABELS, OPTION_KEYS)},
            "answer": OPTION_LABELS[answer] if answer is not None else None,
            "base_prediction": OPTION_LABELS[base_prediction],
            "posttrain_prediction": OPTION_LABELS[posttrain_prediction],
            "changed": is_changed,
            "base_confidence": base_confidence,
            "posttrain_confidence": posttrain_confidence,
            "base_margin": base_margin,
            "posttrain_margin": posttrain_margin,
            "base_scores": base_group,
            "posttrain_scores": posttrain_group,
        })
    subject_summary = []
    for subject, total in subject_totals.most_common():
        subject_summary.append({
            "subject": subject,
            "samples": total,
            "changed": subject_changes[subject],
            "change_rate": subject_changes[subject] / total,
        })
    metrics = {
        "samples": len(records),
        "labeled_samples": labeled,
        "changed_predictions": changed,
        "change_rate": changed / len(records),
        "base_prediction_distribution": dict(base_distribution),
        "posttrain_prediction_distribution": dict(posttrain_distribution),
        "base_accuracy": base_correct / labeled if labeled else None,
        "posttrain_accuracy": posttrain_correct / labeled if labeled else None,
        "accuracy_delta": (posttrain_correct - base_correct) / labeled if labeled else None,
    }
    return {
        "data_file": str(data_file),
        "base_model": str(base_model),
        "posttrain_model": str(posttrain_model),
        "scoring": "mean conditional log probability of each option text",
        "metrics": metrics,
        "subjects": subject_summary,
        "predictions": details,
    }


def markdown_report(report: dict[str, Any]) -> str:
    metrics = report["metrics"]
    lines = [
        "# Medical MCQ Evaluation",
        "",
        f"- Data: `{report['data_file']}`",
        f"- Samples: {metrics['samples']}",
        f"- Labeled samples: {metrics['labeled_samples']}",
        f"- Changed predictions: {metrics['changed_predictions']} ({metrics['change_rate']:.2%})",
    ]
    if metrics["labeled_samples"]:
        lines.extend([
            f"- Base accuracy: {metrics['base_accuracy']:.2%}",
            f"- Post-trained accuracy: {metrics['posttrain_accuracy']:.2%}",
            f"- Accuracy delta: {metrics['accuracy_delta']:+.2%}",
        ])
    else:
        lines.append("- Accuracy: unavailable because the dataset has no answer labels")
    lines.extend(["", "## Changed Predictions", "", "| ID | Subject | Base | Post-trained |", "|---|---|---:|---:|"])
    shown = 0
    for item in report["predictions"]:
        if item["changed"] and shown < 50:
            lines.append(f"| {item['id']} | {item['subject']} | {item['base_prediction']} | {item['posttrain_prediction']} |")
            shown += 1
    if shown == 0:
        lines.append("| - | - | No changed predictions | - |")
    return "\n".join(lines) + "\n"


def run(args: argparse.Namespace) -> dict[str, Any]:
    data_file = Path(args.data_file).expanduser().resolve()
    base_model = Path(args.base_model).expanduser().resolve()
    posttrain_model = Path(args.posttrain_model).expanduser().resolve()
    output_dir = Path(args.output_dir).expanduser().resolve()
    for path in (data_file, base_model / "config.json", posttrain_model / "config.json"):
        if not path.exists():
            raise RuntimeError(f"required input does not exist: {path}")
    if args.max_length < 2 or args.batch_size < 1:
        raise RuntimeError("max-length must be at least 2 and batch-size must be positive")
    torch, model_factory, tokenizer_factory = load_backend()
    device, dtype = resolve_device(torch, args.device)
    tokenizer = tokenizer_factory.from_pretrained(base_model, local_files_only=True, use_fast=True)
    if tokenizer.pad_token_id is None:
        tokenizer.pad_token = tokenizer.eos_token
    records = load_records(data_file, args.max_samples)
    examples = candidate_examples(tokenizer, records, args.max_length)
    print(f"[Eval] records={len(records)} labeled={sum(labeled_answer(item) is not None for item in records)} device={device}", flush=True)
    base_scores = score_model(base_model, tokenizer, examples, args.batch_size, device, dtype, torch, model_factory)
    posttrain_scores = score_model(posttrain_model, tokenizer, examples, args.batch_size, device, dtype, torch, model_factory)
    report = build_report(records, base_scores, posttrain_scores, data_file, base_model, posttrain_model)
    output_dir.mkdir(parents=True, exist_ok=True)
    json_path = output_dir / f"{data_file.stem}_comparison.json"
    markdown_path = output_dir / f"{data_file.stem}_comparison.md"
    json_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    markdown_path.write_text(markdown_report(report), encoding="utf-8")
    print(json.dumps(report["metrics"], ensure_ascii=False), flush=True)
    print(f"[Eval] JSON report: {json_path}", flush=True)
    print(f"[Eval] Markdown report: {markdown_path}", flush=True)
    return report


def main() -> int:
    try:
        run(parse_args())
    except Exception as exc:
        print(f"[ERROR] {exc}", file=sys.stderr, flush=True)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
