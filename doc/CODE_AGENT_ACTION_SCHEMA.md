# Code Agent Action Schema

## Goal

定义 `app/service/code_agent_runner.sh`、`app/bridge/` 与 `neurx/agent/` 共享的最小动作协议。

当前阶段只覆盖：

- 动作提议
- 动作执行结果
- 审批标记
- 基础上下文摘要

## Runner Envelope

runner 必须返回一个 JSON object。

顶层字段：

- `protocol_version`: 当前固定为 `neurx.code_agent.v1`
- `status`: `completed`、`unhandled`、`requires_approval`、`failed`
- `mode`: 例如 `template`、`planner`、`model-loop-cpp`
- `summary`: 面向 bridge/UI 的简短摘要
- `response`: 直接返回给用户的文本结果；若没有则为空字符串
- `plan`: 兼容旧逻辑的文本计划；后续可逐步弱化
- `file_context`: 初始文件上下文摘要
- `actions`: action 数组
- `action_results`: action result 数组
- `prompt`
- `file_path`
- `repo_root`

## Action Object

每个 action 至少包含：

- `tool`: 动作名
- `args`: JSON object
- `summary`: 动作摘要
- `requires_approval`: 是否需要审批

首批标准动作名：

- `read_file`
- `search_files`
- `write_file`
- `delete_path`
- `run_build`
- `run_test`

示例：

```json
{
  "tool": "read_file",
  "args": {
    "path": "app/bridge/neurx_bridge.cpp",
    "start_line": 1,
    "line_count": 120
  },
  "summary": "Read the target file before planning edits.",
  "requires_approval": false
}
```

## Action Result Object

每个 action result 至少包含：

- `ok`: 布尔值
- `tool`: 动作名
- `summary`: 执行结果摘要
- `output`: 规范化后的输出文本
- `changed_paths`: 路径数组
- `requires_approval`: 是否因审批而未执行

示例：

```json
{
  "ok": true,
  "tool": "generate_completion",
  "summary": "Returned a validated standalone Python program.",
  "output": "print(\"hello\")",
  "changed_paths": [],
  "requires_approval": false
}
```

## Current Use

### `completed`

- `response` 可直接展示
- `action_results` 记录 runner 已完成的动作摘要

### `unhandled`

- `response` 为空
- `actions` 给出下一步建议动作
- `plan` 和 `file_context` 继续保留给旧逻辑与调试使用

### `requires_approval`

- `actions` 中至少一个动作 `requires_approval=true`
- bridge/UI 应展示审批提示，而不是直接执行

## Compatibility

为了避免一次性打断现有逻辑：

- `plan` 和 `file_context` 继续保留
- `response` 继续作为 completed 的直接返回体
- 新消费者优先读 `actions` 与 `action_results`

## Constraints

- 所有路径默认必须是 repo-scoped
- destructive action 必须显式标记 `requires_approval=true`
- `output` 与 `file_context` 应经过长度裁剪
