# Claude Code 文件操作功能快速实现指南

**创建日期**: 2026-06-08  
**用途**: 在 C++ 中实现对应功能的快速参考

---

## 🚀 快速实现矩阵

### 表格格式 (易于查找)

| # | 功能 | JS/TS 实现 | 参数 | C++ 对标 | 复杂度 | 状态 |
|---|------|-----------|------|---------|--------|------|
| 1 | **写文件(原子)** | `writeFileAtomic` | `path,data,mode` | FileSystemTool::opWriteFile | ⭐⭐⭐ | ✅ |
| 2 | **读文件** | `readFile` | `path,encoding,start_line,end_line` | FileService::readFile | ⭐⭐ | ✅ |
| 3 | **创建目录** | `ensureDirectoryExists` | `path,recursive,mode` | FileService::createDirectory | ⭐ | ✅ |
| 4 | **删除文件** | `fs.unlink` | `path,force` | FileSystemTool::opDeleteFile | ⭐⭐ | ✅ |
| 5 | **移动文件** | `fs.rename` | `source,dest` | FileSystemTool::opMoveFile | ⭐⭐ | ✅ |
| 6 | **复制文件** | `fs.copyFile` | `source,dest,recursive` | FileSystemTool::opCopyFile | ⭐⭐ | ✅ |
| 7 | **列目录** | `fs.readdir` | `path,recursive,filter` | FileService::listDirectory | ⭐⭐ | ✅ |
| 8 | **编辑文件** | 自定义 | `path,operation,text` | ApplyPatchTool | ⭐⭐⭐ | ✅ |
| 9 | **文件搜索** | 自定义 | `pattern,include,case_sens` | SearchTool::opGrepSearch | ⭐⭐ | ✅ |
| 10 | **查找文件** | 自定义 | `pattern,exclude,max_res` | SearchTool::opFindFiles | ⭐ | ✅ |
| 11 | **文件监视** | 自定义 | `path,recursive,debounce` | FileWatcher | ⭐⭐⭐ | ✅ |
| 12 | **权限操作** | 嵌入式 | `path,mode` | FileService::chmod | ⭐ | ✅ |
| 13 | **批量操作** | 自定义 | `files,atomic` | FileCreationTool::opCreateBatch | ⭐⭐⭐ | ✅ |
| 14 | **备份/恢复** | 自定义 | `paths,description` | CheckpointManager | ⭐⭐⭐ | ✅ |
| 15 | **获取元数据** | `fs.stat` | `path` | FileService::getFileInfo | ⭐ | ✅ |
| 16 | **编码处理** | 自定义 | `path,encoding,auto_detect` | FileService::detectEncoding | ⭐⭐ | ✅ |
| 17 | **最近文件** | 自定义 | `maxCount` | FileService::getRecentFiles | ⭐ | ✅ |

---

## 📝 按类别分组的实现顺序

### Phase 1: 基础 I/O (必须)
```
1. readFile          ← FileService::readFile
2. writeFileAtomic   ← FileSystemTool::opWriteFile  
3. createDirectory   ← FileService::createDirectory
4. deleteFile        ← FileSystemTool::opDeleteFile
```

### Phase 2: 文件操作 (重要)
```
5. moveFile          ← FileSystemTool::opMoveFile
6. copyFile          ← FileSystemTool::opCopyFile
7. listDirectory     ← FileService::listDirectory
8. getFileInfo       ← FileService::getFileInfo
```

### Phase 3: 搜索功能 (辅助)
```
9. grepSearch        ← SearchTool::opGrepSearch
10. findFiles        ← SearchTool::opFindFiles
11. detectEncoding   ← FileService::detectEncoding
```

### Phase 4: 高级功能 (可选)
```
12. watchFile        ← FileWatcher
13. editFile         ← ApplyPatchTool
14. batchCreate      ← FileCreationTool
15. checkpoint       ← CheckpointManager
```

---

## 🔧 关键实现细节速查

### 1️⃣ 原子写入
```cpp
// 关键：tmp 文件 → chmod → sync → rename
async writeFileAtomic(targetPath, data, mode) {
  tmpPath = createTempFile(targetPath);
  write(tmpPath, data);
  if (mode) chmod(tmpPath, mode);
  fsync(tmpPath);
  rename(tmpPath, targetPath);  // 原子！
}
```
- **Qt 对标**: `QSaveFile`
- **难点**: 确保 fsync 后再 rename

### 2️⃣ 路径安全检查
```cpp
// 关键：相对路径 → 绝对路径 → 验证在 workspace 内
QString safePath(const QString &rel) {
  abs = QDir::cleanPath(m_root.absoluteFilePath(rel));
  if (!abs.startsWith(m_root.path())) return {};  // 拒绝
}
```
- **检查**: `path.relative(root, abs).startsWith("..")`
- **Qt 对标**: `QDir::relativeFilePath`

### 3️⃣ 递归文件遍历
```cpp
// 关键：QDirIterator + 递归 + 模式过滤
QDirIterator it(path, nameFilters, QDir::Files, QDirIterator::Subdirectories);
while (it.hasNext()) {
  QString file = it.next();  // 自动递归
  // 处理文件
}
```
- **Qt 对标**: `QDirIterator::Subdirectories`
- **模式**: Glob 模式或正则

### 4️⃣ 编码检测
```cpp
// 关键：BOM 识别 → 编码名称
QString detectEncoding(const QByteArray &data) {
  if (data.startsWith("\xEF\xBB\xBF")) return "UTF-8 BOM";
  if (data.startsWith("\xFF\xFE")) return "UTF-16LE";
  if (data.startsWith("\xFE\xFF")) return "UTF-16BE";
  return "UTF-8";
}
```
- **Qt 对标**: `QStringConverter`
- **常见**: UTF-8, UTF-16, Latin1

### 5️⃣ 文件监视
```cpp
// 关键：QFileSystemWatcher + 防抖
m_watcher = new QFileSystemWatcher();
connect(m_watcher, &QFileSystemWatcher::fileChanged,
        this, [this](const QString &path) {
  m_debounceTimer.stop();
  m_debounceTimer.start(500);  // 防抖
});
```
- **Qt 对标**: `QFileSystemWatcher`
- **防抖**: QTimer 延迟处理

### 6️⃣ 批量原子操作
```cpp
// 关键：创建检查点 → 逐个写入 → 失败则恢复
checkpoint = createCheckpoint(paths);
for (file in files) {
  if (!write(file)) {
    restore(checkpoint);  // 回滚
    return error;
  }
}
```
- **Qt 对标**: CheckpointManager
- **事务性**: 全部成功或全部失败

---

## 🎯 逐个实现的核心代码框架

### 模板 1: 简单文件操作
```cpp
class SimpleFileOp {
public:
  bool execute(const QString &path) {
    QString safePath = validatePath(path);
    if (safePath.isEmpty()) return false;
    
    QFile file(safePath);
    if (!file.open(QIODevice::ReadOnly)) return false;
    
    // 处理文件
    
    return true;
  }
private:
  QString validatePath(const QString &path) {
    if (path.isEmpty()) return {};
    QString abs = QDir::cleanPath(m_root.absoluteFilePath(path));
    // 检查 traversal
    if (QDir(m_root).relativeFilePath(abs).startsWith("..")) 
      return {};
    return abs;
  }
};
```

### 模板 2: 写操作 + 检查点
```cpp
class WriteFileOp {
public:
  bool execute(const QString &path, const QString &content) {
    QString safePath = validatePath(path);
    if (safePath.isEmpty()) return false;
    
    // 创建检查点
    QString id = m_checkpoint->checkpoint({path}, "write_file");
    
    // 原子写入
    QSaveFile file(safePath);
    if (!file.open(QIODevice::WriteOnly)) return false;
    file.write(content.toUtf8());
    if (!file.commit()) return false;
    
    return true;
  }
};
```

### 模板 3: 迭代 + 搜索
```cpp
class SearchOp {
public:
  QStringList execute(const QString &pattern) {
    QRegularExpression re(pattern);
    QDirIterator it(m_root, QDir::Files, QDirIterator::Subdirectories);
    QStringList results;
    
    while (it.hasNext()) {
      QString file = it.next();
      QFile f(file);
      if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) continue;
      
      QTextStream in(&f);
      int lineNum = 0;
      while (!in.atEnd()) {
        ++lineNum;
        if (re.match(in.readLine()).hasMatch()) {
          results << QString("%1:%2").arg(file, lineNum);
        }
      }
    }
    return results;
  }
};
```

---

## 📚 源代码快速定位

| 功能 | 源文件 | 函数/类 | 行数 |
|------|--------|--------|------|
| 写文件 | FileSystemTool.cpp | opWriteFile | ~190 |
| 读文件 | FileService.cpp | readFile | ~60 |
| 创建目录 | FileService.cpp | createDirectory | ~50 |
| 删除文件 | FileSystemTool.cpp | opDeleteFile | ~240 |
| 移动文件 | FileSystemTool.cpp | opMoveFile | ~250 |
| 列目录 | FileSystemTool.cpp | opListDir | ~210 |
| 搜索 | SearchTool.cpp | opGrepSearch | ~32 |
| 监视 | FileWatcher.cpp | onFileChanged | ~160 |
| 权限 | FileService.cpp | - | 嵌入 |
| 编码 | FileService.cpp | detectEncoding | ~75 |

---

## ✅ 验收标准

每个功能实现完成后检查:

- [ ] 路径遍历防护 ✓
- [ ] 错误处理完整 ✓
- [ ] 权限验证 ✓
- [ ] 日志记录 ✓
- [ ] 单元测试 ✓
- [ ] 集成测试 ✓
- [ ] 文档完整 ✓

---

## 🔗 跨引用

- **完整分析**: CLAUDE-CODE-FILE-OPERATIONS-ANALYSIS.md
- **C++ 参考**: neurx-code/src/services/FileService.h
- **工具参考**: neurx-code/src/tools/FileSystemTool.h

---

**最后更新**: 2026-06-08 | **版本**: 1.0
