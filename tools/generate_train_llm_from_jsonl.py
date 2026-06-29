#!/usr/bin/env python3
"""
generate_train_llm_from_jsonl.py

Read a JSONL file (one JSON object per line, with a `text` field) and
produce a `train_llm_jsonl.s` variant of `train_llm.s` where the
`build_corpus()` function is replaced with a corpus built from the
provided texts.

Usage:
  python3 tools/generate_train_llm_from_jsonl.py data/sample.jsonl

This writes `train_llm_jsonl.s` next to `train_llm.s`.
"""
import json
import sys
from pathlib import Path


def text_to_ints(s: str):
    # Convert to bytes and return list of ints 0-255
    b = s.encode('utf-8', errors='replace')
    return [c for c in b]


def make_corpus_array(ints, repeat=1):
    # Build S code for []int literal with cap and values
    total = len(ints) * repeat
    lines = []
    lines.append(f"    []int corpus = []int{{cap: {total}}}")
    if total == 0:
        lines.append("    corpus")
        return "\n".join(lines)
    # Fill repeated copies
    idx = 0
    for rep in range(repeat):
        offset = rep * len(ints)
        for i, v in enumerate(ints):
            lines.append(f"    corpus[{offset + i}] = {v}")
            idx += 1
    lines.append("    corpus")
    return "\n".join(lines)


def main():
    if len(sys.argv) < 2:
        print("Usage: generate_train_llm_from_jsonl.py <input.jsonl> [repeat]")
        sys.exit(2)
    inpath = Path(sys.argv[1])
    repeat = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    root = Path(__file__).resolve().parents[1]
    orig = root / 'train_llm.s'
    out = root / 'train_llm_jsonl.s'

    texts = []
    with inpath.open('r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
                if isinstance(obj, dict) and 'text' in obj:
                    texts.append(str(obj['text']))
                else:
                    # Fallback: use whole JSON string
                    texts.append(json.dumps(obj, ensure_ascii=False))
            except Exception:
                # Fallback: use raw line
                texts.append(line)

    all_ints = []
    for t in texts:
        # separate entries with newline
        all_ints.extend(text_to_ints(t))
        all_ints.append(10)  # newline

    if not orig.exists():
        print(f"Original train_llm.s not found at {orig}")
        sys.exit(1)

    content = orig.read_text(encoding='utf-8')
    start_token = 'func build_corpus()'
    i = content.find(start_token)
    if i == -1:
        print("Could not find build_corpus() in original source")
        sys.exit(1)
    j = content.find('\nfunc main()', i)
    if j == -1:
        print("Could not locate func main() after build_corpus()")
        sys.exit(1)

    prefix = content[:i]
    suffix = content[j:]

    new_func = 'func build_corpus() []int {\n'
    new_func += make_corpus_array(all_ints, repeat=repeat)
    new_func += '\n}\n\n'

    out.write_text(prefix + new_func + suffix, encoding='utf-8')
    print(f"Wrote {out} with corpus size {len(all_ints) * repeat}")


if __name__ == '__main__':
    main()
