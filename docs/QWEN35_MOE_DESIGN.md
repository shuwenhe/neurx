# 通用混合注意力 MoE Decoder 设计

2026-11-26；**DESIGN REVIEW COMPLETED — WAITING FOR HUMAN APPROVAL**。本次只修订文档，本文不授权实施；数值运行与容差标定仍PENDING。
范围：NeurX 原生 Decoder、C++/CUDA 算子和既有 S 服务接入；不修改外部 S 仓库，不使用外部引擎做正式后端。真实证据见 [架构审计](QWEN35_MOE_ARCHITECTURE_AUDIT.md)，资源规划见 [内存计划](QWEN35_MOE_MEMORY_PLAN.md)，验收见 [差距与阶段](QWEN35_MOE_IMPLEMENTATION_GAP.md)。模块/接口均为拟议，不代表代码存在。

## 目标与候选方案

目标是 reusable hybrid mixer + sparse FFN，在保持现有 dense/Qwen2.5/DeepSeek 路径的基础上，以 Qwen3.6-35B-A3B 为第一个完整文本模型验收；最终命令保持 `make inference CHAT_MODEL_PATH=/home/shuwen/shuwen/model/Qwen3.6-35B-A3B`。多模态、MTP speculative、长上下文262144、多并发和训练不属于首版验收；checkpoint 中这些权重必须完整列入清单，显式标记 not executed，不能假称整套多模态模型已运行。

| 方案 | 代价与收益 | 结论 |
|---|---|---|
| A：通用接口+顺序 recurrence 正确性基线，再分组Q4/专家分页，最后chunk优化 | 最易隔离数学错误；首版prefill慢，但可在受限主机逐步验证 | 推荐，待审批 |
| B：直接实现chunk DeltaNet、融合MoE、异步INT4整条高性能路径 | 早期吞吐潜力更高，但数值、cache、量化、异步多个变量耦合，无法快速定位误差 | 本次不推荐 |
| C：给现有Qwen2.5 Decoder加条件分支 | 改动表面较小，但norm、投影、层状态和权重布局均不同，复用边界失控 | 不采用 |

用户已明确选择原生支持；上述内部路线尚未批准。下面按推荐A展开为可审阅设计，不提前执行计划或开发。

## 1. ModelConfig 与 registry

增加通用 `HybridDecoderConfig`：outer_model_type、text_model_type、hidden/vocab、num_layers、`LayerSpec[]`、normalization policy、position policy、token generation policy、支持dtype/量化format、context runtime limit。`LayerSpec {MixerKind, MixerConfig variant, FfnKind, FfnConfig}`；不能用“每4层”覆盖显式 layer_types。读取嵌套text_config，验证长度40、枚举、尺寸、GQA整除、rotary_dim偶数、expert/topk范围和全局内存预算。新配置允许 hidden2048 与 query width4096不同；不能继承旧 hidden=heads*head_dim 的假设。

`ArchitectureRegistry.resolve(root_config) -> ModelAdapter`，精确匹配外层`qwen3_5_moe`和文本`qwen3_5_moe_text`，适配器负责 `parse_config / build_weight_manifest / validate_capabilities / create_decoder / generation_policy`。未知类型或属性明确失败。旧架构factory保留，各自配置验证隔离；目录型registry可读取capabilities，但不能仅注册名称就声称runtime支持。

拟议实现边界：`src/runtime/model/hybrid_config.*`、`architecture_registry.*`、`mapped_weight_store.*`；`backend/platform/cuda/hybrid_decoder_cuda.*`、独立DeltaNet/attention/MoE kernels与Q4 kernel；NeurX内原生量化工具；既有CUDA bridge只负责factory/session转接。目录职责如下冻结，文件内部拆分可在批准后细化，不需要修改外部编译器。保留现有S/C ABI，使调度、服务、健康检查和生成使用现有主链。

### 拟议工程目录（以下文件不代表已创建）

```text
neurx/
├── backend/platform/cuda/
│   ├── hybrid_decoder_cuda.h
│   ├── hybrid_decoder_cuda.cu
│   ├── gated_deltanet_kernels.cuh
│   ├── gated_attention_kernels.cuh
│   ├── qwen_moe_kernels.cuh
│   └── s_inference_cuda_bridge.cu   # 现有接入点，审批前不修改
├── src/runtime/model/
│   ├── hybrid_config.*
│   ├── architecture_registry.*
│   └── mapped_weight_store.*
├── src/runtime/native/
│   ├── quantization.*
│   └── memory management           # 描述职责，非字面文件名
├── test/native-construction/
└── scripts/
```

CUDA负责算子和Decoder执行；Runtime Model负责配置、架构注册、真实权重映射；Runtime Native负责量化格式/转换逻辑和可复用内存管理（现有quantization.h不等于完整实现）；Test负责独立参考、数值、资源及端到端验收；Scripts只提供原生量化工具的参数/启动入口，核心转换是NeurX原生代码，不是外部推理后端。CUDA专有内存操作通过native memory接口/现有ABI衔接，避免Model parser依赖CUDA。现有Dense、Qwen2.5、DeepSeek路径与能力独立保留。拟议Q4 Kernel可独立放在CUDA目录，其packed格式契约由Runtime Native定义，不能各自发明布局。

## 2. 核心接口、类型与生命周期

```text
Decoder.create_session(context_limit, memory_budget) -> Session
Decoder.prefill(ids, Session&, LogitsMode::Last|All) -> Logits
Decoder.decode(token_id, Session&) -> Logits
Decoder.reset(Session&) / destroy_session(Session&)
Mixer.forward(X[B,S,H], PositionSpan, LayerState&, Workspace&, WeightLease[]) -> Y[B,S,H]
SparseFFN.forward(X[B,S,H], Workspace&, ExpertProvider&) -> Y[B,S,H]
WeightStore.view(name) -> TensorDescriptor(shape,dtype,stride,file,offset,length)
WeightStore.slice(descriptor, expert_id, group_range) -> TensorSlice
Residency.acquire(slices, stream) -> WeightLease{device_ptr,ready_event}
Residency.release_after(lease, compute_event)
```

首版B=1、连续非padding文本、S在顺序prefill中为1，配置context<=2048；拒绝其他batch/mask模式，不能忽略padding。逐层hidden `[B,S,2048]` row-major contiguous；weight `[out,in]`，expert `[E,out,in]`，最后维连续。BF16文件值解码到计算类型；基线激活/累加/softmax/路由/Delta状态FP32。定义独立compatibility数值模式匹配官方BF16边界；FP32激活不声称逐位等同BF16执行。

每个Session绑定model fingerprint、device、owner、position、40个 `variant<FullAttentionState,DeltaState>`；decoder权重只读，workspace首版单请求串行，明确拒绝同时调用，后续session独立workspace。FullState拥有KV和有效长度，DeltaState拥有conv ring、游标、recurrent matrix；初始化全零。token有效性、容量、必要weight leases先验证；全部层成功且CUDA完成事件确认无错误后才提交session.position。若中途CUDA/IO失败，标记session invalid并要求reset，不允许只回退position而留下已更新state。reset清零两类状态并使position=0；销毁等待所有event后释放。首版不支持Delta状态随意截断、KV-only prefix复用或speculative rollback。

## 3. Layer执行顺序与Norm

每层：`r=X; U=OffsetRMSNorm(X); X=r+Mixer(U); r=X; U=OffsetRMSNorm(X); X=r+MoE(U)`。最后OffsetRMSNorm，再 untied LM head。OffsetRMSNorm 为 `x*rsqrt(mean(x²)+eps)*(1+w)`，FP32归约，eps1e-6；不能复用直接乘w的普通RMSNorm。QK norm亦为offset版本。Delta output的gated norm乘w而非1+w，二者必须不同policy/测试。

## 4. Gated DeltaNet

真实形状：输入2048；QKV fused projection8192=`2048(Q)+2048(K)+4096(V)`；z4096、a32、b32。raw QKV先depthwise causal conv kernel4，再SiLU，之后拆分。conv layout `[B,8192,4]`，最旧到最新，与权重tap顺序明确，初始左补零；保存的是conv前raw投影，不是SiLU后的值。z/a/b从归一化输入各自projection，不经此conv。

Q,K reshape `[B,S,16,128]`，V,z `[B,S,32,128]`。Q/K按head重复2次（value head h对应key head floor(h/2)），使用 `q/sqrt(sum(q²)+1e-6)`、k同样归一化，q再乘`1/sqrt(128)`。epsilon在平方和内部，不是对norm做clamp。FP32基线在乘方前转FP32、FP32归约及输出；官方本地fallback源码243/344先对输入dtype执行L2、随后才转换FP32进入recurrence，其BF16中间舍入与融合Kernel是否一致尚未运行验证。因此BF16兼容oracle固定为该hash的纯fallback，后续测试必须记录L2输入/归约/返回的实际dtype与转回BF16位置，禁止把FP32基线当作逐位BF16参考；小范数、全零和BF16舍入边界加入独立验收。不施加RoPE。`beta=sigmoid(b)`，`g=-exp(A_log)*softplus(a+dt_bias)`，exp/softplus FP32且稳定实现。

每value head的state `S[K=128,V=128]` row-major，FP32；每token按顺序：

```text
D = exp(g_t) * S_previous
prediction[v] = sum_k D[k,v] * k_t[k]
delta[v] = beta_t * (v_t[v] - prediction[v])
S_new[k,v] = D[k,v] + k_t[k]*delta[v]
o_t[v] = sum_k S_new[k,v]*q_t[k]
```

必须先衰减再预测，再更新并读取新state；不能简化成KV累加。按128维对o做direct-weight RMSNorm，乘`SiLU(z)`，flatten4096后out_proj到2048。state布局 `[B,32,128,128]`，GPU按head/block和V tile计算，跨k归约；首版允许多个简单Kernel，完成数值再融合。独立CPU FP64/FP32 recurrence为oracle；Kernel测试须输入非零initial_state、长序列、padding拒绝、极端g、chunk边界。

首版prefill顺序使用同一数学recurrence建立基线；优化版chunk64可借鉴官方等价delta-rule，但实现和参考必须独立，跨chunk输出和最终state均对齐。不能只对比最后logit。

### DeltaNet精度契约与参考分层

数学参考M64：同一BF16文件值先精确解码为FP64，投影、conv、L2、门、递推、norm均FP64，显式按k维确定顺序计算；用于数学定义，不宣称是官方BF16执行。M32独立实现相同方程但运算/状态FP32，记录归约顺序并禁用未声明的TF32/fast-math；M64与M32误差先于CUDA标定。CUDA基线FP32与M32对齐；计算顺序改变的fusion另验收，不能混成一组容差。

官方兼容O-BF16固定Transformers 5.15.0与审计记录的文件SHA256 `16ef7b0dc6e26eae26a6ffd0ad11d93f85424f90ffb85fbcc9eecc0759cc930d`。静态dtype顺序如下；R_bf16表示按运行参考的BF16边界舍入，FP32表示张量可见dtype，不把GPU内部累加精度凭空等同于输出dtype。

| 步骤 | O-BF16源码规定的可见dtype/舍入边界 | M32基线区别 |
|---|---|---|
| offset norm与projection | offset norm内部FP32，乘(1+w)后转输入BF16；QKV/z/a/b linear输出BF16 | 输入/输出激活均FP32，BF16权重值解码后参与计算 |
| conv与SiLU | raw QKV传入conv前to(weight.dtype=BF16)，conv结果BF16，SiLU结果BF16；cached conv state沿用BF16 | raw ring与conv/SiLU均FP32 |
| beta/g | b.sigmoid输出BF16；A_log.float().exp，a.float()+dt_bias、softplus与g为FP32 | beta亦FP32；g同为FP32 |
| QK L2 | BF16输入，源码(x*x).sum+eps→rsqrt→x*inv_norm，未显式float；epsilon在sum内部；每个BF16可见结果是R_bf16边界 | 乘方前转FP32，归约/结果FP32；不使用clamp(norm,eps) |
| recurrence入口 | L2之后q/k及v/beta/g显式转FP32；q再乘1/sqrt(128)，initial state转FP32 | 与方程同dtype，避免把beta来源舍入差异隐藏 |
| recurrence主体/出口 | S、prediction/delta、输出累积FP32；返回core output转initial_dtype=BF16，final recurrent state保持FP32 | output保持FP32，S同样FP32 |
| gated norm | core BF16先转FP32归约；归一化结果先转输入BF16再乘BF16 norm.weight；SiLU(z.float())为FP32，与前者相乘后最终转BF16 | direct-weight norm及gate乘法全FP32 |
| out projection/residual/后续层 | out projection BF16输出；残差按BF16张量运算产生BF16结果；最终logits输出边界需与固定官方模型路径trace一起记录 | 残差和LM head logits基线FP32 |

这张表来自源码静态推导，**运行dtype探针、内部归约实现、实际BF16舍入、chunk与recurrent兼容性均PENDING**。未来运行oracle时须锁定torch版本、设备、matmul精度、禁用autocast和动态Kernel替换，检查实际tensor dtype并存trace；模型源码SHA固定并不固定底层torch数值行为。O-BF16 prefill使用官方chunk fallback，单步cached decode使用官方recurrent fallback，二者独立记录；测试不得用生产CUDA算子充当参考，也不能安装依赖后擅自更换该源码。当前不运行/不安装参考框架。

每token输出和S_t均记录maxabs/relative L2/RMSE，最终logits另记录误差/argmax；覆盖长序列累积、非零初state、全零/小范数、g接近0/大负值、连续decode及chunk边界。浮点容差按上述三种参考分别标定，全部为PENDING，未冻结不得PASS，详见差距文档。

## 5. Gated Full Attention 与Partial RoPE

q_proj结果8192 reshape `[B,S,16,512]`，**每head**前256为q、后256为gate；不可把8192简单分成两个4096全局块。k/v投影各512 reshape `[B,S,2,256]`。q/k分别对256维做OffsetRMSNorm，再只对前64维half-split旋转，剩余192维原样保留。频率`theta^(-2*j/64)`，j=0..31，theta1e7；配对位置j与j+32。

纯文本位置T/H/W相同，interleaved MRoPE在这个受限范围化为相同position的partial half-split；未来多模态必须实现真实三轴interleaving，不可宣称此简化覆盖图像。Full KV保存旋转后的K和原V，推荐布局`[B,T,2,256]`；Full Attention为16/2 GQA，q head h映射KV head floor(h/8)。scores=`QK^T/sqrt(256)`，causal mask只允许position<=query position，FP32稳定softmax。attention结果4096逐元素乘sigmoid(gate)，再o_proj `[2048,4096]`。

首版small-context正确性Kernel可借鉴旧GQA，但新Kernel须独立支持q宽度、64 rotary、QK norm、门控。后续采用分块online-softmax避免shared memory随context线性膨胀；不沿用旧Kernel动态shared scores去承诺262144。

## 6. Qwen MoE

归一化输入的router logits=`X @ Wgate^T`，shape `[B*S,256]`。FP32 softmax，top8，selected probs重新归一化，返回ID与FP32权重。精确ties定义index升序作为NeurX稳定策略，独立数学oracle采用同一规则；非tie要求ID完全一致。若第8/9名并列，官方topk可能选中不同expert，因expert函数不同，即使概率相同输出也未必相同。此时单列兼容性差异，用固定selected IDs比较FFN/combine，不得假称集合或最终输出必然等价；官方兼容性主数据集避免边界tie但保留单独tie测试。禁止DeepSeek的不同scale或balance bias混入。

融合gate_up `[256,1024,2048]` 每expert第一512行是gate、后512行是up；down `[256,2048,512]`。`expert(X)=Wdown*(SiLU(Wgate*X)*(Wup*X))`，按top8权重加和。shared expert同样SwiGLU512，乘`sigmoid(X @ shared_expert_gate^T)`后加到routed sum；shared不占top8，也不参与路由归一化。

首次decode顺序dispatch8个expert，FP32 accumulator，稳定combine顺序；后续prefill按expert聚合token，gather/scatter必须保留token ID与slot权重，禁止capacity截断丢token。调度可复用E4思路，但权重slice、gated shared与元信息需新实现。为降低传输，路由可在GPU计算后仅传8个ID/权重；首版CPU Top-K则明确计入同步成本。不能通过把“活跃3B”当作总权重省略其余专家。

## 7. Loader、映射与量化

使用独立可复用的read-only mapped store，从E4抽取并加强校验，不改旧路径语义。先读index与headers，不读取全部payload。验证安全相对路径、dtype、shape*itemsize溢出、offset/范围/重叠、重复键、index与shard一致及required tensors。manifest应覆盖全部1045 tensor，但首版执行text 693 tensors（611 other+80expert+2 embed/head）；MTP/vision在manifest明确标记。架构adapter提供prefix映射与精确shape；不能移除qwen preflight来试探加载成功。

新增expert slice：slice byte offset=`tensor_data_start + expert_id*out*in*itemsize`，gate/up在expert slice内分段；只为当前expert取得数据。原模型BF16不修改。新Q4 sidecar另存group128沿in轴的signed nibble与FP16scale；group不跨row/expert，round-to-nearest-even、clamp[-7,7]、全零group scale=1、拒绝NaN/Inf、低nibble为偶数column、高nibble奇数column，signed4二补码。元数据version和checksum强校验。第一个CUDA W4A32 GEMV直接解包乘FP32 scale/activation累加，禁止把整层256专家反量化；性能版W4A16另行验收。

norm、router、A_log/dt_bias、conv、shared expert和其余text先保留BF16存储，计算按policy；量化仅主routed专家。严格分开三类误差：量化权重重建误差Qerr、同一重建权重的CUDA计算误差Kerr、完整模型相对未量化oracle的质量损失ModelLoss；参考与验收定义见差距文档，三者不能相互替代。需要更高精度的敏感专家可在预算内以BF16补救，但不得提前承诺Q4质量。

### Q4E-v1量化格式与公式（拟议契约）

只用于主routed experts，逻辑W[E,O,I] row-major，group_size=128沿I轴，不跨row/expert。本模型I均可整除128；v1对不可整除shape明确拒绝，padding扩展需新版本。对每group，BF16值精确转FP32后先拒绝NaN/Inf，m=max(abs(W))。

```text
if m == 0:
    s16 = FP16(1); q[i] = 0
else:
    s_ideal = FP32(m / 7)
    s16 = round_to_nearest_even_FP16(s_ideal)
    require isfinite(s16) and s16 > 0
    s = FP32(s16)
    q[i] = clip(round_to_nearest_even_FP32(W[i] / s), -7, 7)
W_reconstructed[i] = FP32(q[i]) * FP32(s16)
```

原始建议公式scale=maxabs/7在FP16存储时会再次舍入；v1明确**使用已存储scale的FP32值计算q**，保证转换和重建使用同一个scale。非零group若scale转FP16为0或Inf则拒绝并报告tensor/expert/row/group，不能默默把零scale当1；本模型是否触发仍PENDING。scale乘法重建为FP32，不展开为常驻全模型。量化误差包括scale舍入和q取整/截断，不只是4bit取整。

q取值[-7,7]，二补码低4bit存储；-8 nibble为保留非法码，reader拒绝。byte = (q_even & 0xF) | ((q_odd & 0xF)<<4)，低nibble偶数column、高nibble奇数column；CPU/CUDA都先取nibble n，再以n>=8?n-16:n符号扩展，不依赖signed shift。packed布局[E,O,I/2] U8；scales布局[E,O,I/128] IEEE754 FP16 little-endian，最后group维连续；两数组独立范围，偏移/长度/对齐由manifest明确记录。零点固定0且不占存储，无激活/KV量化含义。

metadata version=`Q4E-v1`，记录源checkpoint及tensor fingerprint、源BF16 shape/dtype、E/O/I、group轴与大小、packed/scales stride和byte order、RNE/clamp/zero policy、低高nibble顺序、有效范围、每payload和scale段SHA256、manifest canonical字段checksum。manifest校验和对去掉自身checksum字段后key排序、UTF-8无空白的序列化计算，避免自引用。错版本/损坏/shape/源hash不符均拒绝，不能按文件名自动信任。离线转换后与首次激活前完成hash校验；runtime读错误显式失败，模型文件始终只读。

测试分离：Qerr比较原始BF16与CPU重建值（按tensor/group/expert记录maxabs/RMSE/relative L2和scale误差）；Kerr以同一重建值和输入比较独立CPU与CUDA结果；ModelLoss比较完整Q4与未量化oracle的逐层hidden/logits/argmax/PPL。CPU/CUDA字节解包必须exact，浮点重建/算子容差和模型质量阈值仍PENDING。FP16 scale开销2/128 bytes/parameter已纳入20.029168GiB预算。

## 8. Offloading与状态管理

采用内存文档的约20.03GiB文本混合权重方案：非专家优先常驻GPU，专家cache默认目标7GiB、由动态准入下调，首版不自动升至8GiB，余下mmap/可回收CPU页，冷页从NVMe读取。copy/compute stream与事件保护lease，GPU eviction不能复用尚在执行的指针。转换器和artifact均在NeurX内，不安装依赖、不借外部引擎运行。

拟议 `GpuMemoryAdmissionController.admit(config, session, measured_free, workspace_plan) -> Reservation{cache_cap, state_bytes, workspace_bytes, headroom}`；算法与理论/实测区分以[内存计划](QWEN35_MOE_MEMORY_PLAN.md)为单一依据，cache默认目标7GiB且动态向下取整，不是固定保证。session admission包括KV、Delta state和workspace；每增加session线性增加状态，首版限制1个。CPU cache不无限pin，无足够RAM时降低resident上限或明确拒绝，不能依赖8GiB swap承受64GiB BF16匿名数组。

## 9. Prefill、Decode、Token Generation

prefill token序列逐token运行40层，复用状态；Last logits只为最后position执行LM head，All模式只在小规模trace测试打开。新token位置等于session.position，全部层完成后递增。decode完全相同step，支持已有状态继续生成。优化版chunk必须保证split-prefill与整段prefill最终两类state一致。

原生BPE复用前先验证中文、emoji、单数字切分、空白、special token；原生模板renderer按真实jinja支持system/user/assistant多轮和enable_thinking=false/true，并对超范围tools/multimodal功能显式拒绝，不能默默采用简化模板。官方源码/分词器只作测试oracle，不作生产运行依赖。

首版确定性greedy，generation EOS集合248046/248044，tokenizer不自动BOS，停止token不显示到用户文本。超出tokenizer可解码ID时不得捏造内容，需明确定义为不可显示ID并报告/测试；不得擅自mask logits破坏数值对齐。默认采样策略后续按generation_config完整实现并记录seed。多轮初版可完整重放历史获得正确状态；缓存增量追加仅在模板token prefix精确一致时允许，禁止同一对话重复prefill历史。

## 10. 审批、风险与实施边界

原生hybrid Decoder、CUDA+S/C ABI、Q4专家与CPU mmap/GPU cache技术路线由用户明确；推荐A的分阶段实现、初版text-only/B1/context2048/greedy及具体精度/资源策略仍等待完整设计审批。未确定的数值容差、质量、实际吞吐和cache命中率均标记PENDING，通过差距文档的标定与客观门禁解决，不靠猜测。完整BF16大模型oracle在此32GiB主机需有界stream实现或另获授权的参考硬件，不能先加载64.56GiB BF16到RAM。独立测试参考允许离线实现，不引入正式框架后端。参考执行也必须受RAM预算约束：M32按层流式读取；O-BF16测试harness可逐层构造固定官方模块、加载该层BF16权重并释放上层临时对象，不能调用会一次性驻留完整模型的from_pretrained路径。oracle层构造峰值、torch依赖版本及可用硬件仍PENDING；若无法获得准确官方边界或受资源限制则标BLOCKED，不能以近似oracle宣称官方兼容。所有harness后续只在NeurX内实现，不修改官方或外部S源码。

只有本设计获明确批准后才编写实施计划、修改产品/Makefile/preflight、创建依赖或算子。preflight对新架构的拒绝须保留至完整40层、prefill/decode与独立数值验收通过，届时以真实capability检测替代拒绝，不是绕过。现有模型回归必须继续通过。

前次审阅记录（不等同本轮完整复核）：独立审阅代理无法读取完整文件，因此仅对传入的关键设计摘录做了技术复核；未发现容量或核心公式计算错误，提出8GiB cache余量与L2精度边界两项问题，已按上文收紧。此记录不冒充完整文档审阅或模型测试。作者另检查四份文档的相互链接、真实40层shape、参数分类和审批边界。

本轮最终复核：四份原文档已交叉修订；未创建产品文件或实施计划。架构和容量有模型header证据，BF16实际dtype/浮点容差/量化质量/资源峰值/吞吐仍PENDING，不将设计一致性当运行验收。状态：**DESIGN REVIEW COMPLETED — WAITING FOR HUMAN APPROVAL**。
