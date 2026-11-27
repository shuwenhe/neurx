# Full Attention BF16 架构审计

日期：2026-11-27（Asia/Shanghai）。Git 基线：`a56388ea6ebd598f26016783e20a071821c703a2`，核心历史提交 `9e8dd875`、`a56388ea` 均保留。本轮只读分析已有源文件与环境，唯一交付写入为这三份报告；没有编写/执行新 Attention probe，没有修改生产代码、现有测试、Bridge、Preflight、外部编译器或历史证据，也不提交/重写 Git 历史。

本阶段状态：**审计与设计已形成，待人工确认；Full Attention BF16 实现/数值验收 UNVERIFIED，完整 Phase 2 仍 BLOCKED。** P0 历史 PASS 不能推广为 Attention BF16 PASS。本次没有重跑历史测试，历史 11/11/16/16 等仅是上轮证据。

参考环境只读检查：Transformers distribution 5.15.0；固定 Torch 2.6.0+cu124，Torch CUDA 12.4，cuDNN 90100；GPU NVIDIA GeForce RTX 4060 Ti，驱动 580.159.03，nvcc 12.0.140，Compute Sanitizer 2022.4.1。宿主机检查时 VRAM 1507/16380 MiB（含检查进程约120 MiB），不是推理显存峰值。参考子进程调用既有 configure_runtime 设置 highest、TF32=False、BF16 reduced precision reduction=False、deterministic=True、autocast/compile=False；未运行 forward。普通沙箱仍无 GPU 访问，后续 CUDA 验收必须在宿主机执行。

官方文件目录：`/home/shuwen/.local/lib/python3.12/site-packages/transformers/`。checkpoint config 的 transformers_version=4.57.1 是序列化元数据，不能替代此次实际 distribution/source 版本；远端模型发布版本/commit 与本地目录名称“Qwen3.6”的来源对应关系未独立证明，参考由本地架构和文件哈希界定。

## 检查文件与真实调用链

已读取 `backend/platform/cuda/hybrid_attention_cuda.h/.cu`、`gated_attention_kernels.cuh`、`hybrid_mixer_state.h`、`test/native-construction/qwen35_stage2_probe.cu`、`test_qwen35_stage2.py`、`src/runtime/model/hybrid_config.cpp`、`architecture_registry.h`，并搜索 src/backend/makefile 中 FullAttentionSession 调用方，检查 Preflight/服务器相关入口。官方相关文件及关键文件 SHA256 见本文末。

可定位的原生路径：

```text
Stage2 Python test → nvcc(--fmad=false, 无 fast-math) → qwen35_stage2_probe
  → config / ArchitectureRegistry / MappedWeightStore.validate
  → BF16 checkpoint bytes 展开为 host float（真实权重模式）
  → FullAttentionSession ctor → cudaMalloc(float)/cudaMemcpy(H2D)
  → forward(input, position, trace)
      linear(Q+gate), linear(K), linear(V)
      normalize_qg(Q/gate split), normalize_k
      partial_rope(Q), partial_rope(K)
      D2D append rotated K and V → keys/values
      gated_gqa(score/scale/causal/max/exp/denom/weighted sum/gate)
      linear(O) → synchronize → D2H float output/trace → past += rows
```

源码锚点：hybrid_attention_cuda.cu:18–34 为实际 allocation/copy dtype；36–54 constructor；59–83 forward；gated_attention_kernels.cuh:6–47 为真实 kernel。MixerState.forward 使用 std::variant 分派到同一个 FullAttentionSession 并检查 owner；这是独立组件包装，不是完整 Decoder。搜索结果中的构造主要来自 Stage2/Stage3 probe 与 MixerState；未发现目标模型的生产 decoder factory/正式 serve 路径已连接该组件的证据。ArchitectureRegistry.runtime_supported() 仍 false。现有二进制的完整编译 provenance/SASS 未在本轮审计，不能仅凭头文件编译契约声称某任意二进制已满足 --fmad=false。

## 实际模型形状

本地 config：hidden=2048，Q heads=16，KV heads=2，head_dim=256，GQA ratio=8；Q feature width=4096，Q+gate width=8192，KV width=512；partial rotary=64（25%），仅前64维旋转、后192维保持；theta=10000000、epsilon=1e-6；bias=False，dropout=0，gate=True。Full Attention 层索引为3,7,11,15,19,23,27,31,35,39（0-based）；当前 Stage2 --model 只选择第一个 full 层3，不能据此声称全部10层验证。

权重布局：q_proj[8192,2048]（每个 head 的 Q256+gate256，不是全 Q 后全 gate）、k/v_proj 各[512,2048]、o_proj[2048,4096]、q_norm/k_norm 各[256]。源码 manifest 检查这些形状；此轮没有重新读取并 hash 六项 payload，payload 来源完整性/数值未重新验收。

## Native 实际数据类型与算术

| 节点 | 真实调用/存储 | Reduction / rounding | 已实现与缺口 |
|---|---|---|---|
| 输入/权重 | host vector<float> → GPU float*；BF16 checkpoint 被展开 | 没有 BF16 GPU 存储 | FP32 IMPLEMENTED；BF16 MISSING |
| Q+gate/K/V | linear：float product、顺序 float sum、float output | --fmad=false 构建目标下无 BF16 出口舍入 | 不可按 BF16 linear 验收 |
| Q/K norm | float square/sum/mean/sqrt；乘 (1+weight) | head 内归约；全部 FP32，不是 DeltaNet L2/gated RMSNorm | Q/K norm IMPLEMENTED，BF16 出口缺失 |
| Gate split | Q projection 按 [head,2*D] 分半；gate float | gate 原值保留直到 fused kernel | 必须保留 head-local layout |
| RoPE | float powf、angle、cosf/sinf、两乘一加/减 | in-place float；位置=position+t | BF16 cos/sin、mul/add 边界缺失 |
| KV append | float keys/values，[context,KH,D]，D2D | rotated K、未旋转 V；每元素4bytes | BF16 KV MISSING |
| Score | gated_gqa 每个输出特征重复算 dot | float 顺序 dot；scale=float 1/sqrt(D) | 未单独输出 score/scale |
| Causal | visible=past+t+1，仅遍历可见 prefix | 不产生 additive mask tensor | 没有 padding/custom mask API |
| Softmax | 第一遍max；第二遍exp、denom和weighted sum | FP32 expf、sum，最终sum/denom；没有显式 probability buffer | 注释称three-pass，源码是两次score遍历+最终除法；按真实代码描述 |
| AV | sum += unnormalized exp * V，最后除denom | 全float；未将P舍入BF16后再AV | 与 eager BF16不等价 |
| Output gate | 稳定 FP32 sigmoid(gate)，乘float attention | 没有 BF16 sigmoid或乘法出口 | BF16 gate 边界必须单测 |
| O projection | 同一个float linear | 顺序float sum → float | BF16输出缺失 |
| Residual | FullAttentionSession只返回mixer output | 没有input norm/residual加法/MoE | 调用方责任；不在本轮集成 |

FP16 未在此路径使用。无 cuBLAS/cuDNN 调用出现在这些自写 kernel 内，故 Native 顺序 float accumulator 可从源码判断；官方库内部算术仍需区分。

## Prefill、Decode 与 KV 生命周期

prefill 一次 rows>1：三个投影批量算所有 rows；归一化/RoPE 后把全部新KV写入cache；gated_gqa每个query仅访问past+t+1，因此将来token虽然已写入但不可见。decode为rows=1，走同一kernel链；没有独立decode kernel。position必须等于past，不能直接指定与cache长度不同的absolute RoPE origin。

cache一次分配完整context，未清零；合法访问依赖past/visible，未来不能将未写区读入attention。reset只同步并设置past=0/valid=true，不清零cache。BF16新设计需明确“逻辑为空”与“字节为零”的区别，禁止读取旧suffix。当前没有导入非零cache接口；可先通过真实prefix生成非零状态，不应将“非零K/V值”误写为“支持任意cache导入”。

所有操作有session mutex/current-device检查，析构切回owner device并释放；算术/复制异常在try块内将valid=false，reset恢复。输入shape、position、chunk/context、finite检查位于try之前，失败通常不改状态。constructor使用checked spans、budget/free-headroom admission；当前allocator没有像DeltaNet BF16那样分配后再次检查free-headroom，作为新实现需设计验证的差异记录，不修改旧代码。现有trace只输出q/k/v、gate后attention及output，不含raw projections、score、softmax阶段或cache快照；trace没有专门的host字节admission，BF16新probe必须有独立限制，避免T² trace耗尽内存。

单层KV bytes：FP32=2*T*2*256*4=4096T；拟议BF16=2048T。T=2048时分别8MiB/4MiB，此为单层cache理论字节、不是实际总显存或40层预算；权重/工作区/trace另计。

## 官方与 Native 差异摘要

| 位置 | 官方显式 eager BF16 目标（源码语义，待动态trace确认） | Native 当前 | 影响 |
|---|---|---|---|
| Norm | x.float，FP32 norm与1+weight.float，最后一次转BF16 | 全float、无出口转BF16 | 不复制DeltaNet norm规则 |
| RoPE | FP32频率生成→BF16 cos/sin；文本函数BF16 mul、mul、add | float cos/sin和算术 | 不是vision分支FP32 rotate语义 |
| QK/scale | BF16 matmul output→独立BF16 scale output | dot/scale一直float | 出口边界不同 |
| Mask | 通常BF16 additive 0/finfo.min（取决输入mask） | 直接省略未来token | 单测mask及全masked行策略 |
| Softmax | 请求FP32 output→转换BF16概率 | 不存P，float exp分子/denom | probability舍入改变AV |
| AV/gate/O | BF16 AV output、BF16 sigmoid gate/乘法、BF16 O output | float fused AV/gate再float O | 不能只转换最终output |
| KV | DynamicLayer cat存输入K/V dtype，目标为BF16 | float预分配cache | 读取类型与state测试缺失 |

## 缺失能力、风险与门禁

IMPLEMENTED：原生FP32组件及其独立测试源码；PARTIAL：目标架构metadata/owner wrapper；MISSING：Attention BF16 session与逐节点probe、官方Attention专用hash-pinned harness、BF16 KV；UNVERIFIED：实际官方Attention GPU tensor trace、库内部accumulation/softmax topology、BF16误差预算、sanitizer新路径、真实多层/大位置结果。现有DeltaNet官方harness只加载DeltaNet AST，不能直接宣称覆盖Attention。

建议后续建立独立 BF16 Attention session，与旧FP32源码隔离；详见 TEST_PLAN。不得由本审计宣布完整Phase2 PASS，不推进MoE/Decoder/缓存分页/E2E。风险包括隐式选择SDPA、误用vision RoPE、把gate遗漏、把动态cache.reset当成清空长度、全masked行处理差异、近零相对误差和softmax概率舍入放大。

## 起始 Git 证据与关键 SHA256

Git status：

```text
 M docs/reports/QWEN35_MOE_STAGE3_BF16_ACCEPTANCE.md
 M docs/reports/QWEN35_STAGE3_BF16_DTYPE_AUDIT.md
?? artifact/review/qwen35_stage3/source/test/test_qwen35_bf16_rounding.py
?? test/native-construction/test_qwen35_bf16_rounding.py
```

起始 staged diff 为空。未跟踪文件即上面两个rounding测试，均未改写。起始完整 git diff（本轮结束应逐字保持）：

```diff
diff --git a/docs/reports/QWEN35_MOE_STAGE3_BF16_ACCEPTANCE.md b/docs/reports/QWEN35_MOE_STAGE3_BF16_ACCEPTANCE.md
index 9660d450..8f751e82 100644
--- a/docs/reports/QWEN35_MOE_STAGE3_BF16_ACCEPTANCE.md
+++ b/docs/reports/QWEN35_MOE_STAGE3_BF16_ACCEPTANCE.md
@@ -119,3 +119,5 @@ CUDA memcheck 和 initcheck 在宿主机使用已有 `compute-sanitizer` 执行
 本轮再次使用现有 `compute-sanitizer --injection-path /usr/lib/nvidia-cuda-toolkit/compute-sanitizer --target-processes all` 执行 memcheck 和 initcheck：均 exit 255，并报告 `Target application terminated before first instrumented API call`；**UNVERIFIED**，不能计作通过。审查者因无文件读取工具无法独立检查源码；审查 **NOT COMPLETED**。
 
 完整四路 13 节点中间 trace **BLOCKED**；先前 output/core/state/history/beta/decay 的四路结果为 **PARTIAL**。BF16 每节点预算 **PENDING**，长序列 FP32/官方对比 **PARTIAL**；用户态测试 probe 变化并不等于实现 BF16 兼容路径。真实层比较结果见后续记录；所有上述门禁未关闭前，Stage 3 **BLOCKED**，Stage 4 **NOT AUTHORIZED**。
+
+BF16 输入转换的 36 个半 ULP 边界及相邻值（含正负和次正规）在 GPU Torch 与独立 fixture RNE 转换间一致（1 test PASS）；这不构成各中间算子门限。运行期间用户工作区提交更新为 `591699d0`；本任务未创建该提交，任务起始基线仍为 `19cae974`。
diff --git a/docs/reports/QWEN35_STAGE3_BF16_DTYPE_AUDIT.md b/docs/reports/QWEN35_STAGE3_BF16_DTYPE_AUDIT.md
index 8d37d1f7..6e92fcfb 100644
--- a/docs/reports/QWEN35_STAGE3_BF16_DTYPE_AUDIT.md
+++ b/docs/reports/QWEN35_STAGE3_BF16_DTYPE_AUDIT.md
@@ -22,3 +22,5 @@
 ## 本轮门禁核对
 
 基线 `main` / `19cae974`；2026-11-26 宿主机 GPU RTX 4060 Ti、驱动 580.159.03、固定官方 model SHA256 未变。dtype 边界审计 **PARTIAL**：现有 1277 条 tensor 操作 trace 未给出 GPU kernel 内部累加 dtype，也没有覆盖四路所有 13 个中间量；不能据此证明 BF16 原生实现逐舍入兼容。BF16 每节点独立门限保持 PENDING，直到独立参考、足够分布与独立审查完成。
+
+本轮新增 `test/native-construction/test_qwen35_bf16_rounding.py`：36 个正负、次正规/正规及 BF16 tie 和相邻 FP32 位模式，比较 NumPy RNE fixture 转换与 GPU Torch BF16 转换，**1/1 PASS**。该结果只验证参考输入转换，不证明 kernel 内部运算或完整算子舍入语义。
```

| 文件 | 起始 SHA256 |
|---|---|
| backend/platform/cuda/hybrid_attention_cuda.h | `e5a09b86c4b02a0c483db46c1ff547529993ddd94384c56223a839930b394456` |
| backend/platform/cuda/hybrid_attention_cuda.cu | `ba60e46807d84379e6ddf81b76eab1c5ef9e6a28d086f4bf97a55a6398667949` |
| backend/platform/cuda/gated_attention_kernels.cuh | `7c1e5ef1e3aa99904b2803fe06e602fb1bf6dc2bc0000e515c0fc6ce27cbf382` |
| backend/platform/cuda/hybrid_mixer_state.h | `c6ffce32663a317d519aaa92f2c7bc5a3fac356d4622746361bb55ade3671e3b` |
| backend/platform/cuda/hybrid_deltanet_bf16.h | `2d53e35483f1cc2a03858d1df5036f9979b5a2363f722121fd5d3673dfc1273b` |
| backend/platform/cuda/hybrid_deltanet_bf16.cu | `c87ea03d1bf548078c627d08f369f83f9dfb6abd000ddcd1a7f0641040758841` |
| test/native-construction/qwen35_stage2_probe.cu | `881b549f63c81ca604593b973649ac1d27a877e32db9561f3ac4dd509073041f` |
| test/native-construction/test_qwen35_stage2.py | `16a54d6f5d224d8cf7be7a6ecaa771bc4a4f3312748172641e6fbf90ee137387` |
| test/native-construction/qwen35_official_reference.py | `d48e6c652a63b8ceaea8ab0fc3504e7ef0d4d60759cb1cb7abbf56fd3890b61b` |
| scripts/run_cuda_sanitizer.py | `2c69cec35d86f10b84e4e81b08ae7604e853464ea3539010d4c09c96eb3ac614` |
| src/runtime/model/hybrid_config.cpp | `90cf1853c41abe7dc7f3a20e4193aaacdd3040aa9e61c3af3741cc07a1a92709` |
| src/runtime/model/architecture_registry.h | `b7b7f6b2092a21639bfcdcad706773dbf0bf2bd3601ad6b18ede08a249691da5` |
| scripts/check_inference_model.py | `ca7c6a060fcc749717a1d007c60dc7f6a3363d4e70e7eddfda999e6f5d534bf4` |
| backend/platform/cuda/inference_server.s | `a2377ba65f559f5584c53f8abd00bb94bc10a2aeef8288235d56cc2ecb6046c1` |
| makefile | `2161688e13a188170b9eb3611595c60b3226dddbe01751381f80d6d40a46e12b` |
| ../model/Qwen3.6-35B-A3B/config.json | `93a4693fa9d8392fbfccd4b3c9873f4bfdcb14fdede978b123d07d19675efe99` |
| /home/shuwen/.local/lib/python3.12/site-packages/transformers/models/qwen3_5_moe/modeling_qwen3_5_moe.py | `16ef7b0dc6e26eae26a6ffd0ad11d93f85424f90ffb85fbcc9eecc0759cc930d` |
| /home/shuwen/.local/lib/python3.12/site-packages/transformers/models/qwen3_5_moe/configuration_qwen3_5_moe.py | `5053663170053d27610b88ef6a0e06952bb083b572efbb795685f7553521d414` |
| /home/shuwen/.local/lib/python3.12/site-packages/transformers/cache_utils.py | `0d5fd6901ce2b7108eff40e06d7ce29e9b0f9cc8ed2f40d2fb3a2e4d4f43e630` |
| /home/shuwen/.local/lib/python3.12/site-packages/transformers/masking_utils.py | `e8c497af6979274fc6ae78980ad9893e7850bdb750e46d459f09178123992196` |
| /home/shuwen/.local/lib/python3.12/site-packages/transformers/modeling_utils.py | `a7392c26dd2f005383cc3c1f8562638a6039d393ca03fb1933513479a6d264e4` |
| /home/shuwen/.local/lib/python3.12/site-packages/transformers/modeling_rope_utils.py | `a8bf3f6a53760366fb5fa51cecc06a8707d3cded36fd8f3ac51e140c0718af21` |
| /home/shuwen/.local/lib/python3.12/site-packages/transformers/integrations/sdpa_attention.py | `d334e0b1d0c17ac97964348e49e6df681a4193241c8161f23292817ca39e2098` |
| artifact/review/qwen35_stage3/source/test/test_qwen35_bf16_rounding.py | `e5bf3ae0cd743fa977acf1c0d0a1143e3ddb2e2adfa9651614486e88f3ed7e88` |
| test/native-construction/test_qwen35_bf16_rounding.py | `e5bf3ae0cd743fa977acf1c0d0a1143e3ddb2e2adfa9651614486e88f3ed7e88` |
| docs/reports/QWEN35_MOE_STAGE3_BF16_ACCEPTANCE.md | `267307930daaa9ca2d8b1d4b599cb2f995aed8621f62696ac8c99fc52c62ff87` |
| docs/reports/QWEN35_STAGE3_BF16_DTYPE_AUDIT.md | `25ec1591f26fb9ed293095a2a10096dca9983d5598c370cac691f8aa75428b65` |

这些hash覆盖旧Attention、DeltaNet BF16、已有测试、Bridge/Preflight/config和官方依赖。交付检查已复算这些27项hash及额外PyTorch functional.py共28项，HEAD、index、原始git diff和原未跟踪文件均保持；新增路径仅三份报告。报告内保留原始git diff的context空白行，不为whitespace检查改写证据。未hash外部S编译器整个仓库；本轮未执行任何编译器修改/构建命令。

按brainstorming技能执行独立只读builder check，审查者可访问源码并核对文本RoPE、inv_freq、cache reset及score/P/AV/gate边界；提出crop(0)不清空cache的语义澄清，已修正为fresh cache或非空时crop(-L)。未发现其他影响实施规划的重要未答问题。该复核不是CUDA数值/实现验收，未执行inference，仍等待用户第10节要求的人工确认。

