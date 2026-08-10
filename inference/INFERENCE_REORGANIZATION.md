# NeurX Components Reorganization

## Overview
重组了 NeurX 推理引擎的功能模块，将其分解为专用的功能文件夹，以改进代码组织和可维护性。

## 功能映射

### 原始位置 → 新位置

| 原始文件 | 功能 | 新位置 | 模块 |
|---------|------|-------|------|
| `neurx/request_queue.s` | 请求队列管理 | `queue/request_queue.s` | Queue Management |
| `neurx/metrics.s` | 性能指标监控 | `metrics/inference_metrics.s` | Metrics & Monitoring |
| `neurx/neurx.s` | NeurX 运行时引擎 | `scheduler/neurx_runtime.s` | Scheduling & Orchestration |
| `neurx/prefix_cache.s` | 前缀缓存 | `cache/` (已存在) | KV Cache Management |

## 新的目录结构

```
inference/
├── api/                      # HTTP/REST 接口层
├── serve/                    # 服务层（连续批处理、准入控制）
├── scheduler/                # NEW: 调度和运行时管理
│   └── neurx_runtime.s       # NeurX 运行时编排引擎
├── queue/                    # NEW: 请求队列管理
│   └── request_queue.s      # 请求队列实现
├── metrics/                  # NEW: 性能监控
│   └── inference_metrics.s  # 性能指标收集和计算
├── cache/                    # KV 缓存管理
│   ├── kv_cache.s
│   ├── paged_kv_cache.s
│   └── prefix_cache.s
├── decode/                   # Token 解码
├── sampling/                 # 采样策略
├── runtime/                  # 底层运行时
├── eval/                     # 评估框架
└── neurx/                     # Legacy: 保留原始 NeurX 实现（兼容性）
    ├── neurx.s               (已迁移)
    ├── request_queue.s      (已迁移)
    ├── prefix_cache.s
    └── metrics.s            (已迁移)
```

## 包声明更新

### Queue 模块
```s
package neurx.inference.queue.request_queue
```

### Metrics 模块
```s
package neurx.inference.metrics.inference_metrics
```

### Scheduler 模块
```s
package neurx.inference.scheduler.neurx_runtime

use neurx.inference.queue.request_queue
use neurx.inference.metrics.inference_metrics
use neurx.inference.neurx.prefix_cache
use neurx.scheduler.inference_neurx_scheduler
use neurx.attention.inference_paged
```

## 功能描述

### 1. Scheduler 模块 (`scheduler/neurx_runtime.s`)
**职责：** 协调推理流程，管理请求生命周期

**核心结构：**
- `neurx_runtime_state` - 完整的运行时状态
- `neurx_runtime_step_result` - 单步执行结果

**关键操作：**
- `new_neurx_runtime_state()` - 初始化运行时
- `neurx_runtime_enqueue_request()` - 添加请求
- `neurx_runtime_schedule_next()` - 选择下一个请求执行
- `neurx_runtime_record_decode()` - 记录解码进度
- `neurx_runtime_finish_request()` - 完成请求

### 2. Queue 模块 (`queue/request_queue.s`)
**职责：** 管理待处理请求队列

**核心结构：**
- `neurx_request_queue_state` - 队列状态
- `neurx_queue_pop_result` - 出队结果

**关键操作：**
- `neurx_queue_enqueue()` - 加入队列
- `neurx_queue_pop_front()` - 前端出队
- `neurx_queue_pop_shortest()` - 弹出最短请求
- `neurx_queue_size()` - 获取队列大小
- `neurx_queue_empty()` - 检查是否为空

### 3. Metrics 模块 (`metrics/inference_metrics.s`)
**职责：** 收集和计算性能指标

**核心指标：**
- 吞吐量: `admitted` / 时间
- 缓存命中率: `cache_hits` / (`cache_hits` + `cache_misses`)
- 平均队列深度: `queue_depth_sum` / `queue_depth_samples`

**关键操作：**
- `neurx_metrics_record_enqueue()` - 记录请求入队
- `neurx_metrics_record_decode()` - 记录解码token数
- `neurx_metrics_record_cache()` - 记录缓存命中/失败
- `neurx_metrics_record_finish()` - 记录请求完成
- `neurx_metrics_avg_queue_depth()` - 计算平均队列深度
- `neurx_metrics_hit_rate()` - 计算缓存命中率

## 迁移影响

### 需要更新的导入语句

#### 在 neurx/ 目录中使用这些模块的代码：
```s
// OLD
use neurx.inference.neurx.request_queue
use neurx.inference.neurx.metrics
use neurx.inference.neurx.neurx

// NEW
use neurx.inference.queue.request_queue
use neurx.inference.metrics.inference_metrics
use neurx.inference.scheduler.neurx_runtime
```

#### 在其他模块中引用这些功能：
```s
// 要使用请求队列
use neurx.inference.queue.request_queue

// 要使用性能指标
use neurx.inference.metrics.inference_metrics

// 要使用运行时管理
use neurx.inference.scheduler.neurx_runtime
```

## 向后兼容性

`neurx/` 目录保留原始文件以维持向后兼容性。新代码应使用新位置的模块。

## 优势

1. **代码组织** - 功能清晰分离
2. **可维护性** - 相关功能聚集在一起
3. **可重用性** - 模块可独立使用
4. **扩展性** - 易于添加新的调度或监控功能
5. **清晰的依赖** - 模块间依赖关系明确

## 性能影响

无性能影响。这仅是代码组织的改进。

## 下一步

1. ✅ 创建新目录结构
2. ✅ 迁移文件并更新包声明
3. ⏳ 更新所有引用这些模块的代码
4. ⏳ 运行集成测试验证兼容性
5. ⏳ 更新文档和示例

---

**Date:** 2026-08-10  
**Status:** Code reorganization complete, testing pending
