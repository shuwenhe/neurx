# Attention BF16 numerical contract — candidate v1

2026-11-27（Asia/Shanghai）。Git starting baseline `a56388ea6ebd598f26016783e20a071821c703a2`。状态：**PARTIAL / REVIEW_REQUIRED，未冻结，不授权 Native kernel 实现**。本报告在任何 Native Attention BF16 源码存在前形成；所有统计来自官方 GPU reference 与独立 CPU FP64 诊断，不使用 Native 结果拟合门限。

运行期间外部提交将HEAD更新为`c43c0577169ec178eb1c47dcf138785fd923f409`，纳入原有修改/未跟踪文件和本轮参考初版；该提交不是执行者创建，未回退。起始22项受保护文件hash均保持一致，见baseline-transition.json。

## 参考身份与范围

官方 Transformers distribution 5.15.0，modeling_qwen3_5_moe.py SHA256 `16ef7b0dc6e26eae26a6ffd0ad11d93f85424f90ffb85fbcc9eecc0759cc930d`；cache `0d5fd6901ce2b7108eff40e06d7ce29e9b0f9cc8ed2f40d2fb3a2e4d4f43e630`；generic `b60d9ecbbaeadb084134dda4a9b92419d35d22af6bc882e062fd530f4e47a4e1`；Torch functional `724c30072ca0cb69228553a636b2937ff88b60a2a2c80b806bd2a3827033e2b6`。官方数学函数体 AST SHA 保留，移除的 deprecate_kwarg/dynamic_rope_update 装饰器逐项记录；只支持 default RoPE，禁止借去除动态更新装饰器支持其他 RoPE 类型。

环境：RTX4060Ti 16GB，驱动580.159.03，nvcc12.0.140；oracle Torch2.6.0+cu124、CUDA12.4、cuDNN90100；eager显式绑定，eval/dropout0、TF32/autocast/compile关闭、BF16 reduced precision reduction关闭、deterministic启用。后者是配置，不是cuBLAS内部累加类型/算法的证明；库内部算术及softmax内部归约拓扑仍UNVERIFIED。

新增文件：test/native-construction/qwen35_attention_official_reference.py、test_qwen35_attention_official_bf16.py。原始日志/trace/fixture/provenance位于 artifact/build/qwen35_attention_bf16/reference。CPU FP64只作同操作数数学诊断，不冒充CUDA验收。大真实head fixture使用可复现seed/NumPy版本/各payload SHA manifest，首次完整fixture仍保留在本地real-head-shape-fixture.json，不提交约380MB的JSON；manifest及生成源码可重建相同BF16位模式。

## Phase A 动态结果

修复独立审查发现的两项观察/记录缺口后，参考自检7/7通过：hash拒绝、19个节点及dtype、trace on/off与重复运行逐bit一致、prefill/decode/chunks cache长度与dtype、真实head形状、非幂次D6及T1/3/63/64/65、固定seed521/1807及held-out标识7319。

实际观测：Q/K/V/shared gate projection、Q/K RMSNorm出口、文本RoPE乘/加、cache K/V、QK score、scale、mask-add、AV、sigmoid gate、gated AV、O均BF16；softmax dispatch输入tensor为BF16，dtype参数指定FP32，输出为FP32，再显式转BF16 probability。API内部的输入精度转换不等于观测到独立FP32输入buffer。Norm dispatch确认输入转FP32、pow/mean/add/rsqrt/multiply保持FP32，最后转BF16。RoPE模块仅迁移device，inv_freq保持FP32，cos/sin转换BF16；不会将整个rope module先to(BF16)而丢掉inv_freq位。

小维度seed521/1807与heldout7319：BF16各节点对独立FP64语义诊断的max abs/mean abs/max relative均0；FP32 softmax max abs为5.960464477539063e-8。T63/64/65同样只有softmax的该级差异。所有采集节点NaN/Inf=0。

真实head（合成权重/输入，H2048,QH16,KH2,D256,R64,T3，seed1807）：独立FP64语义计算后经FP32→BF16转换对官方Q/shared gate/O的max abs分别0.0625/0.03125/0.25；其他BF16节点在此case为0；FP32 softmax max abs5.960464477539063e-8。完整mean/max-relative及每节点shape/input-output dtype在real-head-shape-trace.json；不是实际checkpoint权重或真实模型hidden state，不报告模型性能。

## 比较对象必须分开

1. **官方执行重复性**：相同输入/权重/partition、同环境、trace开关的输出与cache逐bit一致，容差0。仅证明观察不干扰与确定性，不当数值正确性证据。
2. **同操作数隔离节点**：把官方实际记录的输入bits交给Native单算子，与对应官方节点比较。所有预算以相同输入为前提。
3. **数学诊断**：本harness从实际捕获的操作数进行独立FP64计算，并显式FP64→FP32→BF16转换（pointwise RoPE在每个BF16乘法/加法后转换）。这不是宣称官方库使用FP64或等价顺序；GEMM差异不能直接视作参考失败。
4. **组合Attention/跨chunk**：输入已带上游误差，不能把隔离节点预算直接套在整模块上。先用固定canonical fixture逐节点精确对齐作为首个严格目标；非精确GEMM的组合误差传播预算尚未充分建立，保留REVIEW_REQUIRED，不能凭隔离单测放行完整模块。

## 候选规则表（审查前不生效）

| 节点/状态 | 候选判定 | 依据与限制 |
|---|---|---|
| 输入/权重存储、Q/gate split、layout、cache写读、tail/pass维、reset有效长度、maskbits | BF16原始bits或整数状态精确相等，0容差 | 没有数值归约；必须验证实际GPU element_size=2，而非只核对host float值 |
| BF16 scale、mask-add、RoPE每次mul/add、probability cast、gate乘法 | 同输入与相同dtype边界逐bit相等；0容差 | Torch可见操作语义，不将乘加合并，不把未舍入FP32值直接继续用 |
| Q/K RMSNorm的BF16出口 | 同输入、相同1+weight语义，先以官方BF16出口bit-exact为门禁 | FP32 norm和weight乘法后最后一次BF16转换；不照搬DeltaNet规则；FP32内部reduction单独比较 |
| RoPE频率/cos/sin与sigmoid等transcendental | 当前固定fixture以实际官方可见BF16边界精确比较 | 更广输入/大位置的数值误差来源和近似界UNVERIFIED；若不精确须独立参考证据与重审，不能按Native失败反向给ULP |
| Linear、QK、AV：Native FP32 accumulator 对精确数学dot | E_n=gamma_n*sum(abs(a_i*b_i))，正常数/无overflow/无FTZ影响条件下逐元素绝对界 | u=2^-24，gamma_n=n*u/(1-n*u)，BF16正常乘积可由FP32表示；必须核查实现累加模型，不声称证明库算法 |
| BF16 GEMM出口 | 候选：由同操作数数学dot±E_n经BF16 RNE所得闭区间；区间塌缩时精确相等 | 双方是否遵守同一模型须分别验证。区间非零宽时只作诊断，尚未批准替代官方逐节点门禁 |
| FP32 softmax output | 候选合同待专项审查；本轮参考-only观测最大abs约1个FP32 ULP，不等于已制定1-ULP通用界 | 内部exp/归约拓扑未证明，不从观测最大值乘常数定义阈值；完整固定FP32预算仍PENDING |
| FP32 norm中间量 | 归约按gamma_n模型；rsqrt/mean/weight乘法的传播预算待审查 | 不能将GEMM的gamma_n直接套完整norm，也不能复制DeltaNet rtol |
| 模块output及prefill/decode/chunk组合 | 需在上述预算审核后冻结组合误差传播规则，再给模块PASS | 本轮未冻结，不能只测单次forward代替cache验收 |

本候选表刻意保留尚无足够证据的条目，不将不完整预算标为FROZEN。首次Native实现之前必须由人审查并明确精度/输入范围；尚未证明的transcendental/组合传播要么补参考证据，要么以严格精确规则限定范围并明确验收范围，不能静默放宽。

## FP32 点积理论及独立校准

对正常有限数、无溢出/无FTZ影响的FP32累加模型，n项dot采用前向绝对误差界 gamma_n*S，S=sum(abs(a*b))，gamma_n=n*u/(1-n*u)。这是先验算术模型，不是从本轮差异拟合。n=2048时gamma=0.00012208521548040532，n=4096时0.0002442002442002442，n=256时1.5259021896696422e-5。

真实head case的官方输出落在候选量化区间内（outside count=0）；QG共享未split张量bound最大0.026230394743822272、区间最大宽0.125；O bound最大0.3167708301883817、量化区间最大宽1.0。**这些区间较保守且不证明库实现精度**。Q/gate记录的diagnostic标为whole unsplit QG linear tensor，避免把整个QG计数误当单Q计数。该统计仅证实本case与该模型相容，不能据此冻结全模型、任意长度或任意subnormal输入预算。

不采用BF16相对误差常量掩盖取消误差；near-zero独立记录。max relative分母floor为FP32 tiny（1.1754943508222875e-38），它是诊断指标，不单独作为所有节点通过阈值。所有最新记录含max abs、mean abs、max relative、near-zero计数、NaN/Inf与位置、BF16 bit mismatch/最大ULP（FP32节点为null）、shape/stride/layout、逻辑GPU tensor字节数、input/output dtype与舍入描述。逻辑字节数不等于独立allocation或显存峰值，view可能共享底层storage。

## 冻结流程与阻塞

- 当前没有backend/platform/cuda/hybrid_attention_bf16.h/.cu，也没有Native Attention BF16候选结果；新结果不会进入容差制定过程。
- 独立审查需要复核AST数学函数体、观察器无干扰、参考版本与上述理论适用条件；审查意见与修正保留。
- 已获批准的TEST_PLAN明确“候选预算文档必须在看到native结果前人工审查并SHA冻结；未冻结就停止实现验收”。因此独立代码审查不能自动替代该人工预算决定。
- 人工确认具体规则、未决项目处理和输入范围后，生成不可变budget ID、完整文件SHA、签审记录，并且先将预算配置写入测试，再开始Batch1 RED→GREEN。若有条目仍PENDING，不进入依赖它的Native批次。
- 不修改历史报告，不放宽现有FP32/DeltaNet容差。正式Bridge/Preflight、MoE/Decoder/E2E全部未动。

## 真实测试命令及状态

```bash
CUBLAS_WORKSPACE_CONFIG=:4096:8 PYTHONDONTWRITEBYTECODE=1 \
  artifact/reference-env/bin/python test/native-construction/test_qwen35_attention_official_bf16.py
```

GPU参考自检PASS不等于Native数值PASS。Sanitizer针对新Native路径尚不存在，状态UNVERIFIED；prefill延迟/TPOT/launch/显存读写量/转换开销均UNVERIFIED，不能以本7项参考测试总耗时替代组件或模型性能。后续Phase1/Phase2/KV/FINAL报告须保持真实阶段状态。
