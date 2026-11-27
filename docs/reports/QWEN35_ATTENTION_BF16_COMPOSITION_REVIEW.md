# Attention BF16 composition review

2026-11-27；基线d27229a8；状态 **PARTIAL / conditional theory only**。

## 两类实际证据

Canonical fixture固定seed521、H12/QH4/KH2/D8/R4，T=3/17/65；三种分区prefill、逐token decode、chunks=[1,T-1]，共9记录。官方输出和最终K/V相对prefill全部max/mean abs和max relative=0。只证明这些样例的官方分区一致性，不证明真实模型或任意CUDA GEMM分区一致。

另对每个T的同一输入第一个BF16元素移动一个可表示步长，执行完整官方prefill。记录各节点相对未扰动节点的总变化，以及扰动运行内部的同操作数FP64局部误差。三个T中总变化的最大abs均为：Q投影0.0009765625、K Norm0.0078125、score0.03125、softmax0.0019480586051940918、probability0.00390625、最终O0.001953125。完整mean/max-relative/nearzero见v4/propagation.json；这些是上游扰动响应，不是Native误差、统计置信界或验收阈值。没有在每个内部节点注入独立误差；广泛最坏情况传播仍UNVERIFIED。

## 逐坐标构造，拒绝最大误差求和

令实际输入坐标误差包络E_A/E_B≥0。矩阵乘法真实数学传播为 `|A|E_B + E_A|B| + E_A E_B`；随后另加本算子浮点dot误差。线性权重完全相同则E_B=0。局部dot条件界γ_nΣ|a_i b_i|要求具体FP32累加模型、有限正常数无上下溢/FTZ；库符合此前提未证实。原harness用FP64求中心及Σ绝对乘积，仍有FP64误差，不是严格向外舍入证书。需精确BF16整数/有理点积或加入FP64自身误差后向外舍入。

Norm采用NORM_REVIEW逐坐标区间，考虑输入误差引起的平方/均值/rsqrt变化；BF16量化不连续，不能直接把实数Jacobian当量化实现Lipschitz界。Partial RoPE对旋转坐标的线性误差为 |cos|E_x+|sin|E_rot（频率若变再计交叉项），**每次BF16乘/加都映射舍入单元**，tail精确复制。

Score按QK传播式；scale、mask按同可见集合逐步RNE。可见集合发生变化时不使用同域连续界。对实数有限logits的softmax，有Jacobian行绝对和2p_i(1-p_i)≤1/2，因此 `||Δp||∞≤0.5||Δz||∞`。这只涵盖实数输入传播，FP32实现误差/转换必须另加。

更紧逐坐标概率区间：若l≤z≤h，`p_i^- = 1/(1+Σ_(j≠i) exp(h_j-l_i))`，`p_i^+ = 1/(1+Σ_(j≠i) exp(l_j-h_i))`。必须稳定求值并向外舍入，mask固定，非有限域另处理。这里是推导式，不是已实现并验证的认证求值器。

AV使用矩阵交叉项传播；sigmoid实数导数≤1/4，但需另加库sigmoid误差。gated AV误差是 |gate|E_AV+|AV|E_gate+E_AV E_gate，加BF16乘法舍入，再经O投影。每个BF16边界可跨舍入单元，不能只相加节点最大值；cache历史误差沿K/V区间逐token传播，不因decode而清零。

## 冻结与剩余项

可以冻结计算图、fixture、可见mask规则和逐舍入边界；相同操作数局部精确目标可先列合同。不能冻结完整组合数字预算：Norm rsqrt、Softmax exp/div、sigmoid库误差及严格向外舍入实现均缺可靠证据。有限canonical样例全部相等也不能证明全域0预算。原历史大head fixture已证明官方与FP64投影有差异，更不能推广canonical bit-exact为通用矩阵乘法合同。Native保持未启动。
