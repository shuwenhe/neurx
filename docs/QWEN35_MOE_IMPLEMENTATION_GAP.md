# 实现差距、实施阶段与验收门禁

2026-11-26；**DESIGN REVIEW COMPLETED — WAITING FOR HUMAN APPROVAL**。当前只完成审计、设计与文档复核。下列为设计级路线与验收建议，**不是已批准实施计划**。证据E编号见 [审计](QWEN35_MOE_ARCHITECTURE_AUDIT.md)，详细接口见 [设计](QWEN35_MOE_DESIGN.md)。

## 可以复用与必须新增

| 模块 | 可复用 | 必须新增/改造 | 当前证据与状态 |
|---|---|---|---|
| 服务入口 | S服务、HTTP健康检查、进程清理、生成会话边界 | 通用Decoder factory转接和会话state variant | E1/E3/E12，PARTIAL |
| Config/registry | JSON parser、旧adapter保持 | 嵌套text_config、layer_types、能力注册、shape规则 | E3/E6，PARTIAL |
| Loader | E4 mmap、bounds校验、BF16读取 | 通用mapped store、3D expert slice、manifest、Q4 sidecar | E4/E6，PARTIAL |
| GPU基础 | RAII buffer、device枚举、同步传输 | 有界pinned双缓冲、event lease、异步专家缓存 | E7基础IMPLEMENTED，调度PARTIAL |
| 普通attention | GQA与half-split思路、测试结构 | q/gate head内split、QK offset norm、partial64 RoPE、sigmoid gate | E4/E8，目标算子MISSING |
| DeltaNet | 通用matvec/SiLU/归约思路 | conv、L2 norm、衰减delta recurrence、gated norm、状态 | E3/E4/E5，MISSING |
| MoE | DeepSeek topk/FFN/combine控制流 | Qwen router精度、融合expert张量、shared gate、dispatch映射 | E4/E10，PARTIAL |
| Quantization | 概念、格式经验 | 可验证group128 packed Q4转换器和CUDA W4A32 | E11，UNVERIFIED |
| Tokenizer | ICU BPE、special token查找 | Qwen3.6模板、双EOS、未分配ID策略与多轮精确对齐 | E12，PARTIAL |
| 测试 | 独立NumPy参考结构与CUDA probe模式 | 新架构算子/40层/真实模型/资源测量门禁 | E8/E9，目标MISSING |

## 第一版最小可运行目标

在现有4060Ti16GB/约32GB RAM上，以真实全部40层文本Decoder执行中文/英文短prompt，B=1，context<=2048，greedy连续生成至少32个token（遇EOS可提前结束），支持双EOS、reset和两轮文本对话；新架构所有权重映射、30个DeltaNet和10个gated full attention及40个MoE均参与。Q4主routed专家+BF16非专家+CPU mmap/GPU cache确保预算；不实现vision/MTP，但其权重清单完整、输入明确拒绝。真logits与独立参考必须通过以下门禁，不能以输出像人话代替。

## 数值标准：参考、测试定义与 PENDING 门禁

当前新架构算子、完整模型和Q4均未执行数值测试，**所有浮点容差、质量阈值和吞吐阈值均为 PENDING**。撤回前版未经实测的rtol/atol、cosine、argmax百分比及PPL增幅阈值；它们不是可执行的既定通过标准。数学语义、形状、格式、错误处理等exact不变量可以现在冻结；浮点门槛必须按参考实现、dtype、归约/融合顺序和序列长度标定并独立审查后冻结，不能用被测实现自身误差反向定义合格线。

参考分三层：M64独立CPU FP64数学定义；M32独立CPU FP32递推（不调用被测CUDA）；O-BF16固定Transformers 5.15.0官方纯fallback，源文件SHA256=`16ef7b0dc6e26eae26a6ffd0ad11d93f85424f90ffb85fbcc9eecc0759cc930d`。O-BF16禁止自动替换FLA/Hub/融合Kernel，prefill走固定chunk fallback、cached单步走recurrent fallback。其逐步dtype契约见设计文档；源码静态读取已完成，实际BF16舍入探针仍PENDING，不能宣称数值兼容通过。

测试记录每token/每层max absolute、relative L2、RMSE、cosine（零向量另定义，不除零）、argmax与top1/top2 margin；state单独报告，不用logits误差替代。相对L2定义`||actual-ref||2/max(||ref||2,1e-12)`。三类误差分开：Qerr=BF16原权重与CPU按存储scale重建Q4之差；Kerr=同一重建权重、同一输入下CUDA与独立CPU之差；ModelLoss=完整量化模型相对未量化oracle的logits/argmax/PPL变化。不能拿Qerr给Kerr超差开脱，也不能把M32与O-BF16 dtype差异计作量化损失。

| 模块 | 独立参考与输入 | 必测量与exact不变量 | 浮点验收/执行状态 |
|---|---|---|---|
| Header/loader | 真实26分片headers+index、损坏/缺失fixtures | 1045 tensors清单、693主text准确映射，shape/dtype/offset exact，vision/MTP显式非执行 | 元数据本次复核通过；未来loader运行PENDING |
| Partial RoPE/Norm | M64/M32，position0/1/边界/2047，BF16另用O-BF16 | rotary64误差、其余192维bitwise不变；offset与direct norm分别验证 | 容差PENDING；算子未执行 |
| Full Attention | M64/M32，GQA16/2、非零cache、causal mask、gate极值 | attention输出、QK norm、KV内容；未来token不能改变历史输出 | 容差PENDING；未执行 |
| DeltaNet | M64/M32与O-BF16分开比较；零/非零初state | 每token mixer输出与S_t误差、conv history、最终state；连续decode与split-prefill | 容差PENDING；未执行 |
| MoE Router | 独立FP32/FP64softmax，明确top8 tie策略 | 非tie ID exact、weight误差/归一化；tie边界按设计中的固定ID oracle | 权重容差PENDING；未执行 |
| Expert FFN | 独立原权重及Q4重建权重两组reference | gate/up分段、每expert输出、shared gate、combine、无丢token | 容差PENDING；未执行 |
| INT4 | CPU独立pack/unpack和格式公式 | nibble/sign/shape/checksum exact；权重重建maxabs/RMSE/relative L2及每group误差 | Qerr门槛PENDING；CPU/CUDA测试未执行 |
| Hybrid Decoder | 同权重/同dtype独立stream oracle | 全40层mixer、MoE、hidden逐token误差；两类state/reset/owner/invalid生命周期 | 容差PENDING；未执行 |
| Full Model | M32未量化、O-BF16、Q4各自固定输入teacher forcing | 全logits误差、argmax agreement及margin；greedy轨迹分叉点、EOS/多轮；固定语料PPL | 数值与质量门槛PENDING；未执行 |

DeltaNet序列覆盖1/3/4/63/64/65/257和2048连续decode；另以独立算子序列8192检查长时误差累积，不声称首版模型支持8192context。覆盖全零/小范数、非零initial state、g接近0及极大负数、beta边界、BF16舍入边界；报告误差随token位置曲线。g=0可作数学算子边界fixture，不要求真实参数恰好产生0。NaN/Inf输入明确拒绝，合法极端衰减允许exp下溢到0但不得出现NaN/Inf。chunk64比较输出与最终state，不仅最终文本。

冻结流程：批准设计后，先固定参考源码/运行环境、输入集和dtype trace；取得M64↔M32↔O-BF16的独立基准误差，再提出逐模块、逐dtype、逐长度误差预算并审核冻结，然后评价CUDA。至少128个teacher-forced位置与至少2048个PPL预测token作为最低覆盖建议，不是精度保证。语料覆盖中文/英文/数字/代码/重复序列并记录hash。参考资源不足为BLOCKED，未冻结门槛不得PASS；完整BF16 oracle需有界stream或另获授权参考硬件，不得一次性读入64.56GiB。

## 七阶段依赖、交付、测试与失败回退（设计路线）

此表保留七阶段，只有设计批准后才编写实际实施计划和开始开发。阶段依赖为1→2→3→4→5→6→7；独立算子探索不改变门禁顺序。

| 阶段 | 前置依赖 | 交付 | 测试方法 | 验收条件 | 失败回退策略 |
|---|---|---|---|---|---|
| 1 ModelConfig、Registry、Safetensors mmap | 人工批准完整设计及后续实施计划 | 嵌套配置、manifest、3D切片、模型fingerprint与budget接口 | 真实header对照+缺失/错shape/越界/溢出fixtures；旧loader回归 | exact元数据与错误语义通过，有界RSS；不宣称40层执行 | 新factory不启用，旧架构继续工作；保持preflight拒绝 |
| 2 Gated Full Attention、Partial RoPE、KV | 阶段1；M64/M32算子参考与容差已冻结 | offset norm、head内gate、partial64、GQA/KV | 独立attention/position/KV对齐、causal/reset/owner测试 | 算子误差满足冻结门槛、状态与资源不变量通过 | 禁用新mixer；定位projection/norm/RoPE，禁止套用旧Qwen结果冒充 |
| 3 Gated DeltaNet、Recurrent State | 阶段1/2公共接口；Delta dtype/reference与容差冻结 | conv、recurrence、gated norm、混合state容器 | 每token输出/state、非零初态、长时decode、分段对齐 | 数值与状态门禁通过；只有mixer拓扑验证，不声称MoE完整模型 | 回到顺序M32定义排查；失败session invalid/reset；不推进chunk |
| 4 Qwen MoE、Top-8、Shared Expert | 阶段1–3；router/FFN参考已冻结 | 融合expert slices、dispatch/combine、shared gate、小型hybrid | IDs/weights/FFN/hidden参考；人为ties和无丢token测试 | exact路由策略及浮点门槛通过，小模型全链通过 | 保留逐expert串行路径定位；不替换router语义或丢expert |
| 5 INT4、CPU Offloading、GPU Expert Cache | 阶段1–4未量化小模型通过；Q4E-v1格式冻结 | 有界转换、sidecar、W4A32、动态admission、lease cache | Qerr/Kerr分离；强制miss/eviction/IO错误、低显存和RAM压力 | 格式exact、已冻结计算误差门槛、hit/miss同结果；峰值实测不过预算 | 停用损坏sidecar、缩cache/拒绝请求；数值问题回到小模型BF16，不能在本机强载全BF16 |
| 6 真实模型Prefill、Decode、连续生成 | 阶段1–5；真实模型oracle与质量阈值冻结 | 40层文本、模板/tokenizer、双EOS、多轮、入口能力接入 | 全层trace/logits/argmax/PPL、至少32token或EOS、旧Dense/Qwen2.5/DeepSeek回归 | 质量/状态/资源门禁全部通过；此时才允许以能力检测替换preflight拒绝 | 保持新架构不可用；回溯首个分歧层；禁止仅靠文本合理放行 |
| 7 Chunk Prefill、Kernel Fusion、性能优化 | 阶段6正确性基线与性能报告可复现 | chunk64、融合/分组执行和有界异步优化 | 与顺序基线逐输出/state对齐；cold/warm与资源复测 | 冻结数值门槛持续通过、无资源回归；性能目标另行基线评审，当前PENDING | 按模块关闭优化，退回已验收顺序路径，旧模型路径不变 |

禁止以CPU mock替代CUDA证据；外部S编译器有阻塞只报告或在NeurX既有ABI内解决，不修改外部仓库。阶段5建立必要事件生命周期与有界异步基础，阶段7仅优化overlap/融合，二者不是重复或循环依赖。阶段6绕不开阶段5的内存与量化质量门禁。

## 性能验收与风险

报告加载时间（区分offline转换）、TTFT、prefill TPS、decode TPS、平均/p50/p95 token latency、GPU peak、CPU RSS/PSS、H2D/D2H与磁盘bytes、cache命中率、faults。warmup后至少5次，cold与warm分别报告，tokens数量/停止条件一致；cuda event量计算时延，monotonic host clock量端到端。资源目标单session额外RSS<=24GiB、context2048、GPU动态预算且>=0.5GiB headroom；总系统available>=4GiB，否则缩减cache或拒绝。吞吐目标待实测基线后批准，本阶段不承诺虚构TPS。

主要风险按优先级：Qwen offset norm与gated norm混淆；q_proj head内layout误判；Delta decay/conv状态顺序错误；3D expert整tensor误上传；INT4质量导致router敏感层偏差；异步eviction指针失效；32GB RAM page thrash；量化缓存指纹错误；模板差异使多轮缓存失效；旧量化目标缺源码。每项在上述独立门禁中有对应测试，不能留到“生成文本合理”才判断。

## 十个交付问题的直接回答

1. 可复用：S服务/C ABI、JSON/BPE、CUDA分配/传输、mmap基础、旧GQA/FFN算法和独立测试结构，均有E1–E12证据与限制。
2. 新增：hybrid config/factory、两类layer state、DeltaNet、gated full attention、Qwen专家切片/共享门、可用CUDA Q4与资源调度。
3. DeltaNet：causal conv4→SiLU→QK L2 norm/重复head→衰减delta recurrence→direct RMSNorm×SiLU(z)→out，详见设计公式。
4. 混合注意力：按显式layer_types分派，30层线性状态与10层KV分别管理，不能每层统一普通Transformer。
5. Qwen MoE：FP32 softmax top8重归一化、融合3D gate/up/down、shared expert sigmoid门、精确加权combine。
6. 16GB运行：GPU非专家常驻+默认目标7GiB、由准入动态下调的专家cache，CPU mmap约20.03GiB混合权重、冷页NVMe；所有budget动态校验。
7. INT4不足以全部驻留；仍需CPU/磁盘offload；量化质量尚未证实。
8. MVP：真实40层、B1、2048context、文本greedy、多轮/EOS和独立数值对齐，见上文。
9. 建议七个实施阶段，需先批准设计。
10. 每阶段按上表精度、状态、真实模型、回归及资源指标客观验收。前次审计记录preflight四测试与基础CUDA通过；本次未重跑运行测试，未宣称新模型已可运行。

当前停止点：四份文档交付后等待人工审批；不开始产品开发、Makefile/preflight修改、依赖安装或实施计划。
