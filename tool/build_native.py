#!/usr/bin/env python3
"""Build NeurX commands with S Stage4, without seed or legacy fallback."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

COMMANDS = ('train', 'benchmark', 'worker', 'controller', 'serve')


def source_package(source, scanner):
    tokens = list(scanner.source_tokens(source))
    for position, token in enumerate(tokens):
        if token == 'package':
            position += 1
            name = tokens[position]
            while position + 2 < len(tokens) and tokens[position + 1] == '.':
                name += '.' + tokens[position + 2]
                position += 2
            return name
    return ''


def source_index(project, s_root, scanner):
    index = {}
    for base in (project, s_root / 'src'):
        for path in sorted(base.rglob('*.s')):
            relative = path.relative_to(base)
            if any(part in {'.git', 'artifact', 'artifacts', 'test', 'testdata', 'legacy', 'experimental'}
                   or part.startswith('.') for part in relative.parts):
                continue
            if path.name.endswith('_test.s'):
                continue
            package = source_package(path.read_text(), scanner)
            if package and package != 'main':
                index.setdefault(package, []).append(path.resolve())
    return index


def source_closure(entry, index, scanner):
    pending = [entry]
    sources = []
    seen = set()
    while pending:
        path = pending.pop(0)
        if path in seen:
            continue
        seen.add(path)
        sources.append(path)
        for imported in scanner.imports(path.read_text()):
            # Historical NeurX imports include a terminal dot or a member name.
            package = imported.rstrip('.')
            if package not in index:
                package, _, member = imported.rpartition('.')
                if package not in index or not declared_member(member, index[package], scanner):
                    raise ValueError(f'{path}: unresolved import: {imported}')
            pending.extend(index[package])
    return sources


def declared_member(name, sources, scanner):
    for source in sources:
        tokens = list(scanner.source_tokens(source.read_text()))
        depth = 0
        for position, token in enumerate(tokens[:-1]):
            if depth == 0 and token in {'func', 'struct', 'enum', 'trait', 'const', 'var'} and tokens[position + 1] == name:
                return True
            if token == '{':
                depth += 1
            elif token == '}':
                depth -= 1
    return False


def build(name, args, index, scanner):
    executable = args.output_dir / name
    assembly = args.output_dir / (name + '.sasm')
    log = args.output_dir / (name + '.log')
    # A failed rebuild must never expose an old executable as its result.
    executable.unlink(missing_ok=True)
    assembly.unlink(missing_ok=True)
    record = {'command': name, 'status': 'failed'}
    try:
        sources = source_closure(args.project_root / 'cmd' / name / 'main.s', index, scanner)
        (args.output_dir / (name + '.sources')).write_text(''.join(str(p) + '\n' for p in sources))
        record['sources'] = list(map(str, sources))
        with tempfile.TemporaryDirectory(prefix='.' + name + '-', dir=args.output_dir) as temporary:
            temporary = Path(temporary)
            commands = [
                [str(args.compiler), '--compile-unit', str(temporary / 'unit.sasm'), *map(str, sources)],
                [str(args.compiler), '--emit-bin', str(temporary / 'unit.sasm'), str(temporary / name)],
            ]
            with log.open('w') as stream:
                for command in commands:
                    stream.write(json.dumps(command) + '\n')
                    stream.flush()
                    result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, cwd=args.project_root)
                    if result.returncode:
                        record['exit_code'] = result.returncode
                        return record
            os.replace(temporary / 'unit.sasm', assembly)
            os.replace(temporary / name, executable)
        record['status'] = 'built'
        record['executable'] = str(executable)
    except (OSError, ValueError) as error:
        log.write_text(str(error) + '\n')
        record['error'] = str(error)
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    project = Path(__file__).resolve().parents[1]
    parser.add_argument('--project-root', type=Path, default=project)
    parser.add_argument('--s-root', type=Path, default=Path(os.environ.get('S_REPO_ROOT', project.parent / 's')))
    parser.add_argument('--compiler', type=Path, default=os.environ.get('S_NATIVE_COMPILER'))
    parser.add_argument('--output-dir', type=Path)
    parser.add_argument('--commands', nargs='+', choices=COMMANDS, default=list(COMMANDS))
    args = parser.parse_args()
    args.project_root = args.project_root.resolve()
    args.s_root = args.s_root.resolve()
    args.compiler = (args.compiler or args.s_root / '.bootstrap/native-imports/stage4').resolve()
    args.output_dir = (args.output_dir or args.project_root / 'artifact/build/native-stage4').resolve()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for name in dict.fromkeys(args.commands):
        for suffix in ('', '.sasm', '.sources'):
            (args.output_dir / (name + suffix)).unlink(missing_ok=True)
    results = []
    compiler_hash = None
    try:
        if not args.compiler.is_file() or not os.access(args.compiler, os.X_OK):
            raise ValueError(f'Stage4 compiler unavailable: {args.compiler}; bootstrap S first')
        compiler_hash = hashlib.sha256(args.compiler.read_bytes()).hexdigest()
        sys.dont_write_bytecode = True
        spec = importlib.util.spec_from_file_location('s_source_imports', args.s_root / 'src/cmd/dist/source_imports.py')
        scanner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(scanner)
        index = source_index(args.project_root, args.s_root, scanner)
        for name in dict.fromkeys(args.commands):
            result = build(name, args, index, scanner)
            results.append(result)
            print(f'{name}: {result["status"]} (log: {args.output_dir / (name + ".log")})', flush=True)
            if result['status'] != 'built':
                print((args.output_dir / (name + '.log')).read_text().rstrip(), file=sys.stderr)
    except (OSError, ValueError, SyntaxError) as error:
        for name in dict.fromkeys(args.commands):
            results.append({'command': name, 'status': 'failed', 'error': str(error)})
            (args.output_dir / (name + '.log')).write_text(str(error) + '\n')
        print(str(error), file=sys.stderr)
    (args.output_dir / 'manifest.json').write_text(json.dumps({
        'compiler': str(args.compiler),
        'compiler_sha256': compiler_hash,
        'results': results,
    }, indent=2) + '\n')
    return int(any(row['status'] != 'built' for row in results))


if __name__ == '__main__':
    sys.exit(main())
