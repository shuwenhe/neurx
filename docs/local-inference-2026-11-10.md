# NeurX 本地推理诊断与修复记录

> 本文保留早期失败阶段的历史结论。后续已完成指定原生 Qwen 验收；当前结果和剩余限制见 [最终验收报告](NATIVE_INFERENCE_ACCEPTANCE.md)。

## 验收结论

**NOT DONE：没有完成真实 Qwen checkpoint 的完整加载，没有完成该 checkpoint 的前向传播，没有产生 logits 或生成 token。** 以下单元测试和 Stage1 诊断构建不作为最终验收成功的证据。没有用 Python、预设回答、外部 API 或 reference-model 冒充模型推理结果。

已实测的具体阻塞：原生 S 后端对每个 `array_set` 分配并复制整个数组。NeurX 使用逐元素写入初始化大张量，因此初始化为二次复杂度。直接把数组写入改为原地写入会破坏现有值语义，不能作为修复。本轮保留了语义正确性，没有加入这种替代。

全部工作目录现位于 `artifact/local-inference/`，包括 `recovery/`、`evidence/`、`compiler-source/`、`bootstrap-verified/` 和 `tmp/`。用户追加目录限制前创建的两个外部目录已移入其中；外部 S 仓库的源码、分支和 Seed 二进制已恢复。模型未被改写，原 `artifact/build/qwen-local/compile.log` 的 SHA-256 已验证未变。

## 1. 恢复点和修改范围

- NeurX 起始 HEAD：`35ab871c05bf74653e99cfe18ebef4a72b2ac019`，起始源码工作树干净。
- S 起始 HEAD：`dd0c8057838cee84fd67fdd5d451ab20dc5a061e`，起始源码工作树干净。
- NeurX 修复分支：`fix/real-local-inference-20261110`。
- `artifact/local-inference/recovery/{neurx,s}/` 保存 HEAD、状态、二进制 diff、Git recovery bundle、原日志和构建产物哈希清单。
- `artifact/local-inference/evidence/preservation-check.json` 保存原 compile.log 的校验结果。

修改文件及目的：

| 文件 | 修改 |
|---|---|
| `.gitignore` | 忽略本地恢复、工具链副本和诊断产物 |
| `makefile` | 旧 direct-chat IR 目标构建完整导入闭包 |
| `tool/build_legacy_ir.py` | 解析传递依赖，在编译阶段拒绝缺失模块；成功后才发布 IR |
| `src/model/loaders/hf_transformer.s` | 加载和验证 Q/K/V bias；加入显式启用的加载轨迹 |
| `src/model/formats/hf_config.s` | 修正省略 attention_bias 时的架构默认值 |
| `backend/platform/cpu/transformer_decode.s` | 使用 Qwen split-half RoPE 和按 head_dim 计算的频率，修正指数与平方根精度，应用 bias，记录前向和 argmax 轨迹 |
| `src/inference/executor/native_executor.s` | 显式 trace 模式记录 tokenizer 和 prompt/generated token IDs |
| `test/native-stage4/test_hf_numerics.py` | 数值、BF16、多 token 缓存、bias、tied embedding、缺失 bias 拒绝及默认值回归 |
| `test/native-stage4/test_legacy_imports.py` | 执行具有传递导入的 IR，确认函数体参与链接 |
| `tool/toolchain-patches/20261110-string-index.patch` | 保存 S 修复及回归测试，避免丢失被忽略的工具链副本修改 |
| `docs/superpowers/plans/2026-11-10-real-local-inference.md` | 计划与执行记录 |

S 修改仅保存在 NeurX 内的工具链副本及上述 patch：Seed 语义分析器、Seed standalone 字符串索引运行时、测试入口、新索引回归测试。

## 2. `load_real_text_engine` 完整生命周期

1. **声明与实现存在**：`src/inference/runtime/real_text_engine.s` 定义了非泛型函数 `load_real_text_engine(string)`；部分 GPU 文件另有 extern 声明。
2. **导入存在**：`production_chat_direct.s` 导入 `neurx.inference.runtime.real_text_engine.`。
3. **语义注册不等于代码链接**：Seed 的 `load_module_source_signatures` 等逻辑提供导入签名；单文件 `seed_compile_source_text` 只对传入源码做解析、语义分析和 IR 生成，并不将包实现自动链接进产物。
4. **不涉及泛型特化**：该函数不是泛型。
5. **旧路径不是 canonical MIR**：历史目标只对聊天入口调用 Seed 单文件编译，产出 `SSEED-TARGET-V1`。产物含 `CALL|...|load_real_text_engine|1`，没有对应 `FUNC_BEGIN`。
6. **没有发生原生机器码链接**：这份产物由 portable IR runner 执行，并非原生 Stage4 ELF。
7. **运行时解析失败**：解释器从 `FUNC_BEGIN` 构建函数表；找不到该函数后在 `runtime/runtime.c` 的 builtin/user-function 分派末端报 `unknown function`。因此不应把它归因于原生链接器丢失符号。
8. **闭包还有真实缺失依赖**：修复构建闭包后，真实旧入口明确报缺失 `neurx.inference.model_cpu_inference.`。其类型/加载接口无法由当前源码闭包提供；没有添加空实现。

根因是历史构建漏链接模块实现，并且其旧引擎依赖已经缺失。新构建会提前拒绝这一状态。最小传递导入测试已通过；旧完整引擎仍不可构建，不能报告旧引擎已恢复。最终模型目标使用独立的原生 HF 路径。

证据：`evidence/legacy-missing-function.log`、`legacy-imports-red.log`、`legacy-imports-green.log`、`legacy-full-closure.log`。

## 3. 编译器兼容性

原 Seed 把 `string[index]` 静态类型识别为 string，但 C 解释器返回 unsigned byte；standalone Seed 的索引又跳到返回单字符字符串的函数。canonical self-hosted 语义分析器则把它定义为 int。修复统一为 unsigned-byte int，未插入强制转换来绕过检查。

最小复现：

```swift
package main
func identity(int value) int { return value }
func main() int {
    string text = "A"
    return identity(text[0])
}
```

原 Seed 拒绝：`expected 'int', got 'string'`。新回归同时验证整数参数执行结果、UTF-8 首字节，以及向 string 参数传 byte 必须报错。

`evidence/compiler-inventory.json` 记录实际存在的二进制、SHA-256、文件大小、ELF 架构。Seed 与 Stage1 为 Linux/amd64；自举 Stage1 为静态 ELF。原安装命令的行为另见 `installed-identity.log`。没有把 Seed 或 Stage1 重命名成 Stage4。

官方流程使用独立副本运行 `make selfhost`，指定全新 bootstrap 目录和 NeurX 内的安装前缀。此目标包含 Stage1→Stage2→Stage3→Stage4、收敛/执行检查以及 `install-distribution.py` 安装。**完整验证和正式安装没有完成，不能宣称存在已接受的 Stage4 编译器。** 详细进度保存在 `selfhost-local.log` 和 `bootstrap-verified/`。阶段终态及回归总数见末尾执行结果。

兼容边界：Seed 的 `SSEED-TARGET-V1` 与 canonical 原生 `S-NATIVE-AMD64-V1` 不是可直接混用的对象格式。Seed standalone 运行时采用 tagged values；canonical 原生数组是长度头加 8 字节元素，浮点运算使用原生浮点表示和对应 AMD64 调用约定。现有浮点/storage/coercion/array fixture 执行验证了本轮涉及的调用与存储边界，但不能证明所有 FFI 或任意标准库兼容。正式安装的版本身份仍未建立。

## 4. 构建和回归证据

- 原生 Stage1 诊断构建成功，日志包含 `native-codegen=structured-mir-to-ssa-to-amd64`。该构建不满足 Stage4 安装验收。
- 原有 19 项 native-stage4 测试在改动前的可用 Stage1 诊断环境通过。
- 新 Seed 索引测试经历两项失败到两项通过；64 位整数测试、20 million iterations/128 MiB 内存测试、900 个整数差分用例通过。
- 三项新增数值测试经历失败到通过：RoPE、指数/RMS、BF16 双层模型多 token 前向与独立 NumPy 参考的逐维比较；同时检查 tied embedding 的 argmax、所需 bias 缺失时拒绝。
- 独立审查指出省略 attention_bias 的 bias-free 配置兼容性回归，已补充专项测试。
- Parsing/typing/MIR/codegen 的证据限于实际产物和执行过的程序；Stage2 全编译器日志已出现 `CHECK complete`，随后进入原生代码生成；后续阶段和正式安装未完成，不能泛化成整个工具链已通过。

所有 reference/小模型 fixture 测试仅验证接口及数值缺陷，绝不视为真实 checkpoint 验收。

## 5. 真实模型尝试与资源

模型：`/home/shuwen/model/Qwen2.5-0.5B-Instruct`。运行时读取配置得到 24 层、hidden size 896、vocabulary 151936、BF16。完整张量 header 和 checkpoint/tokenizer/config 哈希保存于 `model-tensor-header.json` 与 `model-manifest.json`；完整原始模型与生成配置另存为 `model-config.json`、`model-generation_config.json`，CPU/内存环境见 `host-config.json`。

实际输入严格为：`Explain how a compiler performs semantic analysis.`；请求生成 32 token。诊断 ELF 进入真实模型分支，读到 checkpoint 配置、safetensors header 和第一层参数加载，随后停留在第一层 Q 权重数组构造。

受控 30 秒采样见 `model-profile.json`：约 30.22 秒、用户 CPU 15.52 秒、系统 CPU 14.66 秒、峰值 RSS 7,556,840 KiB（约 7.21 GiB）。超时后只终止测试子进程。**完整模型加载：未完成；前向：0；logits：未产生；生成：0。** 这里的耗时是失败尝试耗时，不是推理吞吐或 token latency。

`strace` 受沙箱 ptrace 限制无法使用，错误保存在 `diagnostic-model-resource.log`，没有声称完成 syscall 级跟踪。替代证据为静态执行路径、显式运行时轨迹、小模型数值/权重缺失负向测试；完整 checkpoint 的独立输出验证仍未完成。

## 6. 已实测的阻塞

`compiler-source/src/cmd/compile/internal/codegen/amd64_program.s` 的 `array_set` 生成：分配新数组、复制全部元素、写一个元素。没有可用于大张量初始化的批量构造或经过所有权证明的原地更新。

| 元素数 | 实测 wall time | 生成代码要求复制的字节数 |
|---:|---:|---:|
| 4,096 | 0.07 s | 134,217,728 |
| 8,192 | 0.30 s | 536,870,912 |
| 16,384 | 1.33 s | 2,147,483,648 |
| 32,768 | 5.49 s | 8,589,934,592 |

每次翻倍耗时约四倍。原生 probe 均校验最终元素正确并返回 0；源码、生成汇编、完整指标在 `evidence/array-scaling/`。这些是数组性能测试，不是推理成功输出。

例如模型一组拼接 gate 权重有 `24 * 4864 * 896 = 104,595,456` 个元素。当前逐元素写入仅这一数组就要求约 `8*N*N` 字节的复制（约 87.5 PB，代码推导，并非实际运行了如此多的数据量）。这解释了为何修复编译及数学仍不能实际初始化该模型。

剩余必要能力：保持值语义的批量张量构造、切片/复制，以及受所有权/别名分析保证的高效更新，或等价且 ABI/类型经验证的原生 tensor buffer 支持。全量 C++/Python 引擎替换、直接破坏数组值语义、关闭验证均未采用。

## 7. 可复现命令

以下命令全部从 NeurX 目录运行，日志/临时文件写在其中。已有的原 compile.log 不会被覆盖。

```bash
cd /home/shuwen/shuwen/neurx
work="$PWD/artifact/local-inference"
export TMPDIR="$work/tmp"
export S_REPO_ROOT="$work/compiler-source"
export S_SOURCE_ROOT="$S_REPO_ROOT"

# Seed 修复回归（诊断用途）
python3 "$S_REPO_ROOT/test/native-bootstrap-diagnostic/test_seed_string_index.py"

# 当前 Stage1 诊断回归；不是最终 Stage4 验收
S_NATIVE_COMPILER="$work/evidence/bootstrap/stage1" \
  python3 -m unittest discover -s test/native-stage4 -v

# 官方完整自举和安装；选一个新的输出目录以保留此前记录
make -C "$S_REPO_ROOT" selfhost \
  NATIVE_BOOTSTRAP_IMPORTS_DIR="$work/bootstrap-next" \
  PREFIX="$work/toolchain" INSTALL_BIN_DIR="$work/toolchain/bin" \
  > "$work/evidence/selfhost-next.log" 2>&1
```

仅在上一步全部通过并正式安装后，才可执行下面的验收构建；当前不宣称这些步骤已成功：

```bash
installed_driver=$(readlink -f "$work/toolchain/bin/s")
installed_compiler="$(dirname "$installed_driver")/s_compiler"
make native-stage4 NATIVE_COMMANDS=serve \
  S_REPO_ROOT="$S_REPO_ROOT" S_NATIVE_COMPILER="$installed_compiler" \
  NATIVE_OUTPUT_DIR="$work/native-accepted"
NEURX_MODEL=/home/shuwen/model/Qwen2.5-0.5B-Instruct \
NEURX_PROMPT='Explain how a compiler performs semantic analysis.' \
NEURX_MAX_TOKENS=32 NEURX_TRACE=true \
/usr/bin/time -v "$work/native-accepted/serve"
```

恢复点、日志和部分 bootstrap 产物全部保留；没有提交、合并或发布代码。

## 执行终态

官方 bootstrap 在 Stage2 MIR 日志出现 `CHECK complete` 后进入代码生成。本轮在确认真实推理的二次复杂度阻塞后主动终止该构建，保留其全部新建产物；这是未完成状态，不是伪造的通过，也不是将主动终止描述成编译器报错。Stage2 原生编译器没有产出，Stage3/Stage4 与官方安装尚未执行完成。详见 `artifact/local-inference/evidence/bootstrap-status.json`。

原生浮点/数组/字符串索引回归 `test/native-float/test_execution.py` 的 8 个 fixture 子用例全部通过（1 个 unittest 测试方法）。编译器身份为诊断 Stage1。

最终审查后回归：`test/native-stage4` 共 **24 项测试通过**，耗时 296.902 秒，详见 `artifact/local-inference/evidence/final-reviewed-regression.log`。最终 Seed 索引测试 **2 项通过**，详见 `final-seed-index-fixed.log`；测试已固定工具链 cwd，避免从 NeurX 目录启动时找不到 standalone runtime 汇编。`git diff --check` 与编译器补丁反向适用检查通过。上述通过项均不改变本报告的真实模型验收 NOT DONE 结论。
