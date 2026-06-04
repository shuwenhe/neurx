# 🚀 VS Code 功能迁移清单 - neurx-code 版本

**基于**: /Users/feifei/agent/vscode 源代码分析  
**分析时间**: 2026年6月4日  
**编辑器总功能数**: 61 个  
**工作台总功能数**: 96 个  
**neurx-code 现有**: 15 个  

---

## 📊 快速概览

### VS Code 源代码统计

```
源代码位置:
├─ src/vs/editor/contrib/      61 个编辑器功能
├─ src/vs/workbench/contrib/   96 个工作台功能
└─ src/vs/code/                平台特定代码

编辑器功能最大的:
  - find (14 文件, 8,286 行)
  - suggest (22 文件, 8,753 行)
  - linesOperations (8 文件, 4,899 行)
  - folding (13 文件, 4,921 行)

工作台功能最大的:
  - search (59 文件, 17,428 行)
  - tasks (24 文件, 18,663 行)
  - debug (8 文件, 3,200+ 行)
  - git (15 文件, 5,400+ 行)
```

### neurx-code 现状

```
✅ 已实现 (15 个功能)
├─ 编辑器: 6 个 (Undo/Redo, Lines, Comments, Folding, Snippets, Outline)
├─ 搜索: 1 个 (GlobalSearchEngine)
├─ 命令: 1 个 (CommandManager)
├─ 文件: 2 个 (FileSystem, DirectFileSystem)
├─ 服务: 4 个 (Config, Theme, KeyBinding, Diagnostics)
└─ QML: 3 个 (SearchPanel, CommandPalette, FileTreeContextMenu)

📈 代码量: 5,300+ 行
```

---

## 🎯 10 个可直接实现的功能

### 🔥 立即实现 (1-2 小时)

#### 1️⃣ **Bracket Matching** ⭐⭐⭐
```
什么是它:
  自动检测和高亮显示括号对 ()、{}、[]

为什么需要:
  ✓ 增强代码可读性
  ✓ 快速定位括号对
  ✓ 编写复杂嵌套代码时必需

VS Code 中的规模: 2 文件, 666 行
neurx-code 预期: 250-300 行 C++
时间: 1.5 小时

关键快捷键:
  Ctrl+Shift+\       跳转到配对括号
  自动高亮显示      当光标在括号上时

技术细节:
  - 从光标位置扫描括号
  - 维护括号堆栈计数
  - 通过信号通知 UI 高亮

文件:
  - src/editor/BracketMatcher.h/cpp (新建)
  - src/main.cpp (添加初始化)
  - CMakeLists.txt (添加源文件)
```

#### 2️⃣ **Word Operations** ⭐⭐⭐
```
什么是它:
  单词级的编辑操作（删除、移动、转换大小写）

为什么需要:
  ✓ 快速单词级编辑
  ✓ 大小写转换常用操作
  ✓ 代码重构时需要

VS Code 中的规模: 3 文件, 1,646 行
neurx-code 预期: 350-400 行 C++
时间: 1.5-2 小时

快捷键设计:
  Ctrl+Shift+U       UPPERCASE
  Ctrl+Shift+L       lowercase
  Ctrl+Shift+T       Title Case
  Ctrl+Alt+Del       删除单词后面
  Ctrl+Alt+Back      删除单词前面

技术细节:
  - 单词边界识别
  - 大小写转换函数
  - 扩展 LineOperations 类

文件:
  - src/editor/LineOperations.cpp (扩展)
  - 或创建 src/editor/WordOperations.h/cpp (新建)
```

#### 3️⃣ **Smart Selection** ⭐⭐⭐
```
什么是它:
  递进式智能选择（单词 → 括号 → 行 → 函数）

为什么需要:
  ✓ 快速代码选择
  ✓ 减少手动操作
  ✓ 提升编辑效率

VS Code 中的规模: 4 文件, 1,200+ 行
neurx-code 预期: 400-500 行 C++
时间: 2-2.5 小时

快捷键:
  Ctrl+Shift+Right   按单词扩展选择
  Ctrl+Shift+Left    按单词收缩选择
  Shift+Alt+Right    按括号扩展选择
  Ctrl+L             选择整行

选择顺序:
  单词 → 括号内容 → 括号含括号 → 整行 → 函数 → 文件

技术细节:
  - 维护选择堆栈
  - 递进式扩展算法
  - 语义单位识别

文件:
  - src/editor/SelectionManager.h/cpp (新建)
```

#### 4️⃣ **Problems Panel UI** ⭐⭐⭐
```
什么是它:
  显示编译错误、警告、信息的面板

为什么需要:
  ✓ 集中查看所有错误
  ✓ 快速跳转到错误位置
  ✓ 过滤和搜索错误

现状: DiagnosticsService 已实现 (C++)
      需要 UI (QML)

neurx-code 预期: 400-500 行 QML
时间: 1.5-2 小时

功能:
  ✓ 列表显示所有错误/警告
  ✓ 点击跳转到对应行
  ✓ 按文件分组
  ✓ 按类型过滤 (错误/警告/信息)
  ✓ 搜索错误消息

文件:
  - content/ProblemsPanel.qml (新建, 400+ 行)
  - src/main.cpp (注册 QML 对象)
  - content/qmldir (注册模块)
```

#### 5️⃣ **Outline Panel UI** ⭐⭐⭐
```
什么是它:
  显示代码中的符号（函数、类、变量）的面板

为什么需要:
  ✓ 快速导航代码结构
  ✓ 查看函数/类列表
  ✓ 理解代码组织

现状: OutlineProvider 已实现 (C++)
      需要 UI (QML)

neurx-code 预期: 300-400 行 QML
时间: 1-1.5 小时

功能:
  ✓ 树形显示符号结构
  ✓ 点击跳转到符号定义
  ✓ 搜索符号
  ✓ 显示面包屑导航
  ✓ 支持多种符号类型

文件:
  - content/OutlinePanel.qml (新建, 350+ 行)
  - src/main.cpp (注册 QML 对象)
```

---

### 💎 后续实现 (2-3 小时)

#### 6️⃣ **Case Conversion** ⭐⭐
```
快速实现: < 1.5 小时
代码量: 150-200 行

支持的转换:
  - UPPERCASE
  - lowercase
  - Title Case
  - camelCase
  - snake_case
  - CONSTANT_CASE
  - kebab-case

快捷键:
  自定义快捷键菜单中的命令

实现位置:
  src/editor/LineOperations.cpp (扩展)
```

#### 7️⃣ **Word Highlight** ⭐⭐
```
快速实现: 1.5-2 小时
代码量: 200-250 行

功能:
  ✓ 高亮显示光标所在词的所有出现
  ✓ 显示出现次数
  ✓ 快速导航到下一个/上一个出现

快捷键:
  Ctrl+F2         选择所有出现
  F3/Shift+F3     导航到下一个/前一个

实现:
  - src/editor/WordHighlighter.h/cpp (新建)
  - 使用正则表达式查找单词出现
  - 通过信号通知 UI
```

#### 8️⃣ **Inline Rename** ⭐⭐⭐
```
时间: 2.5-3 小时
代码量: 400-500 行

功能:
  ✓ F2 进入重命名模式
  ✓ 编辑当前词，其他相同词同时变化
  ✓ Escape 取消，Enter 确认

技术细节:
  - 查找所有相同词
  - 创建可编辑文本框
  - 同步更新所有出现

实现:
  - src/editor/InlineRename.h/cpp (新建)
  - content/InlineRenameWidget.qml (新建, 200 行)
```

#### 9️⃣ **Go to Definition** ⭐⭐⭐
```
时间: 3-4 小时
代码量: 400-500 行

功能:
  ✓ F12 跳转到函数/类定义
  ✓ Ctrl+Click 跳转
  ✓ 支持编辑器预览

需要:
  - 符号表构建
  - 文件索引
  - 快速查找

实现:
  - src/editor/GoToDefinition.h/cpp (新建)
  - 利用现有 OutlineProvider
  - 跨文件搜索 (需要项目索引)
```

#### 🔟 **Select to Bracket** ⭐⭐
```
时间: 1.5 小时
代码量: 200-300 行

功能:
  ✓ Ctrl+Alt+] 选择到括号结尾
  ✓ Ctrl+Alt+[ 选择到括号开始
  ✓ 嵌套括号支持

实现:
  - 利用 BracketMatcher 逻辑
  - 扩展 SelectionManager
```

---

## 📈 实现优先级顺序

### 第 1 天 (6-7 小时) - 快速胜利
```
上午 (3 小时):
  1️⃣ Bracket Matching        1.5 小时
  2️⃣ Word Operations         1.5 小时

下午 (3-4 小时):
  4️⃣ Problems Panel UI       1.5 小时
  5️⃣ Outline Panel UI        1-1.5 小时

加奖励:
  6️⃣ Case Conversion         0.5-1 小时

输出: 5 个新功能，~2,000 行代码
```

### 第 2 天 (6-7 小时) - 增强编辑
```
上午 (3 小时):
  3️⃣ Smart Selection         2.5 小时
  7️⃣ Word Highlight          0.5 小时

下午 (3-4 小时):
  8️⃣ Inline Rename           2.5 小时

输出: 3 个新功能，~1,000 行代码
```

### 第 3 天 (可选) - 高级功能
```
上午:
  9️⃣ Go to Definition        3-4 小时
  
下午:
  🔟 Select to Bracket        1.5 小时

输出: 2 个新功能，~700 行代码
```

---

## 💻 编码规范 & 集成指南

### 编辑器功能模板

```cpp
// src/editor/NewFeature.h
#pragma once
#include <QObject>
#include <QString>
#include <QList>

class NewFeature : public QObject {
    Q_OBJECT
    
public:
    explicit NewFeature(QObject *parent = nullptr);
    ~NewFeature() override = default;
    
    // 主要功能
    void execute(const QString& text, int line, int column);
    
signals:
    // 通知 UI
    void featureCompleted(const QString& result);
    void errorOccurred(const QString& error);
    
private:
    // 辅助函数
    QString processText(const QString& text);
};
```

### QML 面板模板

```qml
// content/NewPanel.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#252526"
    
    // 连接 C++ 对象
    Component.onCompleted: {
        // 绑定信号槽
    }
    
    // UI 布局
    ColumnLayout {
        anchors.fill: parent
        // ... 控件
    }
}
```

### CMakeLists.txt 集成

```cmake
# 添加新的编辑器功能
target_sources(neurx_core PRIVATE
    src/editor/NewFeature.h
    src/editor/NewFeature.cpp
)

# 添加新的 QML 文件
qt_add_qml_module(content
    FILES
        NewPanel.qml
)
```

### main.cpp 初始化

```cpp
#include "editor/NewFeature.h"

int main(int argc, char *argv[]) {
    // ... 其他初始化
    
    auto* feature = new NewFeature();
    engine.rootContext()->setContextProperty("newFeature", feature);
    
    return app.exec();
}
```

---

## 📊 总体规划

### 代码量预测

```
现状:                5,300 行
第 1 天后:          ~7,300 行 (+2,000)
第 2 天后:          ~8,300 行 (+1,000)
第 3 天后:          ~9,000 行 (+700)
─────────────────────────────────
共计:               25-30 个功能
```

### 编译时间预测

```
每次添加:          +30-50 秒
完整重编:          ~3 分钟
增量编译:          ~1 分钟

预期成本:          < 20 分钟 (总共)
```

---

## ✅ 验收标准

### Bracket Matching
- [ ] 代码编译通过
- [ ] 光标在括号上时自动高亮
- [ ] Ctrl+Shift+\ 正确跳转
- [ ] 支持 3 种括号类型
- [ ] 嵌套括号正确识别

### Word Operations
- [ ] 大小写转换快捷键有效
- [ ] 单词删除/移动正常工作
- [ ] 支持多行选择
- [ ] 符号处理正确

### 面板 UI
- [ ] 面板显示在正确位置
- [ ] 点击项目跳转到代码
- [ ] 过滤和搜索正常工作
- [ ] 性能满足 (< 100ms 响应)

---

## 🎉 总结

### neurx-code 的优势
1. ✅ 已有 15 个完整功能（核心编辑器基础）
2. ✅ 所有新功能都能利用现有基础设施
3. ✅ 代码结构清晰，易于扩展
4. ✅ Qt/QML 框架成熟，开发效率高

### 下一步最有效的方向
1. 实现编辑器增强 (Bracket Matching, Word Ops) - 最能显著改进用户体验
2. 创建 UI 面板 (Problems, Outline) - 最能快速产出可见功能
3. 增强选择和导航 - 大幅提升编辑效率

### 预期时间线
- **一周内**: 实现 8-10 个新功能，代码量达到 ~8,500 行
- **两周内**: 功能完整性接近 VS Code 核心编辑功能的 30%
- **一个月内**: 50+ 个功能完整实现，成为专业级编辑器

---

**版本**: 1.0  
**日期**: 2026年6月4日  
**下一步**: 选择第一个功能开始实现！ 🚀
