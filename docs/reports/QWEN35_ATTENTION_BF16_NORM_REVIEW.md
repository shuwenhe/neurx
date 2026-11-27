# Attention BF16 FP32 RMSNorm review

2026-11-27。状态 **PARTIAL**；本轮基线 `d27229a8`。没有 Native Attention BF16 代码。官方版本/AST 身份、运行命令和保护核对见 CONTRACT_FINAL_REVIEW；原 TOLERANCE 候选保留不覆盖。

## 实际语义与证据

固定官方 `Qwen3_5MoeRMSNorm._norm/forward` 数学函数体未改：`x.float(); v=x.pow(2).mean(-1,keepdim=True); t=x*rsqrt(v+eps); y=(t*(1+weight.float())).type_as(x)`。eps=1e-6，weight 存储 BF16；不是 DeltaNet norm，也不是先把 t 转 BF16 再乘权重。dispatch 记录 square/mean/add/rsqrt/mul 输出均 FP32，最终 BF16。实际 reduction 拓扑、指令和 rsqrt 实现精度 **UNVERIFIED**，输出 dtype 不能证明归约顺序。

48 GPU 样例：D=6/8/64/256，seed521/1807，各含 random、zero、nearzero(1e-10)、tiny(1e-30)、large_safe(1e10)、overflow(1e20)。scale 表示高斯样本尺度，不是严格最大值；准确输入 bits 在 v4/norm.json。权重含 -1、-0.99609375、-1.0078125，确保 BF16 中真实存在零乘子和两侧邻值。v1/v2 的 FP32 nextafter 转 BF16 后塌缩为 -1，此覆盖缺陷已保留记录并在 v3/v4 修复。

同输入理想 FP64 公式 → FP32 → BF16 诊断：除 overflow 外各组 BF16 max/mean abs、max relative、最大 ULP 均0。overflow 最大 abs=3.8125，最大 BF16 ULP=16500；FP32 平方溢出导致与实数公式显著不同，不能纳入正常算术域，不能放宽容差来吸收。每个 FP32 节点另有实际操作数的 FP64 局部诊断，含所有误差字段；输出0误差不意味着内部无误差。FP64 是诊断近似，不是经过认证的实数 Oracle。

## 条件数学合同（非已证明的库保证）

令 u=2^-24，γ_k=ku/(1-ku)，k*u<1。BF16→FP32 精确；BF16 有效位8，正常且无上下溢的 BF16 平方可在 FP32 精确表示。若 square 下溢/FTZ 或 overflow，此前提不成立。令 s=Σx_i²，假设所有加法 FP32 RNE、每个求和路径最多D-1次加法、无上下溢，sum∈[s(1-γ_(D-1)),s(1+γ_(D-1))]。mean 若使用一次正确舍入除法，则再除D并乘(1±u)；若先乘近似1/D或其他算法，必须另计该实现误差，不能默认相同。

用 FP32 eps 常量 ε32 而非实数1e-6；区间 v 加 ε32 后按 FP32 RNE 向外包络 [a,b]，a>0。若已独立建立 rsqrt 相对误差 ρ，则其值在 [(1-ρ)/sqrt(b),(1+ρ)/sqrt(a)]。目前 **ρ 未获对本地库的可靠保证，保持符号参数，不填经验阈值**。对 x*r、1+w、t*(1+w)逐次做有符号区间乘法和 FP32 舍入包络；最后映射到 BF16 RNE 舍入单元。不可在取消严重时使用相对输出误差；w≈-1 时乘子接近0，需绝对/舍入单元规则。

近零 x：eps 提供正下界，实数 RMSNorm 对 x 的 Jacobian 算子2范数≤1/sqrt(eps)；含权重乘法时乘 max|1+w|，FP32实现误差另外加入。这是有条件的灵敏度界，并非 rsqrt 误差界。tiny 平方可下溢，本轮零差只说明这些样例；不自动扩展正常数 γ 模型到 FTZ 域。

输入域候选：有限 BF16、D∈{6,8,64,256}、eps=1e-6；理论正常域另要求每个非零平方/相关归约正常、无溢出/FTZ，1+w有限。零输入可独立精确分类。更大D、不同eps、任意subnormal、无界极值、动态形状不获本轮支持。

## 冻结判断

可审查冻结：dtype、顺序、1+weight、每个显式舍入边界，以及指定同操作数 primitive replay 的严格精确目标。不能冻结：任意 CUDA reduction/rsqrt 的通用数字容差。需证明具体 mean/rsqrt 实现模型并用严格向外舍入计算区间；本轮数学式给出构造方法，没有冒充已实现认证区间求值器。
