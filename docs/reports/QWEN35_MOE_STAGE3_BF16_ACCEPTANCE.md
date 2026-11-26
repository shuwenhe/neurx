# Qwen3.6 Stage 3 官方 BF16 参考验收

日期：2026-11-26（Asia/Shanghai）。**Stage 3 完整验收：BLOCKED；Stage 4 MoE：不允许开始。** 已恢复本次宿主机 GPU 访问并运行官方参考及有限的原生对比；尚无经冻结审核的 BF16 误差预算，也未覆盖全部必需场景。

## GPU 环境与根因

普通执行沙箱中 `nvidia-smi` 报无法与驱动通信，`/dev/nvidia0`、`/dev/nvidiactl`、`/dev/nvidia-uvm` 均不可见，`CUDA_VISIBLE_DEVICES` 未设置；这解释了此前的 `cudaErrorNoDevice (100)`。相同用户在获准的宿主机执行中可见这些设备节点（权限 `crw-rw-rw-`），`nvidia-smi` 正常识别 GPU。因此本次根因是执行环境的设备节点隔离，而不是已证实的驱动故障或设备权限不足；没有改动驱动、系统工具链或 CUDA 库。

宿主机 NVIDIA GeForce RTX 4060 Ti，显存 16380 MiB，检查时使用 1582 MiB；驱动 580.159.03，`nvidia-smi` 显示驱动支持 CUDA 13.0。系统 `nvcc` 12.0.140，系统动态链接器能找到 `libcuda.so.1`、`libcudart.so.12`（12.0.146）与 `libnvidia-ml.so.1`。隔离 Python 的 PyTorch CUDA 构建为 12.4；宿主机 `torch.cuda.is_available()` 为 True、设备数 1，沙箱中为 False。GPU 可通过获准宿主机执行访问，普通沙箱仍无法直接访问。

## Qwen2.5 恢复验证

执行 `make inference CHAT_MODEL_PATH=/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct`，额外将 runner 与 CUDA runtime 构建目录指定到 `/tmp`、使用端口 18179 并设生成上限 128，以保护现有未提交的构建产物。Preflight、GPU 模型加载、health 和真实生成成功；整个构建及单次管道运行 real 29.41 秒。管道的多行被客户端合并，不能作为逐轮验收。

随后使用该次 make 新建的相同 runner、runtime 和现有 IR，在同一 GPU 后端入口逐条交互（日志 `artifact/build/qwen35_stage3/bf16_acceptance_20261126/qwen25_backend.log`）：

| Prompt | 实际生成 | prompt / generated tokens |
|---|---|---:|
| Hello, introduce yourself briefly. | Hello! I am an AI language model created by Anthropic to be helpful, harmless, and honest. I am here to assist you with any questions or tasks you may have. How can I help you today? | 25 / 43 |
| 请用中文解释什么是大语言模型。 | 大语言模型是一种人工智能技术，它使用深度学习和自然语言处理技术来模拟人类的语言能力。这些模型可以理解、生成和解释人类语言，包括但不限于自然语言处理、机器翻译、文本生成、对话系统等。大语言模型可以处理各种语言，包括但不限于中文、英文、法语、西班牙语等。它们可以用于各种场景，如语音识别、文本生成、机器翻译、情感分析等。 | 87 / 90 |
| 我的项目名称是 NeurX，请记住这个名称。 | NeurX | 199 / 3 |
| 刚才我告诉你的项目名称是什么？ | NeurX | 220 / 3 |

历史文本出现在后续请求的 prompt 中，多轮结果 PASS；模型自述身份是生成内容，不是对模型来源的事实判断。后端日志记录生成 token 数，但未为每轮记录独立耗时。生成证实本次 prefill/decode 路径工作；日志显示重发历史文本，跨轮 KV Cache 实际复用 **UNVERIFIED**。

## 官方 BF16 测试

复用既有 `artifact/reference-env`，没有安装依赖：`torch 2.6.0+cu124`、CUDA 12.4、cuDNN 90100；关闭 TF32、autocast、compile，固定确定性配置和 `CUBLAS_WORKSPACE_CONFIG=:4096:8`。官方 `modeling_qwen3_5_moe.py` SHA256 为 `16ef7b0dc6e26eae26a6ffd0ad11d93f85424f90ffb85fbcc9eecc0759cc930d`；辅助 `cache_utils.py` 为 `0d5fd6901ce2b7108eff40e06d7ce29e9b0f9cc8ed2f40d2fb3a2e4d4f43e630`，`activations.py` 为 `5b20c0a3625edc0001a98f09ce3c6b5baa1100e1d7ad8dee649e4d45c8468665`，均通过参考 harness 固定哈希检查。该 harness 提取官方 AST 原函数体，移除 Hub/accelerate 装饰器并显式选择纯 torch chunk/recurrent fallback；不使用 FLA、Hub 自动替换或融合 kernel。

命令：

```bash
CUBLAS_WORKSPACE_CONFIG=:4096:8 PYTHONDONTWRITEBYTECODE=1 \
  artifact/reference-env/bin/python test/native-construction/test_qwen35_official_bf16.py
```

宿主机 GPU 结果：**5 tests，4.416 s，OK**。覆盖源码哈希拒绝、dtype 探针、随机和零/小范数及非零初态校准、长度 1/3/4/63/64/65/257 的官方 prefill 与 incremental decode 比较。测试观察到输出 BF16、recurrent state FP32、convolution history BF16；L2 的乘法、求和、加法、rsqrt 输出可见 dtype 为 BF16。官方两种模式在测试长度下输出 maxabs 为 0，最终 state 在该测试的 rtol 1e-4、atol 2e-5 内；这只是官方两路径相互比较，不是原生 CUDA 通过 BF16 验收。完整校准与 dtype 轨迹在 `artifact/build/qwen35_stage3/official/`。

## 原生 CUDA 与官方 BF16 逐 token 比较

使用现有 Stage 3 CUDA probe（SHA256 `ec52164e248ea8514459e58308a6d6ed8aa960f3369076d40f575180377534d7`）和 BF16 舍入后的同一 tiny fixture，seed 781、2191 各 5 token，官方首 token chunk、随后 recurrent；对每 token 的输出、state 和 history 计算 maxabs、RMSE、relative L2、cosine。脚本与完整指标分别为 `artifact/build/qwen35_stage3/bf16_acceptance_20261126/compare.py` 和 `per_token_metrics.json`。这比较的是现有 **FP32** 原生路径与官方 BF16，不声称实现 BF16 逐舍入兼容。

| Seed | 对象 | 五个 token 的 maxabs（顺序） | 最坏逐 token relative L2 |
|---:|---|---|---:|
| 781 | output | 0.000783196, 0.00422365, 0.00103068, 0.000987768, 0.00498468 | 0.00945161 |
| 781 | state | 0.0000865487, 0.000606723, 0.000370182, 0.000509419, 0.000650965 | 0.00654295 |
| 781 | history | 0.00184584, 0.00184584, 0.00184584, 0.00358474, 0.00358474 | 0.00172741 |
| 2191 | output | 0.00107199, 0.00203727, 0.00400233, 0.00185782, 0.000708222 | 0.0193080 |
| 2191 | state | 0.000625707, 0.000588462, 0.000523031, 0.000393674, 0.000716895 | 0.00678490 |
| 2191 | history | 0.00378704, 0.00378704, 0.00378704, 0.00378704, 0.00203753 | 0.00189633 |

这些差异不是量化误差；官方和 FP32 计算路径有不同 BF16 舍入边界。既有 FP32 数学阈值不适用于 BF16 兼容验收，不能据此标 PASS 或擅自放宽阈值。当前测试未完成真实权重官方逐 token 对齐、所有 BF16 舍入边界、2048 连续 decode、长序列误差及经独立审核冻结的 BF16 逐模块/长度预算；独立 GPU sanitizer 也仍 UNVERIFIED。需要补全这些证据，并在预算冻结后评价原生结果；如未满足则修复并重测，不降低标准。

## 结论与阶段门禁

- GPU 环境：**宿主机可用；普通沙箱设备隔离**。
- Qwen2.5：**英文、中文及文本多轮生成 PASS**；跨轮 KV 复用 UNVERIFIED。
- 官方 fallback 测试：**5/5 PASS**；这是参考和有限覆盖结果，不等于完整 Stage 3 通过。
- Stage 3 官方 BF16 完整验收：**BLOCKED**；未冻结预算且覆盖不完整。
- Stage 4 MoE：**不允许开始**，等待 Stage 3 门禁完整通过。
- Qwen3.6 全模型 runtime：仍 UNSUPPORTED，独立算子结果不代表完整 decoder 已通过。

未修改 Qwen3.6 preflight、Makefile 默认模型、外部 S 编译器或模型权重；未推送远程仓库。

## 2026-11-26 最终攻关补充（当前仍 BLOCKED）

本次执行基线 `main`、`19cae974`，保留开始时所有未提交修改。宿主机 RTX 4060 Ti、驱动 580.159.03 可访问；沙箱 GPU 隔离问题与前文一致。复用 torch `2.6.0+cu124`、cuDNN 90100 和固定官方文件，未安装依赖。逐算子实际可见 dtype 和内部累加的未验证项见 [dtype 审计](QWEN35_STAGE3_BF16_DTYPE_AUDIT.md)。独立审查派发后因审查者无法访问本地工具而未完成，详见 [审查状态](QWEN35_STAGE3_BF16_FINAL_REVIEW.md)。

### 四路数值与真实权重

固定 tiny fixture 三个 seed（781、2191、7419）、每个五 token；四类误差分别计算，每 token 比较 output/core/state/history/beta/decay，记录 maxabs、relative L2、RMSE、cosine、argmax、非有限计数和可见 dtype。所有 seed/token 的最坏 maxabs：

| 比较 | output | recurrent state | convolution history |
|---|---:|---:|---:|
| M32 vs M64 | 2.13363e-7 | 2.85559e-8 | 5.96046e-8 |
| O-BF16 vs M32 | 0.01340735 | 0.000822052 | 0.00384855 |
| N-CUDA FP32 vs M32 | 1.19209e-7 | 2.23517e-8 | 0 |
| N-CUDA FP32 vs O-BF16 | 0.01340726 | 0.000822052 | 0.00384855 |

以上不是经批准的 BF16 门限。四路逐 token 文件及脚本位于 `artifact/build/qwen35_stage3/final_bf16_20261126/four-way-metrics.json` 和 `four_way.py`。本对比未记录全部要求的 raw QKV、conv、prediction、delta、gated RMSNorm，不能称为完整逐算子验收。

第 0 层九个真实 BF16 权重通过各自真实 checkpoint index/header 读取并记录 payload SHA256；使用三 token 合成输入、零初态，原生使用两 token prefill 加一步 decode，官方参考首 token chunk 后逐 token recurrent。N vs M32 的 output/state/history 最大误差分别为 2.79397e-9、1.11759e-8、0；N vs O 分别为 4.76576e-5、0.000296142、0.00378942。官方参考峰值 allocated 134876160 bytes、reserved 150994944 bytes；不是全模型内存。详见该目录 `real-layer0.json` 和 `real_layer0.py`。该第 0 层结果不覆盖非零初态或 reset，也不是完整模型 hidden state。

另外以临时测试 probe 明确选择第 4 层，读取同样九项真实 BF16 权重并记录 hash；三 token 合成输入、相同非零 FP32 初始 recurrent state 与 BF16 舍入后 history，原生两 token prefill 加 decode，官方由非零缓存开始逐 token recurrent。N vs M32 output/state/history 的最大误差为 1.34110e-7、5.93718e-9、0；N vs O 为 0.00100058、0.000249293、0.00193870。首次执行的 history 未在三路统一 BF16 舍入，因此作废；上述值来自统一 history 后的重跑。详见 `real-layer4.json`、`real_layer4.py`、`layer4_probe.cu`。第 4 层 reset 后另执行一个 token：N vs M32 的 output/state/history maxabs 为 1.04774e-9、5.58794e-9、0；N vs O 为 1.39433e-5、0.000163770、0.00187355（见 `real-layer4-reset.json`）。更多层和 reset 场景尚未验证。

### 长序列

小维度（KH1/VH2/KD2/VD2）、近单位衰减、BF16 舍入的合成输入；每个 token 比较 output/core/state/history/beta/decay，包含首 token 官方 chunk 和后续 recurrent，原生连续单步 decode。2048 和 8192 的各比较最坏 maxabs：

| 长度 | 比较 | output | state | history |
|---:|---|---:|---:|---:|
| 2048 | M32 vs M64 | 1.54514e-6 | 9.86846e-8 | 1.19209e-7 |
| 2048 | O-BF16 vs M32 | 0.0162544 | 0.00358657 | 0.00747395 |
| 2048 | N-CUDA vs M32 | 1.69873e-6 | 8.94070e-8 | 0 |
| 2048 | N-CUDA vs O-BF16 | 0.0162543 | 0.00358658 | 0.00747395 |
| 8192 | M32 vs M64 | 1.54514e-6 | 9.86846e-8 | 1.49012e-7 |
| 8192 | O-BF16 vs M32 | 0.131211 | 0.00429448 | 0.00770473 |
| 8192 | N-CUDA vs M32 | 1.69873e-6 | 8.94070e-8 | 0 |
| 8192 | N-CUDA vs O-BF16 | 0.131211 | 0.00429446 | 0.00770473 |

完整逐 token 曲线压缩保存在 `final_bf16_20261126/long-fourway-2048.json.gz` 和 `long-fourway-8192.json.gz`。8192 仅为小维度独立算子，不代表模型支持该上下文；2048 同样不是完整真实维度模型验收。长序列记录没有所有中间 tensor 的 dtype/argmax，不能称为完整误差分析系统。BF16 预算仍 PENDING；不根据上述 CUDA 差异反向设定阈值。

### 回归与 sanitizer

本轮重跑 Stage 1：11/11；Stage 2 GPU：11/11；Stage 3 GPU：16/16；固定官方 BF16 参考：5/5。指定本地兼容编译器的 `make native-stage4-test` 完整回归为 34 tests / 472.262 s / OK（包含原有 31 项与工作区新增 3 项 GPU 请求测试），日志 `artifact/build/qwen35_stage3/final_bf16_20261126/native-stage4.log`。阶段 3 测试包括 FP32 的 2048 连续 decode、8192 小维度、真实第 0 层权重、owner、reset、invalid 恢复和 64 MiB trace 上限；不能将 FP32 测试当 BF16 全面通过。

CUDA memcheck 和 initcheck 在宿主机使用已有 `compute-sanitizer` 执行；默认路径报告找不到注入库，显式指定现有 `/usr/lib/nvidia-cuda-toolkit/compute-sanitizer` 后均报 `Target application terminated before first instrumented API call`，未获得有效插桩。两项均 **UNVERIFIED**，不计零错误。未修改系统 CUDA。

**Stage 3：BLOCKED。Stage 4：禁止开始。** 仍需补齐模块级 trace、更多真实层及 reset 场景、BF16 参考分布与独立审核的冻结预算、资源/生命周期和有效 sanitizer 证据，并完成可访问代码的独立审查。上述条件满足后才能判定是否需要且如何实现 BF16 CUDA 路径；本轮未修改生产 CUDA、Preflight、默认模型或已验收 Phase 1/2。

仓库整体 `git diff --check` 报既有未提交文档 `NEURX_QWEN25_NATIVE_INFERENCE_ACCEPTANCE.md` 的 5 处行尾空格；该文件属于本轮开始前的用户修改，未清理。

## Final Acceptance Gate Closure — 本轮记录

起始 Git 为 `main` / `19cae974`；现有用户修改已保留。当前 `git diff --check` 退出 0，历史报告中的 5 处行尾空格在本轮起始状态不再复现，不修改历史报告作为当前状态。宿主机 RTX 4060 Ti，驱动 580.159.03，官方源码 SHA256 仍为 `16ef7b0dc6e26eae26a6ffd0ad11d93f85424f90ffb85fbcc9eecc0759cc930d`。

新增测试 probe 的显式 `--layer` 选择并保持旧接口：RED 为旧 probe 对 `--layer` 误入 JSON 权重路径报 `qkv` 缺失；GREEN 后三个专项测试检查可选线性层、Full Attention/越界/负数拒绝及不同层非零输入输出不同，**3/3 PASS**。使用新 probe 重跑受影响的 Stage 3 原 GPU 回归：**16/16 PASS**。原 Stage 3 生产 `.cu/.h/.cuh` 与历史报告中哈希匹配；历史 Stage 1/2、官方参考和 34 项旧路径结果未因本轮测试 probe 修改而重跑。

本轮再次使用现有 `compute-sanitizer --injection-path /usr/lib/nvidia-cuda-toolkit/compute-sanitizer --target-processes all` 执行 memcheck 和 initcheck：均 exit 255，并报告 `Target application terminated before first instrumented API call`；**UNVERIFIED**，不能计作通过。审查者因无文件读取工具无法独立检查源码；审查 **NOT COMPLETED**。

完整四路 13 节点中间 trace **BLOCKED**；先前 output/core/state/history/beta/decay 的四路结果为 **PARTIAL**。BF16 每节点预算 **PENDING**，长序列 FP32/官方对比 **PARTIAL**；用户态测试 probe 变化并不等于实现 BF16 兼容路径。真实层比较结果见后续记录；所有上述门禁未关闭前，Stage 3 **BLOCKED**，Stage 4 **NOT AUTHORIZED**。
