# FileCreationTool 使用指南

## 快速开始

### 1. 工具注册

在 Agent 系统中注册 FileCreationTool：

```cpp
#include "tools/FileCreationTool.h"

// 创建工具实例
auto fileTool = std::make_unique<FileCreationTool>(workspaceRoot);

// 设置沙箱管理器（可选但推荐）
fileTool->setSandboxManager(sandboxManager);

// 设置检查点管理器（可选）
fileTool->setCheckpointManager(checkpointManager);

// 注册到工具注册表
toolRegistry->registerTool(fileTool.get());
```

### 2. 基本用法

#### 创建单个文件

```json
{
  "tool": "file_creation",
  "operation": "create_file",
  "path": "src/main.py",
  "content": "#!/usr/bin/env python3\nprint('Hello, World!')",
  "create_dirs": true,
  "line_ending": "lf"
}
```

**响应**:
```json
{
  "bytes_written": 39,
  "dirs_created": true,
  "filepath": "src/main.py",
  "line_ending": "lf",
  "lint": {
    "path": "src/main.py",
    "status": "ok"
  }
}
```

#### 覆盖现有文件

```json
{
  "tool": "file_creation",
  "operation": "write_file",
  "path": "config.json",
  "content": "{\"version\": \"2.0\"}"
}
```

注意: `write_file` 默认 `overwrite=true`

#### 批量创建文件

```json
{
  "tool": "file_creation",
  "operation": "create_batch",
  "files": [
    {
      "path": ".gitignore",
      "content": "*.pyc\n__pycache__/\n.DS_Store"
    },
    {
      "path": "README.md",
      "content": "# My Project\n\nDescription here."
    },
    {
      "path": "src/app.py",
      "content": "#!/usr/bin/env python3\nimport sys\n\nif __name__ == '__main__':\n    pass"
    }
  ]
}
```

**响应**:
```json
{
  "total": 3,
  "succeeded": 3,
  "failed": 0,
  "files": [
    {"filepath": ".gitignore", "bytes_written": 33, "dirs_created": false},
    {"filepath": "README.md", "bytes_written": 30, "dirs_created": false},
    {"filepath": "src/app.py", "bytes_written": 62, "dirs_created": true}
  ]
}
```

---

## 参数详解

### 通用参数

#### `operation` (必需)
- **类型**: string
- **值**: `"create_file"` | `"write_file"` | `"create_batch"`
- **说明**: 要执行的操作类型

#### `path` (必需，除 create_batch 外)
- **类型**: string
- **示例**: `"src/hello.py"`, `"config/app.json"`
- **说明**: 相对于工作区根目录的文件路径
- **注意**: 自动处理路径遍历攻击

#### `content` (必需)
- **类型**: string
- **示例**: `"print('hello')"`
- **说明**: 要写入的文件内容
- **限制**: 单个文件最大 50MB

#### `overwrite` (可选)
- **类型**: boolean
- **默认值**:
  - `create_file`: `false` (拒绝覆盖现有文件)
  - `write_file`: `true` (默认覆盖)
- **说明**: 是否允许覆盖现有文件

#### `create_dirs` (可选)
- **类型**: boolean
- **默认值**: `true`
- **说明**: 是否自动创建不存在的父目录
- **示例**: 创建 `"deep/nested/file.txt"` 时自动创建 `deep/` 和 `deep/nested/`

#### `line_ending` (可选)
- **类型**: string
- **值**: `"auto"` | `"lf"` | `"crlf"`
- **默认值**: `"auto"`
- **说明**:
  - `"auto"`: 检测现有文件的行结尾格式，默认使用 `"lf"`
  - `"lf"`: Unix 风格 (`\n`)
  - `"crlf"`: Windows 风格 (`\r\n`)

#### `preserve_existing` (可选)
- **类型**: boolean
- **默认值**: `true`
- **说明**: 覆盖现有文件时是否保留其元数据（权限、行结尾等）

#### `files` (批量操作必需)
- **类型**: array of objects
- **项目结构**:
  ```json
  {
    "path": "string (必需)",
    "content": "string (可选，默认空)",
    "overwrite": "boolean (可选)",
    "create_dirs": "boolean (可选)"
  }
  ```
- **说明**: 批量操作时的文件列表

---

## 响应格式

### 成功响应

```json
{
  "filepath": "path/to/file.txt",
  "bytes_written": 1024,
  "dirs_created": true,
  "line_ending": "lf",
  "lint": {
    "path": "path/to/file.txt",
    "status": "ok"
  }
}
```

### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `filepath` | string | 实际写入的文件路径 |
| `bytes_written` | int | 写入的字节数 |
| `dirs_created` | boolean | 是否创建了新目录 |
| `line_ending` | string | 使用的行结尾格式（`"lf"` 或 `"crlf"`）|
| `lint` | object | 语法检查结果 |
| `error` | string | 错误信息（仅在失败时出现） |

### 错误响应

```json
{
  "error": "File already exists. Use overwrite=true to replace."
}
```

```json
{
  "error": "Path traversal detected"
}
```

```json
{
  "error": "Cannot write to protected path: /etc/passwd"
}
```

---

## 常见场景

### 场景 1: 创建 Python 项目结构

```json
{
  "operation": "create_batch",
  "files": [
    {
      "path": "pyproject.toml",
      "content": "[tool.poetry]\nname = \"my-app\"\nversion = \"0.1.0\"\n"
    },
    {
      "path": "src/__init__.py",
      "content": "\"\"\"My Application\"\"\"\n__version__ = \"0.1.0\"\n"
    },
    {
      "path": "src/main.py",
      "content": "#!/usr/bin/env python3\n\ndef main():\n    print('Hello')\n\nif __name__ == '__main__':\n    main()\n"
    },
    {
      "path": "tests/__init__.py",
      "content": ""
    },
    {
      "path": "tests/test_main.py",
      "content": "import unittest\n\nclass TestMain(unittest.TestCase):\n    pass\n"
    }
  ]
}
```

### 场景 2: 创建配置文件 (JSON)

```json
{
  "operation": "create_file",
  "path": "config.json",
  "content": "{\n  \"version\": \"1.0\",\n  \"debug\": false,\n  \"port\": 8080\n}",
  "line_ending": "lf"
}
```

响应包含 JSON 语法检查结果：
```json
{
  "bytes_written": 67,
  "lint": {
    "status": "ok"
  }
}
```

### 场景 3: 更新现有文件保留格式

```json
{
  "operation": "write_file",
  "path": "data.txt",
  "content": "new content",
  "preserve_existing": true
}
```

如果 `data.txt` 原本使用 CRLF，新内容也会自动转换为 CRLF。

### 场景 4: 覆盖文件时进行检查点

```json
{
  "operation": "write_file",
  "path": "src/app.py",
  "content": "# Updated version",
  "overwrite": true
}
```

系统会自动：
1. 创建 `src/app.py` 的检查点备份
2. 原子写入新内容
3. 返回成功响应及检查点 ID

---

## 与 LLM 集成示例

### Agent 提示词模板

```
你可以使用 file_creation 工具创建和修改文件。

工具支持以下操作:
- create_file: 创建新文件（如果已存在会报错）
- write_file: 创建或覆盖文件
- create_batch: 批量创建多个文件

示例：
1. 创建单个 Python 文件:
   {
     "tool": "file_creation",
     "operation": "create_file",
     "path": "hello.py",
     "content": "print('Hello, World!')"
   }

2. 创建多个文件时，使用 create_batch 提高效率:
   {
     "tool": "file_creation",
     "operation": "create_batch",
     "files": [...]
   }

关键点:
- 路径相对于工作区根目录
- 默认创建父目录
- 保留现有文件的格式
- 保护系统关键文件
```

---

## 错误处理

### 常见错误及解决方案

| 错误 | 原因 | 解决 |
|-----|------|------|
| "File already exists" | 文件已存在且 `overwrite=false` | 设置 `overwrite: true` 或删除文件 |
| "Path traversal detected" | 路径试图访问工作区外 | 使用相对路径，避免 `../` |
| "Path write not allowed" | 沙箱拒绝访问 | 检查沙箱配置 |
| "Cannot write to protected path" | 目标是受保护的系统路径 | 改用允许的路径 |
| "Failed to create temporary file" | 磁盘满或权限问题 | 检查磁盘空间和文件权限 |

### 调试建议

启用详细日志：
```cpp
// 在工具执行前
fileCreationTool->setVerboseLogging(true);
```

检查返回的 `lint` 字段了解语法问题：
```json
{
  "lint": {
    "status": "error",
    "error": "JSON Error at 42: Expected '}'"
  }
}
```

---

## 最佳实践

### ✅ 推荐做法

1. **使用原子操作**
   ```json
   {"operation": "write_file", "path": "config.json", "content": "..."}
   ```
   而不是多步操作

2. **批量创建相关文件**
   ```json
   {"operation": "create_batch", "files": [...]}
   ```
   比单个创建更高效

3. **设置正确的行结尾**
   ```json
   {"line_ending": "lf"}  // 对 Unix/Linux
   {"line_ending": "crlf"}  // 对 Windows
   ```

4. **利用检查点**
   ```json
   {"operation": "write_file", "path": "important.txt", "content": "..."}
   // 系统自动创建备份
   ```

5. **验证语法**
   ```json
   {"path": "config.json", "content": "{...}"}
   // 响应包含 lint 结果
   ```

### ❌ 避免做法

1. **不要手动处理路径遍历**
   ```json
   {"path": "../../etc/passwd"}  // 会被拒绝
   ```

2. **不要创建超大文件**
   ```json
   {"content": "..."}  // > 50MB 会被拒绝
   ```

3. **不要忽视错误响应**
   ```cpp
   // 总是检查 result.isError
   if (result.isError) { handle_error(); }
   ```

4. **不要假设文件会立即可见**
   ```cpp
   // write_file 后立即 read_file 可能有延迟
   // 使用返回的 bytes_written 验证成功
   ```

---

## 性能优化

### 大量文件创建

对于 100+ 个文件，使用 `create_batch`:

```cpp
// ❌ 慢：100 个请求
for (int i = 0; i < 100; i++) {
    toolRegistry->execute("file_creation", createFileOp());
}

// ✅ 快：1 个请求
QJsonArray files;
for (int i = 0; i < 100; i++) {
    files.append(fileSpec(i));
}
batchOp["files"] = files;
toolRegistry->execute("file_creation", batchOp);
```

### 大文件处理

对于接近 50MB 限制的文件：

```json
{
  "operation": "create_file",
  "path": "large_data.bin",
  "content": "...49MB content..."
}
```

如需超大文件，建议分块：
1. 使用外部工具（`dd`, `split`）
2. 或实现流式 API（待实现）

---

## 故障排查

### 检查清单

- [ ] 文件路径有效且不包含遍历模式
- [ ] 工作区根目录已正确配置
- [ ] 沙箱管理器已连接（如使用）
- [ ] 磁盘有足够空间
- [ ] 目录权限允许写入
- [ ] 文件不被其他进程锁定

### 启用调试模式

```cpp
// 在创建工具后
fileTool->setDebugLogging(true);

// 执行操作
ToolResult result = fileTool->execute(callId, args);

// 查看详细日志输出
qDebug() << result.output;
```

---

## 相关工具

| 工具 | 用途 | 关系 |
|------|------|------|
| `FileSystemTool` | 读写文件操作 | 补充工具（无原子性保证） |
| `CheckpointManager` | 文件备份 | 集成依赖（自动调用） |
| `SandboxManager` | 沙箱隔离 | 可选但推荐 |

---

## 更新日志

### v1.0 (当前版本)
- ✅ 原子文件写入
- ✅ 元数据保留（行结尾、BOM、权限）
- ✅ 单文件和批量操作
- ✅ 路径安全检查
- ✅ JSON/Python 语法验证
- ✅ 检查点集成

### 计划中 (v2.0+)
- 🔲 异步写入 API
- 🔲 流式大文件处理
- 🔲 Git 自动提交
- 🔲  代码格式化集成
- 🔲  加密存储支持
- 🔲  分布式锁机制
