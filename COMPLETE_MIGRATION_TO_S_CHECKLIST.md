# 🎯 NeurX 100% S 语言迁移总清单

## 📊 总体统计

| 指标 | 数值 |
|------|------|
| **总需迁移脚本** | **46 个** |
| Shell 脚本 (.sh) | 35 个 |
| PowerShell 脚本 (.ps1) | 5 个 |
| Windows Batch (.bat) | 2 个 |
| JavaScript (.js) | 2 个 |
| JavaScript Module (.mjs) | 2 个 |
| **当前 S 代码** | **685 个文件 (~105K LOC)** |
| **迁移后预期** | **100% 纯 S 实现** |

---

## 🔴 优先级 1：核心功能脚本（18 个）

这些脚本涉及训练、推理、分布式计算等核心功能，必须优先迁移。

### 1.1 训练相关（4 个）
| # | 文件 | 功径 | 功能 | 工作量 | 状态 |
|---|------|------|------|-------|------|
| 1.1.1 | `run_train.sh` | `s/run_train.sh` | 训练入口脚本 | ⭐⭐⭐ | ⏳ |
| 1.1.2 | `run_with_config.sh` | `workflows/llm/pretrain/run/run_with_config.sh` | LLM 预训练配置运行 | ⭐⭐⭐⭐ | ⏳ |
| 1.1.3 | `run_with_config.sh` | `workflows/robotics/train/run/run_with_config.sh` | 机器人训练配置运行 | ⭐⭐⭐⭐ | ⏳ |
| 1.1.4 | `compile_runtime.sh` | `workflows/agent/common/compile_runtime.sh` | 编译运行时 | ⭐⭐⭐ | ⏳ |

### 1.2 推理相关（3 个）
| # | 文件 | 路径 | 功能 | 工作量 | 状态 |
|---|------|------|------|-------|------|
| 1.2.1 | `inference_runner.sh` | `artifacts/inference_output/inference_runner.sh` | 推理执行器 | ⭐⭐⭐ | ⏳ |
| 1.2.2 | `materialize_llm_checkpoint.mjs` | `tools/materialize_llm_checkpoint.mjs` | 检查点物化 | ⭐⭐⭐⭐ | ⏳ |
| 1.2.3 | `infer_llm_checkpoint.mjs` | `tools/infer_llm_checkpoint.mjs` | 检查点推理 | ⭐⭐⭐⭐ | ⏳ |

### 1.3 数据处理（2 个）
| # | 文件 | 路径 | 功能 | 工作量 | 状态 |
|---|------|------|------|-------|------|
| 1.3.1 | `fetch_github_datasets.sh` | `dataset/fetch_github_datasets.sh` | GitHub 数据集获取 | ⭐⭐⭐ | ⏳ |
| 1.3.2 | `build_transformer_e2e_bundle.sh` | `tools/build_transformer_e2e_bundle.sh` | Transformer E2E 打包 | ⭐⭐⭐⭐ | ⏳ |

### 1.4 分布式训练（3 个）
| # | 文件 | 路径 | 功能 | 工作量 | 状态 |
|---|------|------|------|-------|------|
| 1.4.1 | `monitor-shard-processing.sh` | `tools/monitor-shard-processing.sh` | 分片监控 | ⭐⭐⭐ | ⏳ |
| 1.4.2 | `quick-start-shard-logging.sh` | `tools/quick-start-shard-logging.sh` | 分片日志启动 | ⭐⭐ | ⏳ |
| 1.4.3 | `run-with-shard-monitor.sh` | `tools/run-with-shard-monitor.sh` | 运行与分片监控 | ⭐⭐⭐ | ⏳ |

### 1.5 安装和环境（3 个）
| # | 文件 | 路径 | 功能 | 工作量 | 状态 |
|---|------|------|------|-------|------|
| 1.5.1 | `install.sh` | `install/auto/install.sh` | 自动安装脚本 | ⭐⭐⭐ | ⏳ |
| 1.5.2 | `env.sh` | `arch/cann/env.sh` | CANN 环境配置 | ⭐⭐ | ⏳ |
| 1.5.3 | `find_s.sh` | `workflows/agent/common/find_s.sh` | S 编译器查找 | ⭐ | ⏳ |

### 1.6 内存工作流（3 个）
| # | 文件 | 路径 | 功能 | 工作量 | 状态 |
|---|------|------|------|-------|------|
| 1.6.1 | `run_with_config.sh` | `memory/memory_workflows/run/run_with_config.sh` | 内存工作流配置运行 | ⭐⭐⭐ | ⏳ |
| 1.6.2 | `launch.ps1` | `memory/memory_workflows/run/launch.ps1` | 内存工作流启动 (Windows) | ⭐⭐ | ⏳ |
| 1.6.3 | `run_with_config.ps1` | `memory/memory_workflows/run/run_with_config.ps1` | 内存工作流配置 (Windows) | ⭐⭐ | ⏳ |

---

## 🟡 优先级 2：辅助工具和工作流（22 个）

这些脚本用于开发、测试、监控、安装等辅助功能。

### 2.1 安装脚本（6 个）
| # | 文件 | 路径 | 功能 | 平台 | 工作量 | 状态 |
|---|------|------|------|------|-------|------|
| 2.1.1 | `install.sh` | `install/desktop/install.sh` | 桌面安装 | Linux/Mac | ⭐⭐ | ⏳ |
| 2.1.2 | `install.ps1` | `install/desktop/install.ps1` | 桌面安装 | Windows | ⭐⭐ | ⏳ |
| 2.1.3 | `install.sh` | `install/mobile/install-android.sh` | Android 安装 | Android | ⭐⭐ | ⏳ |
| 2.1.4 | `install.sh` | `install/mobile/install-ios.sh` | iOS 安装 | iOS | ⭐⭐ | ⏳ |
| 2.1.5 | `install.sh` | `install/robot/install.sh` | 机器人安装 | Robot OS | ⭐⭐⭐ | ⏳ |
| 2.1.6 | `install.sh` | `install/tablet/install.sh` | 平板安装 | Tablet | ⭐⭐ | ⏳ |

### 2.2 构建脚本（2 个）
| # | 文件 | 路径 | 功能 | 平台 | 工作量 | 状态 |
|---|------|------|------|------|-------|------|
| 2.2.1 | `build-windows.bat` | `script/build-windows.bat` | Windows 构建 | Windows | ⭐⭐ | ⏳ |
| 2.2.2 | `setup-windows.bat` | `script/setup-windows.bat` | Windows 设置 | Windows | ⭐⭐ | ⏳ |

### 2.3 文件处理和工具（4 个）
| # | 文件 | 路径 | 功能 | 工作量 | 状态 |
|---|------|------|------|-------|------|
| 2.3.1 | `create-file.js` | `script/create-file.js` | 原子文件创建 CLI | ⭐⭐⭐ | ⏳ |
| 2.3.2 | `file-creation-examples.js` | `examples/file-creation-examples.js` | 文件创建示例 | ⭐⭐ | ⏳ |
| 2.3.3 | `cleanup-old-commits.sh` | `tools/cleanup-old-commits.sh` | 清理旧提交 | ⭐⭐ | ⏳ |
| 2.3.4 | `rewrite-commit-messages.sh` | `tools/rewrite-commit-messages.sh` | 重写提交信息 | ⭐⭐ | ⏳ |

### 2.4 工作流辅助脚本（6 个）
| # | 文件 | 路径 | 功能 | 工作量 | 状态 |
|---|------|------|------|-------|------|
| 2.4.1 | `run_with_config.sh` | `workflows/agent/skills/run/run_with_config.sh` | Agent Skills 工作流 | ⭐⭐⭐ | ⏳ |
| 2.4.2 | `launch.ps1` | `workflows/agent/skills/run/launch.ps1` | Agent Skills 启动 (Windows) | ⭐⭐ | ⏳ |
| 2.4.3 | `run_with_config.ps1` | `workflows/agent/skills/run/run_with_config.ps1` | Agent Skills 配置 (Windows) | ⭐⭐ | ⏳ |
| 2.4.4 | `windows_helpers.ps1` | `workflows/agent/common/windows_helpers.ps1` | Windows 助手函数 | ⭐⭐ | ⏳ |
| 2.4.5 | `convert_to_image.sh` | `docs/flowchart/convert_to_image.sh` | 流程图转图像 | ⭐ | ⏳ |
| 2.4.6 | `QUICK_REFERENCE.sh` | `QUICK_REFERENCE.sh` | 快速参考脚本 | ⭐ | ⏳ |

### 2.5 Git 工具（2 个）
| # | 文件 | 路径 | 功能 | 工作量 | 状态 |
|---|------|------|------|-------|------|
| 2.5.1 | `rewrite-old-commits.sh` | `tools/rewrite-old-commits.sh` | 重写历史提交 | ⭐⭐ | ⏳ |
| 2.5.2 | `watch-auto-commit-push.sh` | `tools/watch-auto-commit-push.sh` | 监视自动提交 | ⭐⭐ | ⏳ |

---

## 🟢 优先级 3：开发和测试工具（6 个）

这些脚本主要用于开发辅助和自动化，优先级相对较低。

| # | 文件 | 路径 | 功能 | 工作量 | 状态 |
|---|------|------|------|-------|------|
| 3.1 | `QUICK_REFERENCE.sh` | `QUICK_REFERENCE.sh` | 快速参考 | ⭐ | ⏳ |
| 3.2 | `convert_to_image.sh` | `docs/flowchart/convert_to_image.sh` | 流程图处理 | ⭐ | ⏳ |
| 3.3 | `cleanup-old-commits.sh` | `tools/cleanup-old-commits.sh` | 提交清理 | ⭐⭐ | ⏳ |
| 3.4 | `rewrite-commit-messages.sh` | `tools/rewrite-commit-messages.sh` | 信息重写 | ⭐⭐ | ⏳ |
| 3.5 | `rewrite-old-commits.sh` | `tools/rewrite-old-commits.sh` | 提交重写 | ⭐⭐ | ⏳ |
| 3.6 | `watch-auto-commit-push.sh` | `tools/watch-auto-commit-push.sh` | 自动提交监听 | ⭐⭐ | ⏳ |

---

## 📋 迁移规划

### 第一阶段：核心功能（1-2 周）
**目标**：迁移所有优先级 1 脚本（18 个）

```
Week 1:
  Day 1-2: 训练脚本迁移 (1.1)
  Day 3-4: 推理脚本迁移 (1.2)
  Day 5:   数据处理脚本迁移 (1.3)

Week 2:
  Day 1-2: 分布式训练脚本迁移 (1.4)
  Day 3-4: 安装和环境脚本迁移 (1.5)
  Day 5:   内存工作流脚本迁移 (1.6)
```

### 第二阶段：辅助工具（1 周）
**目标**：迁移所有优先级 2 脚本（22 个）

```
Week 3:
  Day 1: 安装脚本迁移 (2.1)
  Day 2: 构建脚本迁移 (2.2)
  Day 3: 文件处理脚本迁移 (2.3)
  Day 4: 工作流脚本迁移 (2.4)
  Day 5: Git 工具迁移 (2.5)
```

### 第三阶段：开发工具（3-5 天）
**目标**：迁移所有优先级 3 脚本（6 个）

```
Week 4:
  Day 1-2: 开发和测试工具迁移 (3.x)
  Day 3-5: 测试、验证、文档更新
```

---

## 🛠️ 迁移模式

### Shell (.sh) → S 转换模式

```shell
# 原始 Shell 脚本
#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <arg>"
  exit 1
fi

for file in *.txt; do
  echo "Processing $file"
done
```

```s
// S 语言等价实现
package main

import "os"
import "fmt"
import "strings"

func main() {
    if len(os.Args) < 2 {
        fmt.Println("Usage: prog <arg>")
        os.Exit(1)
    }

    files := filepath.Glob("*.txt")
    for _, file := range files {
        fmt.Printf("Processing %s\n", file)
    }
}
```

### JavaScript (.js/.mjs) → S 转换模式

```javascript
// 原始 JavaScript
const fs = require('fs').promises;
async function main() {
  const content = await fs.readFile('file.txt', 'utf-8');
  console.log(content);
}
main().catch(console.error);
```

```s
// S 语言等价实现
package main

import "os"
import "io"

func main() {
    content := os.ReadFile("file.txt")
    fmt.Println(content)
}
```

### PowerShell (.ps1) → S 转换模式

```powershell
# 原始 PowerShell
param([string]$path)

if (Test-Path $path) {
    Get-Content $path
} else {
    Write-Error "File not found"
}
```

```s
// S 语言等价实现
package main

import "os"
import "fmt"

func main() {
    path := os.Args[1]
    
    if _, err := os.Stat(path); err == nil {
        content := os.ReadFile(path)
        fmt.Println(content)
    } else {
        fmt.Println("Error: File not found")
        os.Exit(1)
    }
}
```

### Windows Batch (.bat) → S 转换模式

```batch
@echo off
setlocal enabledelayedexpansion

if not exist "%1" (
  echo File not found
  exit /b 1
)

echo Processing %1
```

```s
// S 语言等价实现
package main

import "os"
import "fmt"

func main() {
    if len(os.Args) < 2 {
        fmt.Println("File not found")
        os.Exit(1)
    }
    
    path := os.Args[1]
    if _, err := os.Stat(path); err != nil {
        fmt.Println("File not found")
        os.Exit(1)
    }
    
    fmt.Printf("Processing %s\n", path)
}
```

---

## ✅ 迁移验证清单

### 迁移前检查
- [ ] 理解原始脚本的完整功能
- [ ] 识别所有依赖项和外部调用
- [ ] 列出所有命令行参数和环境变量
- [ ] 测试原始脚本的所有路径

### 迁移中检查
- [ ] S 代码编译无误
- [ ] 所有函数都已实现
- [ ] 错误处理完善
- [ ] 性能符合要求

### 迁移后验证
- [ ] 命令行接口与原脚本一致
- [ ] 所有测试用例通过
- [ ] 性能无显著退化
- [ ] 文档已更新

---

## 📊 预期成果

| 指标 | 当前 | 迁移后 | 进度 |
|------|------|--------|------|
| S 文件数 | 685 | 731 (+46) | - |
| 非 S 脚本 | 46 | 0 | 🎯 100% |
| 代码行数 (LOC) | ~105K | ~135K+ | +30K |
| 纯 S 实现 | 99.7% | **100%** | ✅ |
| 项目自洽性 | 部分 | **完全自洽** | ✅ |

---

## 🎯 最终目标

**当所有迁移完成后：**

```
✅ NeurX 完全由 S 语言编写
✅ 零外部脚本依赖
✅ 完全自包含的框架
✅ 跨平台原生支持 (Linux/Mac/Windows)
✅ 单一编译输出 (neurx 二进制)
```

---

## 📝 迁移状态追踪

- 🟥 **未开始** (0 个)
- 🟨 **进行中** (0 个)
- 🟩 **已完成** (0 个)

**总体进度**: 0 / 46 (0%)

