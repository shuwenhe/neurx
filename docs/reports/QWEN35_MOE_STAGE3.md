# Qwen3.5 MoE Stage 3：Gated DeltaNet 数学基线与状态

2026-11-26；分支`feat/qwen35-native`；阶段基线`99fe05e3`。

**FP32实现与专项测试通过；完整阶段3门禁 BLOCKED：官方O-BF16参考依赖缺失，最终dtype兼容预算尚未验证。未进入阶段4。不是Decoder或推理完成报告。**

遵循已批准设计section4及计划Task5。所有新增修改限定NeurX；四份原有未提交设计保留，没有修改模型权重、外部S仓库、Makefile、Preflight、生产S服务或CUDA bridge，没有安装依赖。当前`make inference`仍应拒绝架构执行，算子存在不等于完整Decoder可执行。

## 实现范围

| 文件 | 实际实现 |
|---|---|
| `backend/platform/cuda/hybrid_deltanet_cuda.h/.cu` | `DeltaConfig/Weights/Trace`、不可复制的`DeltaNetSession`；连续position、context/chunk容量、初始state/history、reset与失败invalid生命周期；有预算的权重/状态/workspace |
| `backend/platform/cuda/gated_deltanet_kernels.cuh` | FP32 QKV/z/a/b/out投影、causal depthwise conv、SiLU、QK L2与head映射、门与衰减、delta recurrence、direct gated RMSNorm |
| `backend/platform/cuda/hybrid_mixer_state.h` | `MixerState`以拥有型variant封装Full/Delta状态，使用阶段1同一MixerKind；非零session owner检查在分派前执行，trace返回对应variant。不是完整Decoder/层factory/残差或MoE |
| `test/native-construction/qwen35_stage3_probe.cu`、`test_qwen35_stage3.py` | 独立有序FP64/FP32参考、真实权重独立读取、每token输出/状态/卷积历史检查、逐token误差曲线与资源测试 |

输入由上层完成layer norm，shape`[T,H]`，输出`[T,H]`。真实形状H2048；Q/K各16×128，V/z为32×128，raw QKV8192；conv4。投影权重row-major`[out,in]`；conv权重`[8192,1,4]`按channel/tap展平；history`[8192,4]`最旧到最新，保存conv前raw投影。每新token先shift、写入raw，再按tap0..3卷积和SiLU。

QK按head作sum-square内部加1e-6的L2，q另乘1/sqrt(KD)；value head h取key head floor(h/(VH/KH))；不应用RoPE。beta采用稳定sigmoid，softplus采用`max(x,0)+log1p(exp(-abs(x)))`；decay=`exp(-exp(A_log)*softplus(a+dt))`，合法衰减可下溢到0。极端数值导致非有限执行结果则session失效，不冒充有效输出。

state`[VH,KD,VD]`为FP32，每thread拥有一个head/value列。顺序严格为：decay旧state→使用衰减后state预测→beta*(V-prediction)→更新state→从新state读取core。core按VD维作direct-weight RMSNorm，乘SiLU(z)，再out projection。不采用offset `(1+w)` norm。

## 生命周期与资源准入

session构造持有自身权重、固定大小state/history/workspace；所有cudaMalloc先检查显式budget及cudaMemGetInfo free/headroom，并在分配后再次检查实际headroom。异常由RAII释放。大小先用checked宽整数计算，再验证int kernel索引上限。调用同步默认stream并执行device-wide synchronize；不宣称异步流水或性能优化完成。

position必须等于已提交length。参数/容量错误在launch前拒绝，已提交状态保留；执行/数值失败后invalid，必须reset。多token调用若中间失败，不允许用部分更新状态继续。reset允许显式非零state/history，要求准确shape和有限值，逻辑位置归零；未提供时清零。MixerState owner仅防止意外跨session调用，不是认证机制，也尚未接生产模型generation/owner registry。

定义Q=KH*KD、V=VH*VD、R=2Q+V、S=VH*KD*VD、K=conv_kernel、C=max_chunk，显式GPU分配字节：

```
4 * [ H*(R+2V+2VH) + 2RK + 2VH + VD + S
      + C*(2H+R+V+2VH) + R+2Q+2V+2VH ]
```

测试独立计算并要求allocated_bytes精确一致。真实层测试budget256MiB、headroom256MiB，显式分配137,315,840 bytes，实测free变化另见机器报告。其他案例budget64MiB；这不是整个模型的显存占用或16GB完整预算通过。

trace包含每token core、S_t、history、q/k、beta/decay与output。64MiB门限计FP32 vector元素存储，不包含allocator元数据、参考Python对象和probe JSON序列化；CPU RSS另计。实现先reserve最终容量并检查，再进行GPU计算，避免逐token扩容峰值。真实长序列state trace不能无限保留，超限提前拒绝；生产全模型trace后续需按层/按token流式导出。

## 数学精度证据

独立Python参考使用NumPy显式逐维FP64/FP32归约，不调用生产CUDA、BLAS matmul或外部推理引擎。比较每token的输出、core、state、history、Q/K、beta和decay；误差诊断自身用FP64计算，relative L2分母为max(||ref||2,1e-12)。cosine：两个零向量记1，仅一者为零记0，其他采用归一化dot。

先标定seed781及初始输入集，再用独立seed2191/7419与真实层权重复验。当前**FP32回归候选门限**maxabs≤2e-5、relative L2≤5e-5，仅用于被测数学分布的CUDA/M32及M32/M64；不是已经批准/验证的官方BF16兼容门限。O-BF16未运行，不能按设计的完整参考冻结流程宣称阶段3数值门禁通过。

| 指标 | 实测最大值 |
|---|---:|
| CUDA/M32 maxabs | 2.741813660e-6 |
| M32/M64 maxabs | 5.890286369e-6 |
| CUDA/M32 relative L2 | 3.986975665e-6 |
| M32/M64 relative L2 | 1.449639626e-5 |
| CUDA/M32 RMSE | 6.293042103e-7 |
| M32/M64 RMSE | 1.864485920e-6 |

最小cosine分别约0.999999999992、0.999999999956。16,640条call/tensor记录见`artifact/build/qwen35_stage3/numerics.json`，逐Token maxabs/relative-L2/RMSE曲线见`token-error-curves.json`；汇总、源码hash、9个真实tensor payload SHA256见[机器报告](QWEN35_MOE_STAGE3.json)。这些tensor hash不代表全部模型payload完整性hash。

真实权重来自第一处linear_attention（0-based layer0）的QKV/z/a/b、conv1d、A_log、dt_bias、norm和out。C++经阶段1loader读取，Python通过独立index/header/seek/read解码BF16。执行2-token prefill及1-token decode，使用合成FP32输入；没有执行真实整层残差/MoE或语言模型生成。

## 实际测试与失败修复

- RED：阶段3API缺失导致probe不能构建，`artifact/build/qwen35_stage3/red.log`。混合状态容器同样先观察缺头文件RED，`mixer-red.log`。
- 首轮8项GPU通过；完成独立seed/真实BF16权重后11项通过；之后增加边界、极端beta、近单位衰减长序列、owner与trace容量测试。
- 独立审阅发现Important：只检查最终trace数据量，vector扩容会突破64MiB。新增用例RED实际72,360,748 bytes >67,108,864；改为计算前reserve并检查容量，GREEN实际65,577,004 bytes。日志`trace-red.log`、`trace-green.json`。完整suite在修复后通过。
- 最终**16 tests in 21.348s / OK / exit0**；宿主机RTX4060Ti执行，`gpu-final.log`。编译CUDA12.0，`-O2 --fmad=false -arch=sm_89`，无fast-math；沿用项目FORTIFY兼容参数；额外`-Wall -Wextra -Werror`编译通过。
- 序列1/3/4/63/64/65/257；63+1+1分段；prefill/decode/chunk等价；非零初态/非零raw history；零/小范数；单位与零衰减、beta极端；2048次连续decode；8192-token独立小维度算子且A_log=-8，检验近单位衰减的误差积累。8192不是完整模型context支持声明；长序列使用KH1/VH2/KD2/VD2，不冒充真实head维度长序列。
- 单独覆盖真实KH16/VH32/KD128/VD128；另有真实模型9项BF16权重测试、容量/position/shape/预算/headroom拒绝、失败invalid及reset恢复。混合状态检查Full/Delta类型、owner错误拒绝、对应trace和reset。
- 测试驱动峰值CPU RSS721,780KiB，包含独立参考与误差曲线，远小于32GiB，但不代表全模型RSS。日志记录warm page条件，不作为磁盘带宽/TTFT/TPS。

复现（须可访问GPU，脚本自动构建；QWEN35_STAGE3_PROBE可显式复用同源binary）：

```bash
PYTHONDONTWRITEBYTECODE=1 python3 test/native-construction/test_qwen35_stage3.py
```

回归：Stage1 11项、Stage2 11项通过；指定本地compiler的`make native-stage4-test`31项通过（461.253s）；Preflight4项、startup5项通过。日志均在`artifact/build/qwen35_stage3/`。旧回归不编译新模块，不把它冒充新Decoder验收。未修改旧Dense/Qwen2.5/DeepSeek实现。

## 尚未通过的官方参考与依赖提案

已再次核实安装的Transformers5.15.0官方源码SHA256为`16ef7b0dc6e26eae26a6ffd0ad11d93f85424f90ffb85fbcc9eecc0759cc930d`，与设计一致。静态方程/conv顺序核对完成。`importlib.util.find_spec('torch')`为None；常见项目/用户venv未发现可用替代环境。因此无法运行实际官方BF16 dtype/逐舍入探针、chunk fallback与cached recurrent fallback对齐。NaN/Inf、各BF16舍入边界与最终logits官方差异仍PENDING/BLOCKED。

**不能用M64/M32数据替代O-BF16。按IMPLEMENTATION_GAP的冻结/阶段门禁，阶段3完整验收不放行，不进入阶段4。**

待用户授权的具体提案：在NeurX `artifact/reference-env`建立隔离venv，安装固定`torch==2.6.0` CUDA12.4 wheel及必要依赖；复用只读、已固定SHA的Transformers源码，不安装vision/audio扩展，不修改系统Python、S仓库、模型或驱动。官方[历史版本表](https://pytorch.org/get-started/previous-versions/)列出该版本/cu124；本机Transformers依赖表要求torch>=2.5。实际兼容性仍需验证，不能仅凭最低版本推定通过。pip/torch/HF缓存与临时文件限定artifact内，固定所有实际依赖版本/文件hash。此环境仅用于数值参考，正式后端仍为原生CUDA；oracle按层、小序列、有界显存运行，不from_pretrained整模型。该提案尚未执行，须遵守用户“未经批准不安装依赖”的约束。

## 审阅和保留限制

独立审阅：无Critical；上述trace Important已RED→GREEN。新mixed-state容器追加只读审阅未发现Critical/Important。Deferred minors：普通trace=false路径尚未单独执行；MixerState move/moved-from/null/zero-owner分支未运行验证；GPU device切换、失败构造后显存恢复测量未覆盖。owner只是调用方ID，不是认证。

CUDA sanitizer继续UNVERIFIED：阶段2已证明现有工具在有效插桩前退出，阶段3不重复无意义运行，不声称动态内存安全工具通过。未安装或修复环境。

完整混合层hidden state、logits/argmax、MoE、INT4、offload/cache、完整40层、32-token生成、双EOS、多轮对话及全模型16GB预算均尚未执行。等待官方参考环境授权后先完成阶段3剩余门禁，再继续七阶段路线。
