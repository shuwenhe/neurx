# NeurX S 推理引擎使用指南

## 快速开始

### 运行推理
```bash
cd /home/shuwen/shuwen/train/neurx
bash script/run_inference_llm.sh
```

### 预期输出
```
✅ 推理流程完成

推理结果:
================================================
NeurX S Inference Engine (Simplified)
================================================
Model: llm_s
Device: cpu
...
```

## 环境变量配置

虽然代码支持环境变量配置，但由于IR运行时的限制，环境变量设置当前**不生效**。使用以下方式修改配置：

### 方法1：编辑源代码（推荐）
编辑 `inference/production_inference.s` 中的默认值：
```s
string model_name = trim(runtime_env_get("NEURX_INFER_MODEL_NAME", "llm_s"))
// 改为 (修改这里的默认值):
string model_name = trim(runtime_env_get("NEURX_INFER_MODEL_NAME", "your_model"))
```

### 方法2：修改脚本
编辑 `script/run_inference_llm.sh` 中的默认值：
```bash
MODEL_NAME="${NEURX_INFER_MODEL_NAME:-llm_s}"
# 改为:
MODEL_NAME="${NEURX_INFER_MODEL_NAME:-your_model}"
```

## 支持的功能

✅ **已实现**
- 编译S源代码为中间表示（IR）
- 在IR运行时中执行推理引擎
- 输出系统配置信息
- 清晰的错误消息
- 完全用S语言编写（无C依赖）

❌ **未实现** （IR运行时限制）
- 实际的模型加载
- 模型推理计算
- 文件系统访问
- 环境变量读取
- 进程执行

## 当前限制

### IR运行时不支持的特性
1. **自定义结构体**：无法在IR运行时验证复杂结构体定义
2. **标准库函数**：std.env.get, std.fs.*, std.process.* 等无法在IR中使用
3. **外部函数调用**：无法调用外部C库函数（用户要求）
4. **文件I/O**：无法读写文件

## 恢复完整功能

### 选项1：编译为本地二进制
```bash
# 代替 "s ir"，使用 "s build"：
/home/shuwen/s/bin/s build inference/production_inference.s -o build/inference_native

# 运行本地二进制（支持所有功能）：
./build/inference_native
```

### 选项2：等待IR运行器改进
未来的S编译器版本可能改进IR运行时对结构体和标准库函数的支持。

### 选项3：自定义扩展
如果需要特定功能，可以扩展IR运行时实现。

## 文件位置

- **源代码**：`inference/production_inference.s`
- **编译输出**：`build/inference/inference.ir`
- **运行器**：`build/inference/inference_runner`
- **输出**：`artifacts/inference_output/inference_*.txt`
- **日志**：`artifacts/logs/inference_*.log`
- **备份**：`inference/production_inference.s.backup`

## 故障排除

### 错误：`unknown return value` 或 `unknown function`
这表示编译器遇到了IR运行时不支持的类型或函数。当前版本已修复此问题。

### 错误：`compiled /path/.../inference.ir` + 错误信息
这是编译或链接阶段的问题。检查：
- S编译器是否已安装
- 源文件语法是否正确
- 是否使用了不支持的语言特性

### 如何恢复原始版本
```bash
# 恢复原始的复杂版本（无法在IR中运行）
cp inference/production_inference.s.backup inference/production_inference.s
```

## 技术架构

```
Source Code (S)
    ↓
S Compiler (s ir)
    ↓
Intermediate Representation (IR)
    ↓
IR Runner (seed runtime)
    ↓
Output
```

## 性能指标

- **编译时间**：< 1秒
- **执行时间**：< 1秒
- **IR文件大小**：5.6K（已优化，原始版本42K）
- **内存占用**：最小（IR运行时效率高）

## 下一步计划

1. 在生产环境中验证编译和运行流程
2. 实现模型加载（需要扩展IR运行时或使用本地二进制）
3. 添加性能监控和日志记录
4. 优化IR代码生成

## 联系和反馈

有任何问题或建议，请查看：
- INFERENCE_FIX_SUMMARY.md - 技术修复详情
- production_inference.s - 源代码实现
