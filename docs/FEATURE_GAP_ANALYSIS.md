# neurx-code 功能差距分析与开发路线图

## 📊 neurx-code 已实现功能总结

根据全面分析，neurx-code 已经实现：

### ✅ 核心能力
- **40+ 工具**：文件操作、代码编辑、搜索、Shell 执行、集成等
- **4 个 LLM 提供商**：Anthropic Claude、OpenAI GPT、Google Gemini、Ollama（本地）
- **30+ 编辑器功能**：多光标、代码折叠、内联重命名、括号匹配等
- **完整的 Agent 系统**：规划、执行、验证、子 Agent 委托
- **Claude 风格技能系统**：三层渐进式披露
- **多层记忆系统**：语义、情景、工作记忆 + 跨会话检索（SQLite FTS5）
- **沙箱/权限系统**：细粒度权限控制、Docker 隔离
- **MCP 协议支持**：与外部服务集成
- **丰富的集成**：GitHub、GitLab、Jira
- **原生 Qt6 GUI**：跨平台桌面应用

---

## 🚨 关键缺失功能

### 🔴 高优先级（必须实现）

#### 1. CLI 终端界面
- **问题**：neurx-code 只有 GUI，没有命令行界面
- **影响**：
  - 无法在服务器/SSH 环境使用
  - 无法集成到 CI/CD 流水线
  - 开发者更喜欢 CLI 工作流
- **竞品对比**：
  - Claude Code ✅ 有 CLI
  - Codex ✅ 有 CLI
  - Gemini CLI ✅ CLI 优先
  - Hermes Agent ✅ 完整的 TUI
- **需要实现**：
  ```bash
  neurx                     # 启动交互式 REPL
  neurx chat "实现登录功能"  # 单次对话
  neurx --model claude      # 指定模型
  neurx --workspace ~/proj  # 指定工作目录
  ```
- **技术方案**：
  - Python CLI 框架：Click / Typer / Rich
  - 或 C++ CLI：CLI11 + libedit/readline
  - REPL 循环：prompt → agent → tool execution → response
  - 流式输出：逐字显示 LLM 响应
- **工作量**：2-4 周

#### 2. 图片理解（Vision）
- **问题**：无法处理图片输入
- **影响**：
  - 无法从 UI 截图生成代码
  - 无法理解架构图/流程图
  - 无法从手绘草图生成原型
- **竞品对比**：
  - Claude Code ✅ 支持 Claude Vision
  - Codex ✅ 支持 GPT-4V
  - Gemini CLI ✅ 支持 Gemini Pro Vision
  - Hermes Agent ✅ 支持图片
- **用例**：
  - 上传 Figma 设计稿 → 生成 QML 代码
  - 截图错误信息 → 分析调试
  - 手绘流程图 → 生成类图
- **技术方案**：
  - 集成 Claude 3.5 Sonnet（最佳视觉理解）
  - 集成 GPT-4 Turbo Vision
  - 集成 Gemini Pro Vision
  - 文件上传组件（GUI）
  - CLI 参数：`neurx chat --image screenshot.png "解释这个错误"`
- **工作量**：1-2 周

### 🟡 中优先级（重要但不紧急）

#### 3. 批处理模式
- **问题**：只支持交互式对话
- **影响**：无法用于自动化任务
- **实现**：
  ```bash
  neurx batch --tasks tasks.json --output results.json
  neurx batch --prompt "重构所有 API" --auto-approve
  ```
- **工作量**：1-2 周

#### 4. IDE 集成插件
- **问题**：必须切换到独立应用
- **影响**：打断开发流程
- **实现**：
  - VSCode Extension
  - JetBrains 插件
  - LSP Server
- **工作量**：4-6 周

#### 5. OAuth 登录
- **问题**：只支持 API Key
- **影响**：用户体验不友好
- **实现**：
  - Google OAuth（Gemini）
  - OpenAI OAuth（ChatGPT+）
- **工作量**：1-2 周

#### 6. CI/CD 集成
- **问题**：无 GitHub Action
- **实现**：
  - `neurx-code/run-agent@v1`
  - 自动化 PR 审查
  - 自动化测试生成
- **工作量**：2-3 周

#### 7. PDF 理解
- **问题**：无法处理文档
- **实现**：
  - PyMuPDF 解析
  - Vision API（PDF → 图片）
- **工作量**：1-2 周

#### 8. 插件系统
- **问题**：MCP 之外没有原生插件
- **实现**：
  - 插件市场
  - 热加载
- **工作量**：3-4 周

### 🟢 低优先级（Nice to have）

9. **移动端支持**：Telegram/Discord Bot（工作量：4-6 周）
10. **图片生成**：DALL-E / Imagen 集成（工作量：1-2 周）
11. **语音输入/输出**：STT/TTS（工作量：2-3 周）
12. **云端运行**：Serverless 部署（工作量：3-4 周）
13. **性能分析**：Profiling 工具（工作量：2-3 周）
14. **国际化**：多语言 UI（工作量：2-3 周）

---

## 💡 neurx-code 的独特优势

### ✅ 已有的竞争优势

1. **最完整的编辑器功能**
   - 30+ 编辑器功能（多光标、折叠、重命名等）
   - 竞品依赖 VSCode，neurx-code 是独立应用

2. **多 LLM 支持 + 本地模型**
   - 4 个提供商，灵活切换
   - Ollama 支持（离线使用）
   - 竞品大多只支持自家模型

3. **最强大的工具生态**
   - 40+ 工具，开箱即用
   - 竞品功能类似但数量较少

4. **子 Agent 委托**
   - DelegationTool：并行处理任务
   - 只有 Hermes Agent 有类似能力

5. **完整的沙箱/权限系统**
   - 细粒度权限控制
   - Docker 隔离
   - 企业级安全

6. **Claude 风格技能系统**
   - 三层渐进式披露
   - 降低 token 消耗

7. **多层记忆系统**
   - 语义、情景、工作记忆
   - 跨会话检索（SQLite FTS5）

8. **丰富的集成**
   - GitHub, GitLab, Jira
   - 大部分竞品只有 GitHub

9. **原生 Qt6 桌面应用**
   - 性能优于 Electron
   - 跨平台

10. **检查点系统**
    - Git shadow repo
    - 安全回滚

---

## 🗺️ 开发路线图

### Phase 1: 补齐核心缺失（3 个月）
**目标**：达到 Claude Code / Codex 的功能对等

| 周次 | 任务 | 输出 |
|-----|------|-----|
| 1-2 | CLI 终端界面 | 交互式 REPL、命令补全、历史记录 |
| 3-4 | Vision 支持 | Claude/GPT/Gemini Vision 集成 |
| 5-6 | 批处理模式 | 非交互式执行、JSON I/O |
| 7-8 | OAuth 登录 | Google/OpenAI OAuth |
| 9-10 | PDF 理解 | PDF 解析、文档理解 |
| 11-12 | CI/CD 集成 | GitHub Action、GitLab CI |

### Phase 2: 增强差异化优势（3 个月）
**目标**：超越竞品，打造独特卖点

| 周次 | 任务 | 输出 |
|-----|------|-----|
| 13-16 | IDE 插件 | VSCode Extension、LSP |
| 17-19 | 插件系统 | 插件市场、热加载 |
| 20-22 | 测试生成增强 | 专用测试 Agent、覆盖率分析 |
| 23-25 | 文档生成增强 | API 文档、架构文档 |

### Phase 3: 扩展场景（3 个月）
**目标**：支持更多使用场景

| 周次 | 任务 | 输出 |
|-----|------|-----|
| 26-29 | 移动端支持 | Telegram Bot、Discord Bot |
| 30-32 | 云端运行 | Serverless 部署、SSH 远程 |
| 33-34 | 图片生成 | DALL-E 集成 |
| 35-36 | 语音支持 | STT/TTS |

### Phase 4: 企业级功能（3 个月）
**目标**：满足企业客户需求

| 周次 | 任务 | 输出 |
|-----|------|-----|
| 37-39 | 企业 SSO | SAML、LDAP |
| 40-42 | 审计日志 | 操作记录、合规报告 |
| 43-45 | 团队协作 | 多用户、权限管理 |
| 46-48 | 国际化 | 多语言 UI、本地化文档 |

---

## 🎯 里程碑目标

| 时间点 | 目标 | 关键功能 | 市场地位 |
|--------|-----|---------|---------|
| **当前** | MVP | 40+ 工具、4 LLM、30+ 编辑器功能 | 第二梯队 |
| **3 个月后** | 功能对等 | CLI、Vision、批处理、CI/CD | 第一梯队 |
| **6 个月后** | 差异化 | IDE 插件、增强测试/文档 | 领先 |
| **9 个月后** | 多场景 | 移动端、云端 | 强领先 |
| **12 个月后** | 企业级 | SSO、审计、国际化 | 市场领导者 |

---

## 🚀 立即行动建议

### 本月立即开始

1. **CLI 终端界面**（最关键）
   - 开发者的首选工作方式
   - 解锁 CI/CD 场景
   - 技术债：2-4 周

2. **Vision 支持**（快速跟上趋势）
   - 多模态是未来趋势
   - 用例丰富（UI 生成、图表理解）
   - 技术债：1-2 周

### 3 个月计划

- 完成 Phase 1（6 项功能）
- 达到与 Claude Code / Codex 功能对等
- 准备 1.0 正式版发布

### 6 个月计划

- 完成 Phase 2（4 项功能）
- 建立差异化优势
- 吸引企业客户试用

### 12 个月计划

- 完成 Phase 4（企业功能）
- 商业化就绪
- 国际市场扩张

---

## 📈 竞争力预测

| 竞品 | 当前优势 | neurx-code 补齐后 | neurx-code 独特优势 |
|-----|---------|------------------|-------------------|
| **Claude Code** | CLI、Vision | ✅ 对等 | 多 LLM、完整编辑器、子 Agent |
| **Codex** | CLI、Vision、ChatGPT 账号 | ✅ 对等 | 多 LLM、完整编辑器、本地模型 |
| **Gemini CLI** | CLI、Vision、Google 生态 | ✅ 对等 | 多 LLM、完整编辑器、桌面 GUI |
| **Hermes Agent** | CLI、多 LLM、移动端 | ✅ 超越 | 完整编辑器、桌面 GUI、Qt 原生 |

---

## 📊 总结

### neurx-code 现状
- ✅ **已有功能**：极其完整（40+ 工具、4 LLM、30+ 编辑器功能）
- ❌ **关键缺失**：CLI 界面、Vision 支持
- 🎯 **定位**：强大的桌面应用，需补齐 CLI 和多模态

### 发展策略
1. **Phase 1（3 个月）**：补齐核心缺失 → 功能对等
2. **Phase 2（6 个月）**：增强差异化 → 超越竞品
3. **Phase 3（9 个月）**：扩展场景 → 多端支持
4. **Phase 4（12 个月）**：企业功能 → 商业化

### 竞争优势
- ✅ 最完整的编辑器功能
- ✅ 多 LLM 支持 + 本地模型
- ✅ 子 Agent 委托
- ✅ 原生桌面应用
- ✅ 企业级安全

### 行动建议
**立即启动**：CLI 界面 + Vision 支持（最高优先级）

---

**结论**：neurx-code 已经是一个功能极其完整的平台，但需要在 **CLI** 和 **Vision** 上快速补齐短板。建议优先完成 Phase 1（3 个月），然后根据用户反馈调整后续路线图。
