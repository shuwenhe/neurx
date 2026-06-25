#!/usr/bin/env python3
"""
analyze_dataset.py
Simple analyzer for gzipped JSONL shards produced by stack_streamer.py.
Outputs a JSON report with license/lang distributions and basic length/token stats.

Usage:
  python3 dataset/analyze_dataset.py /path/to/shards_dir --out report.json --max-records 100000
"""
import argparse
import gzip
import json
import os
from collections import Counter
from pathlib import Path
import math

try:
    from tqdm import tqdm
except Exception:
    def tqdm(x, **kw):
        return x


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument('shards_dir', help='directory containing .jsonl.gz shards')
    p.add_argument('--out', default='dataset/report.json', help='output JSON report path')
    p.add_argument('--max-records', type=int, default=0, help='max records to analyze (0 = all)')
    p.add_argument('--sample', type=int, default=0, help='sample every Nth record (0 = no sampling)')
    return p.parse_args()


def process(shards_dir: str, max_records: int = 0, sample: int = 0):
    shards = sorted(Path(shards_dir).glob('*.jsonl.gz'))
    if not shards:
        raise SystemExit(f'No shards found in {shards_dir}')

    license_ctr = Counter()
    lang_ctr = Counter()
    length_samples = []
    line_count_ctr = Counter()
    empty = 0
    total = 0
    token_ctr = Counter()

    for shard in tqdm(shards, desc='shards'):
        with gzip.open(shard, 'rt', encoding='utf-8') as fh:
            for i, line in enumerate(fh):
                if max_records and total >= max_records:
                    break
                if sample and (total % sample) != 0:
                    total += 1
                    continue
                total += 1
                try:
                    obj = json.loads(line)
                except Exception:
                    continue
                txt = obj.get('text') or obj.get('content') or ''
                lic = (obj.get('license') or 'UNKNOWN').lower()
                lang = (obj.get('lang') or obj.get('language') or 'unknown').lower()

                license_ctr[lic] += 1
                lang_ctr[lang] += 1

                l = len(txt)
                length_samples.append(l)

                lc = txt.count('\n') + 1
                line_count_ctr[lc] += 1

                if not txt.strip():
                    empty += 1

                # simple tokenization: whitespace tokens up to 50 tokens
                tokens = txt.split()
                for t in tokens[:50]:
                    token_ctr[t] += 1

        if max_records and total >= max_records:
            break

    # stats
    avg_len = sum(length_samples) / len(length_samples) if length_samples else 0
    median = (sorted(length_samples)[len(length_samples)//2] if length_samples else 0)
    report = {
        'total_records': total,
        'empty_records': empty,
        'license_distribution': license_ctr.most_common(40),
        'lang_distribution': lang_ctr.most_common(40),
        'avg_length_chars': avg_len,
        'median_length_chars': median,
        'line_count_distribution_sample': line_count_ctr.most_common(20),
        'top_tokens_sample': token_ctr.most_common(50),
    }
    return report


def main():
    args = parse_args()
    shards_dir = args.shards_dir
    out = args.out
    report = process(shards_dir, max_records=args.max_records, sample=args.sample)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'w', encoding='utf-8') as fh:
        json.dump(report, fh, ensure_ascii=False, indent=2)
    print(f'Wrote report to {out}')

if __name__ == '__main__':
    main()
