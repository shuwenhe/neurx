#!/usr/bin/env python3
"""Industrial-style data cleaning, dedup, stratified sampling, and resharding.

This pipeline keeps the existing NeurX training paths stable while upgrading the
corpus quality in place:
  1. normalize and clean text
  2. exact + template-aware near dedup
  3. stratified sampling by content type and length
  4. write cleaned JSONL and gzip shards with a fresh manifest
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
import random
import re
import shutil
import unicodedata
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "data" / "training_data.jsonl"
DEFAULT_CLEANED = ROOT / "data" / "training_data.cleaned.jsonl"
DEFAULT_SHARD_DIR = ROOT / "data" / "training_data_shards"
DEFAULT_MANIFEST = DEFAULT_SHARD_DIR / "manifest.json"
DEFAULT_BACKUP = ROOT / "data" / "training_data.jsonl.pipeline.bak"


CONTROL_CHARS = {
    "\u200b",
    "\u200c",
    "\u200d",
    "\ufeff",
    "\u2060",
}

CODE_PATTERNS = [
    r"\bdef\b",
    r"\bclass\b",
    r"\bfunc\b",
    r"\breturn\b",
    r"\bimport\b",
    r"\bfrom\b",
    r"\bif\b.*\bthen\b",
    r"```",
    r";\s*$",
    r"\{\s*\"",
    r"\bSELECT\b",
    r"\bINSERT\b",
    r"\bUPDATE\b",
    r"\bDELETE\b",
    r"\bfor\s+\w+\s+in\s+range\b",
    r"代码片段",
    r"伪代码",
]
JSON_PATTERNS = [
    r"^\s*\{.*\}\s*$",
    r"^\s*\[.*\]\s*$",
    r"^\s*\"[^\"]+\"\s*:\s*",
]
LOG_PATTERNS = [
    r"\[(INFO|WARN|ERROR|DEBUG)\]",
    r"\bstep=\d+",
    r"\bloss=",
    r"\blearning_rate=",
    r"\bcheckpoint\b",
]
DIALOG_PATTERNS = [
    r"用户[:：]",
    r"助手[:：]",
    r"对话[:：]",
    r"User[:：]",
    r"Assistant[:：]",
]
QA_PATTERNS = [
    r"^问题[:：]",
    r"^Q[:：]",
    r"^问[:：]",
    r"^题目[:：]",
]
MATH_PATTERNS = [
    r"O\([^\)]+\)",
    r"P\([^)]+\)",
    r"[\+\-\*/=<>≈√∑∫^]",
    r"\bmean\b",
    r"\bvariance\b",
    r"\bgradient\b",
    r"\bHessian\b",
    r"\bsoftmax\b",
]
SAFETY_PATTERNS = [
    r"安全",
    r"隐私",
    r"审计",
    r"权限",
    r"漏洞",
    r"攻击",
    r"密钥",
    r"脱敏",
    r"合规",
]


BUCKET_WEIGHTS = {
    "longform": 0.22,
    "qa": 0.16,
    "dialog": 0.12,
    "code": 0.15,
    "multilingual": 0.10,
    "math": 0.10,
    "general": 0.07,
    "log": 0.06,
    "json": 0.05,
    "safety": 0.05,
}


@dataclass(frozen=True)
class Record:
    source_index: int
    text: str
    normalized: str
    category: str
    length: int
    quality: float
    length_bin: str
    fingerprint: str


def normalize_text(text: str) -> str:
    text = unicodedata.normalize("NFKC", text)
    for ch in CONTROL_CHARS:
        text = text.replace(ch, "")
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{2,}", "\n", text)
    return text.strip()


def has(patterns: list[str], text: str, flags: int = 0) -> bool:
    return any(re.search(pattern, text, flags) for pattern in patterns)


def count_scripts(text: str) -> tuple[bool, bool]:
    has_cn = bool(re.search(r"[\u4e00-\u9fff]", text))
    has_en = bool(re.search(r"[A-Za-z]", text))
    return has_cn, has_en


def is_json_like(text: str) -> bool:
    stripped = text.strip()
    if stripped.startswith("{") or stripped.startswith("["):
        return True
    return bool(re.search(r'"[^"]+"\s*:\s*', stripped))


def is_template_like(text: str) -> bool:
    return bool(
        re.search(r"^(Sample|样本)\s*\d+[:：]", text)
        or re.search(r"^混合样本\s*\d+[:：]", text)
        or re.search(r"Additional note\s*#\d+", text, re.I)
        or re.search(r"示例数据第\d+条", text)
    )


def char_repeat_ratio(text: str) -> float:
    if not text:
        return 1.0
    counts = Counter(text)
    return max(counts.values()) / len(text)


def classify(text: str) -> str:
    lower = text.lower()
    if has(JSON_PATTERNS, text):
        return "json"
    if has(LOG_PATTERNS, text, re.I):
        return "log"
    if has(CODE_PATTERNS, text, re.I):
        return "code"
    if has(DIALOG_PATTERNS, text):
        return "dialog"
    if has(QA_PATTERNS, text):
        return "qa"
    if has(SAFETY_PATTERNS, text, re.I):
        return "safety"
    if has(MATH_PATTERNS, lower, re.I):
        return "math"
    has_cn, has_en = count_scripts(text)
    if has_cn and has_en:
        return "multilingual"
    sentence_count = text.count("。") + text.count(".") + text.count("!") + text.count("?")
    if len(text) >= 110 or sentence_count >= 2:
        return "longform"
    return "general"


def length_bin(text: str) -> str:
    n = len(text)
    if n < 80:
        return "short"
    if n < 140:
        return "medium"
    if n < 240:
        return "long"
    return "xlong"


def quality_score(text: str, category: str) -> float:
    has_cn, has_en = count_scripts(text)
    tokens = re.findall(r"[A-Za-z0-9_]+|[\u4e00-\u9fff]+", text)
    uniq = len(set(tokens))
    ratio = uniq / max(1, len(tokens))
    score = min(len(text) / 120.0, 2.0)
    score += 0.45 if has_cn and has_en else 0.15 if (has_cn or has_en) else 0.0
    score += 0.35 if category in {"longform", "qa", "dialog"} else 0.2 if category in {"code", "math"} else 0.0
    score += 0.25 if re.search(r"[。！？.!?]", text) else 0.0
    score += 0.4 * ratio
    score -= 1.5 * max(0.0, char_repeat_ratio(text) - 0.25)
    if is_template_like(text):
        score -= 0.6
    if len(text) < 24:
        score -= 0.4
    return round(score, 4)


def weak_fingerprint(text: str) -> str:
    base = unicodedata.normalize("NFKC", text).lower()
    base = re.sub(r"https?://\S+", "<url>", base)
    base = re.sub(r"\b[\w\.-]+@[\w\.-]+\.\w+\b", "<email>", base)
    base = re.sub(r"\b\d{4}-\d{1,2}-\d{1,2}\b", "<date>", base)
    base = re.sub(r"\b\d{1,2}:\d{2}(:\d{2})?\b", "<time>", base)
    base = re.sub(r"\b0x[0-9a-f]+\b", "<hex>", base)
    base = re.sub(r"\b\d+(?:\.\d+)?\b", "<num>", base)
    base = re.sub(r"[^\w\u4e00-\u9fff]+", "", base)
    return base


def read_records(path: Path) -> list[tuple[int, str]]:
    records: list[tuple[int, str]] = []
    with path.open("r", encoding="utf-8") as f:
        for idx, line in enumerate(f):
            line = line.strip()
            if not line:
                continue
            obj = json.loads(line)
            text = obj.get("text", "")
            if isinstance(text, str):
                records.append((idx, text))
    return records


def clean_and_dedup(records: list[tuple[int, str]]) -> tuple[list[Record], dict]:
    exact_seen: set[str] = set()
    weak_seen: set[str] = set()
    cleaned: list[Record] = []
    stats = Counter()

    for idx, raw_text in records:
        stats["input"] += 1
        text = normalize_text(raw_text)
        if not text:
            stats["empty"] += 1
            continue
        if len(text) < 8:
            stats["too_short"] += 1
            continue
        if char_repeat_ratio(text) > 0.45:
            stats["high_repeat"] += 1
            continue

        normalized = re.sub(r"\s+", " ", text)
        exact_key = normalized
        if exact_key in exact_seen:
            stats["exact_duplicate"] += 1
            continue
        exact_seen.add(exact_key)

        category = classify(text)
        if is_template_like(text):
            fingerprint = weak_fingerprint(text)
            if fingerprint in weak_seen:
                stats["template_duplicate"] += 1
                continue
            weak_seen.add(fingerprint)
        else:
            fingerprint = weak_fingerprint(text)

        record = Record(
            source_index=idx,
            text=text,
            normalized=normalized,
            category=category,
            length=len(text),
            quality=quality_score(text, category),
            length_bin=length_bin(text),
            fingerprint=fingerprint,
        )
        cleaned.append(record)
        stats[f"kept_{category}"] += 1

    stats["kept"] = len(cleaned)
    return cleaned, dict(stats)


def select_stratified(records: list[Record], seed: int, target_total: int | None = None) -> tuple[list[Record], dict]:
    rng = random.Random(seed)
    if not target_total or target_total <= 0 or target_total > len(records):
        target_total = len(records)

    by_category: dict[str, list[Record]] = defaultdict(list)
    for record in records:
        by_category[record.category].append(record)

    for bucket in by_category.values():
        bucket.sort(key=lambda r: (-r.quality, -r.length, r.source_index))

    available_counts = {k: len(v) for k, v in by_category.items()}
    weights = {k: BUCKET_WEIGHTS.get(k, 0.0) for k in by_category.keys()}
    weight_sum = sum(weights.values()) or 1.0
    quotas: dict[str, int] = {}
    fractional: list[tuple[float, str]] = []

    for category, bucket in by_category.items():
        exact = target_total * (weights[category] / weight_sum)
        quota = int(exact)
        quotas[category] = min(quota, len(bucket))
        fractional.append((exact - quota, category))

    allocated = sum(quotas.values())
    leftover = target_total - allocated
    for _, category in sorted(fractional, reverse=True):
        if leftover <= 0:
            break
        if quotas[category] < len(by_category[category]):
            quotas[category] += 1
            leftover -= 1

    # Build a length-balanced queue inside each category.
    selected: list[Record] = []
    selected_keys: set[tuple[int, str]] = set()
    leftovers: list[Record] = []

    def bucket_round_robin(category: str, quota: int) -> list[Record]:
        bins: dict[str, list[Record]] = defaultdict(list)
        for record in by_category[category]:
            bins[record.length_bin].append(record)
        for bin_records in bins.values():
            bin_records.sort(key=lambda r: (-r.quality, -r.length, r.source_index))

        order = ["short", "medium", "long", "xlong"]
        chosen: list[Record] = []
        while len(chosen) < quota:
            progressed = False
            for bin_name in order:
                if len(chosen) >= quota:
                    break
                if bins[bin_name]:
                    chosen.append(bins[bin_name].pop(0))
                    progressed = True
            if not progressed:
                break
        # Fill remaining from all bins by score.
        if len(chosen) < quota:
            remainder = [r for bucket in bins.values() for r in bucket]
            remainder.sort(key=lambda r: (-r.quality, -r.length, r.source_index))
            chosen.extend(remainder[: quota - len(chosen)])
        return chosen

    for category, quota in sorted(quotas.items(), key=lambda item: (-item[1], item[0])):
        chosen = bucket_round_robin(category, quota)
        selected.extend(chosen)
        selected_keys.update((r.source_index, r.fingerprint) for r in chosen)

    if len(selected) < target_total:
        leftovers = [r for r in records if (r.source_index, r.fingerprint) not in selected_keys]
        leftovers.sort(key=lambda r: (-r.quality, -r.length, r.source_index))
        needed = target_total - len(selected)
        selected.extend(leftovers[:needed])

    rng.shuffle(selected)

    out_stats = {
        "target_total": target_total,
        "selected_total": len(selected),
        "selected_by_category": dict(Counter(r.category for r in selected)),
        "selected_by_length_bin": dict(Counter(r.length_bin for r in selected)),
    }
    return selected, out_stats


def write_jsonl(path: Path, records: Iterable[Record]) -> None:
    with path.open("w", encoding="utf-8") as f:
        for record in records:
            f.write(json.dumps({"text": record.text}, ensure_ascii=False) + "\n")


def shard_records(records: list[Record], shard_dir: Path, shard_size: int) -> list[dict]:
    shard_dir.mkdir(parents=True, exist_ok=True)
    for old in shard_dir.glob("training_data-*.jsonl.gz"):
        old.unlink()

    manifest_shards: list[dict] = []
    total_records = len(records)
    for shard_index, start in enumerate(range(0, total_records, shard_size)):
        chunk = records[start : start + shard_size]
        shard_name = f"training_data-{shard_index:05d}.jsonl.gz"
        shard_path = shard_dir / shard_name
        payload = "\n".join(json.dumps({"text": r.text}, ensure_ascii=False) for r in chunk) + "\n"
        with gzip.open(shard_path, "wt", encoding="utf-8") as gz:
            gz.write(payload)
        sha256 = hashlib.sha256(shard_path.read_bytes()).hexdigest()
        manifest_shards.append(
            {
                "file": shard_name,
                "records": len(chunk),
                "start_record": start,
                "end_record": start + len(chunk) - 1,
                "sha256": sha256,
            }
        )
    return manifest_shards


def main() -> None:
    parser = argparse.ArgumentParser(description="NeurX industrial data pipeline v2")
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--cleaned", type=Path, default=DEFAULT_CLEANED)
    parser.add_argument("--shard-dir", type=Path, default=DEFAULT_SHARD_DIR)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--backup", type=Path, default=DEFAULT_BACKUP)
    parser.add_argument("--shard-size", type=int, default=int(os.environ.get("SHARD_SIZE", "1024")))
    parser.add_argument("--seed", type=int, default=int(os.environ.get("NEURX_DATA_SEED", "42")))
    parser.add_argument("--target-total", type=int, default=0, help="0 means use all cleaned records")
    parser.add_argument("--apply", action="store_true", help="Overwrite source file with curated output")
    args = parser.parse_args()

    source_records = read_records(args.source)
    cleaned_records, clean_stats = clean_and_dedup(source_records)
    selected_records, sample_stats = select_stratified(
        cleaned_records,
        seed=args.seed,
        target_total=args.target_total or len(cleaned_records),
    )

    args.cleaned.parent.mkdir(parents=True, exist_ok=True)
    write_jsonl(args.cleaned, selected_records)

    if args.apply:
        if args.backup and not args.backup.exists():
            shutil.copy2(args.source, args.backup)
        shutil.copy2(args.cleaned, args.source)

    shard_entries = shard_records(selected_records, args.shard_dir, args.shard_size)

    manifest = {
        "dataset_name": "training_data_v2",
        "source_path": str(args.source),
        "cleaned_path": str(args.cleaned),
        "output_dir": str(args.shard_dir),
        "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "seed": args.seed,
        "shard_size_target": args.shard_size,
        "total_input_records": len(source_records),
        "total_clean_records": len(cleaned_records),
        "total_output_records": len(selected_records),
        "clean_stats": clean_stats,
        "sample_stats": sample_stats,
        "bucket_weights": BUCKET_WEIGHTS,
        "shards": shard_entries,
    }

    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"Source records: {len(source_records)}")
    print(f"Cleaned records: {len(cleaned_records)}")
    print(f"Output records: {len(selected_records)}")
    print(f"Cleaned JSONL: {args.cleaned}")
    if args.apply:
        print(f"Source overwritten in place: {args.source}")
        if args.backup.exists():
            print(f"Backup: {args.backup}")
    print(f"Shards: {len(shard_entries)} -> {args.shard_dir}")
    print(f"Manifest: {args.manifest}")


if __name__ == "__main__":
    main()
