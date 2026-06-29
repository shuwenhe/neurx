#!/usr/bin/env python3
"""
make_sample_jsonl.py

Generate a JSONL file with a specified number of records (default 1000).
Each line is a JSON object with a `text` field containing mixed English and Chinese.

Usage:
  python3 tools/make_sample_jsonl.py [count]

This writes to `data/sample.jsonl` in the repo root.
"""
import json
import random
import sys
from pathlib import Path

COUNT = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
OUT = Path(__file__).resolve().parents[1] / 'data' / 'sample.jsonl'

english_phrases = [
    "The quick brown fox jumps over the lazy dog.",
    "Hello world! This is a small training sample.",
    "NeurX training data sample for model experiments.",
    "This sentence is intended to provide token variety.",
    "Small dataset entry for testing training pipelines.",
    "Edge-case punctuation: !?;:()[]{}<>'\"`~",
    "Numbers and dates: 2026-06-28, 12345, 3.14159.",
    "Example: do not share secrets in training data.",
    "Short line.",
    "A longer English sentence containing several words to increase length and diversity."
]

chinese_phrases = [
    "这是一个中文训练样本。",
    "短文本示例，用于测试 UTF-8 处理。",
    "示例数据第{n}条，用于训练 neurx 模型。",
    "机器学习训练数据：包含中英文混合内容。",
    "特殊字符测试：，。！？；（）【】<>“”‘’",
    "日期示例：2026年6月28日，编号：{n}。",
    "包含数字：12345，浮点数：3.14。",
    "中文和 English 混合示例，用于增加多样性。",
    "长度较长的中文句子，用来测试模型对于较长输入的处理能力。",
    "最后一条示例：谢谢！"
]

def make_text(i: int) -> str:
    # Mix templates
    en = random.choice(english_phrases)
    cn = random.choice(chinese_phrases).format(n=i)
    if i % 5 == 0:
        # occasional longer combined entry
        return f"Sample {i}: {en} {cn} Additional note #{i}."
    if i % 3 == 0:
        return f"Sample {i}: {cn} {en}"
    return f"Sample {i}: {en} {cn}"


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open('w', encoding='utf-8') as f:
        for i in range(1, COUNT + 1):
            obj = {"text": make_text(i)}
            f.write(json.dumps(obj, ensure_ascii=False) + "\n")
    print(f"Wrote {COUNT} records to {OUT}")


if __name__ == '__main__':
    main()
