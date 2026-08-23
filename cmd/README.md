# Command boundaries

Each directory below represents one stable product executable. Commands may
delegate to compatibility targets during migration, but domain implementation
code must remain under `src/`.

| Directory | Binary | Responsibility | Stable Make target |
| --- | --- | --- | --- |
| `train/` | `neurx-train` | Launch training jobs | `make neurx-train` |
| `serve/` | `neurx-serve` | Run the public inference service | `make neurx-serve` |
| `worker/` | `neurx-worker` | Run a cluster worker | `make neurx-worker` |
| `controller/` | `neurx-controller` | Coordinate distributed jobs | `make neurx-controller` |
| `benchmark/` | `neurx-benchmark` | Run reproducible benchmarks | `make neurx-benchmark` |
