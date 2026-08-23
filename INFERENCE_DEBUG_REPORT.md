# NeurX 推理引擎问题报告

## 📋 诊断摘要

**状态**: ❌ 推理失败  
**严重性**: 高 - 所有推理请求都失败  
**诊断时间**: 2026-08-23  

---

## ✅ 已验证的工作部分

| 组件 | 状态 | 详情 |
|-----|------|------|
| **前端界面** | ✅ | HTML 页面正常加载，UI 响应正常 |
| **Nginx 反向代理** | ✅ | 正确转发请求到后端 |
| **后端 HTTP API** | ✅ | 监听在 127.0.0.1:8000，健康检查通过 |
| **模型文件** | ✅ | Qwen2.5-0.5B-Instruct 完整（2.4GB）|
| **模型挂载** | ✅ | 正确挂载到容器 /models/default/ |
| **S 运行时** | ✅ | 进程运行中，能启动并等待请求 |

---

## ❌ 失败的组件

### 推理引擎（S 语言）

**症状**: 所有推理请求都返回固定的错误消息
```
"当前模型输出为空或解码失败，请检查模型权重、上下文模板和推理参数后重试。"
```

**根本原因**: Prefill 阶段失败

**日志证据**:
```
[Inference] Using single model file: /models/default/model.safetensors
[Inference] Greeting detected; using fallback responder
[Inference] Response JSON: {"output":"当前模型输出为空或解码失败..."}
[Prefill] Embedding failed
[Inference-Optimized] Prefill phase failed
```

---

## 🔍 详细诊断

### 问题分析

1. **Prefill 阶段**是推理管道的第一步
2. 它需要：
   - 加载模型权重 ✅（文件完整）
   - 初始化嵌入层 ❌（失败）
   - 处理输入令牌 ❌（失败）

3. **可能原因**：
   - S 语言运行时中的权重加载 bug
   - Embedding 层初始化错误
   - 数据类型不匹配（float32/float16）
   - 内存分配失败

### 后端配置

```
文件: /app/neurx/artifacts/build/production_s_inference/cpu_backend.ir
大小: 167 KB
模型: Language Model 0.5B
隐藏维度: 896
层数: 24
注意力头: 14
词表大小: 151936
缓存: 启用（LRU）
```

---

## 🛠️ 解决方案

### 优先级 1: 调试 S 语言推理代码

**文件需要检查**:
- `/app/neurx/agent/runtime.s` - 推理运行时
- `/app/neurx/inference/` - 推理实现
- Embedding 层的权重加载函数

**检查清单**:
- [ ] Embedding 权重是否正确从 safetensors 加载
- [ ] 是否有类型转换问题（float32 vs float16）
- [ ] 缓冲区大小是否足够
- [ ] 是否有 SIMD 指令兼容性问题

### 优先级 2: 尝试替代后端

可用的 IR 文件:
```
- gpu_backend.ir              (GPU 版本)
- gpu_backend_enhanced.ir     (GPU 优化版本)
- production_chat_enhanced.ir (可能更稳定)
- streaming_chat.ir           (流式推理)
```

### 优先级 3: 临时演示方案

使用 Mock API 展示前端功能:
```bash
python3 /app/shuwen/neurx/mock_api.py &
```

然后修改前端 URL 到 `http://127.0.0.1:8001` 而不是 `8000`

---

## 📊 系统信息

**Docker 容器**:
- 镜像: neurx:latest
- 容器 ID: 0c0869afcbdf
- 命令: /entrypoint.sh api
- 网络: host（直接使用主机网络）

**模型信息**:
```
路径: /model/Qwen2.5-0.5B-Instruct/
大小: 2.4 GB
文件: model.safetensors + config + tokenizer
MD5: 576fd47916c590a8d2526f6229e0245c
```

**资源使用**:
```
CPU: 9.6%
内存: 0.2%（30 MB 实际使用）
```

---

## 🔗 相关资源

**前端访问**:
- 公网: http://8.140.241.141:8080/neurx
- 本地: http://127.0.0.1:8080/neurx

**后端调试**:
```bash
# 检查容器日志
docker logs neurx-api-server | tail -100

# 进入容器
docker exec -it neurx-api-server /bin/bash

# 测试推理
curl -X POST http://127.0.0.1:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"default","messages":[{"role":"user","content":"你好"}],"temperature":0.7,"max_tokens":100}'
```

---

## ✋ 建议的后续步骤

1. **立即**: 使用 Mock API 演示前端功能
2. **短期**: 检查 S 语言 Embedding 实现
3. **中期**: 考虑使用 Python/ONNX Runtime 作为临时推理后端
4. **长期**: 修复 S 语言运行时中的权重加载 bug

---

**报告生成**: 2026-08-23 13:15 UTC+8
