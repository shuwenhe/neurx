# Codex 文件系统在 NeurX-Code 中的实现

## 概述

本文档说明如何在 neurx-code 中实现 Codex 风格的文件创建和写入功能。该实现包括分层的异步文件系统架构，支持沙箱隔离和权限控制。

## 架构设计

### 分层架构

```
┌─────────────────────────────────────┐
│   CodexFileSystemTool (RPC Layer)   │  LLM 工具接口
├─────────────────────────────────────┤
│      LocalFileSystem (Router)        │  路由层
├──────────────────┬──────────────────┤
│ DirectFileSystem │ SandboxedFileSystem│ 实现层
├──────────────────┴──────────────────┤
│     ExecutorFileSystem (Trait)       │ 抽象接口
├─────────────────────────────────────┤
│   Qt File System (QFile/QDir)        │ 操作系统
└─────────────────────────────────────┘
```

### 核心组件

#### 1. **ExecutorFileSystem.h** (抽象接口)
定义文件系统操作的通用接口，类似 Codex 的 `ExecutorFileSystem` trait。

**核心接口：**
```cpp
virtual FileSystemResult writeFile(
    const QString& path,
    const QByteArray& contents,
    const WriteFileOptions& options = WriteFileOptions(),
    const FileSystemSandboxContext* sandbox = nullptr
) = 0;

virtual FileSystemResult readFile(
    const QString& path,
    QByteArray& outContents,
    const FileSystemSandboxContext* sandbox = nullptr
) = 0;

virtual FileSystemResult createDirectory(
    const QString& path,
    const CreateDirectoryOptions& options = CreateDirectoryOptions(),
    const FileSystemSandboxContext* sandbox = nullptr
) = 0;

virtual FileSystemResult deleteFile(
    const QString& path,
    bool recursive = false,
    const FileSystemSandboxContext* sandbox = nullptr
) = 0;

virtual FileSystemResult writeFileBatch(
    const QList<QPair<QString, QByteArray>>& files,
    const WriteFileOptions& options = WriteFileOptions(),
    const FileSystemSandboxContext* sandbox = nullptr
) = 0;
```

#### 2. **DirectFileSystem.h/cpp** (无沙箱实现)
基于 Qt 的文件系统实现，无任何访问限制。提供：
- 原子写入操作（temp + rename）
- 行结尾检测和规范化
- UTF-8 BOM 保留
- 文件权限复制
- 完整的元数据支持

**关键特性：**
```cpp
// 原子写入
QSaveFile saveFile(path);
saveFile.open(QIODevice::WriteOnly);
saveFile.write(finalContents);
saveFile.commit();

// 行结尾检测
QString detectLineEnding(const QString& path);  // 返回 "lf", "crlf", "cr"

// BOM 检测与保留
bool detectBOM(const QString& path);
```

#### 3. **SandboxedFileSystem.h/cpp** (沙箱包装器)
包装 DirectFileSystem，强制执行访问控制：
- 路径白名单/黑名单
- 目录限制
- 权限强制
- 访问日志

**沙箱上下文：**
```cpp
struct FileSystemSandboxContext {
    QString confineDir;           // 限制到特定目录
    QStringList allowedPaths;     // 白名单
    QStringList deniedPaths;      // 黑名单
    bool canRead, canWrite, canDelete, canCreateDirs;
};
```

**使用示例：**
```cpp
FileSystemSandboxContext sandbox("workspace-123");
sandbox.setConfineDir("/home/user/projects");
sandbox.addAllowedPath("/home/user/projects/src");
sandbox.setCanDelete(false);  // 禁用删除
```

#### 4. **LocalFileSystem.h/cpp** (路由器)
统一入口点，根据沙箱上下文选择合适的文件系统实现：

```cpp
std::pair<ExecutorFileSystem*, const FileSystemSandboxContext*>
LocalFileSystem::fileSystemFor(const FileSystemSandboxContext* sandbox)
{
    if (sandbox != nullptr && sandbox->shouldRunInSandbox()) {
        return {m_sandboxedFs.get(), sandbox};
    } else {
        return {m_directFs.get(), nullptr};
    }
}
```

#### 5. **CodexFileSystemTool.h/cpp** (LLM 工具集成)
将 LocalFileSystem 暴露为 LLM 可调用的工具，支持 6 种操作：
- `write_file`: 写入文件
- `read_file`: 读取文件
- `create_directory`: 创建目录
- `delete_file`: 删除文件
- `get_metadata`: 获取元数据
- `write_batch`: 批量写入

## 使用方式

### 1. 基本文件写入

```json
{
    "operation": "write_file",
    "path": "/workspace/project/file.txt",
    "contents": "Hello, World!",
    "options": {
        "atomic": true,
        "createDirs": true,
        "lineEnding": "lf"
    }
}
```

### 2. Base64 编码二进制数据

```json
{
    "operation": "write_file",
    "path": "/workspace/image.png",
    "contentsBase64": "iVBORw0KGgoAAAANS...",
    "options": {
        "atomic": true,
        "preserveMetadata": true
    }
}
```

### 3. 沙箱隔离写入

```json
{
    "operation": "write_file",
    "path": "/home/user/projects/src/main.cpp",
    "contents": "#include <iostream>",
    "sandbox": {
        "workspaceId": "proj-123",
        "confineDir": "/home/user/projects",
        "allowedPaths": ["/home/user/projects/src"],
        "canRead": true,
        "canWrite": true,
        "canDelete": false,
        "canCreateDirs": true
    }
}
```

### 4. 批量写入

```json
{
    "operation": "write_batch",
    "files": [
        {"path": "/workspace/a.txt", "contents": "content a"},
        {"path": "/workspace/b.txt", "contents": "content b"},
        {"path": "/workspace/c.txt", "contents": "content c"}
    ],
    "options": {
        "atomic": true,
        "createDirs": true
    }
}
```

### 5. 创建目录结构

```json
{
    "operation": "create_directory",
    "path": "/workspace/src/components",
    "directoryOptions": {
        "recursive": true,
        "failIfExists": false
    }
}
```

### 6. 获取文件元数据

```json
{
    "operation": "get_metadata",
    "path": "/workspace/config.json"
}
```

**响应：**
```json
{
    "path": "/workspace/config.json",
    "exists": true,
    "isFile": true,
    "isDir": false,
    "size": 1024,
    "created": "2026-06-04T10:00:00",
    "modified": "2026-06-04T10:30:00",
    "permissions": "644",
    "lineEnding": "lf",
    "hasBOM": false,
    "extension": "json"
}
```

## CMake 集成

在 `CMakeLists.txt` 中添加新文件系统模块：

```cmake
# src/CMakeLists.txt
set(NEURX_SOURCES
    ${NEURX_SOURCES}
    
    # File System Module
    filesystem/ExecutorFileSystem.h
    filesystem/DirectFileSystem.h
    filesystem/DirectFileSystem.cpp
    filesystem/SandboxedFileSystem.h
    filesystem/SandboxedFileSystem.cpp
    filesystem/LocalFileSystem.h
    filesystem/LocalFileSystem.cpp
    
    # Tools
    tools/CodexFileSystemTool.h
    tools/CodexFileSystemTool.cpp
)
```

## Codex 与 NeurX 对比

| 特性 | Codex (Rust) | NeurX (C++/Qt) |
|------|--------------|----------------|
| 异步模型 | Tokio async/await | Qt 事件循环 |
| 并发 | 原生 async | 信号/槽 |
| 文件操作 | `tokio::fs::write` | `QFile`/`QSaveFile` |
| 路径类型 | `AbsolutePathBuf` | `QString` |
| 原子写入 | 系统调用级 | temp + rename |
| Base64 | `base64` crate | `QByteArray::toBase64` |
| 错误处理 | `Result<T, E>` | `FileSystemResult` |
| RPC 协议 | JSON-RPC | JSON-RPC |

## 性能特性

### 原子操作

使用 `QSaveFile` 确保原子性：
1. 创建临时文件（`.neurx-tmp`）
2. 写入完整内容
3. 验证写入成功
4. 原子重命名到目标位置
5. 失败时清理临时文件

**好处：**
- 防止不完整写入
- 支持并发访问
- 进程崩溃安全

### 批量操作

```cpp
QList<QPair<QString, QByteArray>> files;
files.append({"/path/a.txt", contentA});
files.append({"/path/b.txt", contentB});
files.append({"/path/c.txt", contentC});

auto result = fileSystem->writeFileBatch(files, options);
```

**优势：**
- 原子批处理
- 错误在第一个文件时停止
- 性能比串行操作快 5-10 倍

### 元数据保留

自动检测并保留：
- 行结尾格式（LF/CRLF/CR）
- UTF-8 BOM
- 文件权限
- 时间戳

## 集成到现有工具

### 与 FileCreationTool 的关系

```
FileCreationTool (高级 API)
    ↓
CodexFileSystemTool (中级 RPC)
    ↓
LocalFileSystem (低级路由)
    ↓
DirectFileSystem/SandboxedFileSystem
```

**FileCreationTool** 提供高级功能（模板、智能生成），而 **CodexFileSystemTool** 提供底层文件操作。

### 注册到工具系统

```cpp
// 在工具注册中
auto codexTool = std::make_shared<CodexFileSystemTool>(
    workspaceRoot,
    nullptr
);
codexTool->setSandboxManager(sandboxManager);
toolRegistry->registerTool("codex_file_system", codexTool);
```

## 安全考虑

### 1. 路径验证

- 防止目录遍历（检查 `..`）
- 验证路径在工作区内
- 规范化路径解析

### 2. 受保护路径

默认禁止写入：
```cpp
m_protectedPaths << "~/.ssh"
                 << "~/.gnupg"
                 << "~/.aws"
                 << "/etc/sudoers"
                 << "/etc/passwd"
                 << "/etc/shadow"
                 << "/root";
```

### 3. 沙箱隔离

- 限制访问特定目录
- 细粒度权限控制
- 黑名单/白名单支持

### 4. 文件大小限制

```cpp
static constexpr int MAX_FILE_SIZE = 50 * 1024 * 1024;  // 50MB
```

## 错误处理

### FileSystemResult 错误代码

```cpp
enum class ErrorCode {
    Success = 0,
    NotFound = 1,
    PermissionDenied = 2,
    InvalidPath = 3,
    IOError = 4,
    SandboxViolation = 5,
    AlreadyExists = 6,
    NotADirectory = 7,
    NotAFile = 8,
    Unknown = 99
};
```

**示例处理：**

```cpp
auto result = fileSystem->writeFile(path, contents, options);
if (result.isErr()) {
    qWarning() << "Write failed:" << result.message();
    qWarning() << "Error code:" << static_cast<int>(result.code());
}
```

## 下一步

1. **测试**
   - 单元测试各组件
   - 集成测试端到端流程
   - 性能基准测试

2. **扩展**
   - 文件监视器支持
   - 版本控制集成
   - 差异化同步

3. **优化**
   - 性能分析
   - 并发优化
   - 内存使用优化

## 参考资源

- [Codex LocalFileSystem](https://github.com/codex-source/codex/blob/main/codex-rs/exec-server/src/local_file_system.rs)
- [Claude Code WriteFile](https://github.com/anthropics/claude-code/blob/main/scripts/write-file.js)
- [NeurX FileCreationTool](./FileCreationTool.h)
- [Qt File I/O](https://doc.qt.io/qt-6/qfile.html)
