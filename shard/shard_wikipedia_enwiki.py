#!/usr/bin/env python3
"""Shard the pretrain Wikipedia XML.BZ2 corpus into JSONL files.

This script streams the compressed Wikipedia dump, extracts page text, and
writes `shard_00000.jsonl`-style files plus a manifest under the pretrain
shard directory.
"""

from __future__ import annotations

import argparse
import bz2
import html
import json
import re
import sys
from pathlib import Path
from datetime import datetime, timezone


DEFAULT_INPUT = Path(
    "/home/shuwen/shuwen/train/neurx/dataset/pretrain/raw/"
    "enwiki-latest-pages-articles.xml.bz2"
)
DEFAULT_OUTPUT_DIR = Path("/home/shuwen/shuwen/train/neurx/dataset/pretrain/shard")
DEFAULT_MANIFEST = Path("/home/shuwen/shuwen/train/neurx/dataset/pretrain/manifest.json")


TITLE_RE = re.compile(r"<title>(.*?)</title>", re.S)
NS_RE = re.compile(r"<ns>(\d+)</ns>")
PAGEID_RE = re.compile(r"<id>(\d+)</id>")
TEXT_RE = re.compile(r"<text[^>]*>(.*?)</text>", re.S)
REDIRECT_RE = re.compile(r"<redirect\b", re.I)
TAG_RE = re.compile(r"<[^>]+>")
PAGE_START_RE = re.compile(r"<page>")
PAGE_END_RE = re.compile(r"</page>")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--docs-per-shard", type=int, default=5000)
    parser.add_argument("--max-pages", type=int, default=0, help="Optional test limit")
    return parser.parse_args()


def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


def strip_markup(text: str) -> str:
    text = html.unescape(text)
    text = TAG_RE.sub(" ", text)
    text = text.replace("&nbsp;", " ")
    text = re.sub(r"\s+", " ", text).strip()
    return text


def extract_page_record(page_xml: str) -> dict[str, str] | None:
    ns_match = NS_RE.search(page_xml)
    if not ns_match or ns_match.group(1) != "0":
        return None
    if REDIRECT_RE.search(page_xml):
        return None

    title_match = TITLE_RE.search(page_xml)
    text_match = TEXT_RE.search(page_xml)
    if not title_match or not text_match:
        return None

    title = html.unescape(title_match.group(1)).strip()
    page_id_match = PAGEID_RE.search(page_xml)
    page_id = page_id_match.group(1) if page_id_match else ""
    text = strip_markup(text_match.group(1))
    if not text:
        return None

    return {
        "title": title,
        "page_id": page_id,
        "text": text,
        "source": "enwiki-latest-pages-articles.xml.bz2",
    }


def shard_name(index: int) -> str:
    return f"shard_{index:05d}.jsonl"


def main() -> int:
    args = parse_args()

    if not args.input.exists():
        log(f"Input file not found: {args.input}")
        return 1
    if args.docs_per_shard <= 0:
        log("--docs-per-shard must be > 0")
        return 1

    args.output_dir.mkdir(parents=True, exist_ok=True)
    for stale in args.output_dir.glob("shard_*.jsonl"):
        stale.unlink()

    if args.manifest.exists():
        args.manifest.unlink()

    total_pages = 0
    shard_index = 0
    docs_in_shard = 0
    shard_docs = 0
    shard_size_bytes = 0
    shards: list[dict[str, object]] = []
    current_path = args.output_dir / shard_name(shard_index)
    current_file = current_path.open("w", encoding="utf-8")
    page_lines: list[str] = []
    in_page = False

    log(f"Input      : {args.input}")
    log(f"Output dir : {args.output_dir}")
    log(f"Manifest   : {args.manifest}")
    log(f"Docs/shard : {args.docs_per_shard}")
    log(f"Starting   : {current_path.name}")
    log("")

    def rotate_shard() -> None:
        nonlocal shard_index, docs_in_shard, shard_docs, shard_size_bytes
        nonlocal current_file, current_path

        completed_name = current_path.name
        current_file.flush()
        current_file.close()
        if current_path.exists():
            shard_size_bytes = current_path.stat().st_size
            shards.append(
                {
                    "shard_id": f"shard_{shard_index:05d}",
                    "file_path": str(current_path),
                    "num_documents": shard_docs,
                    "size_bytes": shard_size_bytes,
                }
            )
            log(
                f"Completed  : {completed_name} "
                f"(docs={shard_docs}, bytes={shard_size_bytes})"
            )

        shard_index += 1
        docs_in_shard = 0
        shard_docs = 0
        shard_size_bytes = 0
        current_path = args.output_dir / shard_name(shard_index)
        current_file = current_path.open("w", encoding="utf-8")
        log(f"Starting   : {current_path.name}")

    with bz2.open(args.input, "rt", encoding="utf-8", errors="replace") as fh:
        for raw_line in fh:
            line = raw_line.rstrip("\n")

            if PAGE_START_RE.search(line):
                in_page = True
                page_lines = [line]
                continue

            if in_page:
                page_lines.append(line)
                if PAGE_END_RE.search(line):
                    in_page = False
                    total_pages += 1
                    page_xml = "\n".join(page_lines)
                    record = extract_page_record(page_xml)
                    page_lines = []

                    if record:
                        current_file.write(json.dumps(record, ensure_ascii=False) + "\n")
                        docs_in_shard += 1
                        shard_docs += 1

                    if args.max_pages and total_pages >= args.max_pages:
                        break

                    if docs_in_shard >= args.docs_per_shard:
                        rotate_shard()

                    if total_pages % 1000 == 0:
                        log(
                            f"Processed pages: {total_pages} | "
                            f"current shard: {current_path.name} | "
                            f"docs in shard: {docs_in_shard}"
                        )

    if current_file and not current_file.closed:
        current_file.flush()
        current_file.close()

    if current_path.exists():
        final_size = current_path.stat().st_size
        if final_size > 0:
            shards.append(
                {
                    "shard_id": f"shard_{shard_index:05d}",
                    "file_path": str(current_path),
                    "num_documents": shard_docs,
                    "size_bytes": final_size,
                }
            )
        else:
            current_path.unlink(missing_ok=True)

    total_documents = sum(int(s["num_documents"]) for s in shards)
    total_size_bytes = sum(int(s["size_bytes"]) for s in shards)
    avg_docs = total_documents // len(shards) if shards else 0

    manifest = {
        "dataset_name": "neurx-pretrain-wikipedia",
        "version": "1.0",
        "created_at": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "source_file": str(args.input),
        "total_shards": len(shards),
        "total_documents": total_documents,
        "total_size_bytes": total_size_bytes,
        "average_docs_per_shard": avg_docs,
        "shards": shards,
    }

    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    log("")
    log(f"Total pages   : {total_pages}")
    log(f"Total shards  : {len(shards)}")
    log(f"Total docs    : {total_documents}")
    log(f"Manifest saved: {args.manifest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
