from __future__ import annotations

import argparse
import json
import sys

from neurx.platform import doctor, format_doctor_report, runtime_info


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="neurx-doctor", description="Tensor platform diagnostics")
    parser.add_argument("--json", action="store_true", help="Print runtime info as JSON")
    parser.add_argument("--require-cuda", action="store_true", help="Fail diagnostics if CUDA is unavailable")
    parser.add_argument("--require-mps", action="store_true", help="Fail diagnostics if MPS is unavailable")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)

    if args.json:
        print(json.dumps(runtime_info(), indent=2, sort_keys=True))
        return 0

    results = doctor(require_cuda=args.require_cuda, require_mps=args.require_mps)
    print(format_doctor_report(results))
    ok = all(item.passed for item in results)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
