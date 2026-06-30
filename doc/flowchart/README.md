# neurx-code Flowchart Collection

本目录包含 neurx-code 项目的流程图和架构图。

## 📁 文件清单

### 1. **neurx-code-architecture.md**
- Markdown 格式的架构文档
- 包含嵌入式 Mermaid 流程图代码
- 可直接在 VS Code 或 GitHub 中预览
- **预览方法**: 按 `Cmd+Shift+V` (macOS) 在 VS Code 中预览

### 2. **neurx-code-architecture.mmd**
- 纯 Mermaid 图表源代码
- 可用于各种 Mermaid 工具和编辑器
- 文本格式，便于版本控制

### 3. **neurx-code-architecture.png** ✅
- 生成的 PNG 图像
- 分辨率: 高质量向量导出
- 大小: 192 KB
- 用途: 报告、演示、文档

## 🎨 架构组件

流程图展示了 neurx-code 的主要架构组件：

### Core Systems (核心系统)
- **Agent System** - AI 代理生命周期管理
- **Bridge Layer** - LLM 集成和工具通信
- **Editor Core** - 编辑器功能和代码分析
- **Execution Engine** - 代码执行和插件管理

### Tool Ecosystem (工具生态)
- **File Operations** - 文件操作工具集
- **Code Tools** - 代码分析和重构
- **Search Tools** - 搜索和文件管理
- **Shell Tools** - 命令执行

### Infrastructure (基础设施)
- **Plugin System** - 插件验证和加载
- **Persistence Layer** - 状态和配置管理
- **Security Layer** - 沙箱和权限管理
- **UI Layer** - QML 用户界面

## 🔄 生成或更新图像

### 方法 1: 使用 Mermaid Live Editor (在线，最简单)
1. 访问: https://mermaid.live
2. 复制 `neurx-code-architecture.mmd` 的内容
3. 粘贴到编辑器中
4. 点击 "Download" 下载为 PNG/SVG/PDF

### 方法 2: 使用自动转换脚本 (推荐)
```bash
bash convert_to_image.sh
```

这将自动尝试多种方法生成图像。

### 方法 3: 使用 mermaid-cli (最灵活)
```bash
# 全局安装
npm install -g @mermaid-js/mermaid-cli

# 生成 PNG
mmdc -i neurx-code-architecture.mmd -o neurx-code-architecture.png

# 生成 SVG
mmdc -i neurx-code-architecture.mmd -o neurx-code-architecture.svg

# 生成 PDF
mmdc -i neurx-code-architecture.mmd -o neurx-code-architecture.pdf
```

### 方法 4: VS Code Markdown 预览
1. 打开 `neurx-code-architecture.md` 文件
2. 按 `Cmd+Shift+V` (macOS) 或 `Ctrl+Shift+V` (Linux/Windows)
3. Markdown 预览会渲染 Mermaid 图表
4. 右键点击图表选择 "Save as image"

## 📋 流程图说明

### 数据流
```
User Input → UI Layer → Agent System 
→ LLM via Bridge Layer → Tool Registry 
→ Execution Engine → Results → UI Update
```

### 关键特性
- ✅ 模块化架构，关注点分离清晰
- ✅ 基于插件的可扩展性系统
- ✅ 完整的安全沙箱
- ✅ 多层持久化系统
- ✅ 集成的 LLM 桥接
- ✅ 丰富的 QML 用户界面

## 🛠️ 依赖和工具

| 工具 | 用途 | 安装方法 |
|------|------|---------|
| Mermaid CLI | 本地生成图像 | `npm install -g @mermaid-js/mermaid-cli` |
| kroki.io | 在线渲染 API | 无需安装，脚本自动使用 |
| jq | JSON 处理 | `brew install jq` |
| python3 | JSON 编码 | 内置或 `brew install python3` |

## 📝 编辑流程图

要编辑流程图：

1. 打开 `neurx-code-architecture.mmd` 文件
2. 修改 Mermaid 代码
3. 运行转换脚本重新生成图像:
   ```bash
   bash convert_to_image.sh
   ```
4. 或在 Mermaid Live Editor 中预览实时更新

## 🔗 相关资源

- [Mermaid 官方文档](https://mermaid.js.org)
- [Mermaid Live Editor](https://mermaid.live)
- [kroki.io 在线渲染](https://kroki.io)
- [neurx-code 项目文档](../README.md)

## 📊 文件大小和格式

| 文件 | 格式 | 大小 | 用途 |
|------|------|------|------|
| .md | Markdown | ~2 KB | 文档和演示 |
| .mmd | Mermaid Source | ~1.5 KB | 编辑和版本控制 |
| .png | 光栅图像 | 192 KB | 报告和演示 |
| .svg | 向量图像 | ~50 KB | Web 和高分辨率 |

## ⚙️ 转换脚本说明

### convert_to_image.sh
- 自动尝试多种转换方法
- 优先使用 kroki.io API (无需本地依赖)
- macOS 兼容
- 支持 PNG 和 SVG 输出

### convert_to_image.py
- Python 版本的转换工具
- 更灵活的配置选项
- 需要 requests 库

## 💡 最佳实践

1. **版本控制**: 保留 `.mmd` 源文件在 Git 中
2. **图像生成**: PNG/SVG 图像可不追踪（`git ignore`），按需生成
3. **文档更新**: 修改后始终运行转换脚本更新图像
4. **在线协作**: 使用 Mermaid Live Editor 进行团队协作

## 🐛 故障排除

### 问题: 脚本运行失败
**解决方案**: 检查 `curl` 和 `jq` 是否安装
```bash
which curl
which jq
```

### 问题: PNG 生成为空文件
**解决方案**: 检查网络连接，尝试使用 Mermaid Live Editor

### 问题: 无法在 VS Code 中预览 Mermaid
**解决方案**: 安装 "Markdown Preview Mermaid Support" 扩展

## 📞 更新日志

- **2026-06-09**: 初始创建，PNG 图像生成成功
- **2026-06-09**: 添加转换脚本和文档

---

**最后更新**: 2026-06-09
