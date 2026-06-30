#!/usr/bin/env python3
"""Link multiple NeurX IR files into one executable IR bundle.

The S compiler emits a mostly linear IR where labels are local to a function
in the source language, but the runtime linker used by this repository treats
labels as global within the bundle. Concatenating IR files directly therefore
causes jump collisions. This linker keeps the first definition of each symbol
and rewrites labels so each function gets a unique label namespace.
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Iterable


def read_ir(path: Path) -> list[str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines:
        raise ValueError(f"{path}: empty IR file")
    if lines[0].strip() != "SSEED-TARGET-V1":
        raise ValueError(f"{path}: missing SSEED header")
    return lines


def split_ir(lines: list[str]) -> tuple[list[str], list[tuple[str, list[str]]]]:
    top_level: list[str] = []
    functions: list[tuple[str, list[str]]] = []
    current: list[str] = []
    current_name = ""
    in_function = False

    for line in lines[1:]:
        if line.startswith("FUNC_BEGIN|"):
            if in_function:
                raise ValueError(f"nested function begin: {line}")
            in_function = True
            current = [line]
            current_name = line.split("|", 2)[1]
            continue

        if line.startswith("FUNC_END|"):
            if not in_function:
                raise ValueError(f"function end without begin: {line}")
            current.append(line)
            functions.append((current_name, current))
            current = []
            current_name = ""
            in_function = False
            continue

        if in_function:
            current.append(line)
        else:
            top_level.append(line)

    if in_function:
        raise ValueError(f"unterminated function: {current_name}")

    return top_level, functions


def rewrite_function(block: list[str], unique_prefix: str) -> list[str]:
    label_map: dict[str, str] = {}
    for line in block:
        if not line.startswith("LABEL|"):
            continue
        parts = line.split("|")
        if len(parts) >= 2:
            old = parts[1]
            if old not in label_map:
                label_map[old] = f"{unique_prefix}{old}"

    rewritten: list[str] = []
    for line in block:
        parts = line.split("|")
        op = parts[0]
        if op == "LABEL" and len(parts) >= 2:
            parts[1] = label_map.get(parts[1], parts[1])
        elif op == "JUMP" and len(parts) >= 2:
            parts[1] = label_map.get(parts[1], parts[1])
        elif op == "JUMP_IF_FALSE" and len(parts) >= 2:
            parts[1] = label_map.get(parts[1], parts[1])
        rewritten.append("|".join(parts))
    return rewritten


def merge_ir_files(paths: Iterable[Path]) -> list[str]:
    header = "SSEED-TARGET-V1"
    top_level_seen: set[str] = set()
    function_seen: set[str] = set()
    top_level_lines: list[str] = []
    function_blocks: list[str] = []

    for index, path in enumerate(paths):
        lines = read_ir(path)
        top_level, functions = split_ir(lines)

        for line in top_level:
            if line.startswith("MOV|"):
                key = line.split("|", 2)[1]
            else:
                key = line
            if key in top_level_seen:
                continue
            top_level_seen.add(key)
            top_level_lines.append(line)

        for func_name, block in functions:
            if func_name in function_seen:
                continue
            function_seen.add(func_name)
            prefix = f"{index}_{func_name}__"
            function_blocks.extend(rewrite_function(block, prefix))

    return [header, *top_level_lines, *function_blocks]


def main() -> int:
    parser = argparse.ArgumentParser(description="Link NeurX IR files")
    parser.add_argument("output", type=Path, help="Output IR file")
    parser.add_argument("inputs", nargs="+", type=Path, help="Input IR files")
    args = parser.parse_args()

    merged = merge_ir_files(args.inputs)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(merged) + "\n", encoding="utf-8")
    print(f"linked {len(args.inputs)} IR files -> {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
