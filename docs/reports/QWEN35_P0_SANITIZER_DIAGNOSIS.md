# CUDA Compute Sanitizer 诊断

状态：**PASS（最小程序及本次 FP32/BF16 probe）**。

日期：2026-11-27（Asia/Shanghai）。起始 HEAD：`cba0f5a3`；实现 Git Commit：`9e8dd875`。本报告与原始证据由后续文档提交保存，可用 `git log -1 --format=%H -- docs/reports/QWEN35_P0_SANITIZER_DIAGNOSIS.md` 查询。

环境：RTX 4060 Ti，16380 MiB VRAM，驱动 580.159.03；nvcc 12.0.140；Compute Sanitizer 2022.4.1。CUDA runtime API 12000、driver API 13000，设备数 1，三个 API 均返回 0。官方参考 torch 2.6.0+cu124 / CUDA 12.4 / cuDNN 90100；TF32/autocast/compile 关闭。真实 GPU 测试在宿主机执行，普通沙箱仍隔离 GPU。版本与硬件日志位于 `artifact/build/qwen35_p0_20261127/`。

## 复现与根因

独立最小 `cuda_sanitizer_minimal.cu` 执行 cudaMalloc、32-thread fill、同步与 D2H 数据检查，直接运行打印 CUDA_MINIMAL_PASS。旧 sanitizer 命令在第一次有效插桩之前退出，真实目标没有启动。strace 明确记录：

```text
execve("/usr/lib/nvidia-cuda-toolkit/compute-sanitizer/TreeLauncherSubreaper", ...) = -1 ENOENT
```

现有系统包装布局分离：helper 位于 `/usr/bin/TreeLauncherSubreaper` 和 `/usr/bin/TreeLauncherTargetLdPreloadHelper`，共享库位于 `/usr/lib/nvidia-cuda-toolkit/compute-sanitizer`。--injection-path 同时影响 helper 查找；只指定库目录仍缺 helper。ldd 还显示 libInterceptorInjectionTarget.so 的依赖解析需要覆盖库目录；仅加 LD_LIBRARY_PATH 不能解决 helper ENOENT。完整复现与诊断日志为 minimal-*.log、minimal-strace.log（含完整失败路径）。

使用完全相同的已安装 sanitizer、驱动和 kernel，修复文件布局后能有效插桩，故此次退出的已证根因为包装路径，不是已证实的 CUDA/驱动不兼容。runtime12000 与 driver13000 已真实完成 kernel，不仅比较版本字符串。

## 修复与编译参数

新增 `scripts/run_cuda_sanitizer.py`：在 NeurX 内 `artifact/build/cuda_sanitizer_bundle/` 建立上述原系统共享库/helpers 的只读文件链接；拒绝覆盖非预期条目；进程级 LD_LIBRARY_PATH 与 --injection-path 指向该目录。无系统安装、无 /usr 修改。工具 --target-processes all、--error-exitcode 99；非零状态透传，无有效零错误 summary 则拒绝通过。summary 本身不足以证明插桩，因此还强制执行本次正负对照验收。

最小程序最初按 -O2 -lineinfo 编译遇到 nvcc12 与宿主 glibc fortify 头兼容错误（28 个 __builtin_dynamic_object_size 未定义）；使用仓库 CUDA 测试既有 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 后构建通过。此兼容编译参数只用于测试程序；不修改系统头或工具链。BF16 probe 同时使用 --fmad=false。-lineinfo 生效：负对照报告定位到 cuda_sanitizer_minimal.cu 的实际源代码行；无需把未带行信息的零报告当作证据。

## 验收

```bash
python3 test/native-construction/test_cuda_sanitizer_p0.py
python3 scripts/run_cuda_sanitizer.py --tool memcheck -- artifact/build/qwen35_stage3/probe < artifact/build/qwen35_native_20261127/sanitizer-input.json
python3 scripts/run_cuda_sanitizer.py --tool initcheck -- artifact/build/qwen35_stage3/probe < artifact/build/qwen35_native_20261127/sanitizer-input.json
python3 scripts/run_cuda_sanitizer.py --tool memcheck -- artifact/build/qwen35_p0_20261127/bf16-probe < artifact/build/qwen35_p0_20261127/bf16-sanitizer-input.json
python3 scripts/run_cuda_sanitizer.py --tool initcheck -- artifact/build/qwen35_p0_20261127/bf16-probe < artifact/build/qwen35_p0_20261127/bf16-sanitizer-input.json
```

最小 clean memcheck/initcheck 均 exit0、CUDA_MINIMAL_PASS、ERROR SUMMARY: 0 errors。故意 OOB device write 和 uninitialized device read 的负对照分别被对应工具捕获，exit99，附源代码行与非零 error summary；4/4 测试通过。不是模拟硬件或伪造错误数据，负对照实际运行有错误的独立测试 kernel。其 RED 日志在添加故障模式之前有两项失败，保留为 sanitizer-controls-red.log；最终日志 sanitizer-controls-final.log，4项/3.616s/OK。

既有 FP32 DeltaNet probe 两工具均有效零错误。新 BF16 probe 包含原 FP32 diagnostic 控制与 BF16 native，每次 5 token，memcheck/initcheck 均有效零错误。详见 deltanet-*-fp32.log、bf16-memcheck.log、bf16-initcheck.log 与 final-commands.json。

限制：这是指定程序与输入的插桩结果，不是所有输入/异常/完整模型内存安全证明；racecheck/synccheck 未执行。脚本适配当前系统包的布局，不保证跨发行版路径。未使用或安装新版 sanitizer。数值误差不属于 sanitizer 的验收指标；数值见 BF16 根因报告。
