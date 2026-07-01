# VS Code 功能迁移到 NeurX Code 的路线图

这份路线图不是“把 VS Code 全抄过来”，而是按 `neurx-code` 当前架构，优先迁移最能提升编码效率、最适合 AI agent 工作流的能力。

## 1. 当前基础

NeurX Code 已经有这些底座：

- QML 桌面 UI
- `AgentController` 作为 UI 与后端桥接
- `Planner` / `Executor` / `Verifier` 的 agent 执行链
- 文件系统、沙箱、审批、补丁、搜索、技能、插件等模块
- 聊天面板、编辑器、设置、文件创建能力

所以迁移策略应该是：

1. 先补“高频编辑/导航”能力
2. 再补“工程化工作流”能力
3. 最后补“平台级扩展能力”

## 2. P0: 先做，收益最大

这些功能最接近 VS Code 的核心体验，也最适合 NeurX 的 agent 形态。

### 2.1 命令面板

目标：

- `Ctrl+Shift+P` 打开命令面板
- 支持命令搜索、分组、最近命令
- 和 `CommandManager` 打通

现有基础：

- `src/commands/CommandManager.cpp`
- `content/ChatPanel.qml`

建议落点：

- 做成独立 `CommandPalette.qml`
- 命令源直接来自 `CommandManager`

### 2.2 全局搜索与替换

目标：

- 文件内容搜索
- 正则搜索
- 替换单个 / 批量替换
- 显示匹配预览和文件分组

现有基础：

- `src/search/GlobalSearchEngine.cpp`

建议落点：

- `SearchPanel.qml`
- 搜索结果列表支持双击跳转

### 2.3 Git / Diff / 回滚

目标：

- 查看工作区改动
- 预览 diff
- 回滚单个文件或单次变更
- 展示分支与状态

现有基础：

- `src/context/WorkspaceContext.cpp`
- `src/plugins/GitWorkflow.h`
- `src/tools/PatchTool.cpp`
- `src/tools/CheckpointManager.*`

建议落点：

- `DiffPanel.qml`
- `GitStatusPanel.qml`

### 2.4 内嵌终端

目标：

- 执行构建、测试、格式化命令
- 终端输出流式展示
- 支持中断

现有基础：

- `src/sandbox/DefaultSandboxManager.cpp`
- `src/tools/ShellTool.cpp`

建议落点：

- `TerminalPanel.qml`
- 终端命令历史按 session 保存

## 3. P1: 中期补强

这些能力会明显提升“像 VS Code 一样”的感觉，但实现成本更高。

### 3.1 LSP / 代码导航

目标：

- 跳转定义
- 查找引用
- 悬浮文档
- 符号大纲
- 面包屑导航

建议落点：

- 增加独立 LSP client 层
- 复用现有编辑器和语言高亮

### 3.2 诊断与问题面板

目标：

- 编译错误、lint、语法错误统一展示
- 可点击跳转到文件位置

建议落点：

- `ProblemsPanel.qml`
- 复用搜索、编辑器、日志系统

### 3.3 任务系统

目标：

- 构建任务、测试任务、格式化任务
- 任务运行状态、输出、失败重试

现有基础：

- `src/planning/PlanStructure.*`
- `src/commands/CommandManager.*`

## 4. P2: 平台化能力

这些功能更像“把 NeurX 做成 IDE 平台”，不是短期必须项。

### 4.1 插件宿主

目标：

- 插件加载、卸载、激活事件
- 命令贡献、菜单贡献、视图贡献

现有基础：

- `src/plugins/PluginManager.*`
- `src/skills/DefaultSkillManager.*`

### 4.2 扩展市场

目标：

- 安装、更新、禁用插件
- 插件元数据和版本管理

### 4.3 调试器

目标：

- 断点
- 单步
- 变量
- 调用栈

这部分可以做，但建议放在后面，因为协议和 UI 都会比较重。

## 5. 推荐实施顺序

### 第 1 阶段

- 命令面板
- 全局搜索 / 替换
- Git 状态 / Diff

### 第 2 阶段

- 终端面板
- 任务系统
- 更强的滚动 / 导航交互

### 第 3 阶段

- LSP
- 诊断面板
- 符号导航

### 第 4 阶段

- 插件宿主
- 扩展市场
- 调试器

## 6. 不建议直接照搬的部分

这些功能不是不能做，而是直接照搬 VS Code 性价比不高：

- 完整扩展宿主沙箱
- 全量 Marketplace 生态
- 复杂 notebook 体系
- 与 VS Code 完全一致的工作台布局

NeurX Code 更适合走“agent-first IDE”路线，而不是“另一个 VS Code”。

## 7. 一句话结论

最值得先做的是：

1. 命令面板
2. 全局搜索 / 替换
3. Git / Diff / 回滚
4. 内嵌终端
5. LSP 导航与诊断

这五项最能快速把 NeurX Code 拉到“可日常使用”的水位。
