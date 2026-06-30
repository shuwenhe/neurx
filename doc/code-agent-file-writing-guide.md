# Code Agent 文件写入实现逻辑详解

## 一、概述

Code Agent（如 Codex、Copilot、Claude Code）将代码内容写入文件的实现有多种方式，从直接文件写入到间接补丁应用，各有优缺点。本文详细讲解neurx-code中的实现。

---

## 二、三种主要的文件写入方式

### 方式1：直接文件写入（WriteTool）

**原理：** 代理直接生成完整的文件内容，通过文件操作API原子性地写入磁盘。

**实现流程：**

```
LLM Agent
  ↓
生成完整文件内容
  ↓
WriteTool.execute()
  ├─ 步骤1: 路径验证（防止目录遍历攻击）
  │  └─ 绝对路径化 + 清理 + 工作空间边界检查
  │
  ├─ 步骤2: Sandbox权限检查
  │  └─ SandboxManager::canAccess(path, Write)
  │
  ├─ 步骤3: 创建父目录
  │  └─ QDir::mkpath() 递归创建目录
  │
  ├─ 步骤4: 保存文件权限（如果文件已存在）
  │  └─ QFile::permissions() 提取原权限
  │
  ├─ 步骤5: 原子写入
  │  └─ QSaveFile:
  │     - open() 获取写入权限
  │     - QTextStream 写入内容
  │     - flush() 确保缓冲区写出
  │     - commit() 原子性提交（写入失败则回滚）
  │
  ├─ 步骤6: 写入验证
  │  └─ QFile::exists() + QFileInfo::size()
  │
  └─ 返回 ToolResult { callId, toolName, isError, message }
```

**代码示例：**

```cpp
// 核心逻辑
ToolResult WriteTool::execute(const QString& callId, const QJsonObject& args)
{
    QString filePath = args.value("file_path").toString();
    QString newText = args.value("new_text").toString();
    
    // 1. 路径验证
    QString absPath = safePath(filePath);  // 防止 ../../ 逃逸
    
    // 2. 权限检查
    if (!m_sandboxManager->canAccess(absPath, FileSystemAccessMode::Write))
        return {callId, name(), true, "Access denied"};
    
    // 3. 创建目录
    ensureDirectoryExists(QFileInfo(absPath).dir().absolutePath());
    
    // 4. 原子写入
    QSaveFile save(absPath);
    save.open(QIODevice::WriteOnly | QIODevice::Text);
    QTextStream out(&save);
    out << newText;
    out.flush();
    
    // 5. 提交（失败自动回滚）
    if (!save.commit())
        return {callId, name(), true, save.errorString()};
    
    // 6. 验证
    return {callId, name(), false, "✓ File created"};
}
```

**特点：**
- ✅ **直接快速** - 无需中间步骤，一次I/O操作
- ✅ **原子性** - QSaveFile确保写入要么完全成功，要么完全失败
- ✅ **简单清晰** - 易于理解和调试
- ⚠️ **全量生成** - 必须生成完整文件内容，大文件低效
- ⚠️ **冲突处理差** - 无法处理并发编辑冲突

---

### 方式2：补丁应用（CodexApplyPatchTool）

**原理：** 代理生成unified diff格式的补丁，通过Codex CLI的`apply-patch`命令应用到文件系统。

**实现流程：**

```
LLM Agent
  ↓
生成Unified Diff补丁
  └─ 格式：
     --- a/old_file
     +++ b/new_file
     @@ -1,3 +1,4 @@
      context_line
     -removed_line
     +added_line
      context_line
  ↓
CodexApplyPatchTool.execute()
  ├─ 步骤1: 补丁格式验证
  │  └─ 检查必要标记：---, +++, @@
  │
  ├─ 步骤2: 沙箱权限检查
  │  └─ SandboxManager::canAccess()
  │
  ├─ 步骤3: 创建临时补丁文件
  │  └─ QTemporaryFile 在 /tmp 创建
  │
  ├─ 步骤4: 调用Codex CLI（子进程）
  │  └─ QProcess::start("codex", {"apply-patch", patch_file, "--cwd", cwd, "--json"})
  │     └─ 30秒超时
  │
  ├─ 步骤5: 解析JSON结果
  │  └─ {"files_changed": 1, "changed_files": ["src/main.cpp"]}
  │
  └─ 返回 ToolResult
```

**代码示例：**

```cpp
// Unified Diff 生成
QString generateUnifiedDiff(const QString &filePath, 
                           const QString &oldContent,
                           const QString &newContent)
{
    QString patch;
    patch += "--- a/" + filePath + "\n";
    patch += "+++ b/" + filePath + "\n";
    
    // 计算行号变化
    auto oldLines = oldContent.split('\n');
    auto newLines = newContent.split('\n');
    
    // 生成 @@ -oldStart,oldCount +newStart,newCount @@ 
    patch += QString("@@ -1,%1 +1,%2 @@\n").arg(oldLines.size()).arg(newLines.size());
    
    // 输出行变化：-删除行，+新增行，空格是上下文
    for (const auto &line : oldLines) {
        if (oldLines.contains(line) && newLines.contains(line))
            patch += " " + line + "\n";  // 上下文
        else
            patch += "-" + line + "\n";  // 删除
    }
    for (const auto &line : newLines) {
        if (!oldLines.contains(line))
            patch += "+" + line + "\n";  // 新增
    }
    
    return patch;
}

// 应用补丁
ToolResult CodexApplyPatchTool::execute(const QString &callId, const QJsonObject &args)
{
    QString patchContent = args.value("patch").toString();
    QString cwd = args.value("cwd").toString();
    
    // 1. 验证补丁格式
    if (!patchContent.contains("---") || !patchContent.contains("+++"))
        return {callId, name(), true, "Invalid patch format"};
    
    // 2. 创建临时补丁文件
    QTemporaryFile tempPatch;
    tempPatch.open();
    tempPatch.write(patchContent.toUtf8());
    tempPatch.flush();
    QString patchFile = tempPatch.fileName();
    
    // 3. 调用Codex CLI（关键步骤）
    QProcess process;
    process.setWorkingDirectory(cwd);
    process.start("codex", {
        "apply-patch",
        patchFile,
        "--cwd", cwd,
        "--json"
    });
    
    if (!process.waitForFinished(30000)) {  // 30秒超时
        process.kill();
        return {callId, name(), true, "Patch application timeout"};
    }
    
    // 4. 解析JSON结果
    if (process.exitCode() != 0) {
        return {callId, name(), true, "Codex apply-patch failed"};
    }
    
    QString output = QString::fromUtf8(process.readAllStandardOutput());
    QJsonDocument doc = QJsonDocument::fromJson(output.toUtf8());
    QJsonObject result = doc.object();
    
    int filesChanged = result.value("files_changed").toInt(0);
    QString message = QString("✓ Patch applied to %1 files").arg(filesChanged);
    
    return {callId, name(), false, message};
}
```

**特点：**
- ✅ **增量更新** - 只需传输差异部分，网络效率高
- ✅ **冲突检测** - 补丁冲突时可回滚
- ✅ **可审核** - 补丁格式易于代码审查
- ⚠️ **外部依赖** - 需要Codex CLI二进制程序
- ⚠️ **复杂度高** - 需要正确生成diff格式

---

### 方式3：文件写入工具（CodexWriteFileTool）

**原理：** 结合方式1和方式2的优点 - 通过生成内容，自动生成补丁，再用Codex CLI应用。

**实现流程：**

```
LLM Agent
  ↓
生成文件内容 + 文件路径
  ↓
CodexWriteFileTool.execute()
  ├─ 步骤1: 读取现有文件（如果存在）
  │  └─ QFile::read() 获取原内容
  │
  ├─ 步骤2: 自动生成Unified Diff
  │  └─ compareContent() 计算差异
  │  └─ generateUnifiedDiff() 生成补丁
  │
  ├─ 步骤3: 创建临时补丁文件
  │  └─ QTemporaryFile
  │
  ├─ 步骤4: 通过Codex CLI应用补丁
  │  └─ QProcess::start("codex apply-patch ...")
  │
  ├─ 步骤5: 验证文件内容
  │  └─ 读取并比对新旧内容
  │
  └─ 返回 ToolResult
```

**代码示例：**

```cpp
ToolResult CodexWriteFileTool::execute(const QString &callId, const QJsonObject &args)
{
    QString filePath = args.value("file_path").toString();
    QString newContent = args.value("content").toString();
    
    // 1. 路径验证
    QString absPath = safePath(filePath);
    
    // 2. 读取旧内容
    QString oldContent = readExistingFile(absPath);
    
    // 3. 自动生成补丁
    QString patch = generateUnifiedDiff(absPath, oldContent, newContent);
    
    // 4. 通过CodexApplyPatchTool应用补丁
    CodexApplyPatchTool patchTool(m_workspaceRoot);
    patchTool.setSandboxManager(m_sandboxManager);
    
    QJsonObject patchArgs;
    patchArgs["patch"] = patch;
    patchArgs["cwd"] = m_workspaceRoot;
    
    return patchTool.execute(callId, patchArgs);
}

// 生成统一差异格式
QString CodexWriteFileTool::generateUnifiedDiff(
    const QString &filePath,
    const QString &oldContent,
    const QString &newContent) const
{
    QString diff;
    diff += "--- a/" + filePath + "\n";
    diff += "+++ b/" + filePath + "\n";
    
    auto oldLines = oldContent.split('\n', Qt::KeepEmptyParts);
    auto newLines = newContent.split('\n', Qt::KeepEmptyParts);
    
    // 简化版：整个文件替换（完全diff）
    diff += QString("@@ -1,%1 +1,%2 @@\n").arg(oldLines.size()).arg(newLines.size());
    
    for (const auto &line : oldLines)
        diff += "-" + line + "\n";
    for (const auto &line : newLines)
        diff += "+" + line + "\n";
    
    return diff;
}
```

**特点：**
- ✅ **最安全** - 利用Codex的验证系统
- ✅ **自动化** - 自动生成补丁，无需人工干预
- ✅ **增量** - 支持部分更新
- ⚠️ **性能** - 额外的补丁生成步骤

---

## 三、完整调用链对比

### 直接写入链
```
Agent (LLM) 
  → WriteTool.execute()
    → QDir::mkpath()         [创建目录]
    → QSaveFile::open()      [打开文件]
    → QTextStream::write()   [写入内容]
    → QSaveFile::commit()    [原子提交]
    → QFile::exists()        [验证]
  → ToolResult 返回给Agent
```

### Codex补丁链
```
Agent (LLM)
  → CodexApplyPatchTool.execute()
    → validatePatchFormat()           [验证补丁]
    → QTemporaryFile()                [临时文件]
    → QProcess::start("codex apply-patch...")  [子进程调用]
    → JSON解析结果
    → ToolResult 返回给Agent
    → (Codex CLI 自己处理文件操作)
```

### 文件写入工具链
```
Agent (LLM)
  → CodexWriteFileTool.execute()
    → readExistingFile()              [读原文件]
    → generateUnifiedDiff()           [生成补丁]
    → CodexApplyPatchTool.execute()   [应用补丁]
      → QProcess::start("codex apply-patch...")
    → ToolResult 返回给Agent
```

---

## 四、安全防护机制

所有写入工具都包含这些关键的安全检查：

### 1. 路径安全（防止目录遍历）
```cpp
QString safePath(const QString& relOrAbsPath) const
{
    QFileInfo fileInfo(relOrAbsPath);
    if (fileInfo.isAbsolute()) {
        return QDir::cleanPath(fileInfo.absoluteFilePath());
    }
    return QDir::cleanPath(m_root.absoluteFilePath(relOrAbsPath));
}

// 验证路径在工作空间内
bool isPathInsideWorkspace(const QString &path, const QString &workspaceRoot)
{
    const QString cleanRoot = QDir::cleanPath(workspaceRoot);
    const QString cleanPath = QDir::cleanPath(path);
    
    if (cleanPath == cleanRoot)
        return true;

    const QString relative = QDir(cleanRoot).relativeFilePath(cleanPath);
    return !relative.isEmpty()
        && !relative.startsWith("..")           // ← 防止 ../../
        && !QDir::isAbsolutePath(relative);
}
```

### 2. Sandbox权限检查
```cpp
if (!m_sandboxManager->canAccess(absPath, FileSystemAccessMode::Write))
    return {callId, name(), true, "Access denied"};
```

### 3. 原子写入（无部分写入）
```cpp
QSaveFile save(absPath);
save.open(QIODevice::WriteOnly | QIODevice::Text);
// ... 写入 ...
if (!save.commit()) {  // ← 失败自动回滚临时文件
    save.cancelWriting();
    return error;
}
```

### 4. 写入验证
```cpp
if (!QFile::exists(absPath))
    return error;  // 文件未成功创建

QFileInfo verifyInfo(absPath);
qint64 writtenSize = verifyInfo.size();  // 验证字节数
```

---

## 五、工作流程示例

### 用户请求：创建 hello.cpp 文件

**Agent内部思考过程：**
```
1. 用户: "创建一个Hello World程序"
2. 代理分析: 需要创建 src/hello.cpp
3. 代理生成: 完整C++代码
4. 代理选择工具: WriteTool (简单新文件 → 直接写入)
5. 调用: WriteTool({ file_path: "src/hello.cpp", new_text: "..." })
6. 执行流程:
   - 验证路径：src/hello.cpp → /workspace/src/hello.cpp ✓
   - 检查权限：Sandbox允许写入 ✓
   - 创建目录：/workspace/src/ ✓
   - 写入文件：原子操作 ✓
   - 验证：文件存在且大小正确 ✓
7. 返回: { isError: false, message: "✓ Created src/hello.cpp (245 bytes)" }
8. 代理报告给用户: "已成功创建 hello.cpp 文件"
```

### 用户请求：修改现有文件的某个函数

**Agent内部思考过程：**
```
1. 用户: "修改 main.cpp 中的 calculateSum 函数"
2. 代理读取: ReadTool({ file_path: "main.cpp" }) → 获取原内容
3. 代理生成: 修改后的函数代码
4. 代理分析: 只修改一部分 → 选择 CodexApplyPatchTool (补丁)
5. 代理生成补丁:
   --- a/main.cpp
   +++ b/main.cpp
   @@ -15,7 +15,8 @@
    int calculateSum(const std::vector<int>& nums) {
   -    int total = 0;
   +    int total = 1;  // 初始化为1
        for (int num : nums) {
            total += num;
        }
6. 调用: CodexApplyPatchTool({ patch: "...", cwd: "/workspace" })
7. 执行:
   - 验证补丁格式 ✓
   - 创建临时补丁文件 ✓
   - 启动: codex apply-patch /tmp/patch_xyz --cwd /workspace --json
   - Codex处理: 应用补丁，检测冲突，更新文件
   - 解析结果: { files_changed: 1, changed_files: ["main.cpp"] }
8. 返回: { isError: false, message: "✓ Patch applied to 1 files" }
9. 代理确认: "已成功修改 main.cpp"
```

---

## 六、错误处理示例

### 常见错误场景

**1. 路径遍历攻击检测**
```cpp
// 输入: "../../../etc/passwd"
// 验证: 相对路径化
QString absPath = m_root.absoluteFilePath("../../../etc/passwd");
// → /workspace/../../../etc/passwd
QString cleaned = QDir::cleanPath(absPath);
// → /etc/passwd

// 检查是否在工作空间内
QString relative = m_root.relativeFilePath(cleaned);
// → ../../etc/passwd (包含 ..)
// ✗ 拒绝：检测到目录遍历攻击
```

**2. 权限被Sandbox拒绝**
```cpp
// 输入: file_path = "/etc/hosts"
// 沙箱检查
if (!m_sandboxManager->canAccess("/etc/hosts", FileSystemAccessMode::Write))
    return {callId, name(), true, "Sandbox policy denied write access"};
```

**3. 原子写入失败**
```cpp
// QSaveFile 失败时自动回滚
QSaveFile save(path);
save.open(...);
// ... write ...
if (!save.commit()) {  // ← 操作系统权限不足或空间不足
    save.cancelWriting();  // 自动删除临时文件
    return error;
}
```

**4. 补丁应用失败**
```cpp
// Codex CLI 返回非零退出码
if (process.exitCode() != 0) {
    QString error = QString::fromUtf8(process.readAllStandardError());
    // 原因可能：
    // - 补丁格式不正确
    // - 目标文件不存在
    // - 行号不匹配（文件已修改）
    return {callId, name(), true, "Patch application failed: " + error};
}
```

---

## 七、性能考量

| 方式 | 延迟 | 网络 | 内存 | CPU | 并发 |
|------|------|------|------|------|------|
| WriteTool | 最低 | 不涉及 | 中 | 低 | 需要锁 |
| CodexApplyPatchTool | 中 | 低 | 中 | 中 | 可靠 |
| CodexWriteFileTool | 最高 | 低 | 高 | 中 | 最安全 |

**选择建议：**
- 📝 新建小文件：`WriteTool` (直接快速)
- ✏️ 修改部分内容：`CodexApplyPatchTool` (高效)
- 🔒 关键系统文件：`CodexWriteFileTool` (最安全)
- 🌐 远程编辑：`CodexApplyPatchTool` (补丁传输小)

---

## 八、总结

| 维度 | WriteTool | Patch | CodexWrite |
|------|-----------|-------|-----------|
| **实现复杂度** | 低 | 中 | 高 |
| **执行速度** | 快 | 中 | 慢 |
| **安全性** | 中 | 高 | 最高 |
| **冲突处理** | 无 | 有 | 有 |
| **适用场景** | 新文件 | 部分修改 | 关键操作 |
| **验证能力** | 基础 | 完整 | 完整 |

所有方式都遵循这个基本安全模式：

```
输入验证 → 路径清理 → Sandbox检查 → 操作 → 验证 → 日志 → 返回结果
```

这确保了代码代理在执行文件操作时的安全性和可靠性。
