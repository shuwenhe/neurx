# Qwen3.5 MoE Stage 1：配置、Registry、mmap 实现报告

日期：2026-11-26（Asia/Shanghai）。分支：`feat/qwen35-native`。基线：`781e8e6b01c01aa407901fd0a60ea0ed6dd362cc`。

**状态：阶段1代码与专项验收通过；全量旧回归门禁未通过，尚未进入阶段2。不是Decoder/推理完成报告。**

实施计划：[2026-11-26-qwen35-native.md](../superpowers/plans/2026-11-26-qwen35-native.md)。原有四份设计的未提交修订在开始时已存在，本次保留；开发授权来自用户明确批准，不把原文档中的审批快照当作新的拒绝。

## 已实现

| 文件 | 实际行为 |
|---|---|
| `src/runtime/model/hybrid_config.h/.cpp` | 严格嵌套配置、显式layer_types、Full/Delta/MoE形状、checked FP32状态容量计算；未知属性、冲突RoPE/错误head比率/不支持语义拒绝 |
| `src/runtime/model/strict_model_json.h` | 整数checked算术、重复键拒绝、有界regular-file读取、O_NOFOLLOW/O_NONBLOCK、checked pread |
| `src/runtime/model/mapped_weight_store.h/.cpp` | read-only mmap、不整读payload、分片/index/总大小/完整范围检查、shape/dtype/溢出/metadata预算、3D expert与2D row切片、共享mapping生命周期 |
| `src/runtime/model/architecture_registry.h/.cpp` | Qwen hybrid metadata adapter；逐层text shape/dtype manifest；vision/MTP显式非执行；`runtime_supported=false` |
| `test/native-construction/qwen35_stage1_probe.cpp`、`test_qwen35_stage1.py` | 独立C++执行与Python byte/header oracle、真实checkpoint核对、负例、生命周期/fd/RSS测试 |

新代码使用已存在的系统nlohmann JSON/OpenSSL EVP SHA256，未安装依赖。元数据身份包含配置、index、headers与文件大小，**不包含payload内容，不能作为完整模型hash、缓存安全指纹或Q4源权重完整性证明**；后续Q4仍须源tensor/payload hash。

所有GPU分配仍为零。没有新增CUDA Kernel、没有生产bridge接入、没有修改Makefile或Preflight；旧Dense/Qwen2.5/DeepSeek源码未变。现有门禁仍拒绝新架构，防止metadata识别被误认为推理能力。

## TDD与失败修复

1. 初始RED：新probe找不到hybrid_config/mapped_weight_store/architecture_registry接口，编译失败；随后实现基础模块。
2. 首轮测试发现一个测试输入错误：tiny fixture key_heads=1时value_heads=3仍可整除，不能判非法。改为key_heads=3/value_heads=2，保持通用head ratio规则，不把生产实现错误收紧到只有2倍。
3. 新增负例RED：滑窗配置被接受、index total_size未核对。实现显式拒绝与payload合计校验；真实index的浮点序列化整数total_size在安全精确范围内允许，shape/offset仍只接受整数JSON。
4. 独立审查提出Important：FIFO在open阻塞、index预算漏掉原始空白、未知config属性未拒绝。新增RED测试复现三入口超时/空白预算/unknown语义，修复后GREEN。复查无遗留Important。

## 实际验证

```bash
PYTHONDONTWRITEBYTECODE=1 python3 test/native-construction/test_qwen35_stage1.py
```

**11 tests PASS**，内部包含多组subtests：

- 真实及tiny配置、独立literal状态容量、重复键、未知语义/错误dtype/head/shape。
- 手工字节fixture校验expert/rows切片与越界；store销毁后slice继续有效。
- 缺分片/不一致index/total_size、shape溢出、截断/overlap/gap、非法dtype/重复tensor、父/绝对/symlink路径拒绝。
- config/index/shard FIFO均在2秒timeout内明确失败，不阻塞。
- index原始空白字节计入调用方metadata预算；header预算独立生效。
- 成功与失败路径重复128次open的fd计数不增长。
- 4GiB sparse payload仅扫描metadata，RSS不随payload扩大到4GiB；96MiB专项RSS门限通过。
- 真实expert7的32字节样本与Python直接seek/read相同，不生成或伪造推理结果。

使用`-Wall -Wextra -Werror`编译通过。另以`-fsanitize=address,undefined -fno-omit-frame-pointer`重新编译，开启leak detection及halt_on_error，运行同一套11测试：**PASS，未报告ASan/UBSan/leak错误**。日志：`artifact/build/qwen35_stage1/sanitizers.log`。

真实模型probe确认：26分片，1045tensor，693text/333vision/19MTP，payload=71,903,645,408 bytes。映射虚拟bytes=71,903,776,776，不等于物理RSS；单次直接运行约8MiB RSS，Python报告驱动下约12MiB，详见[机器报告](QWEN35_MOE_STAGE1.json)，均远低于96MiB测试上限。metadata扫描毫秒级时间不等于权重加载/TTFT或模型性能。

context2048的FP32状态：KV83,886,080 bytes；Delta recurrent62,914,560 bytes；conv3,932,160 bytes。这里只计算容量，没有分配GPU状态。

## 回归结果与未通过项

- Preflight：4 tests PASS；startup：5 tests PASS，开始和修改后均通过。
- 全套`make native-stage4-test`：**Ran 16 tests，errors=3，未通过**。日志`artifact/build/qwen35_stage1/native-stage4.log`：
  - `test_hf_numerics.NativeHFNumerics.setUpClass`：已有S编译器编译serve失败，`canonical parser:2487: unsupported string escape`。
  - `test_serving.NativeServing.setUpClass`：同一serve构建/解析失败。
  - `test_legacy_imports.LegacyImports.test_compiles_transitive_import_implementations`：缺少已有`artifact/build/s_runner/s_ir_runner`，FileNotFoundError。
- 失败所用既有S源、tool、Makefile、legacy loader/bridge均与HEAD无diff；新增C++模块没有接入这些构建。上述为既有路径/环境阻塞的证据，不将其当成通过，也不修改外部S编译器解决。

整体回归门禁尚未满足，因此**阶段2未开始**。下一步先解决或定位这三项旧回归阻塞，再按计划冻结阶段2独立参考/容差并实现新算子。当前不宣称可以运行目标make inference。

## 审阅与保留限制

独立代码审阅及修复复查已完成，三项Important已关闭。保留Minor：vision/MTP目前只按声明与prefix清点，不验证其全部非执行模块shape/层编号；text693项精确验证。mmap失败分支虽RAII静态检查无泄漏，尚未故障注入专门触发；outer/rope未知字段的实现有白名单，但专项负例主要覆盖text。后续进入对应模块时补覆盖，不扩大本阶段为vision/MTP支持。

尚未执行新架构算子、BF16 dtype探针、Q4转换、全层数值、prefill/decode/生成、GPU预算和性能验收。所有相关容差与质量/吞吐结论仍PENDING。未推送、未合并、未修改模型权重或外部源码。
