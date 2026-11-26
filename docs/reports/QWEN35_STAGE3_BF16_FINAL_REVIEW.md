# Stage 3 BF16 审查状态

日期：2026-11-26。**独立审查：未完成；Stage 3：BLOCKED。** 本轮请求独立审查，但受派审查者无法访问本地文件和命令，不能形成独立代码结论。以下是执行者的证据缺口记录，不冒充独立审查通过。

- 固定官方源码与辅助文件哈希由参考加载器检查；运行 trace 已观测 BF16/FP32 tensor 边界。GPU kernel 内部累加类型未由该 trace 证明。
- 现有原生实现和 probe 是 FP32 baseline，不是 BF16 逐舍入兼容实现。未改动生产 CUDA 或 Phase 1/2。
- 四路比较已覆盖 tiny 合成输入和 2048/8192 小维度连续 decode，但 trace 缺 raw QKV、conv 前后、prediction、delta 和 gated norm 的四路逐 token 对比；长序列并未覆盖所有要求的输入、prefill 分块和生命周期组合。
- 真实权重已对第 0 层零初态及第 4 层非零初态各三 token 做 N-CUDA/M32/O-BF16 对比，并在第 4 层 reset 后比较一个 token；更广层和更多 reset 场景仍缺失；合成输入不是模型层 hidden state。
- BF16 的逐模块和长度误差预算未独立制定、审核或冻结，不能由现有 CUDA 误差反推；所有预算保持 PENDING。
- CUDA memcheck/initcheck 均在第一次有效插桩前退出；内存安全 UNVERIFIED。多 session 隔离及异常构造资源释放的完整验收仍未完成。
- `test_qwen35_official_bf16.py` 的通过证明其断言及参考执行成功，不是完整 N-CUDA/BF16 的通过。关于当前结果及具体比较见 [验收报告](QWEN35_MOE_STAGE3_BF16_ACCEPTANCE.md)。

独立审查者需要在可访问此工作目录和原始测试证据的环境中逐项复核、形成书面结论；在此之前不能将审查或 Stage 3 标为 PASS，不允许进入 Stage 4。

## 本轮独立审查请求

再次派发只读独立代码审查，审查代理明确报告没有可用的文件读取/命令工具，无法查看源码、测试或原始证据。独立审查状态仍为 **NOT COMPLETED**，不得将执行者检查冒充独立审查。可供后续审查的源码及原始证据包位于 `artifact/review/qwen35_stage3/`，其 SHA256 manifest 记录包内文件；打包本身不构成审查。
