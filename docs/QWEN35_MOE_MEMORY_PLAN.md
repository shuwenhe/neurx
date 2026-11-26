# Qwen3.5/3.6 MoE 内存与性能设计

2026-11-26；**DESIGN REVIEW COMPLETED — WAITING FOR HUMAN APPROVAL**。公式来自 [架构审计](QWEN35_MOE_ARCHITECTURE_AUDIT.md) 的完整 header 计数；以下预算/带宽情景为估算，不是 benchmark。GiB=2^30 bytes，MiB=2^20 bytes。

## 权重占用

| 范围 | 参数量 | BF16 GiB | 理想 INT4 GiB | INT4+FP16 scale / group128 GiB |
|---|---:|---:|---:|---:|
| 全 checkpoint | 35,951,822,704 | 66.9655 | 16.7414 | 17.2645 |
| 主文本 Decoder+embedding/head | 34,660,610,688 | 64.5604 | 16.1401 | 16.6445 |
| 主 routed experts | 32,212,254,720 | 60.0000 | 15.0000 | 15.46875 |
| 主文本非 routed expert | 2,448,355,968 | 4.5604 | 1.1401 | 1.1757 |

Q4 对称分组方案：每 128 个输入维元素一组，两个有符号 4-bit 值打包进 byte，FP16 scale；scale 开销 2/128=0.015625 bytes/parameter，相对纯 nibble 开销 3.125%。不保存 zero point（固定 0）。若非对称 group128 加 packed 4-bit zero point，则另增 0.5/128 bytes/parameter；若使用 U8/F16/F32 存储 zero point，分别按 1/2/4 bytes/group 增加。格式必须显式记录，不能套用同一容量数。表格全量 INT4 是纯容量假设（不是实际混合精度配置，也不是混合方案的容量上界），实际 norm/router/衰减参数保持高精度，不能声称全部可以同样量化。

推荐首版只量化 routed experts，其余文本 BF16：15.46875+4.560418=**20.029168GiB**（未含索引、alignment、RAM cache），故 INT4 仍不足以全部驻留 16GB GPU。全部文本量化的理论 16.6445GiB 也已超限。主机只有约 31GiB RAM，不能先展开全量 BF16 或 FP32 再量化。

## 状态与激活

Full Attention 仅 10 层，每 session 的 KV bytes = `10*2(K,V)*T*2(KVheads)*256*element_bytes`。FP32 为 40960*T，BF16 为 20480*T：

| T | FP32 KV | BF16 KV |
|---:|---:|---:|
| 2048 | 80MiB | 40MiB |
| 4096 | 160MiB | 80MiB |
| 8192 | 320MiB | 160MiB |
| 262144 | 10GiB | 5GiB |

DeltaNet FP32 recurrent state `[B,32,128,128]`：2MiB/层，30层共60MiB/session。conv history 为 raw projected QKV `[B,8192,4]`，FP32 共3.75MiB；若保留3历史步可减为2.8125MiB，但首版采用4步 ring，明确游标。状态不随 T 增长，但不能丢弃或跨 session 共享。

首版 B=1、T<=2048、顺序 prefill；decode 临时向量为数百 KiB 量级，但这不包括 GEMM workspace、allocator、logits、双缓冲。prefill chunk=64 若后续开启：单个 `[B,64,8192]` FP32 为2MiB；`[64,8,2048]` dispatch 为4MiB；必须层内复用，不保留40层中间激活。禁止分配全上下文 attention score 矩阵。实验 trace 按层落盘，不能留存所有层的长序列激活。

权重量化只压缩 W；初版激活/累加 FP32，BF16 reference compatibility 单独验证。KV FP32 正确性基线，后续 BF16 独立验收；KV INT8/INT4、激活 INT8/FP8 均不属于 Q4 权重功能。Delta recurrence 永久 FP32 首版，A_log/softplus 在 FP32 计算。

## GPU/CPU/磁盘分层

容量策略以 cudaMemGetInfo 动态计算，不依赖标称16GB。实测设备总量15.566GiB，前次运行记录 free约13.97GiB（本轮未重跑设备验收）；桌面与其他进程会变化。

建议单 session 专家 Q4 cache **默认目标7GiB，实际由动态准入向下调整**：主文本非专家 BF16 4.56GiB；KV 0.078GiB（2048 FP32），Delta+conv约0.062GiB；workspaces/allocator和双缓冲合计预留0.75GiB；另保留至少0.5GiB free headroom。0.75GiB必须包含全部量化计算临时区、CUDA库工作区、并发传输device缓冲和allocator开销，不能只算激活向量。8GiB cache在前次瞬时free下仅有约16MiB预算外余量，不作为首版配置；首版不自动向上扩至8GiB。以上为启动 admission 条件，分配失败必须退出或降低可配置 cache，不触碰其他进程。禁止 OOM 后宣称 CPU fallback 成功。

### 动态GPU Memory Admission Controller（拟议，未实现）

先建立CUDA context、handles/streams和当前实现必需的库初始化，测量 `F0=cudaMemGetInfo.free`。已发生的runtime/桌面/其他进程占用已扣于F0，不再当成可分配显存，也不重复从F0扣除；尚未发生的lazy初始化必须纳入workspace测量或在取F0前完成。不能从标称16GiB开始分配。

| F0之后需预约的项目（B1/T2048） | 理论值/预算 | 证据性质 |
|---|---:|---|
| 非专家BF16文本权重 | 4.560418367GiB | 真实header参数*2，不含任何FP32权重常驻副本 |
| FP32 KV | 80MiB = .078125GiB | 10层*2*2048*2*256*4 |
| FP32 recurrent+conv | 63.75MiB = .062255859GiB | 60MiB state+3.75MiB raw ring |
| activation/临时/logits | .125GiB envelope | 设计预算，实际峰值PENDING |
| CUDA库/量化算子workspace | .25GiB envelope | 设计预算；禁止全expert反量化，实际PENDING |
| 并发H2D device双缓冲 | .03125GiB envelope | 两个16MiB；host pinned另计CPU |
| events/allocator辅助临时 | .09375GiB envelope | 设计预算，实际PENDING |
| 分配对齐/碎片余量 | .25GiB envelope | 设计余量，不代表实测碎片 |
| 累计workspace/临时/碎片 | .75GiB | 上五项合计，不重复再加activation |
| 额外free headroom H | >=.5GiB | 准入设计保留，持续观测 |
| expert cache C | 默认目标7GiB | 包含packed+FP16 scale，必须动态下调 |

理论预约（含7GiB cache和.5GiB headroom）=`4.560418367+.078125+.062255859+.75+.5+7=12.950799227GiB`。这不是实测peak；前次F0约13.967GiB只是情景输入。没有空间给非专家的全量FP32副本：若算子要求转换权重，应按有界tile流式临时转换，并计入workspace，否则重新准入。

拟议算法：`C_raw=min(7GiB, F0-N-K-D-W-H)`，N/K/D为实际rounded allocation，W取上述envelope与所选算法实测需求的较大值；按完整expert/allocator粒度向下取整为C（manifest padding也计入）。先预约或实际分配N/K/D/W，再根据新的free重算C，避免初始化过程和TOCTOU过量分配。C最小应容纳当前层8个完整expert（未对齐12.375MiB）及实现实际预取in-flight集合；不能满足则禁用预取/减少in-flight重算，仍不足明确拒绝。不得为了cache挤掉KV/state/workspace/headroom，也不能先分配无限cache后寄希望于eviction。

运行前和请求/层边界观测free、allocator active/reserved、cache bytes、state bytes、workspace高水位。外部进程竞争或出现cudaMalloc失败时，暂停新准入，等待本进程events完成，缩减可驱逐cache；不得驱逐正在执行的lease、释放活跃state或杀其他进程。当前请求若无法继续则session invalid并报错/reset；有限一次缩cache重试，仍失败即FAIL，不无限重试或静默CPU替代。

真实运行验收PENDING：同一软件/模型/context/桌面负载下，从初始化前到加载、prefill、连续decode、EOS/reset测量进程显存峰值（含runtime）、allocator active/reserved/碎片、NVML与free最小值，验证至少.5GiB headroom以及预算无重叠。强制低显存、cache miss、eviction、lazy workspace和分配失败，验证缩cache/拒绝/无泄漏；不得仅凭这张理论表标PASS。7GiB是保守设计目标，不是已经测得的最优cache或性能保证。

### CPU RAM与磁盘

主机将 Q4 文件 mmap，不主动 prefault 全部。初版设计上限（非容量保证）：应用RSS<=24GiB、匿名/锁页内存<=4GiB（含两个16MiB pinned staging 与<=64MiB转换缓冲），OS至少保留4GiB available；以当前系统占用重新 admission，不能直接将 GPU cache 从 RAM 开销中相减：上传后 mmap page cache 仍可能驻留。Q4 mmap 页可回收，必要时回收冷页；不得同时 pin 整个映射。监控 memory PSI、major faults、swap 和 min available；内存压力时收缩host cache或拒绝并发。GPU+CPU只有不同物理空间，不是“共享显存”。20.03GiB映射若全驻留加4GiB匿名与系统开销可能超过此机舒适容量，因此不能保证全部热页留在RAM；必须依靠可回收页与更低host驻留预算，并接受NVMe冷读。RSS含file-backed映射，Linux page cache与该映射物理页通常是同一份，不另算第二份；但显式复制到匿名/锁页staging会新增物理副本。系统available>=4GiB和RSS<=24GiB必须同时满足，不能将两者机械相加当成可用容量。

专家缓存 key=`model fingerprint/layer/expert/projection/quant version`；融合张量按 expert slice 取范围，绝不上传 `[256,...]` 整个 tensor。对称Q4每专家三矩阵合计：3*2048*512*(.5+2/128)=1,622,016 bytes=1.546875MiB。按完整专家 lease 驻留，pin 当前层 top8，Kernel event完成后才可驱逐。两条 stream：copy stream H2D、compute stream GEMV，event wait；不假定下一层 router 提前可知，只有算完下一层输入才能准确选择。允许有界预测预取，失败不能改变输出。

初版 CPU 承担文件映射、cache调度和必要的 router Top-K；GPU承担全部神经算子。CPU 执行冷 expert 是后续可选策略，须与GPU输出独立对齐，不作为首版承诺。磁盘不可用/读取不完整显式失败。

量化转换器后续实施时仅顺序读取专家切片，group128 沿 input axis；输出至 neurx 内用户指定 artifact 目录，原模型只读。按[设计中的Q4E-v1公式与scale布局](QWEN35_MOE_DESIGN.md)约需15.47GiB routed expert sidecar，保留原文件；为临时输出和原子 rename 至少预留约32GiB。manifest 记录模型/源tensor fingerprint、shape、row-major stride、group axis、scale dtype、nibble顺序、rounding/clamp、文件范围和hash。不能每次启动临时把全模型展开后量化。

## 性能下界与测量

40层每token选8/256专家，无缓存时 Q4 expert 流量 `15.46875GiB*8/256=0.483398GiB≈495MiB/token`；BF16为1.875GiB/token。非专家权重若保持驻留，不加入每token H2D；若不能驻留，必须另外计入。GPU expert cache按传输bytes加权命中率 h 时 H2D约`495*(1-h)MiB/token`，只是一阶模型，需实际按投影统计。

4060Ti 链路协商带宽、NVMe随机读和实际缓存命中率尚未测。假设有效 H2D=8/12GiB/s，无命中时仅传输下界约60/40ms/token；磁盘有效读=1/3GiB/s时冷expert读取约483/161ms/token，不能与H2D在无流水实测前直接取max或承诺TPS。每层8个expert会产生大量小请求；CPU page faults、Kernel launch、router同步、LM head和GEMV另计。prefill不同token专家并集可能接近256，不能沿用单token8专家预算；chunk有界、按expert分组，防止cache thrash。

后续记录 cold/warm加载时间（含/不含量化转换）、TTFT、prefill tokens/s、decode tokens/s、每token p50/p95/平均延迟、cuda peak bytes+NVML、CPU RSS/PSS+锁页、H2D/D2H和磁盘bytes、major faults、expert cache命中率。重复至少5次，固定prompt token数/seed/context、后台GPU占用和软件版本。当前没有这些性能实测，因此本设计不设虚构的吞吐承诺。

## 格式与证据一致性

Q4E-v1的唯一规范见设计文档：group128、FP16 scale[E,O,I/128]、signed二补码[-7,7]、偶column低nibble、零group s16=1、非有限输入/无效scale拒绝。容量计入每group2bytes scale，无zero point；header/offset/alignment额外开销按实际sidecar追加，不能称20.029168GiB为最终文件大小。专家packed=15GiB，scale=.46875GiB；混合主文本20.029168367GiB，不包括vision/MTP执行。权重量化、激活量化、KV量化分别评估。

本次只核算参数、布局与容量，没有运行转换器、GPU admission、RAM压力、PCIe或NVMe benchmark。所有workspace envelope、cache最优值、CPU驻留量与带宽推导的可实现性为PENDING；显存不足、RAM page thrash和专家随机I/O均可能限制吞吐。最终通过条件以差距文档的阶段5/6资源实测为准。
