# Codex / Claude Code Parity Plan

## Goal

这份文档定义 `NeurX` 如果要实现接近 `Codex` 和 `Claude Code` 的 code agent 能力，必须具备哪些核心能力，以及这些能力在当前仓库内应该如何落地。

这里的目标不是“模仿 UI”，而是补齐一条真正可用的 coding agent 主链：

`任务理解 -> 上下文收集 -> 结构化动作 -> 安全执行 -> build/test -> 失败修复 -> 结果汇总`

## Scope Definition

本阶段把 “实现 Codex / Claude Code 功能” 限定为以下 8 类能力：

1. 仓库内真实读写代码
2. 结构化工具调用
3. 受控变更与审批
4. build/test 执行与失败摘要
5. bounded repair loop
6. 会话、trace、memory 持续化
7. 任务结果综合与 final answer
8. 基础评测与 smoke task

不包含：

- 云端多租户平台
- 浏览器自动化主线
- 完整 IDE 插件矩阵
- 通用桌面 agent
- 远程容器编排平台

## What Codex / Claude Code Actually Provide

抽象掉产品外观后，这两类系统的共性是：

1. 能把自然语言目标稳定翻译成一小组可执行动作。
2. 能在真实仓库里读取、搜索、编辑、删除、运行命令。
3. 能限制危险动作范围，并在需要时请求确认。
4. 能在失败后读取错误、调整计划、重试。
5. 能给出清楚的修改摘要、验证结果和后续风险。

所以 `NeurX` 不应该把目标理解成“做一个聊天框”，而应该理解成“做一个 repo-scoped software execution agent”。

## Capability Matrix

| Capability | Codex / Claude Code class | NeurX now | Gap |
| --- | --- | --- | --- |
| Structured actions | required | partially done | needs full producer/consumer unification |
| Real file IO | required | mostly done | needs stronger approval flow |
| Search over repo | required | mostly done | needs better result normalization |
| Build/test loop | required | basic | needs retry policy and task fixtures |
| Repair loop | required | partial | needs bounded automatic retry |
| Pending changes / approvals | required | partial | needs unified write/delete/apply gate |
| Session memory | required | basic | needs stronger final-answer persistence and replay |
| Trace / replay | required | partial | needs skill/runtime alignment |
| Task eval | required | weak | needs smoke tasks and success metrics |
| Multi-turn code task UX | required | partial | needs coherent app/native parity |

## NeurX Mapping

### 1. Intent and tool selection

对应目录：

- `executor/model_tool_select.s`
- `executor/executor.s`
- `action/action_schema.s`

目标：

- 所有 route/tool/action 名称统一
- 所有执行请求都转成结构化动作
- 减少自然语言分支判断

验收：

- 用户请求进入 runtime 后，不再依赖脆弱文本猜测来执行主动作

### 2. Workspace actions

对应目录：

- `tool/workspace_tools.s`
- `agent/workspace_search.s`
- `runtime/io/io.s`

目标：

- `read_file`
- `search_files`
- `write_file`
- `delete_path`
- `apply_patch`
- `run_build`
- `run_test`

这些动作都必须：

- 真实执行
- repo-scoped
- 返回结构化 observation

验收：

- 每个动作都返回 `kind:status=...`
- 非法路径、缺参数、空结果都有稳定状态语义

### 3. Runtime orchestration

对应目录：

- `agent/runtime.s`
- `task/planner.s`
- `reasoning/reasoning.s`
- `reflection/reflection.s`

目标：

- runtime 不再消费自由文本状态
- planner / reasoning / reflection / runtime 都依赖 observation parser
- 结束条件、replan 条件、tool disable 条件统一

验收：

- blocked / failed / no_progress / ok / done 在整条执行链里语义一致

### 4. Answer synthesis and trace

对应目录：

- `agent/trace.s`
- `agent/answer_synthesizer.s`
- `agent/runtime.s`

目标：

- trace 标记真实进展，而不是只保留布尔 `ok_flags`
- final answer 优先来自 memory，其次来自最近一次成功 observation
- 失败 observation 不得污染最终答复

验收：

- 没有成功 observation 时不能产出虚假 final answer
- 有成功 observation 时可稳定回退总结

### 5. App-side code agent parity

对应目录：

- `app/service/code_agent_runner.sh`
- `app/bridge/neurx_bridge.cpp`
- `app/service/tools/*.sh`

目标：

- app bridge 和 native S agent 使用同名动作
- 同一套 `action` / `action_result` envelope
- 同一套审批边界和 pending changes 行为

验收：

- app 侧和 native 侧对同一任务，至少在动作名和结果语义上保持一致

## Required Feature Set For Parity

如果要说 `NeurX` 具备了 “Codex / Claude Code 功能”，最低要完成下面这组功能，而不是其中一部分：

### A. Code editing loop

- 读取一个或多个文件
- 搜索仓库
- 修改或创建文件
- 应用 patch
- 展示变更摘要

### B. Safe execution loop

- 删除需要确认
- 写入需要进入统一 gate
- 仓库外路径默认拒绝
- 命令输出做裁剪和记录

### C. Verification loop

- 跑 build
- 跑 test
- 读取失败输出
- 再次修改并重试
- 达到上限后停止

### D. Result loop

- 输出修改文件列表
- 输出验证结果
- 输出失败原因或剩余风险
- 输出可重放 trace

## Phased Implementation

### Phase 1: action and observation unification

当前状态：

- 这条线已经大部分启动

剩余工作：

- executor producer 全量统一
- skill/runtime replay 对齐 observation parser
- app/native 两侧结果字段完全对齐

### Phase 2: approval and pending changes unification

必须完成：

- `write_file`
- `apply_patch`
- `replace_range`
- `delete_path`

都走统一审批 / 暂存通道

这是 `NeurX` 距离 `Codex / Claude Code` 的最大剩余差距之一。

### Phase 3: bounded repair loop

必须完成：

- `run_build`
- `run_test`
- 失败 observation 写回 memory
- 最多 `N` 轮自动修复
- 到达上限后输出 clear failure summary

### Phase 4: task fixtures and smoke evaluation

至少增加：

1. 单文件修复任务
2. 多文件小改动任务
3. build 失败修复任务
4. test 失败修复任务
5. 非法路径拦截任务

没有这些任务，就无法判断 `NeurX` 是否真的接近 `Codex / Claude Code`。

## Concrete Repo Priorities

当前仓库内最该做的顺序不是随机扩展，而是：

1. 收口 `agent/runtime.s`、`skill_feedback`、`trace replay` 的 observation 语义
2. 统一 app bridge 和 native agent 的写入 / 删除审批边界
3. 加 bounded build/test repair loop
4. 加 smoke tasks 和成功率统计
5. 再考虑更强的模型路由和更复杂的 UX

## Completion Standard

只有当下面这些条件同时成立时，才应该说 `NeurX` “实现了 Codex / Claude Code 的 code agent 功能”：

1. 能对仓库任务执行真实读改查删和 build/test。
2. 能在失败后自动进行有限次修复。
3. 所有高风险动作都有一致的审批或 gate。
4. app 侧和 native S 侧动作协议一致。
5. 有 smoke tasks 可以验证成功率，而不是只看演示。
6. final answer、trace、memory 都基于结构化 observation 收敛。

## Current Decision

对 `NeurX` 来说，正确目标不是“复制 Codex 或 Claude Code 的外观”，而是：

- 在本地仓库内做出同类能力边界
- 先完成 execution correctness
- 再优化交互体验

所以后续主线应继续围绕：

- `executor/`
- `agent/`
- `tool/`
- `app/bridge`
- `app/service`

推进，而不是回到更宽的 AI OS 扩张路线。
