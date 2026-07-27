#!/usr/bin/env python3
"""Generate and verify the Phase 2 Module 0 post-train golden snapshot.

The golden directory is the source of truth for Phase 2 Module 0. It freezes:
- a small medical dataset slice,
- a fixed prompt set,
- tokenizer output for those prompts,
- deterministic baseline responses for those prompts,
- and the reference model shape facts used by later modules.

This script is stdlib-only so it can run in the current environment without
external Python packages.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import unicodedata
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Sequence, Tuple


DEFAULT_REPO_ROOT = Path("/home/shuwen/shuwen")
DEFAULT_MODEL_DIR = DEFAULT_REPO_ROOT / "model" / "Qwen2.5-0.5B-Instruct"
DEFAULT_DATA_FILE = DEFAULT_REPO_ROOT / "dataset" / "medical" / "train.json"
DEFAULT_GOLDEN_DIR = DEFAULT_REPO_ROOT / "posttrain" / "golden"
DEFAULT_REFERENCE_MODEL = "Qwen2.5-0.5B-Instruct"
DEFAULT_VERSION = "golden-v1"
GOLDEN_SCHEMA_VERSION = 1
DEFAULT_SEED = 42
DEFAULT_DTYPE = "float16"
DEFAULT_DATASET_LIMIT = 12
DEFAULT_PROMPTS: List[Dict[str, str]] = [
    {
        "name": "treatment_q",
        "text": "What is the treatment for chronic urinary tract infection?",
        "category": "treatment",
    },
    {
        "name": "symptom_q",
        "text": "I have fever and pain in my leg.",
        "category": "symptoms",
    },
    {
        "name": "diagnosis_q",
        "text": "How do doctors make a diagnosis?",
        "category": "diagnosis",
    },
    {
        "name": "medication_q",
        "text": "What medication is used for hypertension?",
        "category": "medication",
    },
    {
        "name": "health_q",
        "text": "Tell me about health and medical care.",
        "category": "health",
    },
]


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2, sort_keys=True, ensure_ascii=False)
        handle.write("\n")


def load_jsonl_samples(path: Path, limit: int) -> List[Dict[str, Any]]:
    samples: List[Dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as handle:
        for line_no, raw_line in enumerate(handle, start=1):
            line = raw_line.strip()
            if not line:
                continue
            item = json.loads(line)
            item["_source_line"] = line_no
            samples.append(item)
            if len(samples) >= limit:
                break
    return samples


def bytes_to_unicode() -> Dict[int, str]:
    bs = list(range(ord("!"), ord("~") + 1))
    bs.extend(range(ord("¡"), ord("¬") + 1))
    bs.extend(range(ord("®"), ord("ÿ") + 1))
    cs = bs[:]
    n = 0
    for b in range(256):
        if b not in bs:
            bs.append(b)
            cs.append(256 + n)
            n += 1
    return {b: chr(c) for b, c in zip(bs, cs)}


def simple_ascii_pretokenize(text: str) -> List[str]:
    """Approximate the GPT-2/Qwen split pattern without external regex packages.

    The prompts used for the golden baseline are ASCII English strings, so a
    conservative ASCII tokenizer is sufficient and deterministic.
    """

    pattern = re.compile(r" ?[A-Za-z]+| ?\d+| ?[^A-Za-z0-9\s]+|\s+")
    return pattern.findall(text)


@dataclass
class BPEModel:
    vocab: Dict[str, int]
    ranks: Dict[Tuple[str, str], int]
    byte_encoder: Dict[int, str]
    unk_token: str | None
    source_sha256: str
    config_sha256: str

    @classmethod
    def from_tokenizer_json(cls, tokenizer_path: Path, config_path: Path) -> "BPEModel":
        payload = read_json(tokenizer_path)
        model = payload["model"]
        vocab = {str(token): int(idx) for token, idx in model["vocab"].items()}
        ranks: Dict[Tuple[str, str], int] = {}
        for rank, merge in enumerate(model["merges"]):
            left, right = merge.split(" ", 1)
            ranks[(left, right)] = rank
        unk_token = model.get("unk_token")
        byte_encoder = bytes_to_unicode()
        return cls(
            vocab=vocab,
            ranks=ranks,
            byte_encoder=byte_encoder,
            unk_token=unk_token,
            source_sha256=sha256_file(tokenizer_path),
            config_sha256=sha256_file(config_path),
        )

    def encode(self, text: str) -> List[int]:
        token_ids: List[int] = []
        for piece in simple_ascii_pretokenize(text):
            byte_piece = "".join(self.byte_encoder[b] for b in piece.encode("utf-8"))
            for token in self._bpe(byte_piece):
                token_id = self.vocab.get(token)
                if token_id is None:
                    if self.unk_token is not None and self.unk_token in self.vocab:
                        token_ids.append(self.vocab[self.unk_token])
                    else:
                        raise KeyError(f"token not found in vocab: {token!r}")
                else:
                    token_ids.append(token_id)
        return token_ids

    def _bpe(self, token: str) -> List[str]:
        word = tuple(token)
        if len(word) == 1:
            return [token]

        pairs = self._get_pairs(word)
        if not pairs:
            return [token]

        while True:
            best_pair: Tuple[str, str] | None = None
            best_rank = None
            for pair in pairs:
                rank = self.ranks.get(pair)
                if rank is None:
                    continue
                if best_rank is None or rank < best_rank:
                    best_rank = rank
                    best_pair = pair
            if best_pair is None:
                break

            first, second = best_pair
            new_word: List[str] = []
            i = 0
            while i < len(word):
                try:
                    j = word.index(first, i)
                except ValueError:
                    new_word.extend(word[i:])
                    break

                new_word.extend(word[i:j])
                i = j
                if i < len(word) - 1 and word[i] == first and word[i + 1] == second:
                    new_word.append(first + second)
                    i += 2
                else:
                    new_word.append(word[i])
                    i += 1
            word = tuple(new_word)
            if len(word) <= 1:
                break
            pairs = self._get_pairs(word)

        return list(word)

    @staticmethod
    def _get_pairs(word: Sequence[str]) -> set[Tuple[str, str]]:
        return {(word[i], word[i + 1]) for i in range(len(word) - 1)}


def summarize_dataset(samples: Sequence[Dict[str, Any]]) -> Dict[str, Any]:
    subject_counts: Dict[str, int] = {}
    choice_counts: Dict[str, int] = {}
    for item in samples:
        subject = str(item.get("subject_name") or "unknown")
        choice = str(item.get("choice_type") or "unknown")
        subject_counts[subject] = subject_counts.get(subject, 0) + 1
        choice_counts[choice] = choice_counts.get(choice, 0) + 1
    return {
        "count": len(samples),
        "subject_counts": dict(sorted(subject_counts.items())),
        "choice_type_counts": dict(sorted(choice_counts.items())),
    }


def build_baseline_prompt_data(prompts: Sequence[Dict[str, str]], tokenizer: BPEModel) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    prompt_tokenizations: List[Dict[str, Any]] = []
    prompt_outputs: List[Dict[str, Any]] = []
    for prompt in prompts:
        token_ids = tokenizer.encode(prompt["text"])
        prompt_tokenizations.append(
            {
                "name": prompt["name"],
                "category": prompt["category"],
                "text": prompt["text"],
                "token_ids": token_ids,
                "token_count": len(token_ids),
                "checksum": hashlib.sha256(
                    json.dumps(token_ids, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
                ).hexdigest(),
            }
        )
        response, matched_rule = deterministic_medical_response(prompt["text"])
        prompt_outputs.append(
            {
                "name": prompt["name"],
                "category": prompt["category"],
                "input": prompt["text"],
                "matched_rule": matched_rule,
                "output": response,
                "output_sha256": hashlib.sha256(response.encode("utf-8")).hexdigest(),
            }
        )
    return prompt_tokenizations, prompt_outputs


def deterministic_medical_response(text: str) -> Tuple[str, str]:
    lower = text.casefold()
    if not lower:
        return "请提供您的医学问题。", "empty"
    if "治疗" in lower or "treatment" in lower:
        return (
            "治疗方案取决于具体病情。常见方法包括：药物治疗、手术治疗或支持性护理。请咨询医疗专业人士获得个性化建议。",
            "treatment",
        )
    if "症状" in lower or "症" in lower or "疼痛" in lower or "腿痛" in lower or "pain" in lower or "fever" in lower or "发烧" in lower:
        return (
            "症状可能由多种原因引起。建议您咨询医生进行专业诊断和评估。",
            "symptoms",
        )
    if "诊断" in lower or "diagnosis" in lower:
        return (
            "诊断需要专业的医学评估。医生通常会进行体格检查、了解病史，并可能进行诊断检查。",
            "diagnosis",
        )
    if "疾病" in lower or "病" in lower or "disease" in lower or "condition" in lower:
        return (
            "不同的疾病和症状需要不同的治疗方法。早期发现和专业医疗护理对改善预后很重要。",
            "disease",
        )
    if "药" in lower or "medication" in lower or "drug" in lower:
        return (
            "药物只能按医生处方使用。请始终遵循用法用量说明，并报告任何不良反应。",
            "medication",
        )
    if "健康" in lower or "health" in lower or "医" in lower or "medical" in lower:
        return (
            "保持健康需要定期运动、均衡饮食、充足睡眠和定期检查。请咨询医疗专业人士获得个性化建议。",
            "health",
        )
    if "你是" in lower or "who are you" in lower:
        return (
            "我是一个医学知识助手。我可以提供关于疾病、治疗和健康主题的一般医学知识。",
            "identity",
        )
    if "请用中文" in lower or "中文" in lower:
        return (
            "当然可以！我现在用中文回答。有什么医学问题我可以帮助您？",
            "chinese",
        )
    if "hello" in lower or "hi" in lower or "help" in lower:
        return (
            "Hello! I'm a medical information assistant. I can provide general medical knowledge. How can I help?",
            "greeting",
        )
    return (
        "这是一个重要的医学问题。对于具体的医疗建议，请咨询能够评估您具体情况的医疗专业人士。",
        "fallback",
    )


def build_model_shapes(config: Dict[str, Any], prompts: Sequence[Dict[str, str]], prompt_tokenizations: Sequence[Dict[str, Any]]) -> Dict[str, Any]:
    hidden_size = int(config["hidden_size"])
    vocab_size = int(config["vocab_size"])
    num_layers = int(config["num_hidden_layers"])
    num_heads = int(config["num_attention_heads"])
    num_kv_heads = int(config["num_key_value_heads"])
    intermediate_size = int(config["intermediate_size"])
    head_dim = hidden_size // num_heads
    kv_dim = num_kv_heads * head_dim
    prompt_shapes = {}
    for prompt, tokenization in zip(prompts, prompt_tokenizations):
        prompt_shapes[prompt["name"]] = {
            "input_ids": [tokenization["token_count"]],
            "embedding": [tokenization["token_count"], hidden_size],
            "logits": [tokenization["token_count"], vocab_size],
        }
    return {
        "reference_model": {
            "model_type": str(config.get("model_type", "qwen2")),
            "hidden_size": hidden_size,
            "num_hidden_layers": num_layers,
            "num_attention_heads": num_heads,
            "num_key_value_heads": num_kv_heads,
            "head_dim": head_dim,
            "kv_dim": kv_dim,
            "intermediate_size": intermediate_size,
            "vocab_size": vocab_size,
            "max_position_embeddings": int(config.get("max_position_embeddings", 0)),
            "rms_norm_eps": config.get("rms_norm_eps"),
            "rope_theta": config.get("rope_theta"),
        },
        "phase2_kernel": {
            "decoder_only": True,
            "causal_mask": True,
            "use_rope": True,
            "use_rmsnorm": True,
            "planned_embedding_shape": [None, hidden_size],
            "planned_logits_shape": [None, vocab_size],
            "attention_weight_shapes": {
                "q_proj": [hidden_size, hidden_size],
                "k_proj": [hidden_size, kv_dim],
                "v_proj": [hidden_size, kv_dim],
                "o_proj": [hidden_size, hidden_size],
            },
            "mlp_weight_shapes": {
                "gate_proj": [hidden_size, intermediate_size],
                "up_proj": [hidden_size, intermediate_size],
                "down_proj": [intermediate_size, hidden_size],
            },
        },
        "prompt_shapes": prompt_shapes,
    }


def build_expected_metrics(
    dataset_samples: Sequence[Dict[str, Any]],
    prompts: Sequence[Dict[str, str]],
    tokenizer: BPEModel,
    prompt_tokenizations: Sequence[Dict[str, Any]],
    prompt_outputs: Sequence[Dict[str, Any]],
    config: Dict[str, Any],
) -> Dict[str, Any]:
    dataset_summary = summarize_dataset(dataset_samples)
    prompt_token_counts = {item["name"]: item["token_count"] for item in prompt_tokenizations}
    output_rules = {item["name"]: item["matched_rule"] for item in prompt_outputs}
    return {
        "version": DEFAULT_VERSION,
        "golden_schema_version": GOLDEN_SCHEMA_VERSION,
        "dataset": dataset_summary,
        "prompts": {
            "count": len(prompts),
            "names": [prompt["name"] for prompt in prompts],
            "token_counts": prompt_token_counts,
            "output_rules": output_rules,
        },
        "tokenizer": {
            "source_sha256": tokenizer.source_sha256,
            "config_sha256": tokenizer.config_sha256,
            "vocab_size": int(config["vocab_size"]),
            "special_tokens": {
                "bos_token_id": config.get("bos_token_id"),
                "eos_token_id": config.get("eos_token_id"),
            },
            "prompt_checksum_map": {
                item["name"]: item["checksum"] for item in prompt_tokenizations
            },
        },
        "behavior": {
            "prompt_count": len(prompt_outputs),
            "output_sha256_map": {item["name"]: item["output_sha256"] for item in prompt_outputs},
        },
        "reference_model": {
            "hidden_size": int(config["hidden_size"]),
            "num_hidden_layers": int(config["num_hidden_layers"]),
            "num_attention_heads": int(config["num_attention_heads"]),
            "num_key_value_heads": int(config["num_key_value_heads"]),
            "intermediate_size": int(config["intermediate_size"]),
        },
    }


def build_metadata(
    model_dir: Path,
    data_file: Path,
    tokenizer_path: Path,
    config_path: Path,
    dataset_samples: Sequence[Dict[str, Any]],
    prompts: Sequence[Dict[str, str]],
) -> Dict[str, Any]:
    return {
        "version": DEFAULT_VERSION,
        "reference_model": DEFAULT_REFERENCE_MODEL,
        "reference_backend": "NeurX local deterministic reference snapshot",
        "golden_schema_version": GOLDEN_SCHEMA_VERSION,
        "seed": DEFAULT_SEED,
        "dtype": DEFAULT_DTYPE,
        "created_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "source": {
            "model_dir": str(model_dir),
            "model_config": str(config_path),
            "tokenizer_json": str(tokenizer_path),
            "dataset_file": str(data_file),
        },
        "source_sha256": {
            "model_config": sha256_file(config_path),
            "tokenizer_json": sha256_file(tokenizer_path),
            "dataset_file": sha256_file(data_file),
        },
        "dataset_count": len(dataset_samples),
        "prompt_count": len(prompts),
    }


def build_snapshot(model_dir: Path, data_file: Path, dataset_limit: int, prompts: Sequence[Dict[str, str]]) -> Dict[str, Any]:
    config_path = model_dir / "config.json"
    tokenizer_path = model_dir / "tokenizer.json"

    config = read_json(config_path)
    tokenizer = BPEModel.from_tokenizer_json(tokenizer_path, config_path)
    dataset_samples = load_jsonl_samples(data_file, dataset_limit)
    prompt_tokenizations, prompt_outputs = build_baseline_prompt_data(prompts, tokenizer)

    snapshot = {
        "metadata": build_metadata(model_dir, data_file, tokenizer_path, config_path, dataset_samples, prompts),
        "dataset": dataset_samples,
        "prompts": list(prompts),
        "tokenizer": {
            "source": {
                "model_dir": str(model_dir),
                "tokenizer_json": str(tokenizer_path),
                "sha256": tokenizer.source_sha256,
            },
            "vocab_size": int(config["vocab_size"]),
            "special_tokens": {
                "bos_token_id": config.get("bos_token_id"),
                "eos_token_id": config.get("eos_token_id"),
                "im_start_token_id": 151644,
                "im_end_token_id": 151645,
            },
            "prompt_tokenizations": prompt_tokenizations,
        },
        "baseline_metrics": build_expected_metrics(
            dataset_samples,
            prompts,
            tokenizer,
            prompt_tokenizations,
            prompt_outputs,
            config,
        ),
        "baseline_outputs": {
            "reference_backend": "NeurX local deterministic reference snapshot",
            "prompts": prompt_outputs,
        },
        "expected_shapes": build_model_shapes(config, prompts, prompt_tokenizations),
        "README": build_readme_text(model_dir, data_file, prompts, dataset_limit),
    }
    return snapshot


def build_readme_text(model_dir: Path, data_file: Path, prompts: Sequence[Dict[str, str]], dataset_limit: int) -> str:
    prompt_list = "\n".join(f"- `{prompt['name']}`: {prompt['text']}" for prompt in prompts)
    return f"""# PostTrain Golden

This directory is the Phase 2 Module 0 source of truth.

## Rules

- `make test-golden` only reads these files.
- `make regenerate-golden` is the only supported way to rewrite them.
- Golden is specification, not cache.
- Do not use these files as training outputs; they are frozen facts for later modules.
- `golden_schema_version` tracks the snapshot format.

## Contents

- `metadata.json`: provenance, hashes, and snapshot version.
- `dataset.json`: frozen medical dataset slice from `{data_file}`.
- `prompts.json`: fixed prompt set for regression checks.
- `tokenizer.json`: frozen tokenization snapshot for the prompt set.
- `baseline_metrics.json`: counts, hashes, and summary metrics.
- `baseline_outputs.json`: deterministic baseline responses for the prompt set.
- `expected_shapes.json`: model/config shape facts used by later modules.

## Reference

- Model directory: `{model_dir}`
- Dataset slice size: `{dataset_limit}`

## Fixed prompts

{prompt_list}
"""


def emit_snapshot_files(snapshot: Dict[str, Any], golden_dir: Path) -> None:
    golden_dir.mkdir(parents=True, exist_ok=True)
    write_json(golden_dir / "metadata.json", snapshot["metadata"])
    write_json(golden_dir / "dataset.json", snapshot["dataset"])
    write_json(golden_dir / "prompts.json", {"prompts": snapshot["prompts"]})
    write_json(golden_dir / "tokenizer.json", snapshot["tokenizer"])
    write_json(golden_dir / "baseline_metrics.json", snapshot["baseline_metrics"])
    write_json(golden_dir / "baseline_outputs.json", snapshot["baseline_outputs"])
    write_json(golden_dir / "expected_shapes.json", snapshot["expected_shapes"])
    (golden_dir / "README.md").write_text(snapshot["README"], encoding="utf-8")


def load_snapshot_files(golden_dir: Path) -> Dict[str, Any]:
    return {
        "metadata": read_json(golden_dir / "metadata.json"),
        "dataset": read_json(golden_dir / "dataset.json"),
        "prompts": read_json(golden_dir / "prompts.json"),
        "tokenizer": read_json(golden_dir / "tokenizer.json"),
        "baseline_metrics": read_json(golden_dir / "baseline_metrics.json"),
        "baseline_outputs": read_json(golden_dir / "baseline_outputs.json"),
        "expected_shapes": read_json(golden_dir / "expected_shapes.json"),
        "README": (golden_dir / "README.md").read_text(encoding="utf-8"),
    }


def compare_json(name: str, actual: Any, expected: Any, problems: List[str]) -> None:
    if actual != expected:
        problems.append(f"{name} mismatch")


def verify_dataset(actual_dataset: Any, expected_dataset: Any, problems: List[str]) -> None:
    if actual_dataset != expected_dataset:
        problems.append("dataset mismatch")
        return
    for index, item in enumerate(actual_dataset):
        for key in ("question", "exp", "cop", "opa", "opb", "opc", "opd", "subject_name", "topic_name", "id", "choice_type"):
            if key not in item:
                problems.append(f"dataset sample {index} missing key: {key}")


def verify_prompts(actual_prompts: Any, expected_prompts: Any, problems: List[str]) -> None:
    if actual_prompts != expected_prompts:
        problems.append("prompts mismatch")


def verify_tokenizer(actual_tokenizer: Any, expected_tokenizer: Any, problems: List[str]) -> None:
    if actual_tokenizer != expected_tokenizer:
        problems.append("tokenizer snapshot mismatch")
        return
    prompt_tokenizations = actual_tokenizer.get("prompt_tokenizations", [])
    if not prompt_tokenizations:
        problems.append("tokenizer prompt tokenizations missing")
        return
    for item in prompt_tokenizations:
        token_ids = item.get("token_ids", [])
        token_count = item.get("token_count")
        if token_count != len(token_ids):
            problems.append(f"tokenizer count mismatch for {item.get('name')}")
        if not all(isinstance(token, int) for token in token_ids):
            problems.append(f"tokenizer ids contain non-integers for {item.get('name')}")


def verify_shapes(actual_shapes: Any, expected_shapes: Any, problems: List[str]) -> None:
    if actual_shapes != expected_shapes:
        problems.append("expected shapes mismatch")


def verify_metrics(actual_metrics: Any, expected_metrics: Any, problems: List[str]) -> None:
    if actual_metrics != expected_metrics:
        problems.append("baseline metrics mismatch")


def verify_outputs(actual_outputs: Any, expected_outputs: Any, problems: List[str]) -> None:
    if actual_outputs != expected_outputs:
        problems.append("baseline outputs mismatch")


def verify_snapshot(snapshot: Dict[str, Any], golden_dir: Path, model_dir: Path, data_file: Path) -> None:
    problems: List[str] = []
    actual = load_snapshot_files(golden_dir)

    # Regenerate the expected snapshot from the source inputs, but keep the
    # stored created_at untouched. The timestamp is provenance only.
    expected = dict(snapshot)
    expected_metadata = dict(expected["metadata"])
    expected_metadata.pop("created_at", None)
    actual_metadata = dict(actual["metadata"])
    actual_metadata.pop("created_at", None)
    compare_json("metadata", actual_metadata, expected_metadata, problems)

    print("[1/6] Dataset Check")
    verify_dataset(actual["dataset"], expected["dataset"], problems)
    if "dataset mismatch" not in problems and not any(p.startswith("dataset sample") for p in problems):
        print("  PASS")

    print("[2/6] Prompt Contract")
    verify_prompts(actual["prompts"], {"prompts": expected["prompts"]}, problems)
    if "prompts mismatch" not in problems:
        print("  PASS")

    print("[3/6] Tokenizer Check")
    verify_tokenizer(actual["tokenizer"], expected["tokenizer"], problems)
    if "tokenizer snapshot mismatch" not in problems and "tokenizer prompt tokenizations missing" not in problems and not any(p.startswith("tokenizer count mismatch") or p.startswith("tokenizer ids contain") for p in problems):
        print("  PASS")

    print("[4/6] Shape Check")
    verify_shapes(actual["expected_shapes"], expected["expected_shapes"], problems)
    if "expected shapes mismatch" not in problems:
        print("  PASS")

    print("[5/6] Metrics Check")
    verify_metrics(actual["baseline_metrics"], expected["baseline_metrics"], problems)
    if "baseline metrics mismatch" not in problems:
        print("  PASS")

    print("[6/6] Prompt Regression")
    verify_outputs(actual["baseline_outputs"], expected["baseline_outputs"], problems)
    if "baseline outputs mismatch" not in problems:
        print("  PASS")

    if actual["README"] != expected["README"]:
        problems.append("README mismatch")

    # Additional explicit invariants for fast diagnostics.
    required_files = [
        "metadata.json",
        "dataset.json",
        "prompts.json",
        "tokenizer.json",
        "baseline_metrics.json",
        "baseline_outputs.json",
        "expected_shapes.json",
        "README.md",
    ]
    for filename in required_files:
        if not (golden_dir / filename).exists():
            problems.append(f"missing file: {filename}")

    if problems:
        print("[test-golden] FAIL")
        for problem in problems:
            print(f"  - {problem}")
        raise SystemExit(1)

    print("[test-golden] PASS")
    print(f"  golden_dir: {golden_dir}")
    print(f"  model_dir: {model_dir}")
    print(f"  dataset_file: {data_file}")
    print(f"  prompts: {len(expected['prompts'])}")
    print(f"  dataset_samples: {len(expected['dataset'])}")


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate and verify posttrain golden artifacts.")
    parser.add_argument("command", choices=("generate", "verify"))
    parser.add_argument("--golden-dir", default=str(DEFAULT_GOLDEN_DIR))
    parser.add_argument("--model-dir", default=str(DEFAULT_MODEL_DIR))
    parser.add_argument("--dataset-file", default=str(DEFAULT_DATA_FILE))
    parser.add_argument("--dataset-limit", type=int, default=DEFAULT_DATASET_LIMIT)
    return parser.parse_args(argv)


def main(argv: Sequence[str]) -> int:
    args = parse_args(argv)
    golden_dir = Path(args.golden_dir)
    model_dir = Path(args.model_dir)
    data_file = Path(args.dataset_file)
    snapshot = build_snapshot(model_dir, data_file, args.dataset_limit, DEFAULT_PROMPTS)

    if args.command == "generate":
        emit_snapshot_files(snapshot, golden_dir)
        print(f"[regenerate-golden] wrote snapshot to {golden_dir}")
        return 0

    verify_snapshot(snapshot, golden_dir, model_dir, data_file)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
