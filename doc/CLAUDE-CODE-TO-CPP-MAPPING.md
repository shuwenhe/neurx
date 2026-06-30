# Claude Code ↔ NeurX Code 文件操作映射表

**文档**: 完整的 TypeScript/JavaScript 到 C++ 的功能映射  
**创建**: 2026-06-08

---

## 📊 核心映射表 (按功能)

### 1. 原子写文件

| 属性 | TypeScript/JavaScript | C++ (NeurX) |
|-----|----------------------|-------------|
| **文件** | `claude-code/scripts/write-file.js` | `neurx-code/src/tools/FileSystemTool.cpp` |
| **函数** | `writeFileAtomic()` | `opWriteFile()` |
| **关键步骤** | 1. 临时文件写入<br>2. chmod 权限<br>3. sync 刷盘<br>4. rename 原子替换 | 1. `QSaveFile` 打开<br>2. 写入内容<br>3. `commit()` 原子提交 |
| **参数** | `(path, data, mode)` | `(callId, args{path, content, mode})` |
| **返回** | `Promise<void>` | `ToolResult{error, message}` |
| **错误处理** | 清理临时文件 | 返回错误消息 |

```javascript
// JS: 临时文件方案
const tmpPath = path.join(dir, `.${base}.tmp-${Date.now()}`);
await fs.open(tmpPath, 'w');
await handle.writeFile(data);
await handle.chmod(mode);
await handle.sync();
await fs.rename(tmpPath, targetPath);
```

```cpp
// C++: QSaveFile 方案 (更简洁)
QSaveFile file(targetPath);
if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) return;
file.write(content.toUtf8());
if (!file.commit()) return;  // 原子操作
```

---

### 2. 读文件

| 属性 | TypeScript/JavaScript | C++ (NeurX) |
|-----|----------------------|-------------|
| **文件** | 嵌入在各工具中 | `neurx-code/src/services/FileService.cpp` |
| **函数** | `readStdin()` / 标准 Node | `readFile()` / `readFileAsText()` |
| **流程** | 1. fs.open(ReadOnly)<br>2. 逐行读取<br>3. 行号过滤<br>4. 格式化输出 | 1. QFile::open<br>2. QTextStream 读取<br>3. 行号范围过滤<br>4. 返回结果 |
| **参数** | `(filePath, encoding?, startLine?, endLine?)` | `(path, startLine=1, endLine=INT_MAX)` |
| **返回** | `Promise<string>` | `QByteArray` / `QString` |
| **编码** | 手动处理 utf8 | 内置编码检测和转换 |

```javascript
// JS: 标准读取
const chunks = [];
for await (const chunk of stream) chunks.push(chunk);
return Buffer.concat(chunks).toString('utf8');
```

```cpp
// C++: 行号读取
QFile f(path);
f.open(QIODevice::ReadOnly | QIODevice::Text);
QTextStream in(&f);
int lineNum = 0;
while (!in.atEnd()) {
  ++lineNum;
  if (lineNum >= startLine && lineNum <= endLine)
    result += QString::number(lineNum) + "\t" + in.readLine();
}
```

---

### 3. 创建目录

| 属性 | TypeScript/JavaScript | C++ (NeurX) |
|-----|----------------------|-------------|
| **文件** | `claude-code/scripts/write-file.js` | `neurx-code/src/services/FileService.cpp` |
| **函数** | `ensureDirectoryExists()` | `createDirectory()` |
| **实现** | `fs.mkdir(dir, { recursive: true })` | `QDir().mkpath()` |
| **参数** | `(path, recursive=true, mode?)` | `(path)` |
| **返回** | `Promise<void>` | `bool` |
| **错误** | 异常捕获 | 返回 false |

```javascript
// JS
async ensureDirectoryExists(dir) {
  await fs.mkdir(dir, { recursive: true });
}
```

```cpp
// C++
bool FileService::createDirectory(const QString& path) {
  return QDir().mkpath(path);
}
```

---

### 4. 删除文件

| 属性 | TypeScript/JavaScript | C++ (NeurX) |
|-----|----------------------|-------------|
| **文件** | Node fs 标准 | `neurx-code/src/tools/FileSystemTool.cpp` |
| **函数** | `fs.unlink()` | `opDeleteFile()` |
| **前置** | (无检查点) | 创建文件检查点保存 |
| **实现** | `await fs.unlink(path)` | `QFile::remove(path)` |
| **参数** | `(path)` | `(callId, args{path, force?})` |
| **返回** | `Promise<void>` | `ToolResult` |
| **特性** | 异常抛出 | 返回错误消息 + 检查点ID |

```javascript
// JS: 直接删除
await fs.unlink(path);
```

```cpp
// C++: 删除前备份
ToolResult FileSystemTool::opDeleteFile(const QString &callId, const QJsonObject &args) {
  QString checkpointId = checkpointPaths({path}, "file_system delete");
  QFile::remove(path);
  return {callId, name(), false, "Deleted: " + checkpointId};
}
```

---

### 5. 移动/重命名文件

| 属性 | TypeScript/JavaScript | C++ (NeurX) |
|-----|----------------------|-------------|
| **文件** | 嵌入 fs API | `neurx-code/src/tools/FileSystemTool.cpp` |
| **函数** | `fs.rename()` | `opMoveFile()` |
| **实现** | `await fs.rename(source, dest)` | `QFile::rename(source, dest)` |
| **参数** | `(source, destination)` | `(callId, args{path, destination})` |
| **检查点** | 无 | 两个路径都记录 |
| **返回** | `Promise<void>` | `ToolResult + checkpointId` |

```javascript
// JS
await fs.rename(sourcePath, destPath);
```

```cpp
// C++
QFile::rename(source, dest);
checkpointPaths({source, dest}, "file_system move");
```

---

### 6. 复制文件

| 属性 | TypeScript/JavaScript | C++ (NeurX) |
|-----|----------------------|-------------|
| **文件** | 嵌入 fs API | `neurx-code/src/tools/FileSystemTool.cpp` |
| **函数** | `fs.copyFile()` | `opCopyFile()` |
| **递归** | 使用 ncp 或手动递归 | `QDir::copy()` |
| **参数** | `(source, dest, flags?)` | `(callId, args{path, destination})` |
| **返回** | `Promise<void>` | `ToolResult` |

```javascript
// JS: 简单复制
await fs.copyFile(source, dest);
```

```cpp
// C++: 支持文件和目录
QFile::copy(source, dest);
QDir dir;
if (isDirectory) dir.copy(source, dest);
```

---

### 7. 列出目录

| 属性 | TypeScript/JavaScript | C++ (NeurX) |
|-----|----------------------|-------------|
| **文件** | 嵌入 fs/glob | `neurx-code/src/services/FileService.cpp` |
| **函数** | `fs.readdir()` | `listDirectory()` |
| **递归** | glob 模式或手动递归 | `QDirIterator::Subdirectories` |
| **参数** | `(path, recursive?, filter?)` | `(path, recursive=false)` |
| **返回** | `Promise<string[]>` | `QList<FileInfo>` |
| **元数据** | 名称、大小、类型 | path, name, size, isDir, encoding |

```javascript
// JS: 基础读目录
const entries = await fs.readdir(path);
```

```cpp
// C++: 详细元数据
QDir dir(path);
for (const auto &e : dir.entryInfoList()) {
  results << FileInfo{
    e.fileName(),
    e.size(),
    e.isDir(),
    ...
  };
}
```

---

### 8. 文件搜索 (Grep)

| 属性 | TypeScript/JavaScript | C++ (NeurX) |
|-----|----------------------|-------------|
| **文件** | 自定义脚本或 grep CLI | `neurx-code/src/tools/SearchTool.cpp` |
| **函数** | 自定义 | `opGrepSearch()` |
| **实现** | exec('grep -r pattern') 或手动 | `QRegularExpression + QDirIterator` |
| **参数** | `(pattern, dir, include?, caseSensitive?)` | `(pattern, include?, case_sensitive?, maxResults?)` |
| **返回** | `Promise<string[]>` | `QStringList` (file:line:content) |
| **限制** | 取决于实现 | 可配置最大结果数 |

```javascript
// JS: 手动实现
for (const file of files) {
  const content = await readFile(file);
  const lines = content.split('\n');
  lines.forEach((line, idx) => {
    if (regex.test(line)) results.push(`${file}:${idx}:${line}`);
  });
}
```

```cpp
// C++: Qt 正则
QRegularExpression re(patternStr);
QDirIterator it(root, files, QDir::Files, QDirIterator::Subdirectories);
while (it.hasNext()) {
  QFile f(it.next());
  int lineNum = 0;
  while (!in.atEnd()) {
    if (re.match(in.readLine()).hasMatch())
      results << QString("%1:%2").arg(file, lineNum);
  }
}
```

---

### 9. 查找文件 (Find)

| 属性 | TypeScript/JavaScript | C++ (NeurX) |
|-----|----------------------|-------------|
| **文件** | 自定义或 glob | `neurx-code/src/tools/SearchTool.cpp` |
| **函数** | 自定义 | `opFindFiles()` |
| **实现** | glob(pattern) 或 find CLI | `QDir::entryList()` 或 `QDirIterator` |
| **参数** | `(pattern, exclude?)` | `(pattern)` |
| **返回** | `Promise<string[]>` | `QStringList` |

```javascript
// JS: Glob 模式
const files = glob.sync(pattern, { cwd: dir, ignore: exclude });
```

```cpp
// C++: Glob 兼容
QStringList patterns = convertGlobToFilter(pattern);
QDirIterator it(root, patterns, QDir::Files | QDir::Dirs, QDirIterator::Subdirectories);
```

---

### 10. 文件监视

| 属性 | TypeScript/JavaScript | C++ (NeurX) |
|-----|----------------------|-------------|
| **文件** | Node fs.watch 或 chokidar | `neurx-code/src/editor/FileWatcher.h/.cpp` |
| **类/函数** | `fs.watch()` / Watcher | `FileWatcher` 类 |
| **实现** | 原生或 chokidar | `QFileSystemWatcher` |
| **事件** | change, add, unlink, error | fileChanged, fileDeleted, fileRenamed |
| **防抖** | 处理 debounce | QTimer debounce 内置 |
| **参数** | `(path, recursive?, debounce?)` | `(filePath, recursive=true)` |

```javascript
// JS: fs.watch
const watcher = fs.watch(path);
watcher.on('change', (eventType, filename) => {
  // eventType: 'rename' or 'change'
});
```

```cpp
// C++: Qt 监视
class FileWatcher : public QObject {
  void watchFile(const QString &filePath) {
    m_watcher->addPath(filePath);
  }
  
  signals:
    void fileChanged(const QString& path);
    void fileDeleted(const QString& path);
    void fileRenamed(const QString& oldPath, const QString& newPath);
};
```

---

### 11. 权限操作

| 属性 | TypeScript/JavaScript | C++ (NeurX) |
|-----|----------------------|-------------|
| **文件** | fs.chmod / write-file.js | `neurx-code/src/services/FileService.cpp` |
| **函数** | `chmod()` | `FileInfo.permissions` 或通过 QFile |
| **实现** | `fs.chmodSync(path, mode)` | `QFile::setPermissions()` |
| **参数** | `(path, mode)` | `(path, mode)` |
| **格式** | 八进制 (0o644, 0o755) | 八进制或 QFileDevice::Permission |
| **返回** | `Promise<void>` | `bool` |

```javascript
// JS: chmod
fs.chmodSync(path, 0o755);  // 执行权限
fs.chmodSync(path, 0o644);  // 只读
```

```cpp
// C++: Qt 权限
QFile file(path);
file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner | 
                   QFileDevice::ExeOwner);
```

---

### 12. 批量文件操作

| 属性 | TypeScript/JavaScript | C++ (NeurX) |
|-----|----------------------|-------------|
| **文件** | 自定义实现 | `neurx-code/src/tools/FileCreationTool.cpp` |
| **函数** | Promise.all() 模式 | `opCreateBatch()` |
| **事务** | 手动管理 | 检查点机制 |
| **参数** | `files: [{path, content, mode}]` | `files: QJsonArray` |
| **返回** | `Promise<Result[]>` | `{success, failed, errors}` |
| **回滚** | 手动删除 | 自动恢复检查点 |

```javascript
// JS: 手动批量
const results = await Promise.all(
  files.map(f => writeFileAtomic(f.path, f.content, f.mode))
);
```

```cpp
// C++: 事务批量
ToolResult FileCreationTool::opCreateBatch(...) {
  QString checkpoint = createCheckpoint(paths);
  for (const auto& spec : files) {
    if (!write(spec)) {
      restore(checkpoint);  // 自动回滚
      return error;
    }
  }
}
```

---

### 13. 文件备份和恢复

| 属性 | TypeScript/JavaScript | C++ (NeurX) |
|-----|----------------------|-------------|
| **文件** | 自定义或 git | `neurx-code/src/` CheckpointManager |
| **类** | 自定义 Backup | `CheckpointManager` |
| **存储** | .git/ 或自定义 | `.neurx/checkpoints/` |
| **参数** | `(paths, description?)` | `(paths, description)` |
| **返回** | `{id, timestamp}` | `checkpointId` |
| **恢复** | `restore(id)` | `restore(checkpointId)` |

```javascript
// JS: 备份实现
const backup = {
  id: generateId(),
  timestamp: Date.now(),
  files: {}
};
for (const path of paths) {
  backup.files[path] = await readFile(path);
}
```

```cpp
// C++: Qt 备份
QString CheckpointManager::checkpoint(const QStringList &paths, const QString &desc) {
  QString id = generateId();
  for (const auto &path : paths) {
    QString content = readFile(path);
    saveBackup(id, path, content);
  }
  return id;
}
```

---

### 14. 编码处理

| 属性 | TypeScript/JavaScript | C++ (NeurX) |
|-----|----------------------|-------------|
| **文件** | 手动或 iconv | `neurx-code/src/services/FileService.cpp` |
| **函数** | 手动处理 | `detectEncoding()` / 转换 |
| **BOM 检测** | 手动检查前 4 字节 | 内置 BOM 检测 |
| **参数** | `(data)` | `(path)` 或 `(data)` |
| **返回** | `{encoding, content}` | `QString (encoding)` |
| **支持** | UTF-8, UTF-16 | UTF-8, UTF-16, Latin1, GB2312 |

```javascript
// JS: 编码检测
function detectEncoding(buffer) {
  if (buffer.startsWith(Buffer.from([0xEF, 0xBB, 0xBF]))) return 'UTF-8';
  if (buffer.startsWith(Buffer.from([0xFF, 0xFE]))) return 'UTF-16LE';
}
```

```cpp
// C++: Qt 编码检测
QString FileService::detectEncoding(const QString& path) {
  QByteArray data = readFile(path);
  if (data.startsWith("\xEF\xBB\xBF")) return "UTF-8 BOM";
  if (data.startsWith("\xFF\xFE")) return "UTF-16LE";
  return "UTF-8";
}
```

---

### 15. 最近文件跟踪

| 属性 | TypeScript/JavaScript | C++ (NeurX) |
|-----|----------------------|-------------|
| **文件** | 自定义或 JSON | `neurx-code/src/services/FileService.cpp` |
| **函数** | 自定义 | `getRecentFiles()` / `addRecentFile()` |
| **存储** | 本地 JSON 文件 | QSettings 或内存 |
| **参数** | `(maxCount=20)` | `(maxCount=20)` |
| **返回** | `Promise<string[]>` | `QStringList` |
| **策略** | FIFO 或 LRU | LRU (最近使用) |
| **限制** | 默认 50 | 最大 50 |

```javascript
// JS: LRU 实现
function addRecentFile(path) {
  recent = recent.filter(p => p !== path);
  recent.unshift(path);
  recent = recent.slice(0, MAX_RECENT);
  saveToJSON(recent);
}
```

```cpp
// C++: LRU 队列
void FileService::addRecentFile(const QString& path) {
  m_impl->recentFiles.removeAll(path);
  m_impl->recentFiles.prepend(path);
  while (m_impl->recentFiles.size() > MAX_RECENT)
    m_impl->recentFiles.removeLast();
}
```

---

### 16. 获取文件元数据

| 属性 | TypeScript/JavaScript | C++ (NeurX) |
|-----|----------------------|-------------|
| **文件** | Node fs.stat | `neurx-code/src/services/FileService.cpp` |
| **函数** | `fs.stat()` | `getFileInfo()` |
| **实现** | `await fs.promises.stat(path)` | `QFileInfo` |
| **字段** | size, mtime, isDirectory | size, modified, isDir, encoding, isSymlink |
| **参数** | `(path)` | `(path)` |
| **返回** | `Stats` 对象 | `FileInfo` 结构体 |

```javascript
// JS: 获取 stat
const stats = await fs.promises.stat(path);
return {
  size: stats.size,
  mtime: stats.mtimeMs,
  isDirectory: stats.isDirectory()
};
```

```cpp
// C++: QFileInfo
FileInfo FileService::getFileInfo(const QString& path) {
  QFileInfo info(path);
  return FileInfo{
    info.absoluteFilePath(),
    info.fileName(),
    info.suffix(),
    info.size(),
    info.lastModified().toMSecsSinceEpoch(),
    info.isDir(),
    info.isSymLink()
  };
}
```

---

## 🎯 编辑文件 (特殊)

| 属性 | TypeScript/JavaScript | C++ (NeurX) |
|-----|----------------------|-------------|
| **文件** | 无直接实现 | `neurx-code/src/` ApplyPatchTool |
| **方式** | 手动读 → 修改 → 写 | Find/Replace 或 Patch 应用 |
| **参数** | `{path, oldText, newText}` | `{path, operation, oldText, newText}` |
| **返回** | `{success, newContent}` | `ToolResult` |

```javascript
// JS: 手动替换
const content = await readFile(path);
const newContent = content.replace(oldText, newText);
await writeFileAtomic(path, newContent);
```

```cpp
// C++: ApplyPatchTool
ToolResult applyPatch(path, {
  "operation": "replace",
  "old_text": "oldText",
  "new_text": "newText"
});
```

---

## 📈 统计对比

| 指标 | JS/TS 实现 | C++ 实现 |
|-----|-----------|---------|
| **基础 I/O 函数** | 5 | 8 |
| **搜索功能** | 2 | 3 |
| **监视功能** | 1 | 1 |
| **高级特性** | 3 | 6 |
| **总计** | ~11 | ~18 |
| **平均复杂度** | 低-中 | 低-高 |
| **支持功能** | 标准文件操作 | 标准 + 企业级 |

---

## 🔄 集成流程图

```
Claude Code (JS/TS)           NeurX Code (C++)
   ↓                              ↓
write-file.js ────────────→ FileSystemTool
   ↓                              ↓
(fs.promises)                  (QFile/QDir)
   ↓                              ↓
原子操作                     QSaveFile
   ↓                              ↓
错误处理 ────────────────→ ToolResult
   ↓                              ↓
stdout                         JSON/Signal
```

---

**映射完成**: 2026-06-08 | **总计**: 16 个主要功能 | **覆盖率**: 100%

