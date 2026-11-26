# Qwen3.6-35B-A3B 原生支持：架构审计

日期：2026-11-26（Asia/Shanghai）。状态：只读审计完成，设计待审批，未实现 Decoder。
仓库基线：`85aeb3f45b90fcda5335b6356c65f9fe7e66798f`。审计前工作树干净；本次仅新增四份 docs 文档，不安装依赖、不修改外部编译器或模型。

## 证据和状态规则

IMPLEMENTED = 代码与本次运行测试支持该项有限结论；PARTIAL = 只有部分能力或不同架构的实现；MISSING = 所查生产调用链缺少所需能力；UNVERIFIED = 有代码/历史记录，但本次未复跑对应数值测试。MISSING 不宣称仓库任何角落都没有同名函数。仓库文件索引、关键词检索与关键生产路径逐段阅读结合使用；未逐行审查全部实验、训练和历史脚本。

证据代号：

| ID | 文件/位置 | 可证明的内容 |
|---|---|---|
| E1 | `makefile:163`、`:1320`、`:1558` | 默认路径、chat-gpu 依赖和 inference 入口 |
| E2 | `scripts/check_inference_model.py:17`、`:52` | 分片/header 检查；明确拒绝 qwen3_5_moe |
| E3 | `backend/platform/cuda/s_inference_cuda_bridge.cu:85`、`:285` | 按 model_type 分支、会话、prefill/decode；没有新架构分支 |
| E4 | `backend/platform/cuda/deepseek_v2_cuda.cu:52`、`:91`、`:358`、`:644` | mmap 权重缓存、DeepSeek MoE、Qwen2.5-VL 文本 Decoder |
| E5 | `backend/platform/cuda/hf_decoder_cuda.h`、`.cu:76` | 普通 attention+FFN 层、prefill/decode、FP32/cuBLAS 路线 |
| E6 | `src/runtime/model/hf_model.cpp:48`、`:107`；`safetensors.cpp:44` | 扁平配置、普通权重映射、整文件读取 |
| E7 | `src/runtime/native/cuda_memory_backend.cu`；`test/cuda_runtime_acceptance.cu` | 分配、同步拷贝、真实向量加法验收 |
| E8 | `test/native-construction/test_qwen_vl_text_cuda.py`、`qwen_vl_text_reference.py`、`test_deepseek_cuda.py` | 独立参考、小模型数值和 staging 测试设计 |
| E9 | `artifact/qwen_vl_text_validation/validation.json`；`artifact/deepseek_v2_validation/numerical_parity.json` | 历史结果，不等于本次执行或新架构通过 |
| E10 | `src/model/extensions/moe/moe_core.s`、`expert_routing.s:221`；`src/inference/compute/transformer/real_transformer_layer.s:214` | 多条 MoE 路线，语义不同或未接入生产桥 |
| E11 | `src/inference/extension/quantization/quant_core.s`；`src/runtime/native/quantization.h` | 量化概念/API，不能证明可用 CUDA INT4 |
| E12 | `src/runtime/model/bpe_tokenizer.cpp:118`；`scripts/run_gpu_chat.py` | ICU/BPE、added tokens、健康检查和子进程生命周期 |

## 实际入口与可复用性

`make inference → check_inference_model.py → make chat-gpu → S IR runner/CUDA runtime 构建 → chat-gpu-run → run_gpu_chat.py → S GPU 服务 → CUDA bridge.load_model → Decoder.prefill/decode → logits → 原生生成循环`。预检查是正确的能力门禁，保持不变直至实现通过验收。`make` 的构建依赖可能调用外部 S 工具，当前只读阶段不运行这些构建目标。

| 审计项 | 状态 | 发现、复用限制与证据 |
|---|---|---|
| 普通 Decoder、Qwen Decoder | PARTIAL | E4 为 Qwen2.5-VL text-only，E5 为 dense Transformer；不是本模型 |
| 架构注册 | PARTIAL | E3 是硬编码分支；`src/model/model_registry.s` 的 adapter 与 `src/model/catalog/model_registry.s` 的目录注册存在，但未连成该路径的可执行 Decoder factory |
| 配置解析 | PARTIAL | E6 读取根级 hidden/intermediate 等字段，不能处理本模型嵌套 text_config 和逐层 mixer |
| 层组织 | PARTIAL | E5 层固定 q/k/v/o+MLP；E4 同类 attention 循环；没有 hybrid layer-state variant |
| Prefill/Decode | PARTIAL | E4 Qwen prefill 是逐 token decode；接口可借鉴，但新模型不可执行 |
| MHA/GQA、causal mask | UNVERIFIED | E4 Qwen attention 按 kv head 分组，只访问历史和当前；E8 有独立参考；本次未复跑数值 |
| KV Cache | PARTIAL | E4 每层 keys/values、owner 和长度校验，尚无 DeltaNet 状态混合管理 |
| RoPE | PARTIAL | E4 half-split 全 head 旋转；新模型只旋转 64/256，且 query width 不等于 hidden |
| Gated Full Attention | MISSING | E4 无 q/gate 交错拆分、QK offset-RMSNorm 和输出 sigmoid 门 |
| Gated DeltaNet | MISSING | 生产 Decoder 未见 causal depthwise conv、衰减 delta recurrence 与 gated RMSNorm 的组合 |
| 混合注意力 | MISSING | 未见按真实 layer_types 调度两类状态的可运行 Decoder |
| Router/Top-K | PARTIAL | E4 DeepSeek 使用 softmax/selection，E10 有 CPU/S 路线；Qwen 精确语义与数值需独立验收 |
| Expert FFN/dispatch/combine | PARTIAL | E4 支持命名独立专家、SwiGLU、weighted sum；本模型为融合 3D expert tensors |
| Shared Experts | PARTIAL | E4 为 DeepSeek shared_experts，缺本模型 shared_expert_gate sigmoid |
| Expert 分层加载 | PARTIAL | E4 有 tensor-level mmap+GPU LRU；尚无 3D tensor 内 expert-slice residency |
| Safetensors/分片/名称映射 | PARTIAL | E6 与 E4 均支持分片；E6 持有所有文件 bytes，不能用于 67GiB/32GiB 主机；E4 mmap 更适合作为基础 |
| BF16/FP16 | PARTIAL | E6 解析 BF16/F16 等；E4 mmap 仅 BF16/F32，计算 FP32；dtype 解析不等于各 Kernel 支持 |
| INT8/INT4 | UNVERIFIED | E11 API 与 S 算法存在，但生产 mmap 路径拒绝这些 dtype；未找到该 CUDA 解码路径的 packed INT4 GEMV 证据 |
| GPU 显存/传输 | IMPLEMENTED | E7 本次沙箱外验收通过分配、H2D/D2H、真实 Kernel 和释放；不证明 Decoder 正确 |
| CUDA 异步执行 | PARTIAL | runtime 其他文件可能有 stream 能力；E4 权重上传为同步 cudaMemcpy；无该路径 prefetch/event/lease 生命周期证据 |
| Tokenizer/生成 | PARTIAL | E12 可复用，但 Qwen3.6 全模板、特殊 token 与双 EOS 需验收 |
| 单元/模型构造测试 | PARTIAL | E8、`test/native-stage4/test_hf_numerics.py` 与 loader validation 存在，未证明新架构构造 |
| 算子精度测试 | UNVERIFIED | E8/E9 针对旧架构；不覆盖新 DeltaNet/门控/融合专家 |
| Prefill/Decode/真实模型测试 | MISSING | 尚无本模型 40 层、中间值、logits 独立对齐证据 |

量化存在额外构建风险：`makefile:2566` 引用的 `src/runtime/native/quantization.cpp` 和 `test/numeric_alignment_probe.cpp` 本次实际不存在，不能将该目标视为已验证能力。`expert_routing.s:221` 用 embedding 与 expert_id 计算路由，不读取真实 router 权重；`moe_core.s` 使用 latent router、近似指数和不同激活，不可直接替代 Qwen MoE。S 文件中的功能名和自测打印不是数值正确性的证明。

## 本次实际运行证据

1. `PYTHONDONTWRITEBYTECODE=1 python3 test/native-construction/test_inference_model_preflight.py`：4 tests，OK。仅证明门禁与缺失/截断检查的这些用例。
2. 现有 `artifact/cuda_validation/cuda_runtime_acceptance` 沙箱内：退出 77，`CUDA_ERROR_NO_DEVICE`，记 BLOCKED，不记 PASS。
3. 同一现有二进制沙箱外：退出 0；RTX 4060 Ti，SM 8.9，设备显存 16,713,449,472 bytes，runtime 12000 / driver API 13000；真实向量加法与独立 CPU exact reference 相同，显存分配/传输/释放通过。free before/after 均为 14,997,323,776 bytes；瞬时数据不作长期预算保证。未重新编译、未安装驱动。
4. E9 记录旧 Qwen 数值误差约 2.40e-7、DeepSeek 约 2.86e-7；属历史记录，不能追溯为当前基线的 fresh PASS。本次没有执行大模型推理。
5. 主机约 31GiB RAM，约 24GiB available、8GiB swap；NVMe GAMMIX S20，分区剩余约 361GiB。吞吐未测，不能承诺 TPS。

## 模型证据：读取真实文件与全部权重 header

模型目录 `/home/shuwen/shuwen/model/Qwen3.6-35B-A3B` 的五项指定 JSON 全部存在并成功解析。26 个分片的所有 header 读取成功；1045 个张量均 BF16，payload 合计 71,903,645,408 bytes，与 index total_size 相同。逐项检查名称/shape/dtype 的结果如下；此前会话完成过全分片哈希校验，本次未重复读取全部 payload。

| 项 | 真实值 |
|---|---|
| architecture/model_type | Qwen3_5MoeForConditionalGeneration / qwen3_5_moe |
| text | hidden=2048，layers=40，vocab=248320，BF16，untied embedding/head |
| layer_types | 0-based 3,7,11,15,19,23,27,31,35,39 为 full，其余 30 层 linear |
| Full attention | 16 query heads、2 KV heads、head_dim=256；输出门启用，projection 无 bias |
| DeltaNet | 16 key heads、32 value heads，key/value dim=128，conv kernel=4，SSM dtype FP32 |
| RoPE | theta=10000000，partial=.25，即 rotary_dim=64；sections=[11,11,10]，interleaved=true |
| MoE | 每层 256 routed experts，top8，expert intermediate=512；一个 512 shared expert 与独立 sigmoid gate |
| context | 配置上限 262144；不代表首版或 16GB 卡可支持此长度 |
| tokenizer | BPE，基础 vocab 248044，tokenizer.json added token 26 个；logit vocab 248320 包含未分配 ID |
| EOS | tokenizer im_end=248046；generation_config EOS=[248046,248044]；禁用自动 BOS |
| sampling | generation_config do_sample=true，temperature=1，top_k=20，top_p=.95；数值验收单独用 greedy |
| 附加模块 | vision 333 tensors；MTP 19 tensors（含额外专家层）；首版明确不执行这些模块 |

tokenizer_config 还列出 tokenizer.json 未加入的 audio token；生成时不能对缺失 token ID 编造字符串。初版需显式支持文本范围，拒绝图像/视频/音频输入。模板位于 `chat_template.jinja`，存在 enable_thinking/add_generation_prompt 分支；不能只用通用 ChatML 猜测。

以 `P=model.language_model.layers.N.` 为前缀，所有 40 层均存在：

| 张量 | shape |
|---|---|
| P.input_layernorm.weight / post_attention_layernorm.weight | [2048] 各一 |
| P.mlp.gate.weight | [256,2048] |
| P.mlp.experts.gate_up_proj | [256,1024,2048] |
| P.mlp.experts.down_proj | [256,2048,512] |
| P.mlp.shared_expert.gate_proj.weight / up_proj.weight | [512,2048] |
| P.mlp.shared_expert.down_proj.weight | [2048,512] |
| P.mlp.shared_expert_gate.weight | [1,2048] |

30 个 linear 层另有：`linear_attn.in_proj_qkv.weight [8192,2048]`、`in_proj_z [4096,2048]`、`in_proj_a/in_proj_b [32,2048]`（均有 .weight）；`conv1d.weight [8192,1,4]`、`A_log/dt_bias [32]`、`norm.weight [128]`、`out_proj.weight [2048,4096]`。

10 个 full 层另有：`self_attn.q_proj.weight [8192,2048]`、`k_proj/v_proj [512,2048]`、`o_proj [2048,4096]`、`q_norm/k_norm.weight [256]`。q_proj 8192 不是 32 个 query heads，而是 16 个 head 内各自的 q 与 gate。

`model.language_model.embed_tokens.weight [248320,2048]`、`model.language_model.norm.weight [2048]`、`lm_head.weight [248320,2048]`。旧 `model.layers.*`/`model.embed_tokens.*` 名称不可照搬。

精确参数分类（先判 mtp，再判 vision，再判 experts，避免把额外 MTP 层算成主 Decoder）：主 routed experts 32,212,254,720；其余文本 2,448,355,968；MTP 844,640,768；vision 446,571,248；总计 35,951,822,704。主文本共 34,660,610,688 参数。

## 官方语义依据与可追溯性

已在线核对 [Qwen 官方配置](https://huggingface.co/Qwen/Qwen3.6-35B-A3B/raw/main/config.json) 的架构标识；它将模型路由到 Qwen3.5 MoE 实现，而不是普通 Transformer MoE。
详细公式和执行顺序依据本机已安装的官方 Transformers 5.15.0 源码静态阅读（未 import torch/执行框架）：
`/home/shuwen/.local/lib/python3.12/site-packages/transformers/models/qwen3_5_moe/modeling_qwen3_5_moe.py`。
关键位置：85 rotary、169 gated norm、201 causal conv、243 L2 norm、332 recurrence、385 DeltaNet、627 full attention、721 experts、760 router、779 shared gate、801 offset norm、821 Decoder。源码 SHA256=`16ef7b0dc6e26eae26a6ffd0ad11d93f85424f90ffb85fbcc9eecc0759cc930d`。这些为参考定义，不是正式推理后端；torch 当前未安装。

模型 JSON SHA256：

| 文件 | SHA256 |
|---|---|
| config.json | 93a4693fa9d8392fbfccd4b3c9873f4bfdcb14fdede978b123d07d19675efe99 |
| model.safetensors.index.json | 41b9356101ebf8e7519e150dc811f80c4226e727301fbb032b890f006ed0be83 |
| tokenizer.json | 5f9e4d4901a92b997e463c1f46055088b6cca5ca61a6522d1b9f64c4bb81cb42 |
| tokenizer_config.json | a39230de929388c748904265340616449f3bdeeb324d99385c6243d0577f98ed |
| generation_config.json | e70c136c1b78ddc1fb0905bac8e733a4dc448d4f852a5dd75143fffc70be550e |

## 未确定事项

官方主分支会变化，应固定本次本机参考 hash 后再建立 oracle；config 中 transformers_version=4.57.1 不是实际兼容性证明。新量化在真实权重上的质量、PCIe/NVMe 实测带宽、专家命中率、Qwen3.6 模板/BPE 的完整原生一致性仍未验证。现有 preflight 的结构检查不等于模型数值正确。本次审计不给新 Decoder 的任何 PASS。
