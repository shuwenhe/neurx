#!/usr/bin/env python3
"""
Create gzipped JSONL shards from a repository directory by extracting text files.

Usage:
  python3 dataset/make_shards_from_repos.py /path/to/repo --out-dir /path/to/shards --shard-size 1000 --max-records 2000
"""
import argparse
import gzip
import json
import os
from pathlib import Path

EXT_LANG = {
    '.py': 'python', '.js': 'javascript', '.ts': 'typescript', '.java': 'java',
    '.cpp': 'cpp', '.c': 'c', '.h': 'c', '.hpp': 'cpp', '.go': 'go', '.rs': 'rust',
    '.rb': 'ruby', '.php': 'php', '.swift': 'swift', '.kt': 'kotlin', '.scala': 'scala',
    '.sh': 'shell', '.ps1': 'powershell', '.html': 'html', '.css': 'css', '.json': 'json',
    '.md': 'markdown', '.txt': 'text'
}


def is_text_file(p: Path) -> bool:
    # Fast heuristic: check extension or small size
    if p.suffix.lower() in EXT_LANG:
        return True
    try:
        if p.stat().st_size > 2_000_000:
            return False
    except Exception:
        return False
    return True


def detect_lang(p: Path) -> str:
    return EXT_LANG.get(p.suffix.lower(), 'unknown')


def iter_files(root: Path):
    for p in root.rglob('*'):
        if p.is_file():
            yield p


def write_shards(records, out_dir: Path, base_name: str, shard_id: int):
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"{base_name}-{shard_id:05d}.jsonl.gz"
    with gzip.open(path, 'wt', encoding='utf-8') as fh:
        for rec in records:
            fh.write(json.dumps(rec, ensure_ascii=False) + '\n')
    return path


def main():
    p = argparse.ArgumentParser()
    p.add_argument('repo', help='path to repo/dataset directory')
    p.add_argument('--out-dir', default='dataset/shards', help='output directory for shards')
    p.add_argument('--shard-size', type=int, default=1000)
    p.add_argument('--max-records', type=int, default=0)
    p.add_argument('--base-name', default='shard')
    args = p.parse_args()

    root = Path(args.repo)
    out_dir = Path(args.out_dir)
    shard_size = args.shard_size
    max_records = args.max_records

    records = []
    shard_id = 0
    total = 0

    for f in iter_files(root):
        if max_records and total >= max_records:
            break
        if not is_text_file(f):
            continue
        try:
            txt = f.read_text(encoding='utf-8', errors='replace')
        except Exception:
            continue
        if not txt.strip():
            continue
        rec = {
            'path': str(f.relative_to(root)) ,
            'text': txt,
            'language': detect_lang(f),
            'license': 'unknown'
        }
        records.append(rec)
        total += 1
        if len(records) >= shard_size:
            write_shards(records, out_dir, args.base_name, shard_id)
            shard_id += 1
            records = []

    if records:
        write_shards(records, out_dir, args.base_name, shard_id)

    print(f'Wrote {shard_id + (1 if records else 0)} shards, {total} records to {out_dir}')


if __name__ == '__main__':
    main()
