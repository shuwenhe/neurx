# Code Agent Reference Map

## Goal

这份文档定义 `NeurX` 在构建 code agent 时，应该优先参考哪些开源项目，以及每个项目分别对应 `NeurX` 的哪一层实现。

核心原则：

- 不参考“最火”的项目
- 只参考“对当前主线最有用”的项目
- 每个参考项目只抄最有价值的那一层

## Primary References

当前最值得参考的 3 个项目：

1. `Aider`
2. `OpenHands`
3. `SWE-agent`

补充参考：

4. `OpenCode`
5. `Continue`

## Recommendation Summary

如果只能给一个排序：

1. 先看 `Aider`
2. 架构层看 `OpenHands`
3. 验证循环看 `SWE-agent`

原因：

- `NeurX` 当前最缺的不是更多 agent 概念，而是真实可用的 coding loop
- `Aider` 最接近“本地仓库里真实改代码”
- `OpenHands` 最适合后续抽象成更完整的 agent runtime
- `SWE-agent` 最适合指导 build/test/retry/eval

## Mapping By NeurX Layer

### 1. `app/service` + `app/bridge`

最优先参考：`Aider`

原因：

- terminal / local repo 优先
- 面向真实代码修改，不是纯问答
- 关注最小闭环，而不是大而全平台

应该参考：

- 文件读写前先收集上下文
- 多文件编辑的最小交互协议
- 改动摘要与可追踪输出
- Git/worktree 友好的编辑模型
- 用户请求到具体修改之间的最短路径

在 `NeurX` 对应目录：

- `app/service/code_agent_runner.sh`
- `app/service/tools/`
- `app/bridge/neurx_bridge.cpp`

对 `NeurX` 的具体落点：

- runner 不再只给 plan，而是给最小 action
- bridge 不直接信任自然语言，优先吃结构化动作
- 每次编辑都能落到 staged/pending change 结构

不该抄：

- 过于依赖 Git patch 文本作为唯一协议
- 把 UX 设计绑死在纯终端交互

## 2. `neurx/agent` + `executor/` + `action/`

最优先参考：`OpenHands`

原因：

- 更像通用软件工程 agent runtime
- 动作、环境、会话、工具边界更清晰
- 比单纯的 terminal pair programmer 更适合作为内核参考

应该参考：

- agent runtime 分层
- action orchestration
- tool execution contracts
- environment abstraction
- 运行时状态与会话管理
- 结构化 observation 回灌

在 `NeurX` 对应目录：

- `executor/executor.s`
- `executor/model_tool_select.s`
- `action/action_schema.s`
- `agent/runtime.s`
- `tool/workspace_tools.s`
- `tool/tool_registry.s`

对 `NeurX` 的具体落点：

- `action/tool/args/result` 结构统一
- route 与 tool 解耦
- planner 只决定动作，不直接拼执行细节
- tool registry 存 capability，不直接耦合 UI 或 prompt

不该抄：

- 太早引入过重的平台复杂度
- 浏览器/桌面/远程执行等与你当前主线无关的子系统

## 3. `build/test/retry/eval`

最优先参考：`SWE-agent`

原因：

- 它最强的不是 UI，而是“修问题”的流程设计
- 适合指导 `NeurX` 从能执行动作，走到能完成任务

应该参考：

- issue/task 到 workspace 操作的链路
- build/test 失败后的重试策略
- 任务级验证
- 可比较的成功/失败判定
- repo task benchmark mindset

在 `NeurX` 对应目录：

- `executor/executor.s`
- `test/`
- `doc/LOCAL_CODE_AGENT_EXECUTION_PLAN.md`
- 后续新增的 agent smoke tests / task fixtures

对 `NeurX` 的具体落点：

- 明确定义成功条件
- build/test 输出结构化
- 失败摘要写回 memory / trace
- bounded retry loop

不该抄：

- 把整个系统过度绑定到 benchmark 格式
- 为了榜单表现而牺牲本地产品可用性

## Secondary References

### `OpenCode`

适合参考：

- terminal-first 交互
- session/上下文压缩
- provider-agnostic 配置
- CLI/TUI 结构

对 `NeurX` 的价值：

- 适合优化 `app/service` / `shell` / 未来 CLI 体验
- 不适合作为第一参考，因为你现在的主要问题不是 TUI，而是动作闭环

### `Continue`

适合参考：

- rules/checks
- source-controlled agent behavior
- CI / PR review integration

对 `NeurX` 的价值：

- 适合后期把 agent 能力外推到 PR 检查、规范审查
- 不适合作为当前 code agent 主线参考

## What NeurX Should Copy First

按优先级排序，应该先抄这些机制：

1. `Aider` 的最小代码修改闭环
2. `OpenHands` 的 action/runtime 分层
3. `SWE-agent` 的 build/test/retry 验收逻辑

## What NeurX Should Not Copy Yet

当前不该投入的方向：

1. 完整浏览器自动化
2. 通用桌面操作 agent
3. 大而全多代理编排平台
4. 复杂 IDE 插件矩阵
5. 重 benchmark 基础设施

原因：

- 这些都会让项目更大
- 但不会显著提高当前本地 coding agent 的完成率

## Implementation Checklist

### Phase A

参考 `Aider`

- 统一 `read/search/write/delete/build/test` 本地动作
- 所有编辑进入 staged/pending changes
- 让一次代码任务能稳定生成真实修改

### Phase B

参考 `OpenHands`

- 把 `runner`、`bridge`、`executor` 的协议统一到 action/result
- 把 `tool selection`、`tool execution`、`observation` 分层
- 把 `neurx/agent` 与 `app/service` 的动作命名彻底对齐

### Phase C

参考 `SWE-agent`

- 加 build/test/retry loop
- 加固定 smoke tasks
- 加任务成功率统计

## Current Decision

对当前 `NeurX` 而言，主参考决策是：

- `app/service` 和 `app/bridge` 先按 `Aider` 的实用主义路线推进
- `executor/agent/action/tool` 逐步按 `OpenHands` 的 runtime 方式收敛
- `test` 和 repair loop 按 `SWE-agent` 的任务闭环来设计

这比“整体模仿某一个项目”更适合当前仓库状态。
