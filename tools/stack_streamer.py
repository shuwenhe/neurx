#!/usr/bin/env python3
"""
Stream `bigcode/the-stack` from Hugging Face, filter by language and license,
perform basic normalization and deduplication using an on-disk SQLite hash table,
and write gzipped JSONL shards.

Usage:
  python tools/stack_streamer.py --lang py --licenses MIT Apache-2.0 BSD-3-Clause \
      --shard-size 1000 --out-dir data/the-stack-py

Requirements:
  pip install datasets tqdm python-magic

Notes:
  - This is a best-effort lightweight pipeline for building a cleaned code corpus.
  - For production-scale dedupe prefer a MinHash / simhash approach and distributed
    deduplication. SQLite-based hash set is fine for modest scale and simplicity.
"""

import argparse
import gzip
import hashlib
import json
import os
import sqlite3
import sys
from pathlib import Path
from typing import Iterable

from datasets import load_dataset
from tqdm import tqdm


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--dataset", default="bigcode/the-stack-dedup", help="Hugging Face dataset identifier to stream")
    p.add_argument("--dataset-config", default=None, help="Optional dataset config/name (e.g. 'all')")
    p.add_argument("--lang", default="py", help="language code to filter (e.g. py, js, java)")
    p.add_argument("--licenses", nargs="+", default=["mit", "apache-2.0", "bsd-3-clause"],
                   help="list of licenses to allow (case-insensitive)")
    p.add_argument("--shard-size", type=int, default=10000, help="number of files per shard")
    p.add_argument("--out-dir", required=True, help="output directory for shards")
    p.add_argument("--max-files", type=int, default=0, help="max files to process (0 = all)")
    p.add_argument("--sqlite-db", default=".dedupe.db", help="sqlite file for dedupe hashes")
    p.add_argument("--progress", action="store_true", help="show progress bar")
    return p.parse_args()


def normalize_code(text: str) -> str:
    # Basic normalization: strip trailing whitespace, collapse CRLF, strip multiple blank lines
    if text is None:
        return ""
    s = text.replace('\r\n', '\n').replace('\r', '\n')
    # strip whitespace at both ends
    s = s.strip() + "\n"
    # collapse multiple blank lines
    parts = []
    blank = False
    for line in s.split('\n'):
        if line.strip() == "":
            if not blank:
                parts.append("")
            blank = True
        else:
            parts.append(line.rstrip())
            blank = False
    return "\n".join(parts).strip() + "\n"


class SqliteDedupe:
    def __init__(self, path: str):
        self.path = path
        self.conn = sqlite3.connect(path)
        self._ensure()

    def _ensure(self):
        c = self.conn.cursor()
        c.execute("CREATE TABLE IF NOT EXISTS seen(hash TEXT PRIMARY KEY)")
        c.execute("PRAGMA synchronous = OFF")
        c.execute("PRAGMA journal_mode = WAL")
        self.conn.commit()

    def seen(self, h: str) -> bool:
        c = self.conn.cursor()
        c.execute("SELECT 1 FROM seen WHERE hash = ?", (h,))
        return c.fetchone() is not None

    def add(self, h: str):
        c = self.conn.cursor()
        try:
            c.execute("INSERT INTO seen(hash) VALUES (?)", (h,))
            self.conn.commit()
            return True
        except sqlite3.IntegrityError:
            return False

    def close(self):
        self.conn.commit()
        self.conn.close()


def stream_stack(lang: str) -> Iterable[dict]:
    # Use the-stack dataset; stream to avoid big downloads
    # Note: dataset config may vary; adapt if needed
    ds = load_dataset(dataset, name=config, split="train", streaming=True)
    for rec in ds:
        yield rec


def main():
    args = parse_args()
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    licenses = set([x.lower() for x in args.licenses])
    deduper = SqliteDedupe(args.sqlite_db)

    shard_index = 0
    shard_count = 0
    shard_path = out_dir / f"shard-{shard_index:05d}.jsonl.gz"
    shard_f = gzip.open(shard_path, "wt")

    processed = 0
    written = 0

    dataset = args.dataset
    config = args.dataset_config or "all"
    ds = load_dataset(dataset, name=config, split="train", streaming=True)
    it = ds
    if args.progress:
        it = tqdm(it, desc="streaming")

    try:
        for rec in it:
            processed += 1
            if args.max_files and processed > args.max_files:
                break

            rec_lang = (rec.get("lang") or rec.get("language") or "").lower()
            rec_license = (rec.get("license") or rec.get("license_name") or "").lower()

            # Quick language filter
            if args.lang and args.lang.lower() not in rec_lang:
                continue

            # Quick license filter: allow if license field contains any allowed license token
            if licenses:
                if not any(tok in rec_license for tok in licenses):
                    continue

            content = rec.get("content") or rec.get("text") or ""
            norm = normalize_code(content)
            if not norm.strip():
                continue

            h = hashlib.sha256(norm.encode("utf-8")).hexdigest()
            if deduper.seen(h):
                continue

            deduper.add(h)

            out = {
                "path": rec.get("path"),
                "repo": rec.get("repo"),
                "license": rec_license,
                "lang": rec_lang,
                "hash": h,
                "text": norm,
            }
            shard_f.write(json.dumps(out, ensure_ascii=False) + "\n")
            written += 1
            shard_count += 1

            if shard_count >= args.shard_size:
                shard_f.close()
                shard_index += 1
                shard_path = out_dir / f"shard-{shard_index:05d}.jsonl.gz"
                shard_f = gzip.open(shard_path, "wt")
                shard_count = 0

    finally:
        try:
            shard_f.close()
        except Exception:
            pass
        deduper.close()

    print(f"Processed {processed} files, wrote {written} unique entries to {out_dir}")


if __name__ == "__main__":
    main()
