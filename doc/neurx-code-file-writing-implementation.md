# neurx-code 文件写入功能实现指南

**项目位置：** `/Users/feifei/agent/neurx-code`  
**编译状态：** ✅ 已成功编译  
**功能状态：** ✅ 已实现并注册

---

## 一、现有文件写入工具概览

### 1. WriteTool - 创建/覆盖文件
**位置：** `src/tools/ClaudeStandardTools.h/cpp`  
**功能：** 创建新文件或覆盖现有文件

```cpp
// 工具参数
{
    "file_path": "string",    // 文件路径（相对或绝对）
    "new_text": "string"      // 文件内容
}

// 返回结果示例
{
    "success": true,
    "message": "✓ Created src/main.cpp (245 bytes)"
}
```

**使用场景：**
- 创建新源代码文件
- 创建配置文件
- 创建文档

**执行流程：**
```
输入验证 → 路径清理 → Sandbox检查 → 目录创建 → 原子写入 → 文件验证
```

---

### 2. EditTool - 字符串替换编辑
**位置：** `src/tools/ClaudeStandardTools.h/cpp`  
**功能：** 通过精确字符串匹配替换文件内容

```cpp
// 工具参数
{
    "file_path": "string",    // 文件路径
    "old_text": "string",     // 要替换的旧文本（必须精确匹配）
    "new_text": "string"      // 替换后的新文本
}

// 返回结果示例
{
    "success": true,
    "message": "✓ Edited src/main.cpp (replaced 1 occurrence)"
}
```

**使用场景：**
- 修改函数实现
- 更新配置值
- 修复bug

**限制：** old_text必须在文件中精确存在

---

### 3. MultiEditTool - 批量编辑
**位置：** `src/tools/ClaudeStandardTools.h/cpp`  
**功能：** 单个文件的多个编辑操作

```cpp
// 工具参数
{
    "file_path": "string",
    "edits": [
        {
            "old_text": "string",
            "new_text": "string"
        },
        // ... 更多编辑 ...
    ]
}

// 返回结果示例
{
    "success": true,
    "message": "✓ Applied 3 edits to src/main.cpp"
}
```

**特点：** 多个编辑原子执行（全成功或全失败）

---

### 4. ReadTool - 读取文件
**位置：** `src/tools/ClaudeStandardTools.h/cpp`  
**功能：** 读取文件内容

```cpp
// 工具参数
{
    "file_path": "string",    // 文件路径
    "start_line": 10,         // 可选：起始行
    "end_line": 20            // 可选：结束行
}

// 返回结果示例
{
    "success": true,
    "content": "... 文件内容 ..."
}
```

---

### 5. 补丁工具 - Codex集成写入
**位置：** `src/tools/CodexApplyPatchTool.h/cpp`

#### CodexApplyPatchTool
应用Unified Diff补丁
```cpp
{
    "patch": "string",      // Unified Diff 格式补丁
    "cwd": "string",        // 工作目录（可选）
    "auto_approve": bool    // 自动批准（可选）
}
```

#### CodexWriteFileTool
通过Codex CLI写入文件（最安全）
```cpp
{
    "file_path": "string",     // 文件路径
    "content": "string",       // 文件内容
    "description": "string"    // 更改描述（可选）
}
```

---

## 二、工具注册现状

### 当前注册的工具

所有工具都在 `ClaudeStandardToolFactory::registerAllTools()` 中注册：

```cpp
// src/tools/ClaudeStandardTools.cpp (第1119行)
void ClaudeStandardToolFactory::registerAllTools(const QString& workspaceRoot,
                                                 AgentToolRegistry* registry,
                                                 SandboxManager* sandboxManager)
{
    if (!registry) return;

    registry->registerTool(createWriteTool(workspaceRoot, sandboxManager));
    registry->registerTool(createEditTool(workspaceRoot, sandboxManager));
    registry->registerTool(createMultiEditTool(workspaceRoot, sandboxManager));
    registry->registerTool(createReadTool(workspaceRoot, sandboxManager));
    registry->registerTool(createBashTool(workspaceRoot, sandboxManager));
    registry->registerTool(createGrepTool(workspaceRoot, sandboxManager));
    registry->registerTool(createGlobTool(workspaceRoot, sandboxManager));
}
```

### 在AgentController中的调用

```cpp
// src/bridge/AgentController.cpp (第3063行)
ClaudeStandardToolFactory::registerAllTools(path, m_registry, m_sandboxManager);

// 同时还注册了Codex工具
CodexFilesystemToolFactory::registerFilesystemTools(path, m_registry, m_sandboxManager);
```

---

## 三、安全防护机制

### 1. 路径安全验证

```cpp
// 防止目录遍历攻击 (../../../etc/passwd)
QString safePath(const QString& relOrAbsPath) const
{
    QFileInfo fileInfo(relOrAbsPath);
    if (fileInfo.isAbsolute()) {
        return QDir::cleanPath(fileInfo.absoluteFilePath());
    }
    // 相对路径转为绝对路径并清理
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
        && !relative.startsWith("..")          // ← 关键防护
        && !QDir::isAbsolutePath(relative);
}
```

### 2. Sandbox权限检查

```cpp
// 每次文件操作前检查权限
if (m_sandboxManager) {
    if (!m_sandboxManager->canAccess(absPath, FileSystemAccessMode::Write)) {
        return {callId, name(), true, "Sandbox policy denied write access"};
    }
}
```

### 3. 原子操作保证

```cpp
// QSaveFile 确保原子性
QSaveFile save(absPath);
if (!save.open(QIODevice::WriteOnly | QIODevice::Text))
    return error;

QTextStream out(&save);
out << newText;
out.flush();

// 失败时自动回滚，不留垃圾文件
if (!save.commit()) {
    save.cancelWriting();  // ← 自动清理临时文件
    return error;
}
```

### 4. 写入后验证

```cpp
// 验证文件确实被写入
if (!QFile::exists(absPath))
    return {callId, name(), true, "File was not created"};

QFileInfo verifyInfo(absPath);
qint64 writtenSize = verifyInfo.size();
qInfo() << "Successfully wrote" << writtenSize << "bytes";
```

---

## 四、实际工作流程示例

### 场景1：Agent创建新C++文件

```
用户: "创建一个Hello World程序"
  ↓
Agent分析: 需要创建 src/hello.cpp
  ↓
Agent生成完整代码:
   #include <iostream>
   int main() {
       std::cout << "Hello, World!" << std::endl;
       return 0;
   }
  ↓
Agent调用 WriteTool:
{
    "file_path": "src/hello.cpp",
    "new_text": "..." // 完整代码
}
  ↓
WriteTool执行流程:
   1. 路径验证: src/hello.cpp → /workspace/src/hello.cpp ✓
   2. 权限检查: Sandbox允许写入 ✓
   3. 创建目录: mkdir -p /workspace/src ✓
   4. 原子写入: 写入到临时文件后原子提交 ✓
   5. 验证: 文件存在且大小正确 ✓
  ↓
返回结果:
{
    "success": true,
    "message": "✓ Created src/hello.cpp (147 bytes)"
}
  ↓
Agent报告: "已成功创建 hello.cpp 文件"
```

### 场景2：Agent修改现有文件的函数

```
用户: "修改 main.cpp 中的 calculateSum 函数"
  ↓
Agent读取现有文件:
   ReadTool({ "file_path": "main.cpp" })
   → 获取完整内容
  ↓
Agent分析修改点:
   旧代码: int calculateSum(const vector<int>& nums) {
               int total = 0;
           旧代码: int calculateSum(const vector<int>& nums) {
               int total = 1;  // 初始化为1
  ↓
Agent调用 EditTool:
{
    "file_path": "main.cpp",
    "old_text": "int calculateSum(const vector<int>& nums) {\n    int total = 0;",
    "new_text": "int calculateSum(const vector<int>& nums) {\n    int total = 1;  // 初始化为1"
}
  ↓
EditTool执行:
   1. 路径验证 ✓
   2. 权限检查 ✓
   3. 读取文件内容
   4. 查找 old_text (精确匹配)
   5. 替换为 new_text
   6. 原子写入新内容
   7. 验证
  ↓
返回:
{
    "success": true,
    "message": "✓ Edited main.cpp (replaced 1 occurrence)"
}
```

### 场景3：Agent执行多个编辑

```
Agent调用 MultiEditTool:
{
    "file_path": "config.cpp",
    "edits": [
        {
            "old_text": "#define MAX_SIZE 100",
            "new_text": "#define MAX_SIZE 1000"
        },
        {
            "old_text": "#define DEBUG false",
            "new_text": "#define DEBUG true"
        },
        {
            "old_text": "static int timeout = 30;",
            "new_text": "static int timeout = 60;"
        }
    ]
}
  ↓
MultiEditTool:
   1. 验证所有编辑点都存在（全检查）
   2. 如果全部存在，执行所有替换（原子操作）
   3. 如果任何一个不存在，全部回滚（保证一致性）
  ↓
返回:
{
    "success": true,
    "message": "✓ Applied 3 edits to config.cpp"
}
```

---

## 五、调试和日志

### 启用详细日志

编译时启用QDebug输出：

```bash
cd neurx-code/build
QT_LOGGING_RULES="*=true" cmake --build . --target neurx-codeApp
```

### 关键日志输出

WriteTool的详细日志：

```
[WriteTool] callId Step 1: Resolved absolute path: /workspace/src/main.cpp
[WriteTool] callId Workspace root: /workspace
[WriteTool] callId Parent directory: /workspace/src
[WriteTool] callId Step 2: Sandbox permission check PASSED
[WriteTool] callId Step 3: Parent directory ensured
[WriteTool] callId File exists, preserving permissions
[WriteTool] callId Step 4: File opened for writing
[WriteTool] callId Step 5: Content flushed to stream
[WriteTool] callId Step 6: File committed atomically
[WriteTool] callId SUCCESS: Wrote 245 bytes to: /workspace/src/main.cpp
```

---

## 六、集成测试

### 测试脚本：test-file-writing.sh

```bash
#!/bin/bash

WORKSPACE="/tmp/neurx-test-workspace"
PROJECT="$WORKSPACE/test-project"

# 创建测试工作空间
mkdir -p "$PROJECT"
cd "$PROJECT"

# 测试1: WriteTool - 创建新文件
echo "=== Test 1: WriteTool (Create File) ==="
cat > test-create.json << 'EOF'
{
    "method": "agent:execute_tool",
    "params": {
        "tool_name": "Write",
        "args": {
            "file_path": "src/hello.cpp",
            "new_text": "#include <iostream>\nint main() {\n    std::cout << \"Hello!\" << std::endl;\n    return 0;\n}\n"
        }
    }
}
EOF

# 测试2: ReadTool - 读取文件
echo "=== Test 2: ReadTool (Read File) ==="
cat > test-read.json << 'EOF'
{
    "method": "agent:execute_tool",
    "params": {
        "tool_name": "Read",
        "args": {
            "file_path": "src/hello.cpp"
        }
    }
}
EOF

# 测试3: EditTool - 修改文件
echo "=== Test 3: EditTool (Edit File) ==="
cat > test-edit.json << 'EOF'
{
    "method": "agent:execute_tool",
    "params": {
        "tool_name": "Edit",
        "args": {
            "file_path": "src/hello.cpp",
            "old_text": "int main()",
            "new_text": "int main()  // Modified"
        }
    }
}
EOF

# 测试4: MultiEditTool - 批量编辑
echo "=== Test 4: MultiEditTool (Multiple Edits) ==="
cat > test-multi-edit.json << 'EOF'
{
    "method": "agent:execute_tool",
    "params": {
        "tool_name": "MultiEdit",
        "args": {
            "file_path": "src/hello.cpp",
            "edits": [
                {
                    "old_text": "// Modified",
                    "new_text": ""
                },
                {
                    "old_text": "Hello!",
                    "new_text": "Hello, neurx-code!"
                }
            ]
        }
    }
}
EOF

echo "Test cases generated in: $PROJECT"
ls -la test-*.json
```

---

## 七、编译和运行

### 编译neurx-code

```bash
cd /Users/feifei/agent/neurx-code/build

# 完整重新编译
cmake --build . --target neurx-codeApp

# 查看编译结果
ls -lah neurx-codeApp
```

### 运行应用

```bash
# 启动neurx-code应用
./neurx-codeApp

# 启用日志输出
QT_LOGGING_RULES="neurx-code.*=true" ./neurx-codeApp
```

---

## 八、工具能力总结表

| 工具 | 功能 | 参数 | 返回值 | 场景 |
|------|------|------|--------|------|
| **Write** | 创建/覆盖文件 | file_path, new_text | success, message | 新建文件 |
| **Edit** | 字符串替换 | file_path, old_text, new_text | success, message | 修改部分代码 |
| **MultiEdit** | 多个编辑 | file_path, edits[] | success, message | 原子多修改 |
| **Read** | 读取文件 | file_path, start_line?, end_line? | success, content | 代码审查 |
| **Bash** | 执行命令 | command, timeout? | success, output | 构建、测试 |
| **Grep** | 搜索文件 | pattern, file_path? | success, results | 代码查找 |
| **Glob** | 列表文件 | pattern | success, files | 目录浏览 |
| **CodexApplyPatch** | 应用补丁 | patch, cwd? | success, files_changed | 补丁应用 |
| **CodexWriteFile** | Codex写入 | file_path, content | success, message | 关键文件 |

---

## 九、常见问题解答

### Q1: 如何防止误操作删除文件？
**A:** 所有写入操作都受到三层防护：
1. 路径验证（防止逃逸）
2. Sandbox权限检查
3. 原子操作（保证数据一致性）

### Q2: 如果EditTool找不到old_text怎么办？
**A:** 返回错误信息，不进行任何修改。这是设计上的保障：必须精确匹配才能修改。

### Q3: 大文件（>100MB）会有问题吗？
**A:** WriteTool在内存中工作。建议：
- 小文件（<10MB）：直接使用 WriteTool
- 大文件（>10MB）：考虑使用 Bash 工具分块写入
- 关键文件：使用 CodexWriteFileTool

### Q4: 如何批量创建多个文件？
**A:** 代理可以多次调用 WriteTool，每次创建一个文件。工具框架确保顺序执行。

### Q5: 支持二进制文件吗？
**A:** 当前实现基于 QTextStream，主要支持文本文件。二进制文件需要特殊处理。

---

## 十、最佳实践

### ✅ 推荐做法

1. **新建文件** - 使用 WriteTool（直接高效）
   ```json
   {
       "file_path": "new_file.cpp",
       "new_text": "... complete content ..."
   }
   ```

2. **修改部分** - 使用 EditTool（精确可靠）
   ```json
   {
       "file_path": "existing.cpp",
       "old_text": "old code",
       "new_text": "new code"
   }
   ```

3. **多个修改** - 使用 MultiEditTool（原子保证）
   ```json
   {
       "file_path": "config.cpp",
       "edits": [
           { "old_text": "...", "new_text": "..." },
           { "old_text": "...", "new_text": "..." }
       ]
   }
   ```

4. **关键文件** - 使用 CodexWriteFileTool（最安全）
   ```json
   {
       "file_path": "critical_config.cpp",
       "content": "...",
       "description": "Security configuration update"
   }
   ```

### ⚠️ 需要避免的做法

1. ❌ **不要** 使用绝对路径（如 `/etc/passwd`）
   - 会被Sandbox拒绝

2. ❌ **不要** 在 EditTool 中使用模糊的 old_text
   - 必须精确匹配，否则失败

3. ❌ **不要** 一次生成超大文件（>500MB）
   - 超级大文件应该用 Bash 脚本分块处理

4. ❌ **不要** 假设目录已存在
   - WriteTool 会自动创建，但 EditTool 要求文件存在

---

## 十一、技术细节参考

### 编译相关文件

- `src/tools/ClaudeStandardTools.h` - 工具声明
- `src/tools/ClaudeStandardTools.cpp` - 工具实现
- `src/tools/CodexApplyPatchTool.h` - Codex补丁工具声明
- `src/tools/CodexApplyPatchTool.cpp` - Codex补丁工具实现
- `src/bridge/AgentController.cpp` - 工具注册点

### 运行时依赖

- Qt6 Core (文件操作)
- Qt6 Concurrent (并发)
- SandboxManager (权限控制)
- AgentToolRegistry (工具注册)
- Codex CLI (补丁应用)

---

## 十二、下一步改进方向

### 可能的增强功能

1. **二进制文件支持** - 扩展 WriteTool 支持二进制数据
2. **流式写入** - 对超大文件的流式处理
3. **差异展示** - EditTool 应用前显示差异
4. **版本控制集成** - 自动 git commit
5. **冲突解决** - 多代理同时编辑时的冲突处理
6. **性能优化** - 大文件的缓冲区优化
7. **权限管理** - 细粒度的文件权限控制

---

## 总结

neurx-code 项目已经完整实现了文件写入功能，包括：

✅ 多种写入方式（直接、编辑、批量、补丁）  
✅ 完善的安全防护（路径、权限、原子性）  
✅ 详细的日志和错误处理  
✅ Codex CLI 集成  
✅ 完全编译成功

所有工具都已注册到 Agent 框架中，可以直接被 LLM 代理调用进行文件操作。
