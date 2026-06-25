#!/bin/bash
set -euo pipefail

# verify_dataset.sh
# Usage: verify_dataset.sh /path/to/shards_dir
# Example: verify_dataset.sh /app/train/neurx/dataset/the-stack

OUT_DIR=${1:-/app/train/neurx/dataset/the-stack}
if [ ! -d "$OUT_DIR" ]; then
  echo "ERROR: directory not found: $OUT_DIR" >&2
  exit 1
fi

shards=("$OUT_DIR"/*.jsonl.gz)
if [ ${#shards[@]} -eq 0 ]; then
  echo "ERROR: no .jsonl.gz shards found in $OUT_DIR" >&2
  exit 1
fi

echo "Found ${#shards[@]} shard files in $OUT_DIR"

total=0
for f in "${shards[@]}"; do
  cnt=$(gzip -cd "$f" | wc -l)
  printf "%s: %d\n" "$(basename "$f")" "$cnt"
  total=$((total + cnt))
done

echo "Total records: $total"

echo "Validating first 10 records from first shard (${shards[0]})..."
gzip -cd "${shards[0]}" | head -n 10 > /tmp/verify_sample.jsonl

python3 - <<'PY'
import sys, json
p='/tmp/verify_sample.jsonl'
count=0
with open(p) as f:
    for i,line in enumerate(f,1):
        try:
            obj=json.loads(line)
        except Exception as e:
            print(f'Invalid JSON at line {i}:', e)
            sys.exit(2)
        # Basic required fields
        for key in ('license','lang','text'):
            if key not in obj:
                print(f'Missing field "{key}" in record {i}; keys: {list(obj.keys())}')
                sys.exit(3)
        count += 1
print(f'Validated {count} sample records successfully')
PY

echo "Verification completed OK"
rm -f /tmp/verify_sample.jsonl
exit 0
