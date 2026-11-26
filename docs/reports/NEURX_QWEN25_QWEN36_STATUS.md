# NeurX Qwen2.5 推理验证与 Qwen3.6 支持状态

日期：2026-11-26（Asia/Shanghai）。本报告区分本轮观测与既有阶段报告；历史 GPU 测试未在本轮重跑。

## Git 基线与环境

- 分支 `main`；最近提交：`19cae974 fix:neurx qwen3.6 moe`、`8e063ef3 feat(cuda): add DeltaNet state baseline and record BF16 reference blocker`、`99fe05e3 feat(cuda): add validated Qwen hybrid full attention baseline`、`b5f2c713 fix(native): restore stage1 regression validation in isolated toolchain`、`e14b10cc feat: add Qwen hybrid config and mapped checkpoint foundations`。
- 执行前已有修改：`artifact/build/production_s_inference/gpu_backend_enhanced.ir`、`gpu_backend_enhanced_entry.ir`、`artifact/build/s_gpu_runtime/libneurx_s_cuda.so`、`backend/platform/cuda/inference_server.s`、`docs/reports/NEURX_QWEN25_NATIVE_INFERENCE_ACCEPTANCE.md`；已有未跟踪文件：`docs/reports/NEURX_QWEN25_CHINESE_MULTITURN_FIX.md`、`test/native-stage4/test_gpu_backend_http_request_parsing.py`。
- `nvidia-smi` 退出码 9：无法与 NVIDIA 驱动通信。`/dev/nvidia*` 不存在；`nvcc` 位于 `/usr/bin/nvcc`。本环境 GPU 型号、驱动版本和可用显存均 UNVERIFIED。历史阶段报告的 RTX 4060 Ti 属于当时的运行记录，不代表本轮可访问的设备。

## 模型预检

| 模型 | config 架构 / model_type | 检查到的权重文件 | 本轮结果 |
|---|---|---:|---|
| `/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct` | `Qwen2ForCausalLM` / `qwen2` | 1 | 完整 preflight PASS |
| `/home/shuwen/shuwen/model/Qwen3.6-35B-A3B` | `Qwen3_5MoeForConditionalGeneration` / `qwen3_5_moe` | 26 | 文件检查无报错；完整 preflight FAIL（架构未支持） |

两目录均存在。分别运行 `python3 scripts/check_inference_model.py <目录> --json`；Qwen3.6 唯一报告错误是原生 `qwen3_5_moe` decoder 尚未实现。26 个分片通过该脚本的索引、存在性及 safetensors 头/长度检查；这不是全部权重内容哈希或数值正确性的证明。

## Qwen2.5 本轮实际运行

尝试用户指定的 `make inference CHAT_MODEL_PATH=/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct`，预检通过。由于 dry run 显示其会重建并覆盖已有未提交修改的 `libneurx_s_cuda.so`，尝试通过 `MAKEFLAGS` 跳过构建，但递归 make 仍开始构建 runner，随即中断（退出 130），未让其覆盖该 CUDA 库。随后以现有 runner、CUDA 库、backend/client IR，按 `chat-gpu-run` 的相同环境和 `scripts/run_gpu_chat.py` 入口启动，使用独立端口 18179、独立日志和 PID 文件。输入管道提供了五条指定 prompt 和 `/exit`，但后端未通过健康检查，客户端从未启动，prompt 未被读取或处理。

启动日志 `/tmp/neurx_qwen25_audit_18179.log`：后端打印模型路径、GPU、端口后报 `cudaGetDeviceCount: cudaErrorNoDevice (100): no CUDA-capable device is detected`；launcher 报 `GPU backend exited during startup (exit 0)`，自身退出码 1。`/usr/bin/time` 实测 real 0.44 秒、user 0.18 秒、sys 0.09 秒；这仅是失败启动时间，不是模型加载或生成耗时。

| 测试输入 | 实际生成文本 | 生成 token 数 / 耗时 |
|---|---|---|
| Hello, introduce yourself briefly. | 无；客户端未启动 | UNVERIFIED |
| 请用中文解释什么是大语言模型。 | 无；客户端未启动 | UNVERIFIED |
| Explain CPU and GPU differences，用中文总结。 | 无；客户端未启动 | UNVERIFIED |
| 我的项目名称是 NeurX，请记住这个名称。 | 无；客户端未启动 | UNVERIFIED |
| 刚才我告诉你的项目名称是什么？ | 无；客户端未启动 | UNVERIFIED |

| 项目 | 本轮证据与状态 |
|---|---|
| 后端进程启动 | 启动并打印配置，随后在 CUDA 设备检查处退出 |
| 服务健康启动 | BLOCKED，未出现 health ready |
| 模型加载 | UNVERIFIED；日志没有加载成功证据 |
| Prefill / Decode / 真实 token 生成 | UNVERIFIED；客户端未启动 |
| 多轮历史保留 | UNVERIFIED |
| KV Cache 实际复用 | UNVERIFIED；不能从聊天或历史记录推断 cache 复用 |

## Qwen3.6 实现审计

下表的独立测试是对应历史报告记录，不是本轮重跑结果；均不等于生产链路验证。源码的 `architecture_registry.h` 返回 `runtime_supported() == false`。

| 模块 | 实际状态 |
|---|---|
| ModelConfig / Registry / mmap | 已实现严格配置解析、架构和权重清单、只读映射及 expert 切片；[Stage 1](QWEN35_MOE_STAGE1.md) 记录 11 项专项测试通过。仅元数据和存储，未接入完整生产 decoder。 |
| Gated Full Attention / Partial RoPE | 已有独立 FP32 CUDA baseline；[Stage 2](QWEN35_MOE_STAGE2.md) 记录 11 项 GPU 测试通过，包括真实层权重与合成输入；未接生产 decoder。 |
| KV Cache | FullAttentionSession 有独立有界 KV 状态并有连续 decode 测试记录；完整 Qwen3.6 模型和生产推理中的 cache 尚未接入及验证。 |
| Gated DeltaNet | 独立 FP32 CUDA session、递归状态、卷积历史与混合状态 variant 已实现；[Stage 3](QWEN35_MOE_STAGE3.md) 记录 16 项 GPU 测试通过，未组成完整 decoder。 |
| 官方 BF16 参考验收 | BLOCKED：Stage 3 报告称缺少 torch，官方 BF16 fallback dtype/舍入探针未运行；FP32 独立参考通过不能代替该门禁。GPU sanitizer 也未获得有效结果。 |
| Qwen MoE Router / Top-8、Shared Expert | Qwen3.6 目标运行路径尚未实现和验收；计划阶段 4。配置及权重清单包含相关形状，不代表计算已经实现。 |
| INT4 权重量化 | Qwen3.6 目标路径尚未实现和验收；计划阶段 5。 |
| CPU offloading / GPU expert cache | Qwen3.6 目标路径的专家加载、内存控制和缓存尚未实现和验收；仓库其他架构或通用 offloader 代码不证明该路径可用。 |
| 完整 40 层 Hybrid Decoder | 未实现/未接生产 bridge；BLOCKED。 |
| 完整模型 prefill / decode / token generation | 未实现/未验证；现有独立算子的 prefill/decode 测试不是整模型生成。 |

## 后续阶段与阻塞

按 [计划](../superpowers/plans/2026-11-26-qwen35-native.md)，先在允许的参考环境完成 Stage 3 官方 BF16 对齐；再实现 Stage 4 Qwen MoE（router、Top-8、shared expert）、Stage 5 量化和有界专家 offload/cache、Stage 6 完整 decoder 与生产 bridge，最后进行 Stage 7 性能与资源验证。需要逐层数值、真实模型 token、内存预算、多轮及回归证据，才能考虑更改架构门禁。本轮用户禁止安装依赖，因此未安装 torch 或其他依赖。

Qwen2.5 恢复 GPU 访问后，需重新执行原命令及全部五条 prompt，分别记录输出、token、耗时、日志和 KV 实际复用证据；GPU 修复和环境权限不在本轮验证范围内。

## 结论

- **Qwen2.5：BLOCKED**（资产 preflight 通过，GPU 不可用，未实际生成）。
- **Qwen3.6 Asset Preflight：PASS**（仅指本轮脚本文件/结构检查；完整 preflight 因架构检查 FAIL）。
- **Qwen3.6 Runtime Support：UNSUPPORTED**。
- **Qwen3.6 Full Decoder：BLOCKED**。
