# Local Code Agent Execution Plan

## Goal

在接下来的 4 周内，把 `neurx` 的主线收敛为一个可本地运行、可真实改代码、可执行自检的 coding agent。

这里的目标不是继续扩展 `AI OS` 概念层，也不是继续横向增加训练、推理、端侧和安装目标，而是先完成一条可验证闭环：

`用户请求 -> 读取上下文 -> 产出结构化动作 -> 应用修改 -> build/test -> 返回结果`

## Non-Goals

以下事项在本阶段降级，不作为主线交付：

- 新模型家族接入
- 新平台安装目标
- 新 UI 形态扩展
- 新分布式训练能力
- 新编译/算子大模块
- 继续扩张 AI OS 子系统命名和目录重组

## Success Criteria

4 周结束时，至少满足以下验收条件：

1. `app/service/code_agent_runner.sh` 能输出结构化 action，而不只是模板或 planner stub。
2. `app/bridge/neurx_bridge.cpp` 能执行 `read/search/write/delete/build/test` 的统一动作协议。
3. 代码助手可以在仓库内完成一个最小修复任务，并返回：
   - 修改了哪些文件
   - build/test 是否通过
   - 失败时的错误摘要
4. destructive action 有明确审批或确认门槛。
5. 所有 agent side effect 都有 trace 或日志记录。

## Product Boundary

本阶段把 NeurX 定义为：

- 一个 Qt app 壳
- 一个本地/远端模型入口
- 一个 repo-scoped coding agent runtime
- 一组受控工具动作

不是：

- 通用 AI 操作系统
- 完整训练框架产品
- 完整推理平台产品

## Primary Workstream

唯一主线：

`app/bridge` + `app/service` + `neurx/agent`

收敛目标：

- `app/service/tools/*.sh` 作为底层工具语义
- `app/bridge` 作为执行和审批边界
- `neurx/agent` 复用同一套 action 名称和结果格式

## Execution Principles

### 1. Prefer one real loop over many partial modules

优先完成一条真实可执行链路，不再并行铺多个半成品模块。

### 2. Actions before intelligence

先把动作做实，再增强模型决策。没有真实 `write/build/test`，再强的 prompt 也只是描述。

### 3. Repo-scoped safety first

所有写入、删除、构建、测试都必须限定在仓库根目录或批准目录内。

### 4. Observable by default

每次动作都要留下参数、结果、耗时和失败原因，便于重放和修复。

## Week 1

主题：统一动作协议，停止双轨分裂。

交付：

- 定义统一 action schema，至少包含：
  - `tool`
  - `args`
  - `approval`
  - `summary`
- 首批标准动作：
  - `read_file`
  - `search_files`
  - `write_file`
  - `delete_path`
  - `run_build`
  - `run_test`
- 明确 action result schema，至少包含：
  - `ok`
  - `tool`
  - `summary`
  - `output`
  - `changed_paths`
  - `requires_approval`
- runner 输出从自由文本切到 JSON action/result envelope。

涉及目录：

- `app/service/code_agent_runner.sh`
- `app/service/tools/`
- `app/bridge/neurx_bridge.cpp`
- `neurx/agent/`

验收：

- runner 可以稳定返回合法 JSON。
- bridge 能解析并区分 completed / requires_approval / failed / delegated。

## Week 2

主题：把动作做实，打通最小读改链路。

交付：

- `read/search/write/delete` 全部接入真实执行。
- 写入统一走 pending changes 或显式 apply 通道，不再混用自由文本建议。
- delete 默认需要确认。
- 所有路径必须通过 workspace root 校验。
- tool output 统一裁剪和标准化，避免 UI/trace 爆炸。

重点：

- 不增加新工具种类。
- 先把已有工具做稳定，再谈扩展。

验收：

- 能对指定文件完成一次读取、修改、应用。
- 能准确返回修改文件列表。
- 非法路径、越界路径、空参数都有明确错误。

## Week 3

主题：加入 build/tests/repair loop，让 agent 开始“闭环”。

交付：

- `run_build` 与 `run_test` 接入统一动作协议。
- runner 支持最多 `N` 轮 bounded repair loop。
- 失败结果可回灌到下一轮动作生成。
- UI/bridge 能展示：
  - 当前步骤
  - 最近动作
  - build/test 摘要

重点：

- 只支持仓库里 1 到 2 条标准 build/test 路径。
- 不在这周追求通用项目检测。

验收：

- 对一个故意制造的最小编译/测试失败样例，agent 能完成：
  - 读取
  - 修改
  - build/test
  - 失败摘要
  - 重试

## Week 4

主题：安全、trace、与 `neurx/agent` 对齐。

交付：

- destructive action 审批机制固化。
- action trace 落盘，支持后续 replay。
- `neurx/agent` 侧对齐同名动作与相同结果格式。
- 清理硬编码敏感配置，改成环境变量或本地开发配置注入。
- 补 3 到 5 个端到端 smoke tests。

验收：

- 一次完整代码任务可重放主要步骤。
- 没有审批时不能直接执行 delete 或高风险写入。
- 本地 app agent 和 native S agent 的动作命名不再分叉。

## Required Refactors

这些改动优先级高于增加新能力：

1. 清理 bridge 中与 code agent 无关但耦合较深的默认配置。
2. 抽离 action parsing / validation / execution，避免继续堆到 `neurx_bridge.cpp`。
3. 给 shell tools 增加统一出参格式，不要每个脚本自由发挥。
4. 把 pending change 结构正式文档化，而不是只存在实现里。

## Metrics

每周只看少量核心指标：

- action JSON 解析成功率
- 有效工具执行成功率
- 单任务平均修改文件数
- build/test 成功率
- 需要人工介入的失败占比
- 越权/非法路径拦截次数

## Risks

### Risk 1: scope relapse

团队可能再次回到“顺手再补一个大模块”的模式。

控制办法：

- 新功能必须回答：是否直接提升本地 coding agent 闭环成功率。

### Risk 2: bridge becomes a god object

`neurx_bridge.cpp` 已经很厚，继续堆逻辑会快速失控。

控制办法：

- 新增 action executor 和 action validator 子模块。

### Risk 3: shell tools are too loose

当前工具脚本具备能力，但协议和安全边界偏弱。

控制办法：

- 统一 JSON envelope
- 统一路径校验
- 统一 stdout/stderr 截断策略

### Risk 4: false sense of progress from model output

模型回答质量提高，不等于 agent 真的可用。

控制办法：

- 所有里程碑必须以真实 side effect 和 build/test 结果验收。

## Stop Doing

从现在开始，以下模式应停止作为主线：

- 继续扩展 AI OS 概念目录但没有执行闭环
- 同时维护两套不兼容的 agent action 语义
- 用自然语言“建议修改”代替结构化 patch/action
- 在没有验收脚本前继续增加平台接入面

## Immediate Next Tasks

如果下一步直接开工，顺序应是：

1. 为 code agent 定义 `action` 和 `action_result` JSON schema。
2. 让 `code_agent_runner.sh` 输出该 schema。
3. 让 `neurx_bridge.cpp` 解析并执行 `read/search/write/delete`。
4. 把 `build/test` 纳入同一执行框架。
5. 增加最小端到端 smoke test。

## Expected Outcome

完成这 4 周计划后，`neurx` 会从“有大量方向和模块的仓库”变成“有一个明确主线并能实际完成代码任务的本地 agent 产品雏形”。
