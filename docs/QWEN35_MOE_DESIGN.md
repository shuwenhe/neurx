# 通用混合注意力 MoE Decoder 设计

2026-11-26；**DRAFT，待人工审批。本文不授权实施。**
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

拟议实现边界：`src/runtime/model/hybrid_config.*`、`architecture_registry.*`、`mapped_weight_store.*`；`backend/platform/cuda/hybrid_decoder_cuda.*`、独立DeltaNet/attention/MoE kernels与Q4 kernel；NeurX内原生量化工具；既有CUDA bridge只负责factory/session转接。路径可由实施者在NeurX内细化，不需要修改外部编译器。保留现有S/C ABI，使调度、服务、健康检查和生成使用现有主链。

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

每个Session绑定model fingerprint、device、owner、position、40个 `variant<FullAttentionState,DeltaState>`；decoder权重只读，workspace首版单请求串行，明确拒绝同时调用，后续session独立workspace。FullState拥有KV和有效长度，DeltaState拥有conv ring、游标、recurrent matrix；初始化全零。token有效性、容量、必要weight leases先验证；全部层成功才提交session.position。若中途CUDA/IO失败，标记session invalid并要求reset，不允许只回退position而留下已更新state。reset清零两类状态并使position=0；销毁等待所有event后释放。首版不支持Delta状态随意截断、KV-only prefix复用或speculative rollback。

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

## 5. Gated Full Attention 与Partial RoPE

q_proj结果8192 reshape `[B,S,16,512]`，**每head**前256为q、后256为gate；不可把8192简单分成两个4096全局块。k/v投影各512 reshape `[B,S,2,256]`。q/k分别对256维做OffsetRMSNorm，再只对前64维half-split旋转，剩余192维原样保留。频率`theta^(-2*j/64)`，j=0..31，theta1e7；配对位置j与j+32。

纯文本位置T/H/W相同，interleaved MRoPE在这个受限范围化为相同position的partial half-split；未来多模态必须实现真实三轴interleaving，不可宣称此简化覆盖图像。Full KV保存旋转后的K和原V，推荐布局`[B,T,2,256]`；Full Attention为16/2 GQA，q head h映射KV head floor(h/8)。scores=`QK^T/sqrt(256)`，causal mask只允许position<=query position，FP32稳定softmax。attention结果4096逐元素乘sigmoid(gate)，再o_proj `[2048,4096]`。

首版small-context正确性Kernel可借鉴旧GQA，但新Kernel须独立支持q宽度、64 rotary、QK norm、门控。后续采用分块online-softmax避免shared memory随context线性膨胀；不沿用旧Kernel动态shared scores去承诺262144。

## 6. Qwen MoE

归一化输入的router logits=`X @ Wgate^T`，shape `[B*S,256]`。FP32 softmax，top8，selected probs重新归一化，返回ID与FP32权重。精确ties定义index升序作为NeurX稳定策略；与参考topk顺序可能不同，tie用集合/总输出比较，非tie要求ID完全一致。禁止DeepSeek的不同scale或balance bias混入。

融合gate_up `[256,1024,2048]` 每expert第一512行是gate、后512行是up；down `[256,2048,512]`。`expert(X)=Wdown*(SiLU(Wgate*X)*(Wup*X))`，按top8权重加和。shared expert同样SwiGLU512，乘`sigmoid(X @ shared_expert_gate^T)`后加到routed sum；shared不占top8，也不参与路由归一化。

首次decode顺序dispatch8个expert，FP32 accumulator，稳定combine顺序；后续prefill按expert聚合token，gather/scatter必须保留token ID与slot权重，禁止capacity截断丢token。调度可复用E4思路，但权重slice、gated shared与元信息需新实现。为降低传输，路由可在GPU计算后仅传8个ID/权重；首版CPU Top-K则明确计入同步成本。不能通过把“活跃3B”当作总权重省略其余专家。

## 7. Loader、映射与量化

使用独立可复用的read-only mapped store，从E4抽取并加强校验，不改旧路径语义。先读index与headers，不读取全部payload。验证安全相对路径、dtype、shape*itemsize溢出、offset/范围/重叠、重复键、index与shard一致及required tensors。manifest应覆盖全部1045 tensor，但首版执行text 693 tensors（611 other+80expert+2 embed/head）；MTP/vision在manifest明确标记。架构adapter提供prefix映射与精确shape；不能移除qwen preflight来试探加载成功。

新增expert slice：slice byte offset=`tensor_data_start + expert_id*out*in*itemsize`，gate/up在expert slice内分段；只为当前expert取得数据。原模型BF16不修改。新Q4 sidecar另存group128沿in轴的signed nibble与FP16scale；group不跨row/expert，round-to-nearest-even、clamp[-7,7]、全零group scale=1、拒绝NaN/Inf、低nibble为偶数column、高nibble奇数column，signed4二补码。元数据version和checksum强校验。第一个CUDA W4A32 GEMV直接解包乘FP32 scale/activation累加，禁止把整层256专家反量化；性能版W4A16另行验收。

norm、router、A_log/dt_bias、conv、shared expert和其余text先保留BF16存储，计算按policy；量化仅主routed专家。量化误差和实现误差分开：CPU用同一Q4重新构造reference定位Kernel误差；全模型BF16 oracle用于质量损失评估。需要更高精度的敏感专家可在预算内以BF16补救，但不得提前承诺Q4质量。

## 8. Offloading与状态管理

采用内存文档的约20.03GiB文本混合权重方案：非专家优先常驻GPU，专家首次验收7GiB有界cache，8GiB仅在完整峰值实测后按admission启用，余下mmap/可回收CPU页，冷页从NVMe读取。copy/compute stream与事件保护lease，GPU eviction不能复用尚在执行的指针。转换器和artifact均在NeurX内，不安装依赖、不借外部引擎运行。

session admission包括KV、Delta state和workspace；每增加session线性增加状态，首版限制1个。CPU cache不无限pin，无足够RAM时降低resident上限或明确拒绝，不能依赖8GiB swap承受64GiB BF16匿名数组。

## 9. Prefill、Decode、Token Generation

prefill token序列逐token运行40层，复用状态；Last logits只为最后position执行LM head，All模式只在小规模trace测试打开。新token位置等于session.position，全部层完成后递增。decode完全相同step，支持已有状态继续生成。优化版chunk必须保证split-prefill与整段prefill最终两类state一致。

原生BPE复用前先验证中文、emoji、单数字切分、空白、special token；原生模板renderer按真实jinja支持system/user/assistant多轮和enable_thinking=false/true，并对超范围tools/multimodal功能显式拒绝，不能默默采用简化模板。官方源码/分词器只作测试oracle，不作生产运行依赖。

首版确定性greedy，generation EOS集合248046/248044，tokenizer不自动BOS，停止token不显示到用户文本。超出tokenizer可解码ID时不得捏造内容，需明确定义为不可显示ID并报告/测试；不得擅自mask logits破坏数值对齐。默认采样策略后续按generation_config完整实现并记录seed。多轮初版可完整重放历史获得正确状态；缓存增量追加仅在模板token prefix精确一致时允许，禁止同一对话重复prefill历史。

## 10. 审批、风险与实施边界

推荐A、初版text-only/B1/context2048/greedy/FP32数学基线+BF16兼容参考/Q4 routed experts/CPU mmap是设计者建议，等待用户批准。未确定的质量、实际吞吐和cache命中率通过差距文档的客观门禁解决，不靠猜测。完整BF16大模型oracle在此32GiB主机需有界stream实现或另获授权的参考硬件，不能先加载64.56GiB BF16到RAM。独立测试参考允许离线实现，不引入正式框架后端。

只有本设计获明确批准后才编写实施计划、修改产品/Makefile/preflight、创建依赖或算子。preflight对新架构的拒绝须保留至完整40层、prefill/decode与独立数值验收通过，届时以真实capability检测替代拒绝，不是绕过。现有模型回归必须继续通过。

审阅记录：独立审阅代理无法读取完整文件，因此仅对传入的关键设计摘录做了技术复核；未发现容量或核心公式计算错误，提出8GiB cache余量与L2精度边界两项问题，已按上文收紧。此记录不冒充完整文档审阅或模型测试。作者另检查四份文档的相互链接、真实40层shape、参数分类和审批边界。
