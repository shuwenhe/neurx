# NeurX 原生 Qwen 验收记录（2026-11-10）

**指定原生推理链路验收通过。全仓测试状态仍为 NOT DONE：三个历史 C++ Make 目标缺少测试源文件，不能宣称所有仓库测试已通过。**

最终源码在 `main`，实际执行的是官方完整 bootstrap 后安装的 Stage4 所构建的 NeurX ELF。没有把 Seed/Stage1 重命名为 Stage4，没有以参考程序提供 NeurX 输出。原模型文件、恢复点、先前日志和原 compile.log 均保留。

## 实际结果

输入严格为 `Explain how a compiler performs semantic analysis.`，没有增加聊天模板。分词为 `840,20772,1246,264,19415,26674,41733,6358,13`，与独立 tokenizer 参考一致。

原生输出（32 token，length 结束）：

> A compiler performs semantic analysis by analyzing the source code and determining the meaning of the code. This involves several steps:
>
> 1. Lexical analysis: The compiler first

- checkpoint：290 个 BF16 张量，读取实际权重 988,065,536 字节，解码 494,032,768 个元素，全部 24 层加载。
- 完整前向 40 次，层执行 960 次；9 个 prompt token 预填充，再进行 31 次 decode 前向。
- 生成 32 个 token，全部与独立 C++ 贪心参考一致；没有触发 EOS。
- 首轮全部 151,936 个 logits 比较：argmax=362 一致，最大绝对误差 9.99986912831e-07，RMS 误差 5.77270202049e-07。原生日志使用 micro 整数截断，量化步长为 1e-6。
- 首个 prompt token 的每层 first/middle/last、sum、sum-of-squares 共 120 个中间统计比较，最大绝对误差 9.93726365195e-07。没有宣称逐元素比较全部中间激活。
- logits 最小值 -17.470921、最大值 17.863359、均值 -3.019250290、标准差 3.166404098；全部有限。参考另外扫描全部 BF16 权重，拒绝 NaN/Inf。

证据目录：`artifact/local-inference/array-construction-20261110/`（下文简称 PHASE）。关键文件：

- `real-qwen-final/native.log`：全部权重名、层轨迹、151,936 logits、token ID 和最终文本。
- `real-qwen-final/execution.json`：实际 ELF 路径/哈希、环境、逐事件时间、退出码与资源。
- `real-qwen-final/numerical-verification.json`：可重算的比较结论。
- `native-final/manifest.json`：实际构建源闭包、编译器 SHA-256 和 ELF。
- `logs/real-qwen-independent-reference.log`、`bench/reference-first-logits.json`：独立对照结果。参考执行程序只用于验证，不在 NeurX 执行路径内。

## 根因与修复

1. 原生 `array_set` 为维护值语义，每次分配并复制整个数组；N 次写入形成 O(N²)。保留这一普通数组行为，增加 typed opaque TensorBuilder 与纯 bulk 操作，只在尚未发布的独占构造区内原地写入。描述符先注册进实际 GC 根，再分配 backing；seal/take 零复制发布并使所有旧 handle 失效。
2. 原先 BF16 解码、分层大数组拼接、权重切片、KV patch、向量输出和 tokenizer 表构造均反复值写入。现用原生 BF16/F16/F32 批量读取、按层 bulk copy、单次纯 slice/patch 和 typed builder。GC、ABI、所有权及错误接口见 [TENSOR_MEMORY.md](TENSOR_MEMORY.md)。
3. safetensors 手工解析器原不接受合法 JSON 空白，并会忽略第三维及整数溢出；现检查字段边界、1/2 维形状、范围、乘积和 offset。空读、EOF、缺失文件、I/O 错误具有不同的结果，不把空数组当失败。
4. tokenizer 在 skip-space 后吞掉结束括号，真实格式化 tokenizer.json 以 invalid_vocab 退出；现重新检查分隔符，缺失 merges 失败并释放 builder，缺失可选 added_tokens 安全处理，截断数组失败。Qwen EOS 优先 `<|im_end|>`。
5. 独立审查发现任意 LM Head 失败都会静默回退 embedding；现只允许配置显式 tying 且 head 真正缺失时回退，untied/损坏/截断 head 失败并清理构造区。
6. 早期 `unknown function: load_real_text_engine` 是旧单文件 Seed IR 未包含实现模块，最终在解释器函数表解析失败；不是 native linker 丢符号。构建闭包修复后暴露旧引擎实际缺失的 `neurx.inference.model_cpu_inference.` 依赖，未填入 mock。完整生命周期分析及最小复现保留在 [原诊断记录](local-inference-2026-11-10.md)。本次完成的是现有 `cmd/serve` 原生 HF 路径，旧入口仍有限制。
7. Seed 与 canonical compiler 对 string[index] 的 string/int 类型不一致，已在本地 compiler-source 修复为 unsigned-byte int，回归拒绝把 byte 传给 string 参数；没有强制转换绕过验证。补丁分别是 `tool/toolchain-patches/20261110-string-index.patch` 与增量 `20261110-native-builders.patch`。

## 编译器与原生构建

官方流程为 `make selfhost` → `native-bootstrap-no-manifest.sh` → Stage1–4 → 严格收敛/执行/源码完整性检查 → `install-distribution.py`。所有输出和安装前缀均在 NeurX 内，未修改外部 S 源码。

| 产物 | 身份/验证 |
|---|---|
| Seed | Linux amd64 C Seed，SHA-256 `629ae656b4cc5cc41dd4fef824798a5d5af8b2e431872dfaa54ed811308772b2` |
| Stage1 | Seed 真正生成的静态原生产物，SHA-256 `657168781c55d4fd9f7f25417647140139a0f8376b83c3bf9718cd311710ce7e` |
| Stage2/3/4、已安装编译器 | 全部逐字节一致，SHA-256 `892ee7893469ee702e663663cdd1c33653d22bbfffa449f8f498e87ebb2fd92c` |
| 安装驱动 | `PHASE/toolchain/bin/s` → 安装 release 的 `bin/s` |
| 已安装编译器 | `/home/shuwen/shuwen/neurx/artifact/local-inference/array-construction-20261110/toolchain/lib/s/dev-dd0c80578-4f3ad950379a98a9/bin/s_compiler` |
| 版本 | `S compiler dev-dd0c80578`，source revision `dd0c8057838cee84fd67fdd5d451ab20dc5a061e`，补丁身份由哈希和保存的 diff 确定 |

`official-bootstrap/.complete`、每阶段 compile/emit/verify/execution 日志、source-sha256 前后比较和官方安装成功日志均存在。Stage2–4 的 assembly 和 ELF 均收敛。没有改变 MIR/SSA intrinsic 签名验证，也没有禁用严格验证。普通数组 ABI 仍是长度头加 8 字节 cell；float intrinsic 参数保持既有 GP raw-slot bits 约定，由 C adapter 接收 bits。

官方开发版安装器默认写入 **`certification NOT CERTIFIED`**。这与本次已执行的 bootstrap/安装验证不是一回事；没有把开发构建称为发行版认证。完整清单见 `logs/final-compiler-identity.json`。

`native-final-audit/serve.log` 单独记录 NeurX parsing、semantic/type analysis、specialization、MIR 验证、native codegen 和 emit；其 ELF 应与实际执行的 `native-final/serve` 比较。最终运行成功退出，验证 runtime initialization 和真实生成。原 `compile.log` SHA-256 仍为 `e6b573b3c4ef1b6b4cc05ae5f417207828db3d705a6745e23e1ae1065a03ad29`；模型哈希逐项复核未变。

## 回归与失败记录

- `logs/neurx-final-installed-regression.log`：全部 27 项 native-stage4 测试通过（75.401 s）。包含原有 CLI、I/O、cluster、导入闭包、serving，以及双层 BF16 多 token 的完整 logits 数值回归。
- `logs/review-fixes-installed-green.log`：7 项构造/加载测试通过（6.123 s）；覆盖有/无 globals 的 GC 根、构造中分配压力、字符串可达性、发布后别名/值语义、双完成、sealed mutation、空读/短读/BF16/IEEE/overflow/allocator null、非法维度、错误 head、缺字段和截断 tokenizer。
- `logs/compiler-runtime-generator-direct.log`：生成器 fresh/stale/missing 非改写回归通过。误用 unittest discovery 时脚本被导入执行但没有 unittest method（exit5）；原日志保留，没有把它称为 unittest 成功。
- 红→绿证据分别保留在 `hf-assembly-*`、`hf-forward-bulk-red`、`full-logits-red`、`checkpoint-metadata-*`、`tokenizer-*`、`head-validation-correct-fixture-red` 和后续 green 日志中。
- 新 head 负向测试最初误以为 tiny fixture 缺少 LM Head，实际含有显式 head，因而错误期望失败。诊断日志保留；修正测试构造为真正移除 head 后，在保存的修复前 loader 上确认预期失败，再在当前源码确认通过。没有改变原 fixture 来掩盖问题。
- 真实 attempt1：24 层权重加载后 tokenizer invalid_vocab 退出，退出码4；attempt2 和最终运行均生成32 token。失败证据未覆盖。
- **三个历史 C++ 目标仍失败**：`tensor-runtime-native-test`、`model-runtime-native-test`、`transformer-reference-test` 引用不存在的 `test/tensor_runtime_native_test.cpp`、`test/model_runtime_native_test.cpp`、`test/transformer_reference.cpp`。`make -k` 已逐个执行，日志 `logs/legacy-cpp-targets-all.log`。没有虚构测试替代它们，因此全仓测试不能报告 PASS。

## 构造复杂度与测量

使用已安装 Stage4，两个模式分别串行跑六种规模；每项独立子进程并保存原始日志、CPU 时间、wait4 峰值 RSS、单调时钟及构造计数。小规模结果受固定启动/分配成本和计时噪声影响。RSS 包含 fork/exec 的高水位基线，不能把小样本的相同 RSS 当作每个 native array 的实际占用。分配计数仅限构造/bulk 接口，不代表全进程 malloc 总数。

### 索引构造

| 元素数 | wall s | CPU s | 峰值 RSS KiB | 构造 ms | 元素/s | 输出字节/s | 分配/复制字节 |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 4,096 | 0.004220 | 0.003394 | 17,604 | 1.747 | 2344887 | 18759099 | 2 / 0 |
| 8,192 | 0.003780 | 0.003548 | 21,828 | 1.840 | 4453222 | 35625775 | 2 / 0 |
| 16,384 | 0.004148 | 0.003890 | 21,844 | 2.086 | 7854289 | 62834313 | 2 / 0 |
| 32,768 | 0.004890 | 0.004565 | 21,844 | 2.865 | 11437958 | 91503665 | 2 / 0 |
| 1,000,000 | 0.037490 | 0.036920 | 21,844 | 34.278 | 29173656 | 233389250 | 2 / 0 |
| 10,000,000 | 0.203253 | 0.202777 | 134,144 | 197.166 | 50718696 | 405749565 | 2 / 0 |

### BF16 批量加载

| 元素数 | wall s | CPU s | 峰值 RSS KiB | 构造 ms | 元素/s | 输出字节/s | 分配/复制字节 |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 4,096 | 0.005066 | 0.004199 | 17,492 | 2.458 | 1666381 | 13331050 | 2 / 0 |
| 8,192 | 0.004548 | 0.004188 | 21,716 | 2.433 | 3367671 | 26941364 | 2 / 0 |
| 16,384 | 0.004614 | 0.004306 | 21,728 | 2.545 | 6438394 | 51507152 | 2 / 0 |
| 32,768 | 0.005196 | 0.004900 | 21,728 | 3.175 | 10321745 | 82573960 | 2 / 0 |
| 1,000,000 | 0.017025 | 0.016765 | 21,728 | 14.230 | 70273580 | 562188640 | 2 / 0 |
| 10,000,000 | 0.176386 | 0.176028 | 134,184 | 169.994 | 58825482 | 470603857 | 2 / 0 |

所有规模都是两次构造分配、零 whole-array copy、live handle 回到零；1M→10M 的 requested bytes 随 N 线性增长。实际 GC rounding 从 8MiB 升到 128MiB，不能等同于 requested bytes。原始逐元素数组值写入 32K 耗时5.49秒、复制约8GiB，原证据仍保留。新版没有每元素整数组复制；性能受内存页和固定开销影响，不声称每次样本严格线性。

## 实际推理性能

| 指标 | 最终测量 |
|---|---:|
| 权重加载 | 8.487057 s |
| 端到端首 token 就绪 | 46.752451 s |
| 生成阶段 TTFT（不含加载/tokenizer） | 36.666257 s |
| 平均相邻 token 间隔 | 4.579676 s |
| decode 吞吐（首 token 后） | 0.218356 token/s |
| 完整进程 wall | 189.082766 s |
| 用户/系统 CPU | 134.747032 / 53.263021 s |
| CPU 占一个核 | 99.433% |
| 峰值 RSS | 12,947,024 KiB（12.347 GiB） |

全部数字包含 trace；没有用独立 C++ 参考的时间冒充 S 性能。当前主要剩余成本是单线程标量 matvec、每层纯权重 slice 拷贝及 GC，尚未实现零拷贝不可变 view、SIMD/GPU 优化。构造的二次复制问题已消除，推理速度仍有明显优化空间。

## 剩余边界

- 全仓历史 C++ 测试入口缺源码，旧 direct-chat 缺模块；指定 `cmd/serve` HF 原生链路的成功不能泛化为它们已恢复。
- 当前 S tokenizer 没有通用解释 Qwen `Split` 正则的实现；本次精确验收 prompt 的9个ID与独立参考一致，但未宣称任意 Unicode/正则输入完整 parity。
- greedy 解码已实测；随机采样和 GPU 执行未计入本次验收。
- LeakSanitizer/strace 受 sandbox ptrace 限制；ASan/UBSan、实际 GC 压力测试、权重读取计数、完整 logits 和32 token独立数值验证已完成，未声称 syscall/LSan 验证成功。
- runtime OOM 保留原有 allocator 行为；测试注入返回 null 验证 builder 清理，不代表原生系统 OOM 可恢复。

## 复现命令

所有命令先 `cd /home/shuwen/shuwen/neurx`。输出目录必须使用新名称，保留旧证据。外部模型只读。

```bash
PHASE="$PWD/artifact/local-inference/array-construction-20261110"
S_SOURCE="$PWD/artifact/local-inference/compiler-source"
export TMPDIR="$PHASE/tmp"
S_NATIVE="$(dirname "$(readlink -f "$PHASE/toolchain/bin/s")")/s_compiler"
"$PHASE/toolchain/bin/s" --version

# 完整官方重跑；另用全新目录，不能覆盖当前阶段日志
(cd "$S_SOURCE" && make selfhost \
  NATIVE_BOOTSTRAP_IMPORTS_DIR="$PHASE/official-bootstrap-reproduce" \
  PREFIX="$PHASE/toolchain-reproduce" INSTALL_BIN_DIR="$PHASE/toolchain-reproduce/bin") \
  > "$PHASE/logs/official-selfhost-reproduce.log" 2>&1

S_REPO_ROOT="$S_SOURCE" S_SOURCE_ROOT="$S_SOURCE" S_NATIVE_COMPILER="$S_NATIVE" \
  python3 -m unittest discover -s test/native-stage4 -v
S_NATIVE_COMPILER="$S_NATIVE" python3 -m unittest discover -s test/native-construction -v

python3 tool/build_native.py --s-root "$S_SOURCE" --compiler "$S_NATIVE" \
  --commands serve --output-dir "$PHASE/native-reproduce"
python3 tool/run_native_acceptance.py --binary "$PHASE/native-reproduce/serve" \
  --model /home/shuwen/model/Qwen2.5-0.5B-Instruct --tokens 32 --dump-logits \
  --output "$PHASE/real-qwen-reproduce"

# 独立参考：只作验证，不向 NeurX 提供输出
 g++ -O2 -std=c++17 -Wall -Wextra -Werror \
  test/native-construction/qwen_reference.cpp src/runtime/model/json.cpp \
  src/runtime/model/bpe_tokenizer.cpp -licui18n -licuuc -licudata \
  -o "$PHASE/bench/qwen-reference-reproduce"
"$PHASE/bench/qwen-reference-reproduce" /home/shuwen/model/Qwen2.5-0.5B-Instruct \
  "$PHASE/bench/reference-logits-reproduce.json" 32 \
  > "$PHASE/logs/reference-reproduce.log"
python3 tool/verify_native_acceptance.py --run "$PHASE/real-qwen-reproduce" \
  --reference-log "$PHASE/logs/reference-reproduce.log" \
  --reference-logits "$PHASE/bench/reference-logits-reproduce.json" \
  --build-manifest "$PHASE/native-reproduce/manifest.json" \
  --output "$PHASE/real-qwen-reproduce/numerical-verification.json"

python3 test/native-construction/benchmark.py --compiler "$S_NATIVE" \
  --mode indexed --output "$PHASE/bench/indexed-reproduce"
python3 test/native-construction/benchmark.py --compiler "$S_NATIVE" \
  --mode bf16 --output "$PHASE/bench/bf16-reproduce"
```

源码修改清单：`PHASE/logs/final-modified-files.txt`。NeurX 主要涉及 runtime builder、safetensors loader、HF layer assembly、CPU forward、tokenizer、测试、复现工具和文档；compiler-source 的实际变更由两份 patch 和本地恢复快照保留。后续仍只在 main 修改。
