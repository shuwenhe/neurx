#!/usr/bin/env python3
"""Build the existing NeurX native-builder ABI in an isolated local S snapshot.

Reads the external toolchain but never patches/builds inside it. This restores
the ABI already consumed by tensor_builder.s; it does not implement inference.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess


ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sections(text):
    parts = {}
    current = None
    for line in text.splitlines(keepends=True):
        if line.startswith('--- a/'):
            current = line[6:].strip()
            parts[current] = []
        if current is not None:
            parts[current].append(line)
    return parts


def insert_once(path, marker, addition):
    text = path.read_text()
    if text.count(marker) != 1:
        raise RuntimeError(f'compiler snapshot incompatible: {path.name}: {marker!r}')
    path.write_text(text.replace(marker, marker + addition, 1))


def build(s_root, destination, producer_kind="native", timeout=600):
    destination = destination.resolve()
    destination.relative_to(ROOT / 'artifact')
    # Do not overwrite an existing snapshot or a user's compiler.
    destination.mkdir(parents=True, exist_ok=False)
    local = destination / 'source'
    shutil.copytree(s_root / 'src', local / 'src')
    script = Path('test/native_runtime/extensions_generate.py')
    (local / script).parent.mkdir(parents=True)
    shutil.copy2(s_root / script, local / script)
    closure = s_root / '.bootstrap/native-imports/stage1.sources'
    sources = [Path(line) for line in closure.read_text().splitlines() if line]
    if not sources or any(p.is_absolute() or '..' in p.parts for p in sources):
        raise RuntimeError('unsafe/empty bootstrap source manifest')
    tracked_inputs = list(dict.fromkeys(sources + [script, Path('src/cmd/compile/internal/codegen/native_runtime_extensions.c')]))
    before = {str(p): sha(s_root / p) for p in tracked_inputs}
    patch_path = ROOT / 'tool/toolchain-patches/20261110-native-builders.patch'
    patch = sections(patch_path.read_text())
    emitter = 'src/cmd/compile/internal/codegen/amd64_program.s'
    # These root-slot hunks still match exactly. Fail rather than fuzz-patching.
    subprocess.run(['patch', '--batch', '--fuzz=0', '-p1'], cwd=local,
                   input=''.join(patch[emitter]), text=True, check=True)
    runtime = 'src/cmd/compile/internal/codegen/native_runtime_extensions.c'
    additions = ''.join(line[1:] for line in patch[runtime]
                        if line.startswith('+') and not line.startswith('+++'))
    if '__native_builder_new' in (local / runtime).read_text() or 's_ext_builder_new' in (local / runtime).read_text():
        raise RuntimeError('snapshot already has native builders')
    with (local / runtime).open('a') as stream:
        stream.write('\n' + additions)
    # Rebase only additive ABI signatures; preserve all newer TCP/crypto entries.
    for kind in ('mir', 'ssa'):
        path = f'src/cmd/compile/internal/{kind}/program.s'
        groups = []
        for line in patch[path]:
            if line.startswith('@@'):
                groups.append([])
            elif line.startswith('+') and not line.startswith('+++'):
                groups[-1].append(line[1:])
        if len(groups) != 2:
            raise RuntimeError('unexpected ABI patch structure')
        for name, added in zip(('result', 'parameters'), groups):
            result_type = 'string' if name == 'result' else 'string[]'
            marker = f'func {kind}_native_intrinsic_{name}(string name) {result_type} {{\n'
            insert_once(local / path, marker, ''.join(added))
    generator = local / script
    extra_names = next(line[1:] for line in patch[str(script)]
                       if line.startswith('+  names.update('))
    generator_text = generator.read_text()
    marker = "  text='package compile.internal"
    if generator_text.count(marker) != 1:
        raise RuntimeError('unrecognized extensions generator')
    generator.write_text(generator_text.replace(marker, extra_names + marker, 1))
    environment = dict(os.environ, PYTHONDONTWRITEBYTECODE='1', TMPDIR=str(destination), S_SOURCE_ROOT=str(local))
    subprocess.run(['python3', str(generator)], cwd=local, env=environment, check=True)
    producer = s_root / ('.bootstrap/native-imports/stage4' if producer_kind == 'native' else 'bin/s_seed')
    assembly = destination / ('compiler.sasm' if producer_kind == 'native' else 'compiler.ir')
    binary = destination / 'compiler'
    with (destination / 'build.log').open('w') as log:
        for command in ([str(producer), '--compile-unit' if producer_kind == 'native' else '--compile-native-unit', str(assembly),
                         *[str(local / p) for p in sources]],
                        [str(producer), '--emit-bin' if producer_kind == 'native' else '--emit-standalone-amd64', str(assembly), str(binary)]):
            log.write(json.dumps(command) + '\n'); log.flush()
            subprocess.run(command, cwd=local, env=environment, stdout=log,
                           stderr=subprocess.STDOUT, check=True, timeout=timeout)
    after = {str(p): sha(s_root / p) for p in tracked_inputs}
    if before != after:
        raise RuntimeError('external compiler sources changed during build')
    record = dict(compiler=str(binary), compiler_sha256=sha(binary),
                  producer=str(producer), producer_sha256=sha(producer),
                  patch_sha256=sha(patch_path), source_root=str(s_root),
                  external_sources_unchanged=True, external_source_sha256=before,
                  local_source_sha256={str(p): sha(local / p) for p in sources},
                  capability='NeurX native builder ABI; runtime tests required')
    (destination / 'manifest.json').write_text(json.dumps(record, indent=2)+'\n')
    print(binary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--s-root', type=Path, default=ROOT.parent / 's')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--producer', choices=('native','seed-native'), default='native')
    parser.add_argument('--timeout', type=int, default=600)
    args = parser.parse_args()
    if args.timeout <= 0: parser.error("timeout must be positive")
    build(args.s_root.resolve(), args.output, args.producer, args.timeout)


if __name__ == '__main__':
    main()
