#!/bin/bash
# ============================================================================
# NeurX 数据清洗脚本
# 将 dataset/pretrain/raw 中的原始数据清洗为 cleaned 版本
# ============================================================================

set -euo pipefail

NEURX_HOME="${NEURX_HOME:-$(cd "$(dirname "$0")/.." && pwd)}"
RAW_DIR="${RAW_DIR:-dataset/pretrain/raw}"
CLEANED_DIR="${CLEANED_DIR:-dataset/pretrain/cleaned}"
OUTPUT_FILE="${OUTPUT_FILE:-$CLEANED_DIR/pretrain_data_cleaned.jsonl}"
MANIFEST_FILE="${MANIFEST_FILE:-dataset/pretrain/manifest.json}"

mkdir -p "$CLEANED_DIR"

echo "╔════════════════════════════════════════════╗"
echo "║     NeurX 数据清洗流程                     ║"
echo "╚════════════════════════════════════════════╝"
echo ""
echo "RAW_DIR: $RAW_DIR"
echo "CLEANED_DIR: $CLEANED_DIR"
echo "OUTPUT_FILE: $OUTPUT_FILE"
echo ""

export NEURX_RAW_DIR="$RAW_DIR"
export NEURX_CLEANED_DIR="$CLEANED_DIR"
export NEURX_OUTPUT_FILE="$OUTPUT_FILE"
export NEURX_MANIFEST_FILE="$MANIFEST_FILE"
export PYTHONUNBUFFERED=1

TRAIN_FILE="$CLEANED_DIR/train.jsonl"
VAL_FILE="$CLEANED_DIR/val.jsonl"
TEST_FILE="$CLEANED_DIR/test.jsonl"
CHECKPOINT_FILE="${CHECKPOINT_FILE:-$CLEANED_DIR/.cleaning_checkpoint.json}"
export NEURX_CHECKPOINT_FILE="$CHECKPOINT_FILE"

finalize_cleaned_dataset() {
    local stage="${1:-unknown}"
    if [ ! -s "$OUTPUT_FILE" ]; then
        echo "No cleaned output found at $OUTPUT_FILE; skipping finalization."
        return 1
    fi

    python3 - <<'PY'
from __future__ import annotations

import json
import os
from pathlib import Path

output_file = Path(os.environ["NEURX_OUTPUT_FILE"])
cleaned_dir = Path(os.environ["NEURX_CLEANED_DIR"])
manifest_file = Path(os.environ["NEURX_MANIFEST_FILE"])
train_path = cleaned_dir / "train.jsonl"
val_path = cleaned_dir / "val.jsonl"
test_path = cleaned_dir / "test.jsonl"

total = sum(1 for _ in output_file.open("r", encoding="utf-8"))
train_size = total * 8 // 10
val_size = total // 10
test_size = total - train_size - val_size

with output_file.open("r", encoding="utf-8") as input_handle, \
        train_path.open("w", encoding="utf-8") as train_handle, \
        val_path.open("w", encoding="utf-8") as val_handle, \
        test_path.open("w", encoding="utf-8") as test_handle:
    for index, line in enumerate(input_handle):
        if index < train_size:
            train_handle.write(line)
        elif index < train_size + val_size:
            val_handle.write(line)
        else:
            test_handle.write(line)

manifest = {}
if manifest_file.exists():
    try:
        manifest = json.loads(manifest_file.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        manifest = {}

manifest.setdefault("dataset_name", "neurx-pretrain-dataset")
manifest.setdefault("version", "1.0")
manifest["status"] = "cleaned data generated"
manifest["cleaned_file"] = "cleaned/pretrain_data_cleaned.jsonl"
manifest["cleaned_splits"] = {
    "train": "cleaned/train.jsonl",
    "val": "cleaned/val.jsonl",
    "test": "cleaned/test.jsonl",
}
manifest_file.parent.mkdir(parents=True, exist_ok=True)
manifest_file.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

print("╔════════════════════════════════════════════╗")
print("║     NeurX 数据清洗流程 (finalize)          ║")
print("╚════════════════════════════════════════════╝")
print(f"OUTPUT_FILE: {output_file}")
print(f"训练分割: {train_path}")
print(f"验证分割: {val_path}")
print(f"测试分割: {test_path}")
print(f"清单文件: {manifest_file}")
print(f"总文档数: {total}")
PY
}

cleanup_finalized=0
trap 'true' EXIT INT TERM

python3 -u - <<'PY'
from __future__ import annotations

import bz2
import html
import hashlib
import json
import os
import re
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

raw_dir = Path(os.environ["NEURX_RAW_DIR"])
cleaned_dir = Path(os.environ["NEURX_CLEANED_DIR"])
output_file = Path(os.environ["NEURX_OUTPUT_FILE"])
manifest_file = Path(os.environ["NEURX_MANIFEST_FILE"])
checkpoint_file = Path(os.environ.get("NEURX_CHECKPOINT_FILE", str(cleaned_dir / ".cleaning_checkpoint.json")))

checkpoint_interval_pages = int(os.environ.get("NEURX_CLEAN_CHECKPOINT_INTERVAL", "200"))


def hash_key(text: str) -> str:
    return hashlib.sha256(compact_key(text).encode("utf-8")).hexdigest()


def normalize_text(text: str) -> str:
    return str(text).replace("\r\n", "\n").replace("\r", "\n").strip()


def compact_key(text: str) -> str:
    return re.sub(r"\s+", " ", normalize_text(text))


def estimate_tokens(text: str) -> int:
    return max(1, len(text) // 4)


def write_record(handle, record) -> None:
    handle.write(json.dumps(record, ensure_ascii=False) + "\n")


def log_progress(message: str) -> None:
    print(message, flush=True)


def supported_sources():
    if not raw_dir.is_dir():
        return []
    files = []
    for path in raw_dir.iterdir():
        if not path.is_file():
            continue
        name = path.name.lower()
        if name.endswith((".jsonl", ".txt")) or name.endswith(".xml.bz2") or name.endswith(".xml"):
            files.append(path)
    return sorted(files)


def load_checkpoint() -> dict | None:
    if not checkpoint_file.exists():
        return None
    try:
        data = json.loads(checkpoint_file.read_text(encoding="utf-8"))
        if isinstance(data, dict):
            return data
    except json.JSONDecodeError:
        pass
    return None


def save_checkpoint(state: dict) -> None:
    payload = {
        "version": 1,
        "status": "in_progress",
        "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "source_index": state["source_index"],
        "source_name": state["source_name"],
        "source_kind": state["source_kind"],
        "source_progress": state["source_progress"],
        "stats": state["stats"],
        "output_file": str(output_file),
        "raw_dir": str(raw_dir),
    }
    checkpoint_file.parent.mkdir(parents=True, exist_ok=True)
    tmp_file = checkpoint_file.with_suffix(".json.tmp")
    tmp_file.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    tmp_file.replace(checkpoint_file)


def clear_checkpoint() -> None:
    if checkpoint_file.exists():
        checkpoint_file.unlink()


def output_summary(path: Path) -> dict:
    summary = {
        "valid_documents": 0,
        "total_tokens_estimate": 0,
    }
    if not path.exists() or path.stat().st_size == 0:
        return summary
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            summary["valid_documents"] += 1
            metadata = record.get("metadata", {})
            if isinstance(metadata, dict):
                tokens = metadata.get("tokens_estimate", 0)
                if isinstance(tokens, int):
                    summary["total_tokens_estimate"] += tokens
    return summary


def rebuild_seen(path: Path) -> set[str]:
    seen: set[str] = set()
    if not path.exists() or path.stat().st_size == 0:
        return seen
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            text = record.get("text")
            if isinstance(text, str) and text:
                seen.add(hash_key(text))
    return seen


def process_plain_text(path: Path, seen: set[str], output_handle, stats: dict, state: dict) -> None:
    stats["total_size_bytes"] += path.stat().st_size
    log_progress(f"处理纯文本文件: {path.name}")
    resume_from = int(state.get("source_progress", 0))
    if path.suffix.lower() == ".txt":
        if resume_from > 0:
            log_progress(f"  从第 {resume_from + 1} 条文本记录继续")
            return
        text = normalize_text(path.read_text(encoding="utf-8", errors="ignore"))
        if not text:
            stats["empty_documents"] += 1
            return
        if len(text) < 50:
            stats["short_documents"] += 1
            return
        stats["total_documents"] += 1
        clipped = text[:100000]
        if len(text) > 100000:
            stats["long_documents"] += 1
        key = hash_key(clipped)
        if key in seen:
            stats["duplicates_removed"] += 1
            return
        seen.add(key)
        tokens = estimate_tokens(clipped)
        write_record(output_handle, {
            "text": clipped,
            "metadata": {
                "source_file": path.name,
                "source_type": "txt",
                "source": "raw",
                "length": len(clipped),
                "tokens_estimate": tokens,
            },
        })
        stats["valid_documents"] += 1
        stats["total_tokens_estimate"] += tokens
        return

    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for index, line in enumerate(handle, start=1):
            if index <= resume_from:
                continue
            stats["total_documents"] += 1
            line = line.strip()
            if not line:
                continue
            try:
                item = json.loads(line)
            except json.JSONDecodeError:
                continue

            text = ""
            if isinstance(item.get("text"), str):
                text = normalize_text(item["text"])
            elif isinstance(item.get("content"), str):
                text = normalize_text(item["content"])
            elif isinstance(item.get("prompt"), str) and isinstance(item.get("response"), str):
                text = normalize_text(f"{item['prompt']}\n{item['response']}")

            if not text:
                stats["empty_documents"] += 1
                continue
            if len(text) < 50:
                stats["short_documents"] += 1
                continue
            clipped = text[:100000]
            if len(text) > 100000:
                stats["long_documents"] += 1
            key = hash_key(clipped)
            if key in seen:
                stats["duplicates_removed"] += 1
                continue
            seen.add(key)
            tokens = estimate_tokens(clipped)
            write_record(output_handle, {
                "text": clipped,
                "metadata": {
                    "source_file": path.name,
                    "source_type": "jsonl",
                    "source": "raw",
                    "source_index": index,
                    "length": len(clipped),
                    "tokens_estimate": tokens,
                    "original_keys": list(item.keys())[:16],
                },
            })
            stats["valid_documents"] += 1
            stats["total_tokens_estimate"] += tokens


def strip_namespace(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def process_wikipedia_dump(path: Path, seen: set[str], output_handle, stats: dict, state: dict) -> None:
    stats["total_size_bytes"] += path.stat().st_size
    log_progress(f"开始解析 Wikipedia dump: {path.name} ({path.stat().st_size} bytes)")
    opener = bz2.open if path.name.endswith(".bz2") else open
    last_report_time = time.monotonic()
    last_report_pages = 0
    resume_from = int(state.get("source_progress", 0))
    page_index = 0
    with opener(path, "rb") as stream:
        context = ET.iterparse(stream, events=("end",))
        for _event, elem in context:
            if strip_namespace(elem.tag) != "page":
                continue

            page_index += 1
            if page_index <= resume_from:
                elem.clear()
                continue
            stats["total_documents"] += 1
            page_count = page_index
            now = time.monotonic()
            if page_count - last_report_pages >= 200 or now - last_report_time >= 20:
                log_progress(
                    f"  进度: 已扫描 {page_count} 页，"
                    f"有效 {stats['valid_documents']}，"
                    f"去重 {stats['duplicates_removed']}，"
                    f"空 {stats['empty_documents']}，"
                    f"短文本 {stats['short_documents']}"
                )
                last_report_pages = page_count
                last_report_time = now
            title = ""
            namespace = ""
            text = ""

            for child in elem:
                name = strip_namespace(child.tag)
                if name == "title":
                    title = child.text or ""
                elif name == "ns":
                    namespace = child.text or ""
                elif name == "revision":
                    for rev_child in child:
                        if strip_namespace(rev_child.tag) == "text":
                            text = rev_child.text or ""
                            break

            elem.clear()

            if namespace != "0":
                continue

            text = normalize_text(html.unescape(text))
            if not text:
                stats["empty_documents"] += 1
                continue
            if len(text) < 50:
                stats["short_documents"] += 1
                continue

            clipped = text[:100000]
            if len(text) > 100000:
                stats["long_documents"] += 1
            key = hash_key(clipped)
            if key in seen:
                stats["duplicates_removed"] += 1
                continue

            seen.add(key)
            tokens = estimate_tokens(clipped)
            write_record(output_handle, {
                "text": clipped,
                "metadata": {
                    "source_file": path.name,
                    "source_type": "wikipedia_dump",
                    "source": "raw",
                    "title": title,
                    "length": len(clipped),
                    "tokens_estimate": tokens,
                },
            })
            stats["valid_documents"] += 1
            stats["total_tokens_estimate"] += tokens
            if stats["valid_documents"] % 200 == 0:
                log_progress(
                    f"  已输出 {stats['valid_documents']} 条有效样本，"
                    f"累计 tokens 估计 {stats['total_tokens_estimate']}"
                )

            if page_index % checkpoint_interval_pages == 0:
                state["source_progress"] = page_index
                save_checkpoint(state)


def main() -> int:
    cleaned_dir.mkdir(parents=True, exist_ok=True)
    sources = supported_sources()
    if not sources:
        print(f"No supported raw files found in {raw_dir}", file=sys.stderr)
        return 1

    log_progress(f"发现 {len(sources)} 个原始数据文件，开始清洗...")
    for path in sources:
        log_progress(f"  待处理: {path.name}")

    checkpoint = load_checkpoint()
    resume_mode = bool(checkpoint and checkpoint.get("status") == "in_progress")
    if resume_mode:
        log_progress(f"检测到断点: {checkpoint.get('source_name')} @ {checkpoint.get('source_progress')}")
    else:
        clear_checkpoint()

    seen = rebuild_seen(output_file) if output_file.exists() else set()
    summary = output_summary(output_file)
    stats = {
        "total_documents": 0,
        "valid_documents": summary["valid_documents"],
        "duplicates_removed": 0,
        "empty_documents": 0,
        "short_documents": 0,
        "long_documents": 0,
        "total_tokens_estimate": summary["total_tokens_estimate"],
        "total_size_bytes": 0,
    }

    if resume_mode:
        checkpoint_stats = checkpoint.get("stats", {})
        if isinstance(checkpoint_stats, dict):
            stats["total_documents"] = int(checkpoint_stats.get("total_documents", 0))
            stats["duplicates_removed"] = int(checkpoint_stats.get("duplicates_removed", 0))
            stats["empty_documents"] = int(checkpoint_stats.get("empty_documents", 0))
            stats["short_documents"] = int(checkpoint_stats.get("short_documents", 0))
            stats["long_documents"] = int(checkpoint_stats.get("long_documents", 0))
            stats["total_size_bytes"] = int(checkpoint_stats.get("total_size_bytes", 0))
            stats["valid_documents"] = max(
                stats["valid_documents"],
                int(checkpoint_stats.get("valid_documents", 0)),
            )
            stats["total_tokens_estimate"] = max(
                stats["total_tokens_estimate"],
                int(checkpoint_stats.get("total_tokens_estimate", 0)),
            )
        source_index = int(checkpoint.get("source_index", 0))
    else:
        source_index = 0
        if output_file.exists():
            output_file.unlink()

    output_file.parent.mkdir(parents=True, exist_ok=True)
    open_mode = "a" if resume_mode and output_file.exists() else "w"
    with output_file.open(open_mode, encoding="utf-8") as output_handle:
        for index, path in enumerate(sources):
            name = path.name.lower()
            if index < source_index:
                continue
            state = {
                "source_index": index,
                "source_name": path.name,
                "source_kind": "wikipedia_dump" if name.endswith((".xml.bz2", ".xml")) else "text",
                "source_progress": int(checkpoint.get("source_progress", 0)) if resume_mode and index == source_index else 0,
                "stats": stats,
            }
            if name.endswith((".xml.bz2", ".xml")):
                process_wikipedia_dump(path, seen, output_handle, stats, state)
            else:
                process_plain_text(path, seen, output_handle, stats, state)
            state["source_index"] = index + 1
            state["source_progress"] = 0
            save_checkpoint(state)

    total = stats["valid_documents"]
    log_progress(f"原始清洗完成，开始切分数据: 有效文档 {total}")
    train_size = total * 8 // 10
    val_size = total // 10
    test_size = total - train_size - val_size

    train_path = cleaned_dir / "train.jsonl"
    val_path = cleaned_dir / "val.jsonl"
    test_path = cleaned_dir / "test.jsonl"

    with output_file.open("r", encoding="utf-8") as input_handle, \
            train_path.open("w", encoding="utf-8") as train_handle, \
            val_path.open("w", encoding="utf-8") as val_handle, \
            test_path.open("w", encoding="utf-8") as test_handle:
        for index, line in enumerate(input_handle):
            if index < train_size:
                train_handle.write(line)
            elif index < train_size + val_size:
                val_handle.write(line)
            else:
                test_handle.write(line)

    manifest = {}
    if manifest_file.exists():
        try:
            manifest = json.loads(manifest_file.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            manifest = {}

    manifest.setdefault("dataset_name", "neurx-pretrain-dataset")
    manifest.setdefault("version", "1.0")
    manifest["status"] = "cleaned data generated"
    manifest["cleaned_file"] = "cleaned/pretrain_data_cleaned.jsonl"
    manifest["cleaned_splits"] = {
        "train": "cleaned/train.jsonl",
        "val": "cleaned/val.jsonl",
        "test": "cleaned/test.jsonl",
    }
    manifest["raw_files"] = [path.name for path in sources]
    manifest["statistics"] = {
        "total_shards": manifest.get("statistics", {}).get("total_shards", 0)
        if isinstance(manifest.get("statistics"), dict) else 0,
        "total_tokens": stats["total_tokens_estimate"],
        "total_documents": total,
        "total_size_bytes": stats["total_size_bytes"],
    }
    manifest["cleaning_stats"] = stats
    manifest_file.parent.mkdir(parents=True, exist_ok=True)
    manifest_file.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    clear_checkpoint()

    print("╔════════════════════════════════════════════╗")
    print("║     NeurX 数据清洗流程 (Python)            ║")
    print("╚════════════════════════════════════════════╝")
    print(f"RAW_DIR: {raw_dir}")
    print(f"CLEANED_DIR: {cleaned_dir}")
    print(f"OUTPUT_FILE: {output_file}")
    print(f"源文件数: {len(sources)}")
    print(f"有效文档: {total}")
    print(f"训练分割: {train_path}")
    print(f"验证分割: {val_path}")
    print(f"测试分割: {test_path}")
    print(f"总 tokens 估计: {stats['total_tokens_estimate']}")
    print(f"清单文件: {manifest_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY

cleanup_finalized=1

finalize_cleaned_dataset "success"

echo ""
echo "✨ 数据清洗流程完成"
echo "下一步可执行:"
echo "  bash train_1t_moe.sh"
