# Qwen3.6 原生推理最新审计

2026-11-27，起始 main / 591699d0。当前整体 **BLOCKED**。

| 项目 | 状态 | 当前证据 |
|---|---|---|
| nested config、架构元数据 | IMPLEMENTED | 40=30+10，Phase 1 11/11 |
| 权重索引/offset/dtype/本地 mmap | IMPLEMENTED | 26 shard，1045 tensor，71,903,645,408 byte 全量 mmap/pread 一致 |
| 上游 payload 真实性 | UNVERIFIED | 没有可信 upstream checksum |
| runtime 注册与 preflight | BLOCKED | runtime_supported=false；native decoder 缺失 |
| Gated DeltaNet | PARTIAL | FP32 GPU 16/16；BF16 RED 1 FAIL |
| Gated Full Attention/Partial RoPE/KV | PARTIAL | FP32 GPU 11/11，非完整 BF16 层 |
| 官方 BF16 参考 | IMPLEMENTED（参考测试范围） | 5/5，仅作 oracle，不是正式后端 |
| 原生 BF16/完整层对齐 | MISSING / BLOCKED | 35/35 输出不满足 BF16 必要条件；预算 PENDING |
| Qwen MoE/shared expert | MISSING | 元数据与其他模型实现不代表本路径计算支持 |
| 完整 hybrid decoder / bridge | MISSING | 尚无真实 token 生成 |
| GPU weight cache/expert paging | MISSING | 仅 host mmap/组件 admission 基础 |
| 宿主机 GPU | IMPLEMENTED（可用） | RTX 4060 Ti 16GB，580.159.03；普通沙箱隔离 |
| GPU sanitizer | BLOCKED / UNVERIFIED | memcheck/initcheck 均在首次有效插桩前退出 |
| Qwen2.5 / DeepSeek 当前 E2E 回归 | UNVERIFIED | 本轮未重跑，生产实现未改 |
| 文本端到端与性能 | BLOCKED / UNVERIFIED | 未运行正式生成，不填造数据 |
| 图像/视频 | MISSING / UNVERIFIED | 不在首版通过范围 |

详细命令、环境、误差、变更与门禁见 QWEN35_PHASE1_ACCEPTANCE.md 至 QWEN35_PHASE6_ACCEPTANCE.md、QWEN35_END_TO_END_ACCEPTANCE.md 与 QWEN35_PERFORMANCE_REPORT.md。

首个当前失败门禁为 Phase 2 BF16 与有效 CUDA sanitizer。按用户要求停止后续阶段；本轮实际完成全量映射测试开发与提交、真实 CUDA 回归、明确失败测试和证据保存，没有完成原生推理目标。
