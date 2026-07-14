# NeurX 待迁移到 S 的清单

## 概述
当前 NeurX 项目中有 **2 个 JavaScript 文件**需要迁移到 S 语言实现。这份清单按照优先级和迁移复杂度排列。

---

## 优先级 1（高）：CLI 工具迁移

### 📌 任务 1.1：`script/create-file.js` → `script/file_creation_tool.s`

**当前位置**：[script/create-file.js](script/create-file.js)  
**文件大小**：8.7K  
**优先级**：🔴 **高** - 这是开发工作流的核心工具  

**功能概述**：
- 原子式文件创建 CLI 工具
- 支持单文件和批量操作
- 自动权限管理（如 0o600 用于敏感文件）
- 目录自动创建
- 行尾符处理（LF/CRLF）
- 文件覆写保护

**当前实现细节**：
```javascript
// 主要功能模块
- parseArgs()          // 命令行参数解析
- createFile()         // 原子式文件创建
- processBatch()       // 批量操作
- validateSyntax()     // 语法检查
- setPermissions()     // 权限设置
- createDirs()         // 目录创建
- handleCheckpoint()   // 检查点管理
```

**迁移策略**：
1. 创建 `script/file_creation_tool.s`
2. 实现命令行参数解析
3. 实现文件 I/O 操作
4. 添加权限管理
5. 实现批量操作

**预期结果**：
```bash
# S 语言版本的用法
s script/file_creation_tool.s --file path/to/file --text "content"
s script/file_creation_tool.s --file path/config.json --mode 0o600 --text "{...}"
s script/file_creation_tool.s --batch operations.json
```

**相关依赖**：
- `core/fs` (文件系统操作)
- `core/args` (参数解析)
- `util/io` (I/O 工具)

---

## 优先级 2（中）：示例代码迁移

### 📌 任务 2.1：`examples/file-creation-examples.js` → `examples/file_creation_examples.s`

**当前位置**：[examples/file-creation-examples.js](examples/file-creation-examples.js)  
**文件大小**：13K  
**优先级**：🟡 **中** - 文档/示例性质，不影响核心功能  

**功能概述**：
- 展示文件创建工具的使用示例
- 8+ 个实际可运行的示例
- 覆盖典型使用场景

**当前示例包括**：
1. 创建源代码文件 (C++)
2. 创建受保护的配置文件 (JSON)
3. 创建可执行脚本 (Bash)
4. 创建 Markdown 文档
5. 批量创建文件
6. 错误处理示例
7. 权限管理示例
8. 检查点管理示例

**迁移策略**：
1. 创建 `examples/file_creation_examples.s`
2. 将每个 JavaScript 示例转换为 S 语言
3. 保持示例的教学意义
4. 添加 S 特有的说明

**预期结果**：
```s
// S 语言示例的结构
func example1_CreateSourceFile() {
    // C++ 源文件示例
    content := `#include <iostream>...`
    createFile("src/main.cpp", content)
}

func example2_CreateProtectedConfig() {
    // 敏感配置文件示例
    config := `{"apiKey": "..."`
    createFileWithMode("config/secrets.json", config, 0o600)
}
```

**相关依赖**：
- `script/file_creation_tool.s` (依赖于任务 1.1 完成)

---

## 迁移计划表

| 任务 ID | 文件名 | 优先级 | 估计工作量 | 依赖关系 | 状态 |
|--------|--------|--------|----------|---------|------|
| 1.1 | `create-file.js` | 🔴 高 | 4-6 小时 | 无 | ⏳ 待迁移 |
| 2.1 | `file-creation-examples.js` | 🟡 中 | 2-3 小时 | 1.1 | ⏳ 待迁移 |

---

## 迁移前准备检查清单

- [ ] 理解原始 JavaScript 代码的完整功能
- [ ] 确认 S 语言已有必要的库支持（文件 I/O、权限管理）
- [ ] 准备 S 语言的单元测试框架
- [ ] 计划向后兼容性（如 CLI 参数格式）

---

## 迁移后验证检查清单

### 任务 1.1 验证
- [ ] `s script/file_creation_tool.s --help` 输出正确
- [ ] 单文件创建功能正常
- [ ] 批量操作功能正常
- [ ] 权限设置正确（`ls -l` 验证）
- [ ] 目录自动创建功能正常
- [ ] 行尾符处理正确
- [ ] 错误处理完善

### 任务 2.1 验证
- [ ] 所有 8+ 个示例都能正确执行
- [ ] 输出格式与原始 JavaScript 版本一致
- [ ] 文档注释清晰

---

## 完成标志

✅ **目标达成**：当以下条件满足时，迁移完成
1. 所有 2 个 JavaScript 文件成功迁移到 S 语言
2. 所有验证检查清单项目通过
3. 文档更新完毕
4. 代码通过审查

---

## 备注

### 当前 100% S 实现覆盖
- ✅ **652 个 S 文件** - 核心框架
- ✅ **~105,000 LOC** - S 语言代码
- ✅ **99.7% 纯度** - 仅有 2 个 JavaScript 文件

### 迁移后预期
- 🎯 **100% S 实现** - 完全零外部依赖
- 🎯 **0 个非 S 文件** - 纯粹的 S 语言项目
- 🎯 **完全自洽** - 所有工具都用 S 编写

