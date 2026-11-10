#!/usr/bin/env python3
"""Link a legacy seed-IR entry with its complete source import closure.

This preserves historical interpreter entry points. It is not the native
Stage4 build or the accepted local-model execution path.
"""
import argparse
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile

from build_native import source_closure, source_index


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    root = Path(__file__).resolve().parents[1]
    parser.add_argument('--project-root', type=Path, default=root)
    parser.add_argument('--s-root', type=Path, default=root.parent / 's')
    parser.add_argument('--compiler', type=Path, required=True)
    parser.add_argument('--entry', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location('source_imports', args.s_root / 'src/cmd/dist/source_imports.py')
    scanner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(scanner)
    sources = source_closure(args.entry.resolve(), source_index(args.project_root.resolve(), args.s_root.resolve(), scanner), scanner)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.with_suffix('.sources').write_text(''.join(str(p) + '\n' for p in sources))
    with tempfile.TemporaryDirectory(prefix='.legacy-link-', dir=args.output.parent) as directory:
        temporary = Path(directory) / 'linked.ir'
        command = [str(args.compiler.resolve()), '--compile-unit', str(temporary), *map(str, sources)]
        result = subprocess.run(command, cwd=args.project_root)
        if result.returncode:
            return result.returncode
        # Publish only a complete, successfully compiled source closure.
        os.replace(temporary, args.output)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError) as error:
        print('legacy IR build: ' + str(error), file=sys.stderr)
        sys.exit(1)
