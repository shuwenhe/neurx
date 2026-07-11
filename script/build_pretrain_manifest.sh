#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SHARD_DIR="${1:-$NEURX_ROOT/dataset/pretrain/shard}"
MANIFEST_FILE="${2:-$NEURX_ROOT/dataset/pretrain/manifest.json}"

if [ ! -d "$SHARD_DIR" ]; then
    echo "Error: shard directory not found: $SHARD_DIR" >&2
    exit 1
fi

python3 - "$SHARD_DIR" "$MANIFEST_FILE" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

shard_dir = Path(sys.argv[1])
manifest_file = Path(sys.argv[2])

shard_paths = sorted(shard_dir.glob("shard_*.jsonl"))
if not shard_paths:
    print(f"Error: no shard files found in {shard_dir}", file=sys.stderr)
    raise SystemExit(1)

shards = []
total_documents = 0
total_size_bytes = 0
total_shards = len(shard_paths)
print(f"[pretrain-manifest] scanning {total_shards} shard files", file=sys.stderr)
for index, path in enumerate(shard_paths, start=1):
    print(f"[pretrain-manifest] shard {index}/{total_shards}: {path.name}", file=sys.stderr)
    num_documents = sum(1 for _ in path.open("r", encoding="utf-8", errors="replace"))
    size_bytes = path.stat().st_size
    total_documents += num_documents
    total_size_bytes += size_bytes
    shards.append(
        {
            "shard_id": path.stem,
            "file_path": str(path),
            "num_documents": num_documents,
            "size_bytes": size_bytes,
        }
    )

manifest = {
    "dataset_name": "neurx-pretrain-wikipedia",
    "version": "1.0",
    "created_at": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
    "source_dir": str(shard_dir),
    "total_shards": len(shards),
    "total_documents": total_documents,
    "total_size_bytes": total_size_bytes,
    "average_docs_per_shard": (total_documents // len(shards)) if shards else 0,
    "shards": shards,
}

manifest_file.parent.mkdir(parents=True, exist_ok=True)
manifest_file.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
