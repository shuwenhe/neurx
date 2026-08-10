#!/usr/bin/env python3
import subprocess
import sys

from tokenizers import Tokenizer

def main() -> int:
    if len(sys.argv) != 3:
        print("usage: tokenizer_hf_parity.py PROBE MODEL_DIR", file=sys.stderr)
        return 2
    probe, model_dir = sys.argv[1:]
    tokenizer = Tokenizer.from_file(model_dir + "/tokenizer.json")
    samples = [
        "Hello, world!",
        "Chronic urethral obstruction",
        "<|im_start|>user\nHello<|im_end|>\n",
        "你好，世界！",
        "can't we'll 1234",
        "line 1\nline 2\n",
    ]
    for sample in samples:
        output = subprocess.check_output([probe, model_dir, sample], text=True)
        native_ids = [int(value) for value in output.splitlines()[0].split()[1:]]
        expected_ids = tokenizer.encode(sample, add_special_tokens=False).ids
        if native_ids != expected_ids:
            print(f"tokenizer mismatch for {sample!r}", file=sys.stderr)
            print(f"native={native_ids}", file=sys.stderr)
            print(f"hf={expected_ids}", file=sys.stderr)
            return 1
    print(f"tokenizer parity PASS ({len(samples)} cases)")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
