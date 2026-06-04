# FileCreationTool 实现总结

## 概述

在 NeurX Code 中实现了参考 Claude Code 最佳实践的高级文件创建和写入工具 (`FileCreationTool`)。该工具提供了安全、原子性的文件操作，具有完整的元数据保留和完整性验证功能。

---

## 📋 核心特性

### 1. **原子文件写入** (Atomic File Writing)
- **实现模式**: 临时文件 + 原子重命名
- **流程**:
  1. 在目标文件同目录创建临时文件 (`.neurx-tmp`)
  2. 将内容写入临时文件
  3. 复制原文件的权限到临时文件（如果存在）
  4. 使用 `QFile::rename()` 原子重命名临时文件到目标位置
  5. 失败时自动清理临时文件，保持原文件完整

**优势**: 确保文件写入的原子性，避免部分写入导致的文件损坏

### 2. **行结尾保留** (Line Ending Preservation)
- **支持的格式**:
  - `lf` - Unix 风格 (`\n`)
  - `crlf` - Windows 风格 (`\r\n`)
  - `auto` - 自动检测现有文件的格式

- **检测机制**:
  ```cpp
  if (content.contains("\r\n")) return "crlf";
  else if (content.contains("\n")) return "lf";
  ```

**优势**: 跨平台协作时保持文件格式一致性

### 3. **UTF-8 BOM 处理**
- 检测原文件是否有 BOM (字节顺序标记)
- 读写时自动剥离/恢复 BOM
- 保持 BOM 的往返完整性

**优势**: 避免编码问题，特别是在 Windows 上

### 4. **自动目录创建**
```cpp
bool ensureDirectories(const QString& path) {
    return m_workspaceRoot.mkpath(path);
}
```
- `create_dirs=true` 时自动创建所有父目录
- 使用 `QDir::mkpath()` 递归创建

**优势**: 无需手动创建目录层级

### 5. **权限复制**
```cpp
bool FileCreationTool::copyFilePermissions(const QString& from, const QString& to) {
    QFileInfo fromInfo(from);
    if (fromInfo.exists()) {
        return QFile::setPermissions(to, fromInfo.permissions());
    }
    return false;
}
```
- 从原文件复制权限到新文件
- 失败不中断主流程（最佳努力策略）

**优势**: 保持文件权限一致

### 6. **安全性和沙箱**
- **路径遍历保护**:
  ```cpp
  QString safePath(const QString& relOrAbsPath) {
      const QString absPath = m_workspaceRoot.absoluteFilePath(relOrAbsPath);
      if (!absPath.startsWith(m_workspaceRoot.absolutePath())) {
          return "";  // 拒绝越界访问
      }
      return absPath;
  }
  ```

- **受保护路径黑名单**:
  ```
  ~/.ssh/
  ~/.gnupg/
  ~/.aws/
  /etc/sudoers
  /etc/passwd
  /etc/shadow
  ```

- **沙箱集成**:
  ```cpp
  if (!m_sandboxManager->canAccess(absPath, FileSystemAccessMode::Write)) {
      return error("Write denied");
  }
  ```

**优势**: 防止意外修改关键系统文件

### 7. **语法检查**
支持的文件类型:

| 格式 | 检查工具 | 说明 |
|-----|--------|------|
| JSON | `QJsonDocument::fromJson()` | 内置 JSON 解析器验证 |
| Python | `python3 -m py_compile` | 使用 Python 编译器检查 |

**优势**: 在写入时及早检测语法错误

### 8. **检查点/备份支持**
```cpp
if (QFileInfo::exists(absPath)) {
    createCheckpoint(spec.path, "Before file modification");
}
```
- 修改现有文件前自动创建检查点
- 支持恢复到前一个状态

**优势**: 提供操作追踪和恢复能力

---

## 🔧 API 设计

### 操作类型

#### 1. `create_file` - 创建单个文件
```json
{
  "operation": "create_file",
  "path": "src/hello.py",
  "content": "print('Hello, World!')",
  "overwrite": false,
  "create_dirs": true,
  "line_ending": "auto",
  "preserve_existing": true
}
```

**返回**:
```json
{
  "filepath": "src/hello.py",
  "bytes_written": 24,
  "dirs_created": true,
  "line_ending": "lf",
  "lint": {
    "path": "src/hello.py",
    "status": "ok"
  }
}
```

#### 2. `write_file` - 写入/覆盖文件
```json
{
  "operation": "write_file",
  "path": "config.json",
  "content": "{\"key\": \"value\"}"
}
```
- 默认 `overwrite=true`（区别于 `create_file`）
- 其他参数同 `create_file`

#### 3. `create_batch` - 批量创建文件
```json
{
  "operation": "create_batch",
  "files": [
    {
      "path": "src/module1.py",
      "content": "# Module 1"
    },
    {
      "path": "src/module2.py",
      "content": "# Module 2"
    }
  ]
}
```

**返回**:
```json
{
  "total": 2,
  "succeeded": 2,
  "failed": 0,
  "files": [
    {"filepath": "src/module1.py", "bytes_written": 10, ...},
    {"filepath": "src/module2.py", "bytes_written": 10, ...}
  ]
}
```

---

## 📊 参数架构

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `operation` | string | 必需 | `create_file`, `write_file`, `create_batch` |
| `path` | string | 必需 | 相对于工作区的路径 |
| `content` | string | "" | 文件内容 |
| `overwrite` | boolean | false | 是否覆盖现有文件 |
| `create_dirs` | boolean | true | 自动创建父目录 |
| `line_ending` | string | auto | `auto`, `lf`, `crlf` |
| `preserve_existing` | boolean | true | 保留现有文件的元数据 |
| `files` | array | - | 批量操作时的文件列表 |

---

## 🗂️ 文件位置

```
neurx-code/src/tools/
├── FileCreationTool.h         (98 行)
└── FileCreationTool.cpp       (380+ 行)
```

### 集成点
1. **CMakeLists.txt**: 自动通过 `GLOB_RECURSE` 包含新文件
2. **ClaudeStandardTools.cpp**: 可注册为标准工具集
3. **Agent 系统**: 通过 `AgentToolRegistry` 发现

---

## 🔍 实现细节对比

### vs Claude Code (hermes-agent)

| 特性 | Claude Code | NeurX FileCreationTool |
|-----|-----------|----------------------|
| 原子写入 | Shell 脚本 + mktemp | C++ QFile + rename |
| 行结尾检测 | head -c 4096 | 内存操作 |
| BOM 检测 | head -c 3 | 内存操作 |
| 权限复制 | stat + chmod | QFile::setPermissions |
| 环境适配 | 多种后端 | 仅本地文件系统 |
| 性能 | 中等（Shell 开销） | 高（直接 C++ API） |

### vs NeurX FileSystemTool

| 特性 | FileSystemTool | FileCreationTool |
|-----|----------------|-----------------|
| 原子性 | 否 | 是 ✅ |
| 元数据保留 | 部分 | 完整 ✅ |
| 行结尾处理 | 否 | 是 ✅ |
| BOM 处理 | 否 | 是 ✅ |
| 检查点 | 是 | 是 ✅ |
| 权限保留 | 否 | 是 ✅ |
| 语法检查 | 否 | 是 ✅ |

---

## 💡 设计决策说明

### 1. 为什么使用原子写入?
- **问题**: 写入中断时文件可能损坏
- **解决**: 临时文件 + 重命名模式保证原子性
- **收益**: 即使在系统崩溃时也能保持文件完整

### 2. 为什么保留元数据?
- **问题**: 不同平台的文件格式不兼容
- **解决**: 自动检测并保留行结尾、BOM、权限
- **收益**: 跨平台协作不失真

### 3. 为什么支持检查点?
- **问题**: 修改出错无法回滚
- **解决**: 集成 CheckpointManager 创建备份
- **收益**: 提供审计踪迹和恢复能力

### 4. 为什么沙箱限制?
- **问题**: LLM 可能意外修改系统文件
- **解决**: 黑名单 + SandboxManager 集成
- **收益**: 安全边界明确，防止误操作

---

## 📈 性能特征

| 操作 | 时间复杂度 | 空间复杂度 | 注意事项 |
|-----|---------|---------|---------|
| 创建小文件 (<1MB) | O(n) | O(n) | 线性于文件大小 |
| 行结尾检测 | O(min(n, 4KB)) | O(1) | 采样前 4KB |
| BOM 检测 | O(1) | O(1) | 仅检查前 3 字节 |
| 权限复制 | O(1) | O(1) | 系统调用开销 |
| 批量创建 (N 文件) | O(N × M) | O(M) | M = 平均文件大小 |

**限制**: `MAX_FILE_SIZE = 50MB`

---

## 🚀 使用示例

### 例1: 创建 Python 文件
```cpp
QJsonObject args;
args["operation"] = "create_file";
args["path"] = "hello.py";
args["content"] = "#!/usr/bin/env python3\nprint('Hello')";
args["line_ending"] = "lf";

ToolResult result = fileTool->execute(callId, args);
// 返回: {bytes_written: 37, line_ending: "lf", lint: {status: "ok"}}
```

### 例2: 批量创建项目文件
```cpp
QJsonArray files;

QJsonObject file1;
file1["path"] = "src/main.cpp";
file1["content"] = "#include <iostream>\nint main() { return 0; }";
files.append(file1);

QJsonObject file2;
file2["path"] = "CMakeLists.txt";
file2["content"] = "cmake_minimum_required(VERSION 3.20)";
files.append(file2);

QJsonObject args;
args["operation"] = "create_batch";
args["files"] = files;

ToolResult result = fileTool->execute(callId, args);
// 返回: {total: 2, succeeded: 2, files: [...]}
```

---

## 🔐 安全考虑

### 已实现的保护

✅ **路径遍历防护**: 拒绝 `../../../etc/passwd` 式访问
✅ **敏感路径黑名单**: ~/.ssh, /etc/sudoers 等
✅ **沙箱集成**: 与 SandboxManager 协作
✅ **原子操作**: 避免部分写入
✅ **权限检查**: 在修改前验证

### 建议的额外强化

🔹 文件大小限制审计
🔹 写入频率限制（防 DoS）
🔹 内容白名单（对特定文件类型）
🔹 日志审计所有写操作

---

## 📝 与 Claude Code 的参考点

本实现参考了 `hermes-agent/tools/file_operations.py` 中的以下设计：

1. **结构化结果类** (`WriteResult` dataclass)
   - 返回完整的操作元数据而不仅仅是错误

2. **原子写入三步法**
   - mktemp → write → rename 模式

3. **行结尾检测**
   - 采样首部而不读整个文件

4. **权限保留**
   - stat 读权限，chmod 应用权限

5. **元数据保留**
   - 往返完整性 (round-trip preservation)

6. **保护路径列表**
   - ~/.ssh/*, ~/.aws/*, /etc/sudoers 等

---

## ✅ 编译验证

```bash
cd /Users/feifei/agent/neurx-code/build
make -j4

# 输出:
[100%] Built target neurx-codeApp
# 0 errors ✓
```

所有新代码已成功编译并集成到 NeurX Code 项目中。

---

## 🎯 后续改进方向

1. **异步写入**: 支持大文件的非阻塞写入
2. **流式写入**: 对超大文件的分块处理
3. **版本控制集成**: 自动 git add/commit
4. **格式化**: 自动代码格式化 (prettier, black 等)
5. **增量更新**: 支持 patch 式的部分修改
6. **加密存储**: 敏感文件的透明加密
7. **分布式锁**: 多进程并发安全

---

## 📚 参考文档

- [Qt File I/O Documentation](https://doc.qt.io/qt-6/qfile.html)
- [Claude Code / hermes-agent FileOperations](https://github.com/cognitivecomputations/hermes-agent/blob/main/tools/file_operations.py)
- [POSIX Atomic Operations](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap03.html)
- [UTF-8 BOM Handling](https://unicode.org/faq/utf_bom.html)
