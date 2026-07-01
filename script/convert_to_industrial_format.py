#!/usr/bin/env python3
"""Convert NeurX JSONL training data into an industrial schema.

The converter keeps `text` for backward compatibility and adds metadata that
supports cleaning, dedup, stratified sampling, and resumable training.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import random
import re
import shutil
import unicodedata
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "data" / "training_data.jsonl"
DEFAULT_OUTPUT = ROOT / "data" / "training_data_industrial.jsonl"
DEFAULT_BACKUP = ROOT / "data" / "training_data.jsonl.bak"


LANG_HINTS = {
    "zh": [r"[\u4e00-\u9fff]", r"，", r"。", r"的", r"了", r"是"],
    "en": [r"[A-Za-z]", r"\bthe\b", r"\band\b", r"\bof\b", r"\bto\b"],
}


DOMAIN_RULES = [
    ("code", [r"\bdef\b", r"\bclass\b", r"\bfunc\b", r"\breturn\b", r"\bimport\b", r"```", r"\bSELECT\b", r"\bINSERT\b", r"\bUPDATE\b", r"\bDELETE\b"]),
    ("math", [r"O\([^\)]+\)", r"P\([^)]+\)", r"[\+\-\*/=<>≈√∑∫^]", r"\bgradient\b", r"\bHessian\b", r"\bsoftmax\b"]),
    ("dialog", [r"用户[:：]", r"助手[:：]", r"User[:：]", r"Assistant[:：]", r"对话[:：]"]),
    ("qa", [r"^问题[:：]", r"^Q[:：]", r"^问[:：]", r"^题目[:：]"]),
    ("log", [r"\[(INFO|WARN|ERROR|DEBUG)\]", r"\bstep=\d+", r"\bloss=", r"\bcheckpoint\b"]),
    ("safety", [r"安全", r"隐私", r"审计", r"权限", r"漏洞", r"攻击", r"密钥", r"脱敏", r"合规"]),
    ("json", [r"^\s*\{.*\}\s*$", r"^\s*\[.*\]\s*$", r'^\s*\"[^\"]+\"\s*:\s*']),
    ("multilingual", [r"[\u4e00-\u9fff]", r"[A-Za-z]"]),
]


SOURCE_HINTS = [
    ("synthetic", [r"^Sample\s+\d+", r"^样本\d+[:：]", r"^混合样本\s*\d+[:：]"]),
    ("ops", [r"\bcheckpoint\b", r"\btraining\b", r"\bdata pipeline\b", r"分布式", r"混合精度", r"日志", r"监控"]),
    ("code", [r"\bdef\b", r"\bclass\b", r"代码", r"伪代码"]),
    ("knowledge", [r"百科", r"定义", r"架构", r"原理", r"概念"]),
    ("web", [r"http[s]?://", r"www\.", r"网页", r"Common Crawl"]),
]


def normalize_text(text: str) -> str:
    text = unicodedata.normalize("NFKC", text)
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"[\u200b\u200c\u200d\ufeff\u2060]", "", text)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{2,}", "\n", text)
    return text.strip()


def guess_lang(text: str) -> str:
    for lang, hints in LANG_HINTS.items():
        if all(re.search(h, text, re.I) for h in hints[:1]):
            if lang == "zh" and re.search(r"[A-Za-z]", text):
                return "multi"
            return lang
    has_cn = bool(re.search(r"[\u4e00-\u9fff]", text))
    has_en = bool(re.search(r"[A-Za-z]", text))
    if has_cn and has_en:
        return "multi"
    if has_cn:
        return "zh"
    if has_en:
        return "en"
    return "unknown"


def classify(text: str) -> str:
    for domain, patterns in DOMAIN_RULES:
        if any(re.search(pattern, text, re.I) for pattern in patterns):
            return domain
    if len(text) >= 110 or text.count("。") + text.count(".") + text.count("!") + text.count("?") >= 2:
        return "longform"
    return "general"


def guess_source(text: str, domain: str) -> str:
    for source, patterns in SOURCE_HINTS:
        if any(re.search(pattern, text, re.I) for pattern in patterns):
            return source
    if domain in {"code", "math", "log", "qa", "dialog", "safety"}:
        return "synthetic"
    return "curated"


def quality_score(text: str, domain: str) -> float:
    length = len(text)
    tokens = re.findall(r"[A-Za-z0-9_]+|[\u4e00-\u9fff]+", text)
    uniq_ratio = len(set(tokens)) / max(1, len(tokens))
    score = min(length / 160.0, 1.2)
    score += 0.3 if re.search(r"[。！？.!?]", text) else 0.0
    score += 0.2 if domain in {"longform", "qa", "dialog", "knowledge"} else 0.1 if domain in {"code", "math"} else 0.0
    score += 0.25 * uniq_ratio
    if len(text) < 20:
        score -= 0.5
    if re.match(r"^(Sample|样本)\s*\d+", text):
        score -= 0.4
    return round(max(0.0, min(score, 1.0)), 4)


def tokens_estimate(text: str) -> int:
    length = len(text)
    words = len(re.findall(r"[A-Za-z0-9_]+|[\u4e00-\u9fff]", text))
    return max(8, int(length * 0.65) + int(words * 1.2))


def content_hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def load_records(path: Path) -> list[dict]:
    records: list[dict] = []
    with path.open("r", encoding="utf-8") as f:
        for idx, line in enumerate(f):
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                obj = {"text": line}
            text = normalize_text(obj.get("text", ""))
            if not text:
                continue
            obj["text"] = text
            obj["_source_index"] = idx
            records.append(obj)
    return records


def build_industrial_record(obj: dict, index: int) -> dict:
    text = obj["text"]
    domain = classify(text)
    lang = guess_lang(text)
    source = guess_source(text, domain)
    quality = quality_score(text, domain)
    tokens_est = tokens_estimate(text)
    h = content_hash(text)
    length = len(text)
    sentences = len([s for s in re.split(r"[。！？.!?]+", text) if s.strip()])
    complexity = "basic"
    if length >= 240 or sentences >= 4:
        complexity = "expert"
    elif length >= 140 or sentences >= 3:
        complexity = "advanced"
    elif length >= 60 or sentences >= 2:
        complexity = "intermediate"

    return {
        "id": f"doc_{index:07d}",
        "text": text,
        "source": source,
        "lang": lang,
        "domain": domain,
        "quality": quality,
        "license": obj.get("license", "unknown"),
        "tokens_est": tokens_est,
        "hash": f"sha256:{h}",
        "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "split": obj.get("split", "train"),
        "type": domain,
        "category": domain,
        "length": length,
        "complexity": complexity,
        "meta": {
            "source_index": obj.get("_source_index", index),
            "normalized": True,
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert training_data.jsonl to industrial schema")
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--in-place", action="store_true", help="Replace the source file after conversion")
    parser.add_argument("--backup", type=Path, default=DEFAULT_BACKUP)
    parser.add_argument("--dedup", action="store_true", default=True)
    parser.add_argument("--no-dedup", action="store_false", dest="dedup")
    args = parser.parse_args()

    if not args.source.exists():
        raise FileNotFoundError(args.source)

    raw_records = load_records(args.source)
    output_records: list[dict] = []
    seen_hashes: set[str] = set()
    stats = Counter()

    for idx, obj in enumerate(raw_records):
        rec = build_industrial_record(obj, idx)
        stats["input"] += 1
        if args.dedup:
            key = rec["hash"]
            if key in seen_hashes:
                stats["duplicate"] += 1
                continue
            seen_hashes.add(key)
        output_records.append(rec)
        stats[f"domain_{rec['domain']}"] += 1
        stats[f"lang_{rec['lang']}"] += 1

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as f:
        for rec in output_records:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")

    if args.in_place:
        if not args.backup.exists():
            shutil.copy2(args.source, args.backup)
        shutil.copy2(args.output, args.source)

    print(f"Input records: {stats['input']}")
    print(f"Output records: {len(output_records)}")
    print(f"Dedup removed: {stats['duplicate']}")
    print(f"Output file: {args.output}")
    if args.in_place:
        print(f"Source overwritten: {args.source}")
        print(f"Backup: {args.backup}")
    print("Domain distribution:")
    for k, v in sorted(((k[7:], v) for k, v in stats.items() if k.startswith("domain_")), key=lambda x: (-x[1], x[0])):
        print(f"  {k}: {v}")
    print("Language distribution:")
    for k, v in sorted(((k[5:], v) for k, v in stats.items() if k.startswith("lang_")), key=lambda x: (-x[1], x[0])):
        print(f"  {k}: {v}")


if __name__ == "__main__":
    main()
