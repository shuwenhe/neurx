# VS Code 核心功能在 neurx-code 中的直接实现清单

这份表只收录“当前架构下可以直接做”的功能，也就是已经有底层模块、主要工作是接线和补 UI 的能力。

| VS Code 功能 | neurx-code 现状 | 现有模块 | 直接实现方式 | 优先级 |
|---|---|---|---|---|
| 命令面板 | 已有命令系统和面板雏形 | `src/commands/CommandManager.*`, `src/services/KeyBindingManager.*`, `content/CommandPalette.qml` | 把命令列表、搜索、执行、快捷键绑定统一到命令面板 | P0 |
| 全局查找/替换 | 已有搜索引擎 | `src/editor/FindAndReplace.*`, `src/search/GlobalSearchEngine.*` | 接入编辑器状态、结果跳转、替换预览、范围限定 | P0 |
| 括号匹配跳转 | 已有括号匹配器 | `src/editor/BracketMatcher.*` | 在编辑器里绑定跳到匹配括号、显示配对高亮 | P0 |
| 单词级编辑 | 已有词操作逻辑 | `src/editor/WordOperations.*` | 接入删词、移词、词边界选择、词级移动快捷键 | P0 |
| 大小写转换 | 已有转换器 | `src/editor/CaseConverter.*` | 接入 upper/lower/title/camel/snake/kebab/pascal 变换 | P0 |
| 智能选区 | 已有选区扩展逻辑 | `src/editor/SmartSelection.*` | 接入 expand/contract selection 和多级选区动作 | P0 |
| 多光标编辑 | 已有多光标数据结构 | `src/editor/MultiCursor.*` | 接入多点插入、批量删除、批量变换、occurrence 选点 | P1 |
| 当前词高亮 | 已有高亮器 | `src/editor/WordHighlight.*` | 在光标移动时刷新高亮，展示 occurrences | P1 |
| 内联重命名 | 已有重命名逻辑 | `src/editor/InlineRename.*` | 接入 rename preview、批量替换、取消重命名 | P1 |
| 跳转定义 | 已有基础定位器 | `src/editor/GoToDefinition.*` | 接入 go to definition、back/forward navigation | P1 |
| 按括号选区 | 已有括号选区选择器 | `src/editor/SelectToBracket.*` | 接入 select to bracket、expand to bracket pair | P1 |
| 工作区打开 | 已有 open folder / workspace 流程 | `src/bridge/AgentController.cpp`, `content/App.qml` | 补 recent folders、.code-workspace、最近工作区恢复 | P1 |
| 文件创建与写入 | 已有文件写入链路 | `src/tools/FileSystemTool.cpp`, `src/tools/SmartFileCreator.cpp`, `src/tools/CodexFileSystemTool.*` | 统一到原子写入、补模板/结构化创建、接入工具面板 | P0 |
| 快捷键系统 | 已有快捷键管理器 | `src/services/KeyBindingManager.*` | 做 keymap 持久化、冲突检测、命令绑定 UI | P0 |
| 工具/命令桥接 | 已有桥接层 | `src/bridge/EditorCommandBridge.*`, `src/bridge/AgentController.cpp` | 把编辑动作统一暴露给 QML 和 agent | P0 |

## 最值得先做的 5 项

1. 命令面板
2. 全局查找/替换
3. 快捷键系统
4. 括号/单词/大小写编辑
5. 文件创建与写入

这 5 项的特点是：

- 不依赖 LSP、调试器或扩展宿主
- 可以直接利用现有 C++ 编辑器模块
- 对用户体感提升最明显
- 最容易做出“像 VS Code 一样能用”的效果

## 明确不算“直接实现”的部分

这些能力当然也能做，但已经超出“直接接线”的范围：

- 完整 LSP 客户端、补全、诊断、重命名语义
- Debug 面板和断点调试
- 扩展宿主与 Marketplace
- 远程工作区、容器工作区、SSH 工作区
- 完整的 VS Code workbench 布局复刻

## 结论

如果目标是尽快把 `neurx-code` 做成一个更像 VS Code 的日常编码环境，最优先的路径不是去复制整套 workbench，而是先把上面 P0 的编辑动作和命令系统打通。
