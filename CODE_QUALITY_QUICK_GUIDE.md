# 代码质量问题 - 快速参考指南

## 📋 问题概览

```
总文件数: 849 个 .s 文件
总问题数: 300+ 个 (5 个大类)

严重性分布:
🔴 P0 (严重): 99+ 个问题 (硬编码路径、错误处理)
🟡 P1 (中等): 130+ 个问题 (空函数、代码重复)
🟢 P2 (低级): 71+ 个问题 (调试信息、命名规范)
```

---

## 🎯 按文件统计的问题分布

### Top 10 最多问题的文件

| 文件 | 硬编码路径 | 空函数 | 其他问题 | 总计 |
|------|----------|--------|---------|------|
| neurx/scripts/legacy/distributed_training.s | 3 | 2 | - | 5 |
| neurx/distributed/cuda_bridge.s | 1 | 5 | - | 6 |
| neurx/checkpoint/distributed.s | 2 | 4 | - | 6 |
| neurx/inference/production_inference.s | 2 | 0 | - | 2 |
| neurx/scripts/convert_medmcqa_complete.s | 3 | 0 | - | 3 |
| neurx/cuda/build_all.s | 1 | 0 | - | 1 |
| neurx/trainer/monitor.s | 0 | 1 | 1 debug | 2 |
| neurx/posttrain/adapter/ | 2 | 0 | - | 2 |
| neurx/distributed/multi_node_launcher.s | 0 | 1 | - | 1 |
| neurx/engine/training_orchestrator_complete.s | 0 | 2 | - | 2 |

---

## 🔍 问题速查表

### 硬编码路径问题 (73+ 处)

**快速定位**: `grep -r "/home/shuwen\|/opt\|/data" neurx --include="*.s"`

**修复模板**:
```s
// ❌ 之前
string path = "/home/shuwen/shuwen/train/model/model.pt"

// ✅ 之后  
string path = runtime_env_get("NEURX_MODEL_PATH", 
    runtime_env_get("HOME", ".") + "/models/model.pt")
```

**涉及的环境变量建议**:
- `NEURX_HOME` - NeurX 项目根目录
- `NEURX_MODEL_PATH` - 模型存储路径
- `NEURX_DATA_PATH` - 数据目录
- `S_COMPILER` - S 编译器路径
- `NEURX_DEBUG` - 调试模式开关

---

### 空函数体问题 (65+ 处)

**快速定位**: `grep -r "func.*{[\s]*}$\|func.*{[\s]*}" neurx --include="*.s"`

**修复优先级**:

| 优先级 | 函数类型 | 数量 | 建议 |
|--------|---------|------|------|
| 🔴 P0 | CUDA/GPU 操作 | 8+ | 必须实现或 panic |
| 🔴 P0 | 检查点/保存操作 | 6+ | 必须实现或 panic |
| 🟡 P1 | 日志/监控函数 | 15+ | 实现或标记 TODO |
| 🟢 P2 | 工具函数 | 36+ | 实现或移除 |

**修复模板**:

```s
// 选项 1: 实现功能
func some_operation() {
    // ... 实现逻辑 ...
}

// 选项 2: 标记为 TODO (推荐)
func some_operation() {
    // TODO: Implement this function
    // Feature: Description of what this should do
    // Context: Why it's not implemented yet
}

// 选项 3: 使用 panic 拒绝
func some_operation() {
    panic("some_operation not yet implemented")
}
```

---

### 错误处理问题 (26+ 处)

**快速定位**: `grep -r "return nil,\|err != nil" neurx --include="*.s" | grep -v "if err"`

**常见模式**:

```s
// ❌ 模式 1: 忽略返回值
result, err := operation()

// ❌ 模式 2: 检查但未处理
if err != nil {
    println(err)  // 只是打印，没有实际处理
}

// ✅ 模式 3: 正确处理
result, err := operation()
if err != nil {
    return nil, fmt.Errorf("operation failed: %v", err)
}
```

**修复步骤**:
1. 确认所有返回错误的函数都被检查
2. 确保错误被正确传播或处理
3. 添加适当的错误消息上下文

---

### 代码重复问题 (15+ 处)

**重复函数列表**:

| 函数名 | 出现次数 | 第一个定义 | 建议动作 |
|--------|---------|-----------|---------|
| `trim()` | 6+ | cluster_orchestration.s | 提取到 util |
| `split_lines()` | 6+ | cluster_orchestration.s | 提取到 util |
| `positive_mod()` | 3+ | scaled_training_system.s | 提取到 util |
| `sleep_seconds()` | 2+ | multi_node_launcher.s | 提取到 util |
| `printf()` mock | 5+ | test_suite_complete.s | 统一到一个地方 |

**修复步骤**:

1. 创建 `neurx/util/common.s`:
   ```s
   package neurx.util.common
   
   func trim(string s) string { ... }
   func split_lines(string text) []string { ... }
   func positive_mod(int value, int modulus) int { ... }
   ```

2. 在其他文件中导入:
   ```s
   use neurx.util.common.{trim, split_lines, positive_mod}
   ```

3. 删除重复的定义

---

### 调试信息残留 (22+ 处)

**快速定位**: `grep -r "debug\|DEBUG" neurx --include="*.s" | grep -E "bool debug|NCCL_DEBUG|log_debug"`

**修复模板**:

```s
// ❌ 硬编码 debug 标志
bool debug_enabled = true
if debug_enabled {
    println("Debug info")
}

// ✅ 使用环境变量
bool debug_enabled = runtime_env_get("NEURX_DEBUG", "false") == "true"
if debug_enabled {
    println("Debug info")
}
```

**建议的统一日志系统**:

```s
// neurx/util/logging.s
func log_debug(string msg) {
    if runtime_env_get("NEURX_DEBUG", "false") == "true" {
        println("[DEBUG] " + msg)
    }
}

func log_info(string msg) {
    println("[INFO] " + msg)
}

func log_error(string msg) {
    println("[ERROR] " + msg)
}

// 使用
use neurx.util.logging.{log_debug, log_info, log_error}

func my_function() {
    log_debug("Starting operation")
    log_info("Operation in progress")
    if error {
        log_error("Operation failed")
    }
}
```

---

## 📊 修复工作量估计

### 按优先级分类

| 优先级 | 问题类型 | 数量 | 工作量 | 预计时间 |
|--------|---------|------|--------|---------|
| 🔴 P0 | 硬编码路径 | 73 | 3小时 | 3h |
| 🔴 P0 | 错误处理 | 26 | 4小时 | 4h |
| 🟡 P1 | 空函数体 | 65 | 6小时 | 6h |
| 🟡 P1 | 代码重复 | 15 | 3小时 | 3h |
| 🟡 P1 | 调试信息 | 22 | 2小时 | 2h |
| 🟢 P2 | 其他问题 | 99 | 4小时 | 4h |
| **总计** | | **300+** | **22小时** | **1周内可完成** |

---

## ✅ 修复检查清单

### 第 1 天 - P0 问题

- [ ] 搜索并列出所有硬编码路径
- [ ] 创建环境变量映射表
- [ ] 替换硬编码路径为环境变量
- [ ] 验证代码能在不同路径下运行

### 第 2 天 - P0 错误处理

- [ ] 找出所有未检查的返回值
- [ ] 为每个错误添加处理逻辑
- [ ] 添加适当的错误消息
- [ ] 测试错误路径

### 第 3 天 - P1 空函数

- [ ] 分类所有空函数（实现 vs TODO vs panic）
- [ ] 实现关键功能（CUDA、检查点等）
- [ ] 标记非关键的 TODO
- [ ] 删除不需要的空函数

### 第 4 天 - P1 代码重复

- [ ] 识别所有重复的函数
- [ ] 创建 `neurx/util/` 目录
- [ ] 提取通用函数
- [ ] 更新所有导入
- [ ] 验证功能完整性

### 第 5 天 - P1 调试信息

- [ ] 统一日志系统
- [ ] 替换硬编码的 debug 标志
- [ ] 清理临时调试代码
- [ ] 文档化调试方式

### 第 6-7 天 - P2 问题

- [ ] 修复包名声明
- [ ] 检查未使用的导入
- [ ] 优化超大文件
- [ ] 最终验证和测试

---

## 🔧 自动化检查脚本

创建 `neurx/scripts/check_quality.sh` (改写为 .s 后续):

```bash
#!/bin/bash

echo "=== NeurX Code Quality Check ==="
echo

# 1. 检查硬编码路径
echo "1. Hardcoded paths:"
HARDCODED=$(grep -r "/home/shuwen\|/opt/\|/data/" neurx --include="*.s" | wc -l)
echo "   Found: $HARDCODED"

# 2. 检查空函数
echo "2. Empty functions:"
EMPTY=$(grep -r "func.*{[\s]*}$" neurx --include="*.s" | wc -l)
echo "   Found: $EMPTY"

# 3. 检查 TODO/FIXME
echo "3. TODO/FIXME comments:"
TODO=$(grep -r "TODO\|FIXME" neurx --include="*.s" | wc -l)
echo "   Found: $TODO"

# 4. 检查 nil 检查缺失
echo "4. Potential nil checks:"
UNCHECKED=$(grep -r "return nil," neurx --include="*.s" | wc -l)
echo "   Found: $UNCHECKED"

echo
echo "=== Summary ==="
TOTAL=$((HARDCODED + EMPTY + TODO + UNCHECKED))
echo "Total issues: $TOTAL"
echo "Priority levels:"
echo "  🔴 P0: $(($HARDCODED + $UNCHECKED))"
echo "  🟡 P1: $EMPTY"
echo "  🟢 P2: $TODO"
```

---

## 📚 相关文档

- 完整报告: `CODE_QUALITY_REPORT.md`
- 问题详情: `CODE_QUALITY_ISSUES_DETAILED.md`
- 本指南: `CODE_QUALITY_QUICK_GUIDE.md`

---

## 🎓 最佳实践

### 路径处理
```s
// ✅ 正确做法
BASE_DIR := runtime_env_get("NEURX_HOME", ".")
MODEL_PATH := BASE_DIR + "/models/model.pt"
```

### 错误处理
```s
// ✅ 正确做法
result, err := operation()
if err != nil {
    return nil, fmt.Errorf("operation failed: %w", err)
}
```

### 代码组织
```s
// ✅ 正确做法：提取通用函数到 util 包
use neurx.util.common.{trim, split_lines}
```

### 日志记录
```s
// ✅ 正确做法：使用环境变量控制调试
use neurx.util.logging.{log_debug, log_info}

log_debug("Operation started")
```

---

## 📞 支持

如有问题，参考：
1. `CODE_QUALITY_REPORT.md` - 完整分析
2. `CODE_QUALITY_ISSUES_DETAILED.md` - 详细问题列表
3. S 语言文档 - 语法和最佳实践

