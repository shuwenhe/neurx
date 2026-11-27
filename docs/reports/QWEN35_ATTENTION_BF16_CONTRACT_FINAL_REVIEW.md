# Attention BF16 Numerical Contract Final Review

2026-11-27。结论 **PARTIAL / REVIEW_REQUIRED；完整合同不可冻结，Native门禁BLOCKED**。本轮没有创建hybrid_attention_bf16.h/.cu，没有修改生产路径，没有调整历史容差。不是Attention BF16模块PASS，也不是人工签审。

## 基线与保护

起始HEAD d27229a8576cd7fa8b3a1ba241617d6b49cda5ad；2bed257e及外部c43c0577保留。基线与index/diff/untracked核对记录在 `artifact/build/qwen35_attention_bf16/contract-review/baseline-audit.json`。22项原保护SHA均一致；原trace/报告不覆盖，新诊断各版本分目录保留。首次普通沙箱GPU调用失败，日志contract-review-red.log保存；随后经宿主机真实CUDA执行，未以CPU冒充。

官方模型文件SHA256 `16ef7b0dc6e26eae26a6ffd0ad11d93f85424f90ffb85fbcc9eecc0759cc930d`，其余cache/generic/functional源及数学函数体AST SHA见v4/provenance.json。加载前校验源SHA；只去除已有报告披露的装饰器，函数体未改。default RoPE、显式eager、dropout0；不涵盖SDPA/Flash/动态RoPE。

环境RTX4060Ti16GB、driver580.159.03；Torch2.6.0+cu124、CUDA12.4、cuDNN90100；TF32/autocast/compile关闭，BF16 reduced reduction关闭；本轮v4/runtime.json记录实际GPU运行配置。库内部指令、归约拓扑与数学函数实现仍UNVERIFIED。固定源码不等于固定cuBLAS算法证明。

## 实际执行与修改文件

新增：`test/native-construction/qwen35_attention_contract_diagnostics.py`、`test_qwen35_attention_contract_evidence.py`、本轮执行计划、四份review及新证据。原reference harness未改。

```bash
CUBLAS_WORKSPACE_CONFIG=:4096:8 PYTHONDONTWRITEBYTECODE=1 \
 artifact/reference-env/bin/python test/native-construction/qwen35_attention_contract_diagnostics.py
PYTHONDONTWRITEBYTECODE=1 artifact/reference-env/bin/python \
 test/native-construction/test_qwen35_attention_contract_evidence.py
```

最终GPU诊断退出0：48 Norm、72 Softmax、9分区、3上游扰动；这是诊断完成数量，没有冻结阈值，不能称48/48数值PASS。证据一致性测试3/3 PASS，日志contract-evidence-final-tests.log。原官方参考回归7/7 PASS，5.649秒，日志contract-reference-regression.log；通过导入测试模块将BUILD指向新目录regression，未覆盖旧trace。上述耗时不是组件延迟或模型性能。原FP32/DeltaNet生产代码未改，本轮没有重跑这些历史生产回归。

原始数据位于 `artifact/build/qwen35_attention_bf16/contract-review/v4/`：norm/softmax/composition/propagation.json、逐partition trace、provenance/runtime/summary.json。全-inf NaN用JSON NaN保留（Python可读扩展，严格JSON读取者需明确转换），finite_count=0的maxabs/ULP=null，不误报零误差。BF16诊断ULP按符号有序编码，正负零相邻；BIT-EXACT检查仍需比较原始bits。FP32节点ULP字段null，不冒充BF16统计。

## 数值合同分类与审查结论

| 类别 | 可供人工冻结条目 | 范围/依据 | 未冻结部分 |
|---|---|---|---|
| BIT-EXACT | 搬运/layout/cache复制/mask bits/reset有效长度 | 无数值归约，原始bits/整数状态精确 | 本轮无Native reset/cache生命周期测试；规则可冻结不代表实现已通过 |
| BF16-EXACT | 相同操作数、明确逐mul/add/cast边界；不融合未舍入中间量 | 官方可见边界，精确目标0容差 | transcendental并非仅凭同dtype就可推断必然相同 |
| DOT/FLOAT Norm | 固定FP32顺序、eps、1+weight及正常数条件推导 | NORM_REVIEW逐步区间 | mean算法、rsqrt误差ρ、认证区间求值尚缺证据 |
| DOT/FLOAT Softmax | max/sub/exp/sum/div及BF16 cast的分步合同结构 | SOFTMAX_REVIEW参数化包络 | exp/div/FTZ/真实归约模型缺证明，不能给经验rtol |
| DOT/FLOAT composition | 矩阵交叉项、Norm区间、固定mask softmax、逐BF16量化 | COMPOSITION_REVIEW推导 | sigmoid及上游各局部库界未定，完整包络未实现认证 |

输入范围：参考fixture seeds521/1807；Norm D6/8/64/256、eps1e-6；Softmax N1/3/63/64/65/257；组合seed521、H12/Q4/KH2/D8/R4、T3/17/65。边界样例用于分类，不代表整个连续输入域通过。理论正常数域另要求无overflow/underflow/FTZ、正分母、固定有效mask；全-inf、平方溢出单列，不纳入正常γ模型。实际模型维度广泛推广/任意长度/所有位置仍UNVERIFIED。

## 独立只读审查

审查者单独检查官方SHA/函数体、原观察非干扰证据、FP64诊断、γ条件、Norm/Softmax/组合公式，并复核新增v2数据。结论PARTIAL，区分数学推导与CUDA库验证。发现并修正：近-1权重在BF16塌缩、全NaN误差误报0、缺上游扰动观测、缺BF16 ULP/有符号Inf分类。v1–v3数据保留；最终v4及证据测试验证修正。最终修正另请审查者只读复核；详见independent-review.md。独立代理审查不替代人工签审。

关键否决项：FP64中心/绝对乘积和不是严格向外舍入，FP64→FP32→BF16不是实数直接BF16，观察最大误差不是通用容差，分区一致性不是组合误差保证。没有证据时不使用统一rtol、不扩大预算。

## 文件SHA与下一门禁

`QWEN35_ATTENTION_BF16_CONTRACT_FINAL_REVIEW.sha256` 对四份本轮报告、原TOLERANCE和诊断源码记录最终SHA256。sidecar避免自引用哈希；它是候选内容身份校验，不是批准或数值合同冻结。Git提交身份由交付提交记录，报告自身不循环嵌入本提交hash。

下一步需补具体库rsqrt/exp/div/sigmoid与reduction的可靠实现证据，或人工明确接受严格受限的逐primitive精确目标和适用域；完善认证向外舍入实现后才能审查数字包络。当前遵照用户停止条件保留PARTIAL/BLOCKED，不启动依赖该预算的Native Batch1。
