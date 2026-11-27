#!/usr/bin/env python3
"""Run installed Compute Sanitizer with a complete repo-local injection layout."""
import argparse
import os
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tool', choices=['memcheck', 'initcheck'], required=True)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('target command required after --')
    root = Path(__file__).resolve().parents[1]
    bundle = root / 'artifact/build/cuda_sanitizer_bundle'
    sources = list(Path('/usr/lib/nvidia-cuda-toolkit/compute-sanitizer').glob('*.so'))
    sources += [Path('/usr/bin/TreeLauncherSubreaper'), Path('/usr/bin/TreeLauncherTargetLdPreloadHelper')]
    if len(sources) < 3 or any(not p.is_file() for p in sources):
        raise RuntimeError('incomplete installed Compute Sanitizer package')
    bundle.mkdir(parents=True, exist_ok=True)
    for source in sources:
        target = bundle / source.name
        if target.is_symlink():
            if target.resolve() != source.resolve():
                raise RuntimeError(f'unexpected existing bundle link: {target}')
        elif target.exists():
            raise RuntimeError(f'refusing to overwrite bundle entry: {target}')
        else:
            target.symlink_to(source)
    env = os.environ.copy()
    env['LD_LIBRARY_PATH'] = str(bundle) + (':' + env['LD_LIBRARY_PATH'] if env.get('LD_LIBRARY_PATH') else '')
    run = subprocess.run(['compute-sanitizer', '--injection-path', str(bundle),
                          '--target-processes', 'all', '--tool', args.tool,
                          '--error-exitcode', '99', *command], env=env, capture_output=True, text=True)
    sys.stdout.write(run.stdout)
    sys.stderr.write(run.stderr)
    if run.returncode:
        return run.returncode
    if 'ERROR SUMMARY: 0 errors' not in run.stdout + run.stderr:
        print('BLOCKED: no successful instrumentation summary', file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
