#!/usr/bin/env python3
"""Split industrial JSONL into train/val/test with stratification by domain."""

from __future__ import annotations

import argparse
import hashlib
import json
import random
from collections import defaultdict, Counter
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "data" / "training_data.jsonl"
DEFAULT_OUT_DIR = ROOT / "data" / "training_data_splits"
DEFAULT_MANIFEST = DEFAULT_OUT_DIR / "manifest.json"


def read_records(path: Path) -> list[dict]:
    records: list[dict] = []
    with path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            records.append(json.loads(line))
    return records


def stable_bucket(record: dict, seed: int) -> int:
    key = f"{seed}:{record.get('hash', record.get('id', ''))}:{record.get('domain', '')}:{record.get('lang', '')}"
    digest = hashlib.sha256(key.encode("utf-8")).hexdigest()
    return int(digest[:8], 16)


def choose_split(bucket: int, train_cut: int, val_cut: int) -> str:
    if bucket < train_cut:
        return "train"
    if bucket < val_cut:
        return "val"
    return "test"


def assign_splits(records: list[dict], seed: int, train_ratio: float, val_ratio: float, test_ratio: float) -> list[dict]:
    if abs((train_ratio + val_ratio + test_ratio) - 1.0) > 1e-6:
        raise ValueError("Ratios must sum to 1.0")

    by_domain: dict[str, list[dict]] = defaultdict(list)
    for record in records:
        by_domain[record.get("domain", "unknown")].append(record)

    output: list[dict] = []
    train_cut = int(train_ratio * 10_000)
    val_cut = int((train_ratio + val_ratio) * 10_000)

    for domain, bucket in sorted(by_domain.items()):
        for record in bucket:
            clone = dict(record)
            split = choose_split(stable_bucket(record, seed) % 10_000, train_cut, val_cut)
            clone["split"] = split
            clone.setdefault("meta", {})
            clone["meta"] = dict(clone["meta"])
            clone["meta"]["split_seed"] = seed
            clone["meta"]["split_method"] = "domain_stratified_hash"
            output.append(clone)

    return output


def write_split(path: Path, records: list[dict]) -> None:
    with path.open("w", encoding="utf-8") as f:
        for record in records:
            f.write(json.dumps(record, ensure_ascii=False) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="Split industrial JSONL into train/val/test")
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--train-ratio", type=float, default=0.96)
    parser.add_argument("--val-ratio", type=float, default=0.02)
    parser.add_argument("--test-ratio", type=float, default=0.02)
    args = parser.parse_args()

    records = read_records(args.source)
    split_records = assign_splits(records, args.seed, args.train_ratio, args.val_ratio, args.test_ratio)

    args.out_dir.mkdir(parents=True, exist_ok=True)
    split_map: dict[str, list[dict]] = {"train": [], "val": [], "test": []}
    for record in split_records:
        split_map.setdefault(record["split"], []).append(record)

    for split_name, split_records_list in split_map.items():
        write_split(args.out_dir / f"{split_name}.jsonl", split_records_list)

    manifest = {
        "source": str(args.source),
        "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "seed": args.seed,
        "ratios": {
            "train": args.train_ratio,
            "val": args.val_ratio,
            "test": args.test_ratio,
        },
        "counts": {split: len(items) for split, items in split_map.items()},
        "domains": {
            split: dict(Counter(rec.get("domain", "unknown") for rec in items))
            for split, items in split_map.items()
        },
        "languages": {
            split: dict(Counter(rec.get("lang", "unknown") for rec in items))
            for split, items in split_map.items()
        },
        "files": {
            split: str(args.out_dir / f"{split}.jsonl")
            for split in split_map
        },
    }
    args.manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"Source records: {len(records)}")
    print(f"Train: {len(split_map['train'])}")
    print(f"Val:   {len(split_map['val'])}")
    print(f"Test:  {len(split_map['test'])}")
    print(f"Output dir: {args.out_dir}")
    print(f"Manifest: {args.manifest}")


if __name__ == "__main__":
    main()
