# Full Attention BF16 测试与最小实现设计（待确认）

日期：2026-11-27（Asia/Shanghai）。Git 基线：`a56388ea6ebd598f26016783e20a071821c703a2`，核心历史提交 `9e8dd875`、`a56388ea` 均保留。本轮只读分析已有源文件与环境，唯一交付写入为这三份报告；没有编写/执行新 Attention probe，没有修改生产代码、现有测试、Bridge、Preflight、外部编译器或历史证据，也不提交/重写 Git 历史。

本阶段状态：**审计与设计已形成，待人工确认；Full Attention BF16 实现/数值验收 UNVERIFIED，完整 Phase 2 仍 BLOCKED。** P0 历史 PASS 不能推广为 Attention BF16 PASS。本次没有重跑历史测试，历史 11/11/16/16 等仅是上轮证据。

参考环境只读检查：Transformers distribution 5.15.0；固定 Torch 2.6.0+cu124，Torch CUDA 12.4，cuDNN 90100；GPU NVIDIA GeForce RTX 4060 Ti，驱动 580.159.03，nvcc 12.0.140，Compute Sanitizer 2022.4.1。宿主机检查时 VRAM 1507/16380 MiB（含检查进程约120 MiB），不是推理显存峰值。参考子进程调用既有 configure_runtime 设置 highest、TF32=False、BF16 reduced precision reduction=False、deterministic=True、autocast/compile=False；未运行 forward。普通沙箱仍无 GPU 访问，后续 CUDA 验收必须在宿主机执行。

官方文件目录：`/home/shuwen/.local/lib/python3.12/site-packages/transformers/`。checkpoint config 的 transformers_version=4.57.1 是序列化元数据，不能替代此次实际 distribution/source 版本；远端模型发布版本/commit 与本地目录名称“Qwen3.6”的来源对应关系未独立证明，参考由本地架构和文件哈希界定。

## 已知基础、参考边界与选择

检查依据：hybrid_attention_cuda.h/.cu、gated_attention_kernels.cuh、hybrid_mixer_state.h、Stage2 probe/test、固定官方 modeling_qwen3_5_moe.py（SHA256 `16ef7b0dc6e26eae26a6ffd0ad11d93f85424f90ffb85fbcc9eecc0759cc930d`）、cache/masking/interface及PyTorch softmax源码、现有sanitizer脚本。完整文件哈希与起始Git diff在ARCHITECTURE_AUDIT；官方版本5.15.0/Torch2.6.0+cu124的具体源码边界在REFERENCE_ANALYSIS。

当前调用链：Stage2 probe→FullAttentionSession→FP32 linear/norm/RoPE→float cache→gated_gqa→float O；源码没有目标BF16或完整decoder连接。IMPLEMENTED仅FP32独立路径，Attention BF16及专用oracle/probe MISSING；所有拟议测试均NOT RUN，不声明新数值PASS或Full Phase2 PASS。

方案比较：

| 方案 | 优点 | 代价/风险 | 建议 |
|---|---|---|---|
| 显式eager oracle + 分阶段BF16 native独立路径 | 可观察投影、norm、RoPE、score、P、AV、gate与cache边界；保护旧代码 | 小序列T² scratch，初期慢；必须设计trace预算 | 首选正确性基线，待人工确认 |
| 直接融合score/softmax/AV或先匹配SDPA | 减少scratch、利于性能 | 不能假设与eager相同舍入；内部不透明、难定位首分歧 | 本阶段不选；未来需单独规范与验收 |

这是一份提案，尚无人批准实现；不会修改现有FP32/DeltaNet代码来“复用”舍入，也不会开始MoE/Shared Expert/Hybrid Decoder/GPU weight cache/expert paging/Bridge/E2E。

## 拟议数据契约和独立 Probe

所有probe必须调用将来同一BF16 native operator实现，禁止只在test内重写算子冒充生产CUDA。每个stage可用独立CLI子命令/入口，接受官方同一份bit-exact输入/权重、明确layout/position/mask，输出原始bits与float诊断值；独立module probe再串接完整mixer。禁止仅核对输出float数值就声称BF16存储，需代码分配dtype+2-byte GPU buffer往返+GPU trace三类证据。

| 独立Probe | 必须捕获 | SOURCE目标dtype与边界 | 必须验证 |
|---|---|---|---|
| Projection | QG raw、head-local Q/gate、K/V；输入weight bits | BF16输入/weight/output；库/自写内部accum另证 | QG layout、真实形状、tie/cancellation/0/极值、FP32对照 |
| QK norm | x.float、square、mean、+eps、rsqrt、normalized、1+w、weighted、cast | head内FP32 norm和weight乘法，最后BF16 | norm权重不是直接w；epsilon；零/小范数；不得套用DeltaNet norm |
| RoPE generation/apply | inv_freq bits、position、freq/cos/sin FP32、cos/sin BF16、two products/add、tail | FP32生成→BF16cos/sin；文本BF16乘/加 | R维/2配对、sign、tail不变、T/H/W文本相等、不同position |
| QK score | Q/K BF16、pre-cast FP32 accumulator（native可见时）、BF16score | 官方matmul出口BF16；内部accum UNVERIFIED | KH重复/group映射，dot D维、取消误差、真实D256 |
| Scale/Mask | scalar、scaled BF16、maskbits、masked结果 | 独立scale出口；mask固定BF16 additive | scale顺序/不同D；causal/prefix/padding；future值不能影响prefix |
| Softmax | 官方FP32softmax结果和BF16 P；独立诊断max/shift/exp/sum/divide | 先转FP32计算，P出口BF16 | 等logit/极差/近饱和、nonnegative、row sum、有效/无效行 |
| AV | BF16P、BF16V、AV_BF16；nativeaccum可见值 | matmulBF16出口，库内部accum UNVERIFIED | 先P舍入再AV；不与未归一exp加权融合冒充 |
| Gate | raw gate、sigmoid_BF16、AV×gate_BF16 | sigmoid与乘法各自出口BF16 | gate=0、正负饱和、head-local split、非SiLU |
| Output projection | gated_input、Wo、O | BF16 operands/output | 最终mixer输出，非residual后的hidden state |
| KV cache | 写入新K/V、历史有效prefix、cache dtype/bytes、读取参与score的K/V | rotated K与V均BF16；读入算术的转换单独标注 | 按token追加、无double-RoPE、非零cache、reset/生命周期/异常恢复 |

权重形状验证、dtype验证、offset验证必须沿用严格mapped store，不能绕过metadata检查；真实checkpoint测试后续固定层3/7/39及六项weight payload SHA256，不把合成输入写作真实模型hidden state。每个probe有host/GPU预算、输出大小上限、有效长度和返回错误协议，不准失败后继续使用被部分改写的cache。

## 测试矩阵（计划，未执行）

固定seeds：521、1807、7319，第三项作held-out，生成算法/版本/bitstream与case ID写入manifest。Torch、NumPy版本及输入payload哈希固定；禁止事后换seed避开失败。

| Case组 | 维度/长度/位置 | 覆盖模块与判定 |
|---|---|---|
| Tiny独立 | B1,H12,QH4,KH2,D8,R4；T1/3/5 | 每个stage bit/dtype/finite；FP64/FP32数学与官方独立对照 |
| 非幂次head | D6,R2，QH6/KH2，hidden独立设定 | scale非1/16、pair索引、非幂次reduction，不只测D256 |
| 真实head布局 | H2048,QH16,KH2,D256,R64；T1/2/3 | QG[8192,2048]，KV512，O[2048,4096]；小T分stage，真实weights3/7/39另列 |
| GQA | ratio1/2/8；不同KV头使用可识别数据 | head映射；cache不必物理repeat；变更一个KV头仅影响其Q组 |
| Tile边界 | T7/8/9、31/32/33、63/64/65、127/128/129、257 | 对应未优化/未来tile；P/score trace按预算截取，不能静默丢case |
| 连续状态 | one-shot、逐token、chunks[2,3]及[31,33,1]；总65 | 同输入同权重，cache逐步bit快照、输出prefix；chunk不变性按独立冻结总budget |
| 长decode | 总2048，tiny及真实head分层预算 | state/output误差曲线；不宣称支持模型最大context；8192为额外门禁不得冒认已过 |
| RoPE位置 | origin0/1/7/63/64/2047；单独RoPE probe再测65535/262143 | cache长度与RoPE origin解耦；真实theta1e7；越界拒绝；尾部192维bit不变 |
| 数值分布 | 0、1e-8、小norm、单位基、取消和、半ULP邻居、极端gate | BF16tie/RNE、normepsilon、softmax稳定；overflow/NaN/Inf必须拒绝或报告 |
| Causality/mask | prefill未来token扰动、cachedprefix、多chunk、padding/custom拒绝 | BF16maskbits；禁止只靠eager Attention.is_causal属性（eager函数不会自动构造mask） |
| 非零cache | 先真实prefix追加，另独立import fixture | 验证历史K/V/position；import是否首版API需确认，不影响前一基本case |
| Reset/lifetime | 两session交错、构造失败、销毁、重复reset、复用buffer | prefix有效区、owner/currentdevice；memcheck/initcheck；多GPU不可用标UNVERIFIED |
| 异常恢复 | wrongposition/shape/dtype/mask、maxchunk/context、非有限、budget不足 | 预验证错误不写cache；执行中故障invalidate，reset后同输入与fresh session一致 |
| 参考自检 | hash篡改、重复运行、trace on/off、eager标签检查 | 错误hash必须拒绝；观测不能改变计算；禁止SDPA静默替换 |

首版推理范围建议B=1纯文本、bias=False、dropout0、default RoPE、无滑窗。padding/custom mask若不实现须在API明确拒绝并有负测试，不能直接忽略；全masked行首版建议拒绝并记录官方观察，不把zero输出定为官方事实。

## 数值验收、事先冻结容差

本轮**不伪造数值阈值已经冻结**。没有Attention专用GPU参考分布/trace前，gemm、FP32归约及长度传播预算为 **PENDING**，这是实现前置门禁。不得直接拷贝DeltaNet的rtol/atol；现有FP32测试的maxabs<=2e-5、relativeL2<=1e-5和prefill/decode rtol2e-5/atol2e-6保持原样，仅用于原FP32回归，不能拿来验收BF16。

冻结流程：

1. 在不运行任何新native候选的前提下，固定官方eager GPU trace、相同输入BF16位模式与独立FP64数学oracle；确认inv_freq、pointwise、mask、cache实际dtype。观察max/exp/sum的独立分解结果不冒充官方softmax内部trace。
2. 预先划分calibration seeds521/1807与held-out7319和真实层分布；不使用native误差拟合任何阈值。dtype、layout、copy/cache、tail、mask/split/gather一律bit-exact；同一BF16operand的pointwise舍入结果原则上bit-exact，transcendental近似差异须事先证明与单独冻结，不默认给“1 ULP”。
3. FP32 dot/reduction可用前向误差理论提出绝对预算：u=2^-24，gamma_n=n*u/(1-n*u)，正常数、无overflow/FTZ影响且乘积恰可表示条件下，ordered FP32 dot 对数学精确和满足约gamma_n*sum(abs(a_i*b_i))；两个满足同一模型的实现差可由两侧预算之和约束。BF16正常乘积在FP32可精确表示并不证明任意库内部遵守该模型；官方内部精度未知时该理论**不能直接当作库误差保证**。subnormal/underflow要独立分类。
4. norm/rsqrt、cos/sin、exp与softmax须结合API精度约束、参考-only实测及传播敏感性形成逐节点/每长度的E_abs+E_rel*abs(ref)或可解释的condition-based绝对界。BF16最终结果比较应区分隔离相同operand与整链输入已含上游误差，不用一个宽松全局rtol掩盖首分歧。候选预算文档必须在看到native结果前人工审查并SHA冻结；未冻结就停止实现验收。
5. 每次报告保存frozen budget ID/hash、校准与held-out标识；fail停止，不反向增大阈值、不换oracle。若独立证据证明规范需修订，保留失败证据、先审查新规范，再重新跑完整门禁。

每个stage/case/token强制记录：shape/layout/stride、实际输入/输出dtype、GPUbuffer字节数、库实现标签、accumulator已证/UNVERIFIED、max abs/mean abs/max relative（分母floor=FP32 tiny，并另记录参考近零计数）、NaN与Inf计数及异常位置、BF16ULP/bit mismatch、比较预算ID。附RMSE/relativeL2便于定位但不替换强制指标。mask预期sentinel单独标注，不能全局屏蔽Inf检查；有效score/output出现NaN/Inf立即失败。

## KV Cache 专项契约与矩阵

建议新BF16 session与旧FP32完全分离，GPU cache分配BF16，保存K_post_rope与V_projection；读取时保持BF16 bits，score/AV kernel可转FP32参与明确累加，不能把整个cache暗中展开为float后声称BF16常驻。测试按真实2-byte容量验证。

- 初始化：空cache length0；prefill T后有效prefix恰T，无旧suffix泄露。D2D append前完成shape/finite/position/mask/capacity检查。
- Decode：写新slot一次，长度+1，旧prefix bit不变；K不可再次RoPE。分配末端guard/canary只能在专用测试分配器中使用，不给生产类加入test-only API。
- 多chunk：logical cache length控制mask；RoPE position_ids单独输入或以validated origin+length推导。第一版是否支持非连续position_ids由人工确认；不支持应拒绝，而非悄悄复用past。
- 非零cache：先通过prefix建立真实非零cache，保存与fresh one-shot对照；如批准import，验证[valid_length,KH,D]、dtype/owner/origin与容量，原子性失败不得部分覆盖。此为新增API提案，不修改旧reset。
- Reset：Native逻辑length清0，未必清内存；参考必须用fresh DynamicLayer/Cache模拟空state。固定官方DynamicLayer.reset是zero_但可能保留shape/length，不能作为空cacheoracle。
- 生命周期：session/device/owner隔离、析构、临时source释放后cache仍有效、两session交错，buffer复用不串扰；资源失败与kernel故障后invalidate，reset+同输入输出和fresh实例对比。
- context末端：T=context-1 +1成功，再+1拒绝且长度不变；零length/oversizedchunk/位置不符拒绝。所有读取只在valid_length内，用initcheck确认未触及未初始化suffix。

## Sanitizer 与回归方案（未执行新Attention BF16测试）

复用现有 scripts/run_cuda_sanitizer.py，不改它或负对照代码。新probe编译 -O2 -lineinfo --fmad=false、禁fast-math，沿用已有nvcc/glibc兼容参数；实际参数、编译器及binary SHA256写日志。host GPU执行；普通沙箱无法访问时记BLOCKED，不用CPU模拟。单个进程零错误summary不足以证明有效插桩，要同时验证目标执行、结果checksum、退出码与正负对照。

拟议命令（对应文件尚不存在，以下不是执行记录）：

```bash
# 人工确认并完成RED/GREEN后，真实宿主机执行
python3 scripts/run_cuda_sanitizer.py --tool memcheck -- artifact/build/qwen35_attention_bf16/probe < fixture.json
python3 scripts/run_cuda_sanitizer.py --tool initcheck -- artifact/build/qwen35_attention_bf16/probe < fixture.json
python3 test/native-construction/test_cuda_sanitizer_p0.py
python3 test/native-construction/test_qwen35_stage2.py
python3 test/native-construction/test_qwen35_stage3.py
python3 test/native-construction/test_qwen35_stage1.py
CUBLAS_WORKSPACE_CONFIG=:4096:8 artifact/reference-env/bin/python test/native-construction/test_qwen35_p0_bf16.py
```

memcheck覆盖空cache→prefill→decode→chunk→context末端→reset、构造失败/销毁、参数拒绝和恢复；initcheck专查未写KV suffix、scratch每条分支的初始化及trace读取。正对照clean kernel exit0/结果正确/summary0；已存在故意OOB和uninitialized read分别exit99并有实际设备诊断。对BF16 Attention启动上述两工具后才可称其插桩成功，不能复用DeltaNet sanitizer PASS。

单独BF16 oracle与numeric suite必须加进回归集合；保留上面原测试阈值，不改变原文件。组件通过仍不授权完整Phase2或decoder集成。

## 最小实现顺序及预计修改文件（需人工确认）

| 顺序 | 内容与门禁 | 预计新文件/修改 |
|---|---|---|
| 0 | 确认本提案、eager目标、mask/position/cache import范围 | 当前仅三份报告；未修改代码 |
| 1 | 新建hash-pinned官方Attention oracle；先失败hash/trace自检再观察dtype，freeze预算 | 新 test/native-construction/qwen35_attention_official_reference.py；新 test_qwen35_attention_official_bf16.py；新参考/预算证据文件 |
| 2 | 为projection/norm/RoPE各写RED；实现真正BF16 buffers，stage隔离验证 | 新 backend/platform/cuda/hybrid_attention_bf16.h/.cu；必要时新 gated_attention_bf16_kernels.cuh；新 qwen35_attention_bf16_probe.cu、test_qwen35_attention_bf16.py |
| 3 | KV dtype/write/read/lifecycle RED→GREEN，prefill/decode位置和mask契约 | 继续仅上述新BF16文件与新测试；如import/position API扩大范围先更新设计 |
| 4 | QK→scale/mask→FP32softmax→BF16 P→AV→sigmoid gate→O，各stage独立RED→GREEN | 同一独立BF16实现及新stage tests；不改原gated_attention_kernels.cuh |
| 5 | 官方整Attention模块逐阶段与组合输出、三seed/真实head/真实weights/长序列、冻结预算 | 新tests与artifact/build/qwen35_attention_bf16证据；先小维再真实；fail停止 |
| 6 | 新路径memcheck/initcheck+正负对照、旧FP32/DeltaNet/Phase1回归与独立审查 | 新验收报告；现有scripts/run_cuda_sanitizer.py只调用、不修改 |

所有实现/测试代码位置均在NeurX。不会修改hybrid_attention_cuda.h/.cu、gated_attention_kernels.cuh、DeltaNet BF16、hybrid_mixer_state.h或生产Bridge/Preflight；MixerState接入不属于这个专项，需另行授权。新增独立class API、GPU资源budget/headroom、trace上限与position/cache契约须写入新头文件并测试，不偷偷改变旧行为。

## 风险、阻塞与人工确认点

风险：参考backend不固定、BF16buffer加载导致inv_freq丢精度、误用vision RoPE、把Q/K norm套成DeltaNet规则、P未舍入就AV、gate遗漏、cache reset/position错位、T² trace OOM、近零相对误差夸大或被宽松rtol掩盖。UNVERIFIED与PENDING项目未消除前，不能宣称可信数值规范已全部冻结，更不能宣布Full Phase2 PASS。

请人工确认上述eager+独立BF16 staged方案、先参考验证及预算冻结的门禁，以及首版B1纯文本范围（mask/非连续position/import超出基本契约时先拒绝并记录）。这是用户第10节要求的实施前确认；没有该确认不会写生产实现或新测试代码。审计报告本身可供复核，不代表已经批准实现。

