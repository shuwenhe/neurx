# Full Attention BF16 官方参考分析

日期：2026-11-27（Asia/Shanghai）。Git 基线：`a56388ea6ebd598f26016783e20a071821c703a2`，核心历史提交 `9e8dd875`、`a56388ea` 均保留。本轮只读分析已有源文件与环境，唯一交付写入为这三份报告；没有编写/执行新 Attention probe，没有修改生产代码、现有测试、Bridge、Preflight、外部编译器或历史证据，也不提交/重写 Git 历史。

本阶段状态：**审计与设计已形成，待人工确认；Full Attention BF16 实现/数值验收 UNVERIFIED，完整 Phase 2 仍 BLOCKED。** P0 历史 PASS 不能推广为 Attention BF16 PASS。本次没有重跑历史测试，历史 11/11/16/16 等仅是上轮证据。

参考环境只读检查：Transformers distribution 5.15.0；固定 Torch 2.6.0+cu124，Torch CUDA 12.4，cuDNN 90100；GPU NVIDIA GeForce RTX 4060 Ti，驱动 580.159.03，nvcc 12.0.140，Compute Sanitizer 2022.4.1。宿主机检查时 VRAM 1507/16380 MiB（含检查进程约120 MiB），不是推理显存峰值。参考子进程调用既有 configure_runtime 设置 highest、TF32=False、BF16 reduced precision reduction=False、deterministic=True、autocast/compile=False；未运行 forward。普通沙箱仍无 GPU 访问，后续 CUDA 验收必须在宿主机执行。

官方文件目录：`/home/shuwen/.local/lib/python3.12/site-packages/transformers/`。checkpoint config 的 transformers_version=4.57.1 是序列化元数据，不能替代此次实际 distribution/source 版本；远端模型发布版本/commit 与本地目录名称“Qwen3.6”的来源对应关系未独立证明，参考由本地架构和文件哈希界定。

## 版本、来源及检查文件

固定本地 `modeling_qwen3_5_moe.py`，SHA256 **16ef7b0dc6e26eae26a6ffd0ad11d93f85424f90ffb85fbcc9eecc0759cc930d**。distribution 5.15.0 与该哈希共同界定参考，不把版本号当源码身份；未核实上游 Git commit/远程 checkpoint revision。读取同目录configuration、cache_utils、masking_utils、modeling_utils、modeling_rope_utils、integrations/sdpa_attention.py；生产 Native 调用链是 Stage2 probe→FullAttentionSession→gated_attention_kernels，自写FP32，不经过本官方库。详见 ARCHITECTURE_AUDIT。

| 固定参考文件 | SHA256 |
|---|---|
| models/qwen3_5_moe/modeling_qwen3_5_moe.py | `16ef7b0dc6e26eae26a6ffd0ad11d93f85424f90ffb85fbcc9eecc0759cc930d` |
| models/qwen3_5_moe/configuration_qwen3_5_moe.py | `5053663170053d27610b88ef6a0e06952bb083b572efbb795685f7553521d414` |
| cache_utils.py | `0d5fd6901ce2b7108eff40e06d7ce29e9b0f9cc8ed2f40d2fb3a2e4d4f43e630` |
| masking_utils.py | `e8c497af6979274fc6ae78980ad9893e7850bdb750e46d459f09178123992196` |
| modeling_utils.py | `a7392c26dd2f005383cc3c1f8562638a6039d393ca03fb1933513479a6d264e4` |
| modeling_rope_utils.py | `a8bf3f6a53760366fb5fa51cecc06a8707d3cded36fd8f3ac51e140c0718af21` |
| integrations/sdpa_attention.py | `d334e0b1d0c17ac97964348e49e6df681a4193241c8161f23292817ca39e2098` |
| /home/shuwen/shuwen/neurx/artifact/reference-env/lib/python3.12/site-packages/torch/nn/functional.py | `724c30072ca0cb69228553a636b2937ff88b60a2a2c80b806bd2a3827033e2b6` |

官方 Attention 相关源码锚点：TextRotaryEmbedding 85–165；rotate_half 544–548；**文本** apply_rotary_pos_emb 552–587；repeat_kv 590–599；eager_attention_forward 602–624；Attention 627–701；RMSNorm 801–818；DecoderLayer 821–877；TextModel.forward 约1255–1315。这些源码已读，尚未对 Attention 执行动态probe；以下用 SOURCE 标明源码/API推导，不能写成 OBSERVED_GPU。DeltaNet harness 的既有 AST selections 未包含 Attention/文本RMSNorm/RoPE/eager helpers，后续需独立参考加载器，不能声称复用旧5/5即获得Attention参考。

## 选择具体参考后端

Attention.forward 调用 ALL_ATTENTION_FUNCTIONS.get_interface(config._attn_implementation, eager_attention_forward)。因此“官方”不唯一：eager显式softmax与P，SDPA/Flash可能融合且有不同内部边界。建议**明确固定 eager、eval、dropout0**作为首个规范。禁止依赖默认backend、静默回退或用SDPA结果证明eager内部边界；SDPA仅作为独立未来对比，不能混入同一budget。

建议后续固定原AST函数体，只移除与执行无关且明示的装饰器，保留所有数学代码，显式绑定eager interface、真实DynamicLayer、文本RoPE。记录每个AST哈希、removed decorator名单、依赖文件哈希、backend标识及运行环境。不得以手写近似函数冒充官方；独立FP64数学oracle可用作校准，但只作补充参考，不是CUDA验收。

## 完整计算图与源码可见的舍入边界

目标为 BF16 hidden_states、BF16 weights、BF16 cos/sin、BF16 additive mask 的显式eager路径。不同dtype的外部position_embeddings/mask会改变类型提升，必须在harness明确拒绝或单独列为case。

```text
X_BF16
 ├─ linear(Wqg) → QG_BF16 → view[Hq,2D] → Q_BF16 + gate_BF16
 ├─ linear(Wk)  → K_BF16
 └─ linear(Wv)  → V_BF16
Q/K → float RMSNorm + (1+weight.float) → cast BF16
positions / inv_freq.float → FP32 frequencies/cos/sin → cast BF16
Q/K前R维: BF16 mul + BF16 rotated-half mul + BF16 add; tail保持
rotated K_BF16 / V_BF16 → DynamicLayer.cat KV → repeated/grouped KV
Q_BF16 @ K_BF16.T → score_BF16
score_BF16 * scale(Python float) → scaled_BF16
+ additive mask_BF16 → masked_BF16
softmax(dtype=float32): masked转FP32 → FP32结果
→ cast probability_BF16 → [eval dropout0]
P_BF16 @ V_BF16 → AV_BF16
sigmoid(gate_BF16) → sigmoid_BF16
AV_BF16 * sigmoid_BF16 → gated_BF16
linear(Wo_BF16) → O_BF16
返回mixer输出；外层Decoder才执行residual + output
```

上述BF16算术出口来自Torch普通dtype规则与未compile/未fuse的API调用，尚待逐opdispatch确认；不是承诺每条硬件指令都在BF16。FP16不属于本次目标。

| 节点 | SOURCE输入→输出与边界 | 本轮证据限制 |
|---|---|---|
| Q/K/V/O Linear | BF16×BF16→BF16可见tensor | GEMM内部accumulator、split-K、FMA/reduction tree **UNVERIFIED**；不能从输出dtype推断 |
| Q/K RMSNorm | x→FP32，平方mean+eps/rsqrt/乘x，全FP32；乘1+weight.float后，最后转回BF16 | 与DeltaNet“norm先BF16再weight”不同；归约拓扑及rsqrt误差UNVERIFIED |
| 频率/三角函数 | inv_freq FP32，position.float，autocast禁用，FP32matmul/cos/sin，最后转x.dtype | 目标cos/sin BF16；内层库细节UNVERIFIED，需在module.to(BF16)后核实inv_freq buffer是否曾被降精度 |
| 文本RoPE | q_rot*cos、rotate_half(q_rot)*sin、再add；输入均BF16时各tensor出口BF16；pass维拼接不运算 | **文本函数没有q.float()/cos.float()**；vision helper才显式float，不能引用错分支 |
| QK Score | matmul后产生BF16 score，之后单独scale | score内部accumulation与Tensor Core选择UNVERIFIED |
| Scale | head_dim**-0.5 Python float；BF16 score乘scalar后保持BF16 | D=256恰为1/16，其他D需记录scale转换与舍入，不能只测256 |
| Mask | create_causal_mask走eager_mask时dtype=inputs_embeds.dtype，true→0、false→finfo(dtype).min；加法另一个tensor出口 | 用户传FP32/4D custom mask可能提升为FP32，不能一概称BF16；须固定mask contract |
| Softmax | nn.functional.softmax(...dtype=FP32)，PyTorch functional.py的API说明输入先cast到dtype；随后.to(query.dtype)→BF16 P | FP32计算语义可由API确定；具体max/exp/sum/reduction tree、exp近似与融合实现 **UNVERIFIED** |
| AV | BF16 P @ BF16 V → BF16 AV；随后transpose/view保持值 | 内部accumulation与reduction order **UNVERIFIED**，不能照搬DeltaNet设定 |
| Gate | torch.sigmoid(BF16 gate)→BF16；再BF16乘AV→BF16 | 数学内部exp精度UNVERIFIED，边界待dispatch；不能忽略这个模块 |
| Cache | rotated K与V传入update，DynamicLayer初始化dtype=key.dtype，torch.cat后返回原dtype（同dtype输入时） | 目标BF16存/读；本轮未运行cache dtype探针；dtype不一致可能发生类型提升，必须约束 |
| Residual | DecoderLayer在mixer返回后才residual+hidden_states；均BF16时加法出口BF16 | 不在Attention内部；本轮仅定义接口，不实现完整layer/MoE |

注意频率buffer风险：TextRotaryEmbedding初始化inv_freq为FP32，但外部Module.to(dtype)可能改浮点buffer后再.float不能恢复丢失bit。官方模型实际加载策略与isolated oracle构造顺序都应记录（先构造/迁移device、是否统一toBF16、state_dict buffer是否持久），后续trace须测inv_freq原始bits；不提前断言所有BF16模型加载都保留同一FP32 inv_freq。

## Softmax规范与可见性

明确API数学语义为softmax(logits_float32)后再转BF16，而不是对未舍入FP32 score直接归一化，也不是把未归一化exp权重一直留FP32做AV后才除sum。底层稳定算法通常涉及max/exp/sum/normalize，但源码这一调用没有暴露中间buffer；不能伪称dispatch已捕获这些内部值。后续需两套证据：原官方完整F.softmax结果作最终oracle；独立分解max/subtract/exp/sum/divide FP32数学probe作诊断。分解实现不是官方内核内部trace，二者差异按独立冻结预算评价。

默认mask使用有限finfo.min；这与直接跳过未来token在常见未全masked行可能等效，但不是所有输入上等价。全masked行、NaN/Inf score、padding/custom mask必须单列；不得用“softmax一定输出零”作未经证实的断言。首版建议拒绝全masked query行，验证发生在cache mutation前；官方对该输入的观察结果另记录，不修改官方以迎合native。

## KV与文本位置

官方TextModel对纯文本默认position使用past_seen_tokens+arange，扩展T/H/W三轴；三轴相同时interleaved MRoPE化为一维文本RoPE。mask query offset与RoPE absolute position虽常相等，语义并不相同，测试必须分开。仅第一R=64维旋转，cache保存的是旋转后的K，读取时不得再次旋转；V不旋转。repeat_kv逻辑不改变值与dtype，物理cache仍只需KH=2头。

DynamicLayer.update按[-2]序列维cat。重要差异：此固定cache_utils.py中DynamicLayer继承CacheLayerMixin.reset，zero_已有keys/values，但get_seq_length返回tensor.shape[-2]；仅调用cache.reset不必然等于“空长度0”。后续规范中的逻辑清空参考应重建新的DynamicLayer/Cache；如必须复用非空对象，先取L=get_seq_length()，仅在L>0时调用crop(-L)并验证长度0。**crop(0)在此固定版本中直接返回，不会清空cache。** 单列官方reset保留形状的观察，不将Native past=0与官方zero_混同。此为源码分析，尚未执行动态cache验证。

## 方案、缺失项及门禁

首个方案建议显式eager逐节点参考+独立BF16 native correctness path；融合优化/SDPA后端属于另一方案，可减少scratch但无法直接暴露所有边界，留到规范冻结与正确性通过之后。

此轮完成的是源码语义清单；**Attention GPU dtype trace、GEMM/AV内部累加、FP32 softmax内部归约/exp误差、inv_freq构造细节、cache运行dtype、独立预算冻结均未完成**。这些UNVERIFIED不能靠DeltaNet结果填补。动态参考验证及budget冻结是下一轮实现前置门禁；测得不符必须修正规范并重新人工确认，不能改oracle或从native误差反推门限。测试矩阵、最小顺序与预期文件见TEST_PLAN，代码与权重基线见ARCHITECTURE_AUDIT。

