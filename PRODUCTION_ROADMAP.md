# 🚀 NeurX 生产级推理框架实现路线图

## 📋 总体规划 (3-4 个月)

### Phase 1: API & 服务层 (2-3 周) 🔴 优先级最高
**目标**: 实现 RESTful API 服务器和基本的并发处理

- [ ] **1.1 HTTP 服务器框架** (inference/api/http_server.s)
  - TCP socket 监听
  - HTTP 请求解析
  - 路由分发
  - 响应序列化

- [ ] **1.2 RESTful API 端点** (inference/api/rest_api.s)
  - POST /api/generate - 文本生成
  - GET /api/models - 模型列表
  - POST /api/chat/completions - 聊天兼容格式
  - GET /api/health - 健康检查
  - POST /api/embeddings - 嵌入生成

- [ ] **1.3 流式输出支持** (inference/api/streaming.s)
  - Server-Sent Events (SSE)
  - 分块响应传输
  - 客户端兼容性

- [ ] **1.4 请求队列管理** (inference/api/request_queue.s)
  - 请求入队/出队
  - 优先级管理
  - 超时处理

### Phase 2: 并发推理框架 (2-3 周) 🟠 优先级高
**目标**: 支持多请求并发处理和连续批处理

- [ ] **2.1 并发管理器** (inference/runtime/concurrency_manager.s)
  - 线程池管理
  - 请求调度
  - 资源分配
  - 负载均衡

- [ ] **2.2 批处理引擎** (inference/runtime/batch_engine.s)
  - 动态批大小调整
  - KV 缓存共享
  - 连续批处理 (Continuous Batching)
  - 推测解码支持

- [ ] **2.3 上下文管理** (inference/runtime/context_manager.s)
  - 会话管理
  - 对话历史保存
  - 上下文窗口管理

### Phase 3: 性能优化 (2-3 周) 🟡 优先级中
**目标**: 实现高性能计算后端和优化

- [ ] **3.1 BLAS 后端集成** (inference/backend/blas_integration.s)
  - CBLAS 调用
  - 性能自适应选择
  - Fallback 机制

- [ ] **3.2 缓存优化** (inference/backend/cache_optimization.s)
  - CPU 缓存友好算法
  - 内存预取
  - 数据对齐

- [ ] **3.3 向量化优化** (inference/backend/simd_kernels.s)
  - SIMD 指令利用
  - 向量化矩阵运算
  - 数据重排优化

- [ ] **3.4 GPU 支持** (inference/backend/gpu_support.s) [可选]
  - CUDA kernel 调用
  - 显存管理
  - GPU 编译支持

### Phase 4: 模型与配置管理 (1-2 周) 🟢 优先级中
**目标**: 完整的模型和配置系统

- [ ] **4.1 模型管理器** (inference/models/model_manager.s)
  - 模型加载/卸载
  - 模型缓存
  - 版本管理
  - 热加载支持

- [ ] **4.2 配置系统** (inference/config/config_manager.s)
  - YAML 配置解析
  - 环境变量覆盖
  - 动态配置更新
  - 验证与约束

- [ ] **4.3 采样策略完整实现** (inference/sampling/advanced_sampling.s)
  - Top-K 采样
  - Top-P (Nucleus) 采样
  - Temperature 控制
  - 重复惩罚
  - 频率惩罚

### Phase 5: 监控与诊断 (1-2 周) 🟢 优先级低
**目标**: 生产级监控和可观测性

- [ ] **5.1 指标收集** (inference/monitoring/metrics.s)
  - 吞吐量统计
  - 延迟分布
  - 内存占用
  - 缓存命中率

- [ ] **5.2 日志系统** (inference/monitoring/logger.s)
  - 结构化日志
  - 日志级别控制
  - 异步写入
  - 日志轮转

- [ ] **5.3 健康检查** (inference/monitoring/health_check.s)
  - 模型状态检查
  - 内存状态
  - 网络连接
  - 性能基准

- [ ] **5.4 性能剖析** (inference/monitoring/profiler.s)
  - 时间分布
  - 热点识别
  - 内存分析

### Phase 6: 高级功能 (2-3 周) 🟢 优先级低
**目标**: 增强功能和用户体验

- [ ] **6.1 长上下文支持** (inference/features/long_context.s)
  - 滑动窗口
  - 稀疏注意力
  - 内存高效编码

- [ ] **6.2 自适应推理** (inference/features/adaptive_inference.s)
  - 动态精度调整
  - 层级裁剪
  - 投机解码

- [ ] **6.3 多模型支持** (inference/features/multi_model.s)
  - 模型路由
  - 模型融合
  - 动态模型切换

## 🏗️ 架构设计

```
┌─────────────────────────────────────────┐
│         HTTP API Layer                  │
│  (RESTful endpoints + Streaming)        │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────┴──────────────────────┐
│      Request Processing Layer           │
│  (Queue, Router, Context Manager)       │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────┴──────────────────────┐
│    Inference Runtime Layer              │
│  (Concurrency, Batching, Scheduling)    │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────┴──────────────────────┐
│      Model Execution Layer              │
│  (Tokenizer→Embed→Transform→Sample)     │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────┴──────────────────────┐
│    Computation Backend Layer            │
│  (CPU/BLAS/SIMD, optionally GPU)        │
└─────────────────────────────────────────┘
```

## 📊 里程碑与时间表

| 阶段 | 功能 | 工时 | 目标日期 |
|-----|-----|------|--------|
| Phase 1 | HTTP API + 基础流式 | 15天 | Week 3 |
| Phase 2 | 并发框架 | 15天 | Week 6 |
| Phase 3 | 性能优化 | 15天 | Week 9 |
| Phase 4 | 配置系统 | 10天 | Week 11 |
| Phase 5 | 监控诊断 | 10天 | Week 13 |
| Phase 6 | 高级功能 | 15天 | Week 17 |
| **总计** | **完整生产框架** | **80天** | **~4 个月** |

## 🎯 阶段性目标

### ✅ Week 1-3: MVP (Minimum Viable Product)
```
✓ HTTP 服务器可响应请求
✓ 基础 /api/generate 端点
✓ 单请求同步推理
✓ JSON 请求/响应格式
```

### ✅ Week 4-6: 并发能力
```
✓ 多请求队列处理
✓ 基础批处理
✓ 简单的流式输出
✓ 请求超时管理
```

### ✅ Week 7-9: 性能基线
```
✓ BLAS 后端可选
✓ 缓存优化应用
✓ 性能基准建立 (50+ tok/s CPU)
✓ 监控指标收集
```

### ✅ Week 10-13: 生产就绪
```
✓ 配置文件系统
✓ 日志和健康检查
✓ 错误恢复机制
✓ 多模型支持
```

### ✅ Week 14-17: 增强特性
```
✓ 长上下文支持
✓ 高级采样策略
✓ 性能可视化
✓ 文档和示例
```

## 💻 开发环境需求

- S 编译器: `/home/shuwen/shuwen/s/bin/s`
- 模型: `/home/shuwen/shuwen/posttrain/model.safetensors` (1.9GB)
- 基础库: `neurx.inference.*` 模块
- 测试工具: curl, wrk (性能测试)

## 🔧 构建与部署

```bash
# 编译生产服务器
make build-production-server

# 启动服务 (默认 localhost:8000)
./bin/neurx-server --port 8000 --model /path/to/model.safetensors

# 测试 API
curl -X POST http://localhost:8000/api/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "医学术语：", "max_tokens": 100}'

# 性能测试 (1000 并发请求)
wrk -t4 -c1000 -d30s http://localhost:8000/api/health
```

## 📚 关键文件清单

### 新增文件
```
inference/api/http_server.s
inference/api/rest_api.s
inference/api/streaming.s
inference/api/request_queue.s
inference/runtime/concurrency_manager.s
inference/runtime/batch_engine.s
inference/runtime/context_manager.s
inference/backend/blas_integration.s
inference/backend/cache_optimization.s
inference/models/model_manager.s
inference/config/config_manager.s
inference/monitoring/metrics.s
inference/monitoring/logger.s
inference/cmd/server.s
```

### 已有文件 (集成)
```
inference/step1_tokenizer.s
inference/step2_embedding.s
inference/step3_transformer.s
inference/step5_sampling_step6_decode.s
inference/safetensors_loader.s
inference/native/production_cpu_backend.s
inference/blas_backend.s
```

## 🚨 风险与缓解

| 风险 | 影响 | 缓解方案 |
|-----|-----|--------|
| S 编译器限制 | 无法实现某些特性 | 预研 + Fallback |
| 内存压力 (1.9GB) | OOM 问题 | 内存映射 + 分层加载 |
| 性能不达预期 | 吞吐量过低 | GPU 支持 + 优化 |
| 并发稳定性 | 死锁/竞态 | 充分测试 + Lock-free |

## ✨ 成功指标

- [ ] API 响应时间 < 100ms (健康检查)
- [ ] 吞吐量 > 50 tok/s (CPU, 批大小=4)
- [ ] 99% 推理延迟 < 2s (seq_len=100)
- [ ] 内存占用 < 2.5GB (峰值)
- [ ] 并发连接数 > 100
- [ ] 可用性 > 99.5% (24h uptime)
- [ ] 支持 OpenAI 兼容 API

---

**状态**: 📋 规划完成 | 🚀 准备开始实现
**维护者**: shuwenhe@pku.edu.cn
**最后更新**: 2026-08-06
