"""Summarize captured MLU GEMM timing CSV after native numerical acceptance."""
import argparse
import csv
import math
import statistics
from collections import defaultdict

TIMINGS = ("kernel_ns", "h2d_ns", "d2h_ns", "sync_ns")
FIELDS = ("dtype", "m", "n", "k", "phase", *TIMINGS)
WARMUP = 5
SAMPLES = 30


def summarize(source):
    reader = csv.DictReader(source)
    if reader.fieldnames is None or set(FIELDS) - set(reader.fieldnames):
        raise ValueError("timing CSV lacks required columns")
    groups = defaultdict(lambda: ([], []))
    for row in reader:
        dtype = row["dtype"]
        m, n, k = (int(row[field]) for field in ("m", "n", "k"))
        phase = row["phase"]
        if dtype not in ("bf16", "fp16") or min(m, n, k) <= 0:
            raise ValueError(f"line {reader.line_num}: invalid configuration")
        if phase not in ("warmup", "measured"):
            raise ValueError(f"line {reader.line_num}: invalid phase")
        values = tuple(float(row[field]) for field in TIMINGS)
        if not all(math.isfinite(t) and t >= 0 for t in values) or values[0] == 0:
            raise ValueError(f"line {reader.line_num}: invalid timing")
        warmups, measured = groups[dtype, m, n, k]
        if phase == "warmup":
            if measured:
                raise ValueError(f"line {reader.line_num}: warm-up follows measurement")
            warmups.append(values)
        else:
            measured.append(values)

    if not groups:
        raise ValueError("timing CSV has no configurations")
    result = []
    for (dtype, m, n, k), (warmups, measured) in sorted(groups.items()):
        if len(warmups) < WARMUP or len(measured) < SAMPLES:
            raise ValueError(f"{dtype} {m}x{n}x{k}: insufficient warm-up or samples")
        kernel, h2d, d2h, sync = map(sorted, zip(*measured))
        median = statistics.median(kernel)
        p95 = kernel[math.ceil(0.95 * len(kernel)) - 1]
        result.append((dtype, m, n, k, len(warmups), len(measured), median, p95,
                       2 * m * n * k / (median * 1e3), statistics.median(h2d),
                       statistics.median(d2h), statistics.median(sync)))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv", type=argparse.FileType("r"))
    args = parser.parse_args()
    try:
        rows = summarize(args.csv)
    except (ValueError, TypeError) as exc:
        parser.error(str(exc))
    print("dtype,m,n,k,warmup,samples,kernel_median_ns,kernel_p95_ns,tflops,"
          "h2d_median_ns,d2h_median_ns,sync_median_ns")
    for row in rows:
        print(",".join(str(value) for value in row))


if __name__ == "__main__":
    main()
