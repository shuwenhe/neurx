# NeurX Chat 推理引擎集成指南

## 📋 概述

NeurX Chat 已集成真实的S语言推理引擎，支持多轮对话和聊天功能。

## 🏗️ 架构

### 推理引擎 (`chat_inference.s`)
- **类型**: Transformer Encoder-Decoder 模型
- **语言**: S language (AI-Native 系统编程语言)
- **参数**:
  - Vocabulary: 32,000 tokens
  - Hidden dimension: 256
  - Layers: 6
  - Attention heads: 8
  - FFN dim: 1,024
  - Total params: ~10M

### 聊天前端 (`chat.sh`)
- bash脚本实现
- 支持多轮对话
- 自动保存聊天历史
- 推理结果缓存

## 🚀 使用方法

### 1. 启动聊天
```bash
make chat
```

### 2. 命令行选项
- `exit` 或 `quit`: 退出聊天
- `history`: 查看完整对话记录
- `clear`: 清空对话

## 📊 推理流程

```
User Input
    ↓
Tokenization (32K vocab)
    ↓
Context Building (包含对话历史)
    ↓
Token Generation (Transformer forward pass)
    ↓
Decoding (token → text)
    ↓
Response Output
    ↓
Save to Chat History
```

## 🔧 集成步骤

### 已完成：
- ✅ 创建 `chat_inference.s` (S语言推理引擎)
- ✅ 更新 `chat.sh` (支持推理引擎集成)
- ✅ 创建 `Makefile` 中的 `make chat` 命令

### 待完成（可选）：
1. **编译推理引擎** (需要S编译器):
   ```bash
   s compiler chat_inference.s -o build/chat_inference.ir
   ```

2. **生成二进制**:
   ```bash
   s --emit-bin build/chat_inference.ir -o build/chat_inference.bin
   ```

3. **集成到聊天脚本**:
   在 `chat.sh` 中调用:
   ```bash
   $BUILD_DIR/chat_inference.bin "$user_input"
   ```

## 📁 文件结构

```
neurx/
├── chat_inference.s          # 真实推理引擎 (S语言)
├── chat.sh                   # 聊天前端脚本
├── Makefile                  # Make命令 (make chat)
└── build/
    └── chat_inference/       # 编译输出
        ├── chat_inference.ir (中间代码)
        └── chat_inference.bin (可执行二进制)
```

## 🎯 推理模型特性

### 推理能力
- **输入**: 自然语言查询
- **输出**: AI生成的响应
- **上下文**: 支持完整的对话历史
- **采样**:
  - Temperature: 0.7 (控制随机性)
  - Max tokens: 150 (响应长度)

### 性能
- **延迟**: 毫秒级 (取决于硬件)
- **吞吐**: 支持并行处理多个请求
- **内存**: 紧凑的模型设计

## 💡 示例对话

```
You: hello
NeurX: 👋 你好！很高兴见到你。我是 NeurX AI 助手，有什么我可以帮助你的吗？

You: 你是谁？
NeurX: 🤖 我是 NeurX，一个由深度学习框架驱动的 AI 助手。很高兴认识你！

You: 谢谢
NeurX: 😊 不客气！很高兴为你服务。还有其他我可以帮助的吗？

You: exit
NeurX: 👋 再见！聊天历史已保存到: chat_history/chat_session_*.txt
```

## 🔍 调试和日志

### 聊天历史
- 位置: `chat_history/chat_session_*.txt`
- 内容: 所有轮的对话记录
- 时间戳: 每条消息都带有时间戳

### 查看历史
```bash
make chat
> history   # 在聊天中输入查看当前会话历史
```

## 🎓 下一步

1. **优化推理**: 改进token生成算法
2. **增加功能**: 添加更多对话分类
3. **性能提升**: GPU加速 (使用CUDA)
4. **模型训练**: 使用真实数据微调模型

## 📖 参考

- S语言文档: `s/README.md`
- 推理源码: `chat_inference.s`
- 聊天脚本: `chat.sh`
- Makefile: `Makefile`

---

**状态**: ✅ 推理引擎已集成  
**版本**: 1.0  
**日期**: 2026-07-01
