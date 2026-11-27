# Attention BF16 FP32 Softmax review

2026-11-27；基线 d27229a8；状态 **PARTIAL**。官方 eager `F.softmax(BF16_score_plus_mask, dim=-1, dtype=float32).to(BF16)` 未改，内部 fused CUDA 算法、exp近似、sum顺序及除法实现均 **UNVERIFIED**。

## GPU evidence

72样例：N=1/3/63/64/65/257，seed521/1807，random、causal、all_finite_mask、all_inf_mask、extreme[-1e4,1e4]、tiny_prob[-110,0]。输入先真正存BF16，参考调用明确FP32输出再转BF16。独立GPU拆分 max/sub/exp/sum/div 另存 `decomposed_not_internal`，**不是官方 softmax 内部动态trace**。FP64数学参考也不是CUDA内部实现。

随机/causal对FP64→FP32诊断最大abs=1.1920928955078125e-7；tiny_prob=5.960464477539063e-8；extreme=1.2037062152420224e-35。有限行的最终BF16诊断差及ULP均0。所有mean/max relative、nearzero、输出、NaN/Inf分类见v4/softmax.json。这些是观察值，**不据此设1ULP、2ULP或统一rtol**。

有限BF16最小值全mask：输入行完全相同，结果均匀；实际加mask可能先丢失score差别，不能解释成合法“无可见key”语义。全 -inf：subtract max形成NaN，官方输出NaN；finite_count=0 时maxabs/ULP记null，仅比较NaN pattern，绝不写“0误差数值通过”。本轮未涵盖输入NaN、+inf混合以及用户级mask错误恢复，均UNVERIFIED。合法合同域要求每行至少一个有限可见logit；全mask行为另列，不假设输出零。

## 分步预算推导

1. BF16→FP32精确；有限数max仅选择操作数，不引入舍入，NaN/±inf需另定策略。
2. z_i=x_i-m≤0；FP32 RNE相减绝对误差≤u|x_i-m|（正常结果），subnormal要另加绝对舍入/FTZ模型。大负logit不能用相对概率常量代替分析。
3. exp输入误差δ使精确exp值落在[exp(z-δ),exp(z+δ)]，再加入具体库exp实现包络 η_exp(z)。underflow/FTZ采用绝对区间，不能套相对η。**η_exp 未证明，保留参数。** 当前CUDA文档列出的某函数误差不能直接赋予未知PyTorch kernel，也不能把“最大观察ULP”当严格保证。
4. 若e_i非负、正常数且无溢出，FP32加法路径≤N-1可用γ_(N-1)包络sum；若拓扑不明，只可给条件界，不能宣称已验证。至少一个max项保证理想分母≥1。实现若对sum使用不同精度则需新证据。
5. 有正分母区间[Slo,Shi]，normalize的实数区间为[e_lo/Shi,e_hi/Slo]，再加入具体div/reciprocal舍入模型。不将 exp、sum和div的最大绝对误差直接相加。
6. 最后将FP32结果区间映射为BF16 RNE可达bits；相同输入FP32 probability的cast规则BF16-EXACT。理想实数直接BF16与FP64→FP32→BF16可能double-round，必须区分。

各步理论求值要稳定并向外舍入；现有NumPy FP64诊断未实现此认证，不是冻结区间。候选输入域为记录的有限BF16 logits、N≤257的指定形状、固定可见集合；未证实 exp/subnormal/除法行为前不得批准完整FLOAT-ERROR预算。可冻结可见mask bits和明确cast边界；通用FP32 softmax容差仍BLOCKED。

来源：[NVIDIA mathematical functions](https://docs.nvidia.com/cuda/cuda-programming-guide/05-appendices/mathematical-functions.html) 区分库函数与intrinsic，部分精度表基于测试而非严格保证；[PyTorch numerical accuracy](https://docs.pytorch.org/docs/stable/notes/numerical_accuracy.html) 不保证不同批处理形状/平台逐bit一致。这些资料支持保留实现未知项，不能代替本地二进制证明。
