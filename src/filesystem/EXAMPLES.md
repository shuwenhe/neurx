# Codex 文件系统 - 使用示例

本文档提供了在 NeurX-Code 中使用 Codex 文件系统的实际示例。

## 目录

1. [基础文件操作](#基础文件操作)
2. [沙箱隔离](#沙箱隔离)
3. [高级用法](#高级用法)
4. [错误处理](#错误处理)
5. [性能优化](#性能优化)

---

## 基础文件操作

### 1. 写入简单文本文件

**C++ 代码：**
```cpp
#include "tools/CodexFileSystemTool.h"

void writeTextFile() {
    auto tool = std::make_shared<CodexFileSystemTool>("/workspace");
    
    QJsonObject args;
    args["operation"] = "write_file";
    args["path"] = "/workspace/hello.txt";
    args["contents"] = "Hello, Codex File System!";
    
    auto result = tool->execute("call-001", args);
    if (!result.isError) {
        qDebug() << "File written successfully!";
        qDebug() << "Result:" << result.output;
    }
}
```

**预期输出：**
```json
{
    "success": true,
    "path": "/workspace/hello.txt",
    "bytesWritten": 28
}
```

---

### 2. 读取文件内容

**请求：**
```json
{
    "operation": "read_file",
    "path": "/workspace/config.json"
}
```

**响应：**
```json
{
    "success": true,
    "path": "/workspace/config.json",
    "size": 256,
    "contents": "{\"version\": \"1.0\", ...}",
    "contentsBase64": "eyJ2ZXJzaW9uIjog..."
}
```

---

### 3. 创建目录结构

**请求：**
```json
{
    "operation": "create_directory",
    "path": "/workspace/src/components/ui",
    "directoryOptions": {
        "recursive": true,
        "failIfExists": false
    }
}
```

**响应：**
```json
{
    "success": true,
    "path": "/workspace/src/components/ui"
}
```

---

### 4. 删除文件或目录

**删除单个文件：**
```json
{
    "operation": "delete_file",
    "path": "/workspace/temp.txt",
    "deleteRecursive": false
}
```

**递归删除目录：**
```json
{
    "operation": "delete_file",
    "path": "/workspace/old_project",
    "deleteRecursive": true
}
```

---

### 5. 获取文件元数据

**请求：**
```json
{
    "operation": "get_metadata",
    "path": "/workspace/main.cpp"
}
```

**完整响应：**
```json
{
    "path": "/workspace/main.cpp",
    "exists": true,
    "isFile": true,
    "isDir": false,
    "size": 2048,
    "created": "2026-06-04T09:30:00",
    "modified": "2026-06-04T14:22:15",
    "permissions": "644",
    "lineEnding": "lf",
    "hasBOM": false,
    "extension": "cpp"
}
```

---

## 沙箱隔离

### 1. 创建受限工作区

**场景：** 允许 AI agent 只在特定目录写入文件

```cpp
#include "filesystem/LocalFileSystem.h"

void createRestrictedWorkspace() {
    auto fileSystem = std::make_shared<LocalFileSystem>("/home/user");
    
    // 创建沙箱上下文
    FileSystemSandboxContext sandbox("project-abc");
    sandbox.setConfineDir("/home/user/projects/abc");
    sandbox.addAllowedPath("/home/user/projects/abc/src");
    sandbox.addAllowedPath("/home/user/projects/abc/config");
    sandbox.addDeniedPath("/home/user/projects/abc/.git");
    
    // 设置权限
    sandbox.setCanRead(true);      // 允许读取
    sandbox.setCanWrite(true);     // 允许写入
    sandbox.setCanDelete(false);   // 禁止删除
    sandbox.setCanCreateDirs(true);// 允许创建目录
    
    // 使用沙箱
    QByteArray contents = "int main() { return 0; }";
    auto result = fileSystem->writeFile(
        "/home/user/projects/abc/src/main.cpp",
        contents,
        WriteFileOptions(),
        &sandbox
    );
    
    if (result.isOk()) {
        qDebug() << "File written in sandbox!";
    } else {
        qDebug() << "Error:" << result.message();
    }
}
```

---

### 2. 沙箱违规检测

**场景：** 尝试在禁止路径写入

```cpp
void testSandboxViolation() {
    FileSystemSandboxContext sandbox("restricted");
    sandbox.setConfineDir("/home/user/safe");
    sandbox.setCanDelete(false);
    
    // ❌ 违反约束：超出限制目录
    auto result1 = fileSystem->writeFile(
        "/etc/passwd",
        QByteArray("hacked"),
        WriteFileOptions(),
        &sandbox
    );
    assert(result1.isErr());
    assert(result1.code() == FileSystemResult::ErrorCode::SandboxViolation);
    
    // ❌ 违反权限：尝试删除
    auto result2 = fileSystem->deleteFile(
        "/home/user/safe/important.txt",
        false,
        &sandbox
    );
    assert(result2.isErr());
    assert(result2.code() == FileSystemResult::ErrorCode::PermissionDenied);
}
```

---

### 3. 多工作区隔离

**场景：** 为不同项目创建独立沙箱

```cpp
void multiProjectSandbox() {
    auto fileSystem = std::make_shared<LocalFileSystem>("/workspace");
    
    // 项目 A 沙箱
    FileSystemSandboxContext sandboxA("project-a");
    sandboxA.setConfineDir("/workspace/project-a");
    
    // 项目 B 沙箱
    FileSystemSandboxContext sandboxB("project-b");
    sandboxB.setConfineDir("/workspace/project-b");
    
    // 项目 A 只能访问自己的目录
    auto resultA = fileSystem->writeFile(
        "/workspace/project-a/file.txt",
        QByteArray("Project A content"),
        WriteFileOptions(),
        &sandboxA
    );
    assert(resultA.isOk());
    
    // 项目 A 不能访问项目 B 的文件
    auto resultB_fail = fileSystem->writeFile(
        "/workspace/project-b/file.txt",
        QByteArray("Hacked!"),
        WriteFileOptions(),
        &sandboxA  // 使用项目 A 的沙箱
    );
    assert(resultB_fail.isErr());
}
```

---

## 高级用法

### 1. 批量写入文件

**C++ 代码：**
```cpp
void batchCreateProject() {
    auto fileSystem = std::make_shared<LocalFileSystem>("/workspace");
    
    QList<QPair<QString, QByteArray>> files;
    files.append({
        "/workspace/project/CMakeLists.txt",
        QByteArray("cmake_minimum_required(VERSION 3.20)\n"
                   "project(MyProject)\n")
    });
    files.append({
        "/workspace/project/src/main.cpp",
        QByteArray("#include <iostream>\nint main() {\n"
                   "    std::cout << \"Hello!\" << std::endl;\n"
                   "    return 0;\n}\n")
    });
    files.append({
        "/workspace/project/src/lib.h",
        QByteArray("#ifndef LIB_H\n#define LIB_H\n"
                   "void hello();\n#endif\n")
    });
    
    auto result = fileSystem->writeFileBatch(
        files,
        WriteFileOptions{
            .atomic = true,
            .createDirs = true,
            .lineEnding = "lf"
        }
    );
    
    if (result.isOk()) {
        qDebug() << "Project structure created successfully!";
    }
}
```

**JSON 请求：**
```json
{
    "operation": "write_batch",
    "files": [
        {"path": "/workspace/project/CMakeLists.txt", "contents": "..."},
        {"path": "/workspace/project/src/main.cpp", "contents": "..."},
        {"path": "/workspace/project/src/lib.h", "contents": "..."}
    ],
    "options": {
        "atomic": true,
        "createDirs": true,
        "lineEnding": "lf"
    }
}
```

---

### 2. 处理行结尾

**场景：** 在不同平台间转换行结尾格式

```cpp
void handleLineEndings() {
    auto fileSystem = std::make_shared<LocalFileSystem>("/workspace");
    
    QString content = "line 1\nline 2\nline 3\n";
    
    // 写入 LF（Unix 风格）
    fileSystem->writeFile(
        "/workspace/unix.txt",
        content.toUtf8(),
        WriteFileOptions{.lineEnding = "lf"}
    );
    
    // 写入 CRLF（Windows 风格）
    fileSystem->writeFile(
        "/workspace/windows.txt",
        content.toUtf8(),
        WriteFileOptions{.lineEnding = "crlf"}
    );
    
    // 自动检测并保留原有格式
    fileSystem->writeFile(
        "/workspace/auto.txt",
        content.toUtf8(),
        WriteFileOptions{.lineEnding = "auto"}
    );
}
```

---

### 3. 保留元数据

**场景：** 更新文件时保留权限和行结尾

```cpp
void preserveMetadata() {
    auto fileSystem = std::make_shared<LocalFileSystem>("/workspace");
    
    WriteFileOptions options;
    options.atomic = true;
    options.preserveMetadata = true;  // 关键：保留元数据
    options.preserveBOM = true;        // 保留 BOM
    options.lineEnding = "auto";       // 自动检测行结尾
    
    // 修改文件内容，但保留权限和格式
    auto result = fileSystem->writeFile(
        "/workspace/config.json",
        QByteArray("{\"version\": 2}"),
        options
    );
    
    // 验证元数据
    auto metadata = fileSystem->getMetadata("/workspace/config.json");
    qDebug() << "Original line ending preserved:" 
             << metadata["lineEnding"];
    qDebug() << "BOM preserved:" << metadata["hasBOM"];
}
```

---

### 4. 处理二进制数据

**场景：** 写入图像、编译的二进制文件等

```cpp
void writeBinaryFile() {
    auto tool = std::make_shared<CodexFileSystemTool>("/workspace");
    
    // 从文件读取二进制数据
    QFile imageFile("/source/image.png");
    imageFile.open(QIODevice::ReadOnly);
    QByteArray imageData = imageFile.readAll();
    imageFile.close();
    
    // 编码为 Base64 并发送
    QJsonObject args;
    args["operation"] = "write_file";
    args["path"] = "/workspace/assets/image.png";
    args["contentsBase64"] = QString(imageData.toBase64());
    args["options"] = QJsonObject{
        {"atomic", true},
        {"createDirs", true}
    };
    
    auto result = tool->execute("call-002", args);
    qDebug() << "Binary file written:" << result.output;
}
```

---

## 错误处理

### 1. 常见错误场景

```cpp
void handleErrors() {
    auto fileSystem = std::make_shared<LocalFileSystem>("/workspace");
    
    // 错误 1: 文件不存在
    QByteArray contents;
    auto result1 = fileSystem->readFile(
        "/workspace/nonexistent.txt",
        contents
    );
    if (result1.code() == FileSystemResult::ErrorCode::NotFound) {
        qWarning() << "File not found";
    }
    
    // 错误 2: 权限不足
    auto result2 = fileSystem->writeFile(
        "/etc/passwd",
        QByteArray("hacked"),
        WriteFileOptions()
    );
    if (result2.code() == FileSystemResult::ErrorCode::PermissionDenied) {
        qWarning() << "Access denied to protected path";
    }
    
    // 错误 3: 无效路径
    auto result3 = fileSystem->writeFile(
        "/workspace/../../../etc/passwd",
        QByteArray("hacked"),
        WriteFileOptions()
    );
    if (result3.code() == FileSystemResult::ErrorCode::InvalidPath) {
        qWarning() << "Path traversal detected";
    }
    
    // 错误 4: 沙箱违反
    FileSystemSandboxContext sandbox("test");
    sandbox.setConfineDir("/workspace/safe");
    
    auto result4 = fileSystem->writeFile(
        "/etc/shadow",
        QByteArray("hacked"),
        WriteFileOptions(),
        &sandbox
    );
    if (result4.code() == FileSystemResult::ErrorCode::SandboxViolation) {
        qWarning() << "Sandbox violation attempted";
    }
}
```

### 2. 详细错误报告

```cpp
void reportDetailedError() {
    auto result = fileSystem->writeFile(
        "/workspace/file.txt",
        QByteArray("content"),
        WriteFileOptions()
    );
    
    if (result.isErr()) {
        QJsonObject errorReport;
        errorReport["code"] = static_cast<int>(result.code());
        errorReport["message"] = result.message();
        
        QString errorType;
        switch (result.code()) {
            case FileSystemResult::ErrorCode::InvalidPath:
                errorType = "InvalidPath"; break;
            case FileSystemResult::ErrorCode::PermissionDenied:
                errorType = "PermissionDenied"; break;
            case FileSystemResult::ErrorCode::IOError:
                errorType = "IOError"; break;
            default:
                errorType = "UnknownError";
        }
        
        errorReport["type"] = errorType;
        qWarning() << "Operation failed:" 
                   << QJsonDocument(errorReport).toJson();
    }
}
```

---

## 性能优化

### 1. 批量操作性能

```cpp
void benchmarkBatchOperations() {
    auto fileSystem = std::make_shared<LocalFileSystem>("/workspace");
    
    // 生成 100 个文件
    QList<QPair<QString, QByteArray>> files;
    for (int i = 0; i < 100; ++i) {
        QString path = QString("/workspace/file_%1.txt").arg(i);
        QByteArray content = QString("Content %1").arg(i).toUtf8();
        files.append({path, content});
    }
    
    // 批量写入（快速）
    auto start = std::chrono::high_resolution_clock::now();
    auto result = fileSystem->writeFileBatch(
        files,
        WriteFileOptions{.atomic = true}
    );
    auto end = std::chrono::high_resolution_clock::now();
    
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(
        end - start
    );
    qDebug() << "Batch write 100 files:" << duration.count() << "ms";
    
    // 比对：串行写入（慢）
    start = std::chrono::high_resolution_clock::now();
    for (const auto& [path, content] : files) {
        fileSystem->writeFile(path, content);
    }
    end = std::chrono::high_resolution_clock::now();
    
    duration = std::chrono::duration_cast<std::chrono::milliseconds>(
        end - start
    );
    qDebug() << "Sequential write 100 files:" << duration.count() << "ms";
}
```

**预期性能：**
- 批量操作：~50-100 ms（100 个文件）
- 串行操作：~500-1000 ms（100 个文件）
- **性能提升：5-10 倍**

---

### 2. 缓存元数据

```cpp
void cacheMetadata() {
    auto fileSystem = std::make_shared<LocalFileSystem>("/workspace");
    QMap<QString, QJsonObject> metadataCache;
    
    auto getMetadataWithCache = [&](const QString& path) {
        if (metadataCache.contains(path)) {
            return metadataCache[path];
        }
        
        auto metadata = fileSystem->getMetadata(path);
        metadataCache[path] = metadata;
        return metadata;
    };
    
    // 重复查询时使用缓存
    auto meta1 = getMetadataWithCache("/workspace/config.json");
    auto meta2 = getMetadataWithCache("/workspace/config.json");  // 来自缓存
}
```

---

### 3. 使用沙箱优化权限检查

```cpp
void optimizeWithSandbox() {
    auto fileSystem = std::make_shared<LocalFileSystem>("/workspace");
    
    // 一次性创建沙箱
    FileSystemSandboxContext sandbox("project");
    sandbox.setConfineDir("/workspace/project");
    
    // 多个操作使用同一沙箱，避免重复权限检查
    for (int i = 0; i < 100; ++i) {
        QString path = QString("/workspace/project/file_%1.txt").arg(i);
        fileSystem->writeFile(
            path,
            QString("Content %1").arg(i).toUtf8(),
            WriteFileOptions{.atomic = true},
            &sandbox  // 重用沙箱
        );
    }
}
```

---

## 总结

Codex 文件系统提供了：
✅ **原子写入** - 防止不完整文件
✅ **沙箱隔离** - 安全的访问控制
✅ **元数据保留** - 智能格式转换
✅ **高性能批处理** - 5-10 倍性能提升
✅ **完整错误处理** - 详细诊断信息
✅ **二进制支持** - Base64 编码

更多示例见 [Codex File System Guide](./CODEX_FILE_SYSTEM_GUIDE.md)
