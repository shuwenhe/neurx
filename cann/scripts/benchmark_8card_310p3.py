#!/usr/bin/env python3
"""Collect and compare FP16/INT8 results from an eight-card 310P3 worker set."""

import argparse
import concurrent.futures
import json
import math
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


DEFAULT_PROMPTS = [
    [1, 2, 3, 4, 5, 6, 7, 8],
    [11, 17, 23, 31, 41, 53, 67, 79],
    [2, 2, 3, 5, 8, 13, 21, 34],
    [101, 97, 89, 83, 79, 73, 71, 67],
]


def worker_urls(base_url, count):
    parsed = urllib.parse.urlsplit(base_url)
    if parsed.port is None:
        raise ValueError("base URL must contain the first worker port")
    host = parsed.hostname or "127.0.0.1"
    if ":" in host:
        host = f"[{host}]"
    return [
        urllib.parse.urlunsplit(
            (
                parsed.scheme or "http",
                f"{host}:{parsed.port + index}",
                parsed.path.rstrip("/"),
                "",
                "",
            )
        )
        for index in range(count)
    ]


def request_json(url, path, payload=None, timeout=300):
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url + path,
        data=data,
        headers={"Content-Type": "application/json"},
        method="GET" if data is None else "POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"{url}{path}: HTTP {error.code}: {body}") from error
    return json.loads(body)


def percentile(values, percentage):
    ordered = sorted(values)
    if not ordered:
        return 0.0
    position = (len(ordered) - 1) * percentage
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (
        position - lower
    )


def load_prompts(path):
    if not path:
        return DEFAULT_PROMPTS
    value = json.loads(Path(path).read_text(encoding="utf-8"))
    if (
        not isinstance(value, list)
        or not value
        or any(
            not isinstance(prompt, list)
            or not prompt
            or any(not isinstance(token, int) or token < 0 for token in prompt)
            for prompt in value
        )
    ):
        raise ValueError("prompts file must be a non-empty JSON array of token arrays")
    return value


def completion_batch(url, prompts, max_new_tokens, seed):
    started = time.perf_counter()
    response = request_json(
        url,
        "/v1/batch-token-completions",
        {
            "input_ids": prompts,
            "max_new_tokens": max_new_tokens,
            "temperature": 0,
            "top_k": 1,
            "top_p": 1,
            "seed": seed,
        },
    )
    elapsed = time.perf_counter() - started
    if int(response["requests"]) != len(prompts):
        raise RuntimeError(f"{url}: batch response row count is inconsistent")
    return int(response["generated_tokens"]), elapsed


def collect(args):
    if (
        args.workers < 1
        or args.top_k < 1
        or args.top_k > 128
        or args.requests < 1
        or args.batch_size < 1
        or args.batch_size > 64
        or args.concurrency < 1
        or args.warmup < 0
        or args.max_new_tokens < 1
    ):
        raise ValueError("collection counts and limits are invalid")
    urls = worker_urls(args.base_url, args.workers)
    prompts = load_prompts(args.prompts)
    for url in urls:
        health = request_json(url, "/health/ready", timeout=args.timeout)
        if health.get("status") != "ok":
            raise RuntimeError(f"{url} is not ready")

    golden = []
    for index, prompt in enumerate(prompts):
        response = request_json(
            urls[index % len(urls)],
            "/v1/benchmark/logits",
            {"input_ids": prompt, "top_k": args.top_k},
            timeout=args.timeout,
        )
        golden.append({"input_ids": prompt, "top_logits": response["top_logits"]})

    for index in range(args.warmup):
        completion_batch(
            urls[index % len(urls)],
            [
                prompts[(index * args.batch_size + row) % len(prompts)]
                for row in range(args.batch_size)
            ],
            min(args.max_new_tokens, 8),
            index,
        )

    started = time.perf_counter()
    results = []
    with concurrent.futures.ThreadPoolExecutor(
        max_workers=args.concurrency
    ) as executor:
        futures = [
            executor.submit(
                completion,
                urls[index % len(urls)],
                [
                    prompts[(index * args.batch_size + row) % len(prompts)]
                    for row in range(args.batch_size)
                ],
                args.max_new_tokens,
                index,
            )
            for index in range(args.requests)
        ]
        for future in concurrent.futures.as_completed(futures):
            results.append(future.result())
    wall_seconds = time.perf_counter() - started
    tokens = sum(result[0] for result in results)
    latencies_ms = [result[1] * 1000.0 for result in results]
    report = {
        "schema": "neurx-ascend-benchmark-v1",
        "precision": args.precision,
        "workers": args.workers,
        "golden": golden,
        "performance": {
            "requests": len(results),
            "sequences": len(results) * args.batch_size,
            "batch_size": args.batch_size,
            "generated_tokens": tokens,
            "wall_seconds": wall_seconds,
            "tokens_per_second": tokens / wall_seconds,
            "request_latency_ms_p50": percentile(latencies_ms, 0.50),
            "request_latency_ms_p95": percentile(latencies_ms, 0.95),
            "request_latency_ms_mean": sum(latencies_ms) / len(latencies_ms),
        },
    }
    Path(args.output).write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(json.dumps(report["performance"], indent=2, sort_keys=True))
    print(f"saved {args.precision} report to {args.output}")


def compare(args):
    fp16 = json.loads(Path(args.fp16).read_text(encoding="utf-8"))
    int8 = json.loads(Path(args.int8).read_text(encoding="utf-8"))
    if fp16.get("schema") != "neurx-ascend-benchmark-v1":
        raise ValueError("FP16 report schema is unsupported")
    if int8.get("schema") != "neurx-ascend-benchmark-v1":
        raise ValueError("INT8 report schema is unsupported")
    if fp16.get("precision") != "fp16" or int8.get("precision") != "int8":
        raise ValueError("report precision labels must be fp16 and int8")
    if len(fp16["golden"]) != len(int8["golden"]):
        raise ValueError("reports contain different prompt counts")

    top1_matches = 0
    overlaps = []
    absolute_errors = []
    for reference, candidate in zip(fp16["golden"], int8["golden"]):
        if reference["input_ids"] != candidate["input_ids"]:
            raise ValueError("reports contain different prompts")
        reference_logits = {
            int(item["token_id"]): float(item["logit"])
            for item in reference["top_logits"]
        }
        candidate_logits = {
            int(item["token_id"]): float(item["logit"])
            for item in candidate["top_logits"]
        }
        if reference["top_logits"][0]["token_id"] == candidate["top_logits"][0][
            "token_id"
        ]:
            top1_matches += 1
        common = set(reference_logits) & set(candidate_logits)
        overlaps.append(len(common) / max(1, len(reference_logits)))
        absolute_errors.extend(
            abs(reference_logits[token] - candidate_logits[token])
            for token in common
        )

    top1_agreement = top1_matches / len(fp16["golden"])
    topk_overlap = sum(overlaps) / len(overlaps)
    mean_abs_error = (
        sum(absolute_errors) / len(absolute_errors)
        if absolute_errors
        else math.inf
    )
    max_abs_error = max(absolute_errors, default=math.inf)
    fp16_tps = float(fp16["performance"]["tokens_per_second"])
    int8_tps = float(int8["performance"]["tokens_per_second"])
    speed_ratio = int8_tps / fp16_tps
    passed = (
        top1_agreement >= args.min_top1_agreement
        and topk_overlap >= args.min_topk_overlap
        and mean_abs_error <= args.max_mean_abs_error
        and speed_ratio >= args.min_speed_ratio
    )
    result = {
        "passed": passed,
        "top1_agreement": top1_agreement,
        "topk_overlap": topk_overlap,
        "mean_absolute_logit_error": mean_abs_error,
        "max_absolute_logit_error": max_abs_error,
        "fp16_tokens_per_second": fp16_tps,
        "int8_tokens_per_second": int8_tps,
        "int8_to_fp16_speed_ratio": speed_ratio,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if passed else 1


def parser():
    root = argparse.ArgumentParser()
    commands = root.add_subparsers(dest="command", required=True)
    collect_parser = commands.add_parser("collect")
    collect_parser.add_argument("--base-url", default="http://127.0.0.1:8080")
    collect_parser.add_argument("--precision", choices=("fp16", "int8"), required=True)
    collect_parser.add_argument("--output", required=True)
    collect_parser.add_argument("--prompts")
    collect_parser.add_argument("--workers", type=int, default=8)
    collect_parser.add_argument("--top-k", type=int, default=32)
    collect_parser.add_argument("--requests", type=int, default=64)
    collect_parser.add_argument("--batch-size", type=int, default=8)
    collect_parser.add_argument("--concurrency", type=int, default=8)
    collect_parser.add_argument("--warmup", type=int, default=8)
    collect_parser.add_argument("--max-new-tokens", type=int, default=32)
    collect_parser.add_argument("--timeout", type=int, default=300)
    collect_parser.set_defaults(function=collect)

    compare_parser = commands.add_parser("compare")
    compare_parser.add_argument("--fp16", required=True)
    compare_parser.add_argument("--int8", required=True)
    compare_parser.add_argument("--min-top1-agreement", type=float, default=0.75)
    compare_parser.add_argument("--min-topk-overlap", type=float, default=0.80)
    compare_parser.add_argument("--max-mean-abs-error", type=float, default=1.0)
    compare_parser.add_argument("--min-speed-ratio", type=float, default=1.0)
    compare_parser.set_defaults(function=compare)
    return root


def main():
    args = parser().parse_args()
    try:
        result = args.function(args)
        return 0 if result is None else result
    except (OSError, RuntimeError, ValueError, KeyError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
