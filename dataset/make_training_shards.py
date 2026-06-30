#!/usr/bin/env python3
"""
Create gzipped JSONL training shards from `data/training_data.jsonl`.

Each output record keeps the repository's simple text-only training schema and
adds lightweight metadata fields that are useful for debugging and validation.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
from pathlib import Path


def guess_lang(text: str) -> str:
    ascii_count = sum(1 for ch in text if ord(ch) < 128)
    if ascii_count >= max(1, len(text) // 2):
        return "en"
    return "zh"


def normalize_record(text: str, record_id: int, source_name: str) -> dict:
    text = text.strip()
    return {
        "text": text,
        "lang": guess_lang(text),
        "license": "unknown",
        "source": source_name,
        "record_id": record_id,
    }


def write_shard(out_path: Path, records: list[dict]) -> tuple[int, str]:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256()
    with gzip.open(out_path, "wt", encoding="utf-8") as fh:
        for rec in records:
            line = json.dumps(rec, ensure_ascii=False, separators=(",", ":"))
            digest.update((line + "\n").encode("utf-8"))
            fh.write(line + "\n")
    return len(records), digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input",
        default="data/training_data.jsonl",
        help="Input JSONL file containing {'text': ...} records.",
    )
    parser.add_argument(
        "--output-dir",
        default="data/training_data_shards",
        help="Directory to write shard files into.",
    )
    parser.add_argument(
        "--shard-size",
        type=int,
        default=1024,
        help="Target records per shard.",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    output_dir = Path(args.output_dir)
    if not input_path.is_file():
        raise SystemExit(f"input file not found: {input_path}")

    raw_records: list[str] = []
    with input_path.open("r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            obj = json.loads(line)
            text = obj.get("text", "")
            if text:
                raw_records.append(text)

    if not raw_records:
        raise SystemExit("no usable records found in input file")

    output_dir.mkdir(parents=True, exist_ok=True)

    shards = []
    total_records = 0
    shard_index = 0
    for offset in range(0, len(raw_records), args.shard_size):
        chunk = raw_records[offset : offset + args.shard_size]
        shard_name = f"training_data-{shard_index:05d}.jsonl.gz"
        shard_path = output_dir / shard_name
        records = [
            normalize_record(text, total_records + i, input_path.name)
            for i, text in enumerate(chunk)
        ]
        count, sha256 = write_shard(shard_path, records)
        total_records += count
        shards.append(
            {
                "file": shard_name,
                "records": count,
                "start_record": total_records - count,
                "end_record": total_records - 1,
                "sha256": sha256,
            }
        )
        shard_index += 1

    manifest = {
        "dataset_name": input_path.stem,
        "source_path": str(input_path.resolve()),
        "output_dir": str(output_dir.resolve()),
        "total_records": total_records,
        "shard_count": len(shards),
        "shard_size_target": args.shard_size,
        "shards": shards,
    }
    (output_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(
        f"wrote {len(shards)} shards with {total_records} records to {output_dir}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
