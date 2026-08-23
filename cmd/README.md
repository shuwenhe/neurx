# Command boundaries

Each directory below represents one stable product executable. Commands may
delegate to compatibility targets during migration, but domain implementation
code must remain under `src/`.

| Command | Responsibility | Stable Make target |
| --- | --- | --- |
| `neurx-train` | Launch training jobs | `make neurx-train` |
| `neurx-serve` | Run the public inference service | `make neurx-serve` |
| `neurx-worker` | Run a cluster worker | `make neurx-worker` |
| `neurx-controller` | Coordinate distributed jobs | `make neurx-controller` |
| `neurx-benchmark` | Run reproducible benchmarks | `make neurx-benchmark` |
