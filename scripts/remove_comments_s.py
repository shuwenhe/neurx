#!/usr/bin/env python3
import os
import sys

root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

def strip_comments(text):
    out = []
    i = 0
    n = len(text)
    in_sq = False
    in_dq = False
    in_line = False
    in_block = False
    escape = False
    while i < n:
        c = text[i]
        nc = text[i+1] if i+1 < n else ''
        if in_line:
            if c == '\n':
                in_line = False
                out.append(c)
            # else skip char
        elif in_block:
            if c == '*' and nc == '/':
                in_block = False
                i += 1
            # skip everything inside block comment
        elif in_sq:
            out.append(c)
            if not escape and c == "'":
                in_sq = False
            escape = (c == '\\' and not escape)
        elif in_dq:
            out.append(c)
            if not escape and c == '"':
                in_dq = False
            escape = (c == '\\' and not escape)
        else:
            # not in any string or comment
            if c == '/' and nc == '/':
                in_line = True
                i += 1
            elif c == '/' and nc == '*':
                in_block = True
                i += 1
            elif c == "'":
                in_sq = True
                out.append(c)
                escape = False
            elif c == '"':
                in_dq = True
                out.append(c)
                escape = False
            else:
                out.append(c)
        i += 1
    return ''.join(out)

changed_files = []
for dirpath, dirnames, filenames in os.walk(root):
    # skip .git and artifacts
    if '.git' in dirpath.split(os.sep):
        continue
    for fn in filenames:
        if fn.endswith('.s'):
            fp = os.path.join(dirpath, fn)
            try:
                with open(fp, 'r', encoding='utf-8') as f:
                    text = f.read()
            except Exception as e:
                print(f"skip {fp}: read error: {e}", file=sys.stderr)
                continue
            new = strip_comments(text)
            if new != text:
                with open(fp, 'w', encoding='utf-8') as f:
                    f.write(new)
                changed_files.append(fp)
                print(f"Stripped comments: {fp}")

print(f"Done. Modified {len(changed_files)} files.")
if len(changed_files) > 0:
    sys.exit(0)
else:
    sys.exit(0)
