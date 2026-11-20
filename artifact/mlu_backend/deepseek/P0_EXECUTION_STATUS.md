# P0 execution status

**BLOCKED at the native runtime gate.** This session sees eight MLU590-M9 devices in PCI inventory, with zero MLU device nodes. Cached CNRT fails to load on glibc 2.31. No native GEMM, latency, throughput or inference results exist.

| Phase | Current evidence |
| --- | --- |
| 0. Preserve and audit | Inspected tracked and untracked work, v1 source, current CNRT integration and model directory. Existing work was preserved. Stage4 smoke compile and run passed. |
| 1. Native runtime | **Blocked** by device exposure and unsupported cached CNRT. The focused ABI contract passed. |
| 2. First GEMM | The existing CPU `cpu_matmul` passed a new Stage4 smoke test. Runtime allocation, transfers, stream and BF16/FP16 MLU compute remain blocked. |
| 3. Benchmark | No MLU configuration executed. The measurement protocol is recorded separately. |
| 4. DeepSeek operators | Development remains gated on native GEMM acceptance. |
| 5. Multi-card | CNCL and single-card acceptance remain unavailable. |
| 6. Model | Confirmed official revision metadata and validated partial shard headers against the weight index. All four finalized shards are missing. No model loading or inference ran. |

## Compiler evidence

`/home/gaozhi/.local/bin/s --version` exited 0 and reported `dev-9cb73e41a`, source revision `9cb73e41a68cb045bf9be6e5c018071e6f1f38aa`, and `certification NOT CERTIFIED`. A positional `s version` exited 1 because the driver interpreted it as a source filename. `sha256sum /app/shuwen/s/bin/s_compiler /app/shuwen/s/.bootstrap/native-imports/stage4` exited 0 and returned the same digest for both files.

`85ceaca5d85a1aa25ec74ea808e10afc8fa0bd72933e5b3c371eeea95ba51268`

A standalone S smoke program returned 0 when `6 * 7 == 42`. Both `/home/gaozhi/.local/bin/s build "$PWD/artifact/build/mlu_p0/stage4_smoke.s" -o "$PWD/artifact/build/mlu_p0/stage4_smoke"` and the resulting executable exited 0. The compiler printed `native-codegen=structured-mir-to-ssa-to-amd64`. The Stage4 and seed toolchains are distinct. The existing MLU ABI target still builds its shared S component through the seed exporter.

The attachment ended at the third report number without giving its name. This phase provides the two named reports plus separate checkpoint and GEMM reports to record the available evidence. The existing Hugging Face connectivity report was preserved.

[Runtime gate](MLU_RUNTIME_ACCEPTANCE.md) · [GEMM acceptance and measurement protocol](P0_GEMM_ACCEPTANCE.md) · [Checkpoint audit](DEEPSEEK_CHECKPOINT_AUDIT.md)
