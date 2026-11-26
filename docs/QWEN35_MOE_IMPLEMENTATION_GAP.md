# 实现差距、实施阶段与验收门禁

2026-11-26；当前只完成审计和设计。下列为设计级路线与验收建议，**不是已批准实施计划**。证据E编号见 [审计](QWEN35_MOE_ARCHITECTURE_AUDIT.md)，详细接口见 [设计](QWEN35_MOE_DESIGN.md)。

## 可以复用与必须新增

| 模块 | 可复用 | 必须新增/改造 | 当前证据与状态 |
|---|---|---|---|
| 服务入口 | S服务、HTTP健康检查、进程清理、生成会话边界 | 通用Decoder factory转接和会话state variant | E1/E3/E12，PARTIAL |
| Config/registry | JSON parser、旧adapter保持 | 嵌套text_config、layer_types、能力注册、shape规则 | E3/E6，PARTIAL |
| Loader | E4 mmap、bounds校验、BF16读取 | 通用mapped store、3D expert slice、manifest、Q4 sidecar | E4/E6，PARTIAL |
| GPU基础 | RAII buffer、device枚举、同步传输 | 有界pinned双缓冲、event lease、异步专家缓存 | E7基础IMPLEMENTED，调度PARTIAL |
| 普通attention | GQA与half-split思路、测试结构 | q/gate head内split、QK offset norm、partial64 RoPE、sigmoid gate | E4/E8，目标算子MISSING |
| DeltaNet | 通用matvec/SiLU/归约思路 | conv、L2 norm、衰减delta recurrence、gated norm、状态 | MISSING |
| MoE | DeepSeek topk/FFN/combine控制流 | Qwen router精度、融合expert张量、shared gate、dispatch映射 | E4/E10，PARTIAL |
| Quantization | 概念、格式经验 | 可验证group128 packed Q4转换器和CUDA W4A32 | E11，UNVERIFIED |
| Tokenizer | ICU BPE、special token查找 | Qwen3.6模板、双EOS、未分配ID策略与多轮精确对齐 | E12，PARTIAL |
| 测试 | 独立NumPy参考结构与CUDA probe模式 | 新架构算子/40层/真实模型/资源测量门禁 | E8/E9，目标MISSING |

## 第一版最小可运行目标

在现有4060Ti16GB/约32GB RAM上，以真实全部40层文本Decoder执行中文/英文短prompt，B=1，context<=2048，greedy连续生成至少32个token（遇EOS可提前结束），支持双EOS、reset和两轮文本对话；新架构所有权重映射、30个DeltaNet和10个gated full attention及40个MoE均参与。Q4主routed专家+BF16非专家+CPU mmap/GPU cache确保预算；不实现vision/MTP，但其权重清单完整、输入明确拒绝。真logits与独立参考必须通过以下门禁，不能以输出像人话代替。

## 数值标准（拟议，必须在实现前冻结）

独立CPU FP64/FP32定义算子oracle，不能调用被测CUDA函数；固定版本官方实现仅提供语义或单独的兼容参考。小尺寸确定性fixture属于算子测试，不能冒充真实模型验收。真实样本需记录prompt、token IDs、模型/sidecar hash、参考hash、dtype/rounding、seed和全部层trace摘要。

| 验收项 | 客观标准 |
|---|---|
| Header/loader | 26分片、1045tensor清单完全匹配；693个主text tensor准确映射；shape/dtype/offset负例全部拒绝；非执行vision/MTP明确列出 |
| Partial RoPE/Norm | FP32 rtol=1e-5, atol=1e-6；192维不旋转部分逐位保持；offset/direct norm分别测试 |
| Conv/Delta recurrence | FP32 rtol=1e-4, atol=2e-5；输出和最终state均比较，序列1/3/4/63/64/65/257及非零initial state；极端衰减无NaN/Inf |
| Gated Full Attention | FP32 rtol=1e-4, atol=2e-5；GQA、mask、gate开关、非零position和KV连续追加；未来token改变不影响过去输出 |
| Router | 非tie top8 IDs完全一致，FP32 weights atol=1e-6且和为1；ties按稳定策略测试集合；测试softmax溢出保护 |
| FFN/dispatch/combine | FP32 rtol=1e-4, atol=2e-5；每expert gate/up边界、shared sigmoid、重复token专家聚合及无丢token |
| Q4格式 | pack/unpack、sign、零group、饱和、row/expert边界exact；CPU与GPU同一量化权重算子rtol=1e-4, atol=2e-5 |
| Prefill/Decode状态 | 同dtype同权重下整段/分段/逐token输出与两类state rtol=1e-4, atol=2e-5；reset、owner、capacity、failure invalidation必须通过 |
| FP32真实层trace | 同BF16存储、FP32执行的独立stream oracle：所有40层mixer/MoE/hidden相对L2<=1e-3；超限逐层定位，不放宽后掩盖 |
| BF16兼容基线 | 先建立独立BF16边界oracle；真实全模型logits相对L2<=1e-2且cosine>=.999，greedy agreement>=99%（>=128个teacher-forced位置）；小margin差异单列，不豁免总体门禁 |
| 量化质量 | 与BF16 oracle区分：量化logits相对L2<=.10、cosine>=.99、argmax agreement>=90%（>=128位置）；固定>=2048预测token文本集PPL增幅<=10%；未达到则调整量化方案，不能声称通过 |

相对L2定义`||actual-ref||2/max(||ref||2,1e-12)`；相对误差不能替代逐tensor绝对误差报告。BF16/Q4阈值是建议目标，不是本模型已知结果。语料、最终prompt集在实施验收前冻结到NeurX测试资产，至少覆盖中文、英文、数字、代码、长重复序列；独立oracle资源不足记BLOCKED，不能用生成质量代替。FP32数学基线与BF16 compatibility需分别对齐，不能把activation dtype不同造成的差异都归咎于Q4。

## 推荐七阶段（批准设计后再细化实施计划）

| 阶段 | 产物 | 进入下一阶段的门禁 |
|---|---|---|
| 1 Config/Registry/Loader | 嵌套配置、层manifest、read-only范围读取与3D切片、资源admission | 全真实header映射；负例；bounded RSS；旧模型映射回归 |
| 2 Norm/RoPE/Gated Full Attention | 新norm policies、head内gate split、partial64、GQA/KV | 独立算子精度；KV owner/reset/causal测试；不超预算 |
| 3 DeltaNet与混合state | conv、FP32 recurrence、gated norm、40层variant调度 | recurrence/state精度与分段等价；故障后session不可复用 |
| 4 Qwen MoE与小模型整合 | router、融合expert/共享gate、dispatch/combine | IDs/权重/FFN精度；全部小模型层运行与中间trace；明确不是大模型推理 |
| 5 Q4与分层加载 | 有界转换器、sidecar、W4A32、expert cache/lease | 格式exact、独立Q4 Kernel精度、cache hit/miss输出相同；RAM/VRAM硬上限与OOM负例 |
| 6 真实模型与入口接入 | 40层真实权重、tokenizer/模板/EOS、多轮、make接入 | 全层trace/logits/argmax/PPL门禁；至少32生成token或EOS；旧Qwen/DeepSeek回归；此时才更新preflight能力判断 |
| 7 性能优化与完整回归 | chunk prefill、grouped expert GEMM、copy/compute overlap、测量报告 | 与基线数值等价、资源不超限、cold/warm指标齐全、优化前后同条件比较 |

阶段1–4可先使用小型真实shape子模块和确定性fixtures验证；本机完整BF16 reference不能通过一次性加载64.56GiB实现，需有界stream CPU oracle，耗时必须记录。若之后申请外部参考硬件或测试依赖，另行获批；当前不安装。

每阶段共同要求：对照独立reference、测试失败或无GPU退出明确FAIL/BLOCKED；不能CPU mock冒充CUDA；不修改外部S工具；不删除旧实现。现有外部编译器无法编译所需接口时记录阻塞，在NeurX内部使用已有ABI解决或报告，不能擅自扩展范围。

## 性能验收与风险

报告加载时间（区分offline转换）、TTFT、prefill TPS、decode TPS、平均/p50/p95 token latency、GPU peak、CPU RSS/PSS、H2D/D2H与磁盘bytes、cache命中率、faults。warmup后至少5次，cold与warm分别报告，tokens数量/停止条件一致；cuda event量计算时延，monotonic host clock量端到端。资源目标单session额外RSS<=24GiB、context2048、GPU动态预算且>=0.5GiB headroom；总系统available>=4GiB，否则缩减cache或拒绝。吞吐目标待实测基线后批准，本阶段不承诺虚构TPS。

主要风险按优先级：Qwen offset norm与gated norm混淆；q_proj head内layout误判；Delta decay/conv状态顺序错误；3D expert整tensor误上传；INT4质量导致router敏感层偏差；异步eviction指针失效；32GB RAM page thrash；量化缓存指纹错误；模板差异使多轮缓存失效；旧量化目标缺源码。每项在上述独立门禁中有对应测试，不能留到“生成文本合理”才判断。

## 十个交付问题的直接回答

1. 可复用：S服务/C ABI、JSON/BPE、CUDA分配/传输、mmap基础、旧GQA/FFN算法和独立测试结构，均有E1–E12证据与限制。
2. 新增：hybrid config/factory、两类layer state、DeltaNet、gated full attention、Qwen专家切片/共享门、可用CUDA Q4与资源调度。
3. DeltaNet：causal conv4→SiLU→QK L2 norm/重复head→衰减delta recurrence→direct RMSNorm×SiLU(z)→out，详见设计公式。
4. 混合注意力：按显式layer_types分派，30层线性状态与10层KV分别管理，不能每层统一普通Transformer。
5. Qwen MoE：FP32 softmax top8重归一化、融合3D gate/up/down、shared expert sigmoid门、精确加权combine。
6. 16GB运行：GPU非专家常驻+7–8GiB专家cache，CPU mmap约20.03GiB混合权重、冷页NVMe；所有budget动态校验。
7. INT4不足以全部驻留；仍需CPU/磁盘offload；量化质量尚未证实。
8. MVP：真实40层、B1、2048context、文本greedy、多轮/EOS和独立数值对齐，见上文。
9. 建议七个实施阶段，需先批准设计。
10. 每阶段按上表精度、状态、真实模型、回归及资源指标客观验收。当前只有preflight四测试与基础CUDA通过，未宣称新模型已可运行。

当前停止点：四份文档交付后等待人工审批；不开始产品开发、Makefile/preflight修改、依赖安装或实施计划。
