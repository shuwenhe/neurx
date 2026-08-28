# NeurX 万卡推理集群与异构芯片路线图

本文给出把 NeurX 推进到“万卡推理集群”和“异构芯片统一支持”时，当前仓库最需要补齐的能力顺序。目标不是写愿景，而是把已有实现拆成可落地的工程 Gate。

## 现状判断

仓库里已经存在一批可复用基础：

- 集群入口：`cmd/controller/main.s`、`cmd/worker/main.s`
- 调度骨架：`sys/scheduler/global_scheduler.s`
- 设备 ABI：`sys/device_abi.s`、`sys/device_abi_cuda.s`
- 平台能力注册：`backend/platform/registry.s`
- Attention backend 选择：`src/inference/attention/backend_registry.s`
- 分布式推理/训练骨架：`src/runtime/distributed/*`、`src/training/pretrain/*`
- GPU 资源管理：`driver/gpu/device_allocator.s`
- 模型注册与分发：`sys/model_registry/model_registry.s`

这说明 NeurX 不是从零开始做集群，而是要把“单机/局部能力”收敛成“控制面 + 节点面 + 后端插件 + 分布式执行”的统一系统。

## 关键结论

1. 万卡集群不是先做“更多节点”，而是先做“稳定控制面”和“能力可见性”。
2. 异构芯片不是先做“统一 API 外观”，而是先做“统一 capability model”。
3. 后端差异必须留在 platform / device ABI / kernel pack / collective backend 层，不要渗透到上层调度与业务逻辑。

## P0: 先把集群能跑起来

这一阶段的目标是让 NeurX 具备最小可运维集群闭环。

### 需要完成的能力

- 控制面
  - 节点注册、注销、心跳、版本上报
  - worker 状态汇聚
  - 任务下发与回收
  - 失败节点隔离
- 请求路由
  - 按模型、GPU/NUMA、显存、拓扑做基本 placement
  - 支持单模型多副本
  - 支持冷启动和热迁移的最小接口
- 可观测性
  - request latency
  - token throughput
  - queue depth
  - GPU/内存/网络利用率
  - 节点健康状态
- 部署
  - controller / worker / model registry 的标准化部署清单
  - 统一配置格式
  - 统一日志和指标输出

### 建议落点

- 把 `cmd/controller/main.s` 定义成集群控制面入口
- 把 `cmd/worker/main.s` 定义成节点代理入口
- 把 `sys/scheduler/global_scheduler.s` 升级成“容量感知 + 拓扑感知 + 后端感知”的全局调度器
- 把 `sys/model_registry/model_registry.s` 升级成模型副本与存储位置的权威来源

### P0 验收

- controller 能看到所有 worker 的在线状态
- worker 失联后能被自动摘除
- 一个推理请求能被稳定路由到正确节点
- metrics 可以定位是排队、显存、通信还是后端不匹配导致的慢

## P1: 统一异构设备能力模型

这一阶段的目标不是“支持更多芯片名字”，而是让 NeurX 在调度层只看到统一能力描述。

### 现有基础

`backend/platform/registry.s` 已经在做雏形：

- `cuda`
- `rocm`
- `xpu`
- `tpu`
- `ascend`
- `cpu`
- `npu`
- `musa`
- `mlx`
- `zen`

并且已经带有：

- `supports_graph_capture`
- `supports_speculative_decode`
- `supports_multimodal`
- `supports_fp8`
- `supports_int4`
- `supports_distributed`
- `distributed_backend`

这非常适合作为统一 capability model 的起点。

### 需要补齐的点

- 把 platform capability 从“单平台判断”提升为“节点级 capability”
  - device type
  - memory size
  - compute capability
  - collective backend
  - graph capture 支持
  - fp8/int4 支持
  - pinned memory / zero-copy 支持
- 把 backend 选择从单点逻辑变成可注册表
  - attention backend
  - cache backend
  - collective backend
  - quantization backend
  - decoding backend
- 把 `sys/device_abi.s` 抽成统一 ABI 门面
  - launch kernel
  - allocate/free memory
  - collective submit
  - stream sync
  - error propagation

### 建议原则

- 上层不直接判断“这是 CUDA 还是 ROCm”
- 上层只判断“这个节点是否满足当前 workload 的 capability”
- 具体后端差异由 registry 和 device ABI 处理

### P1 验收

- 同一份 workload 可以在 `cuda` 和 `rocm` 节点上以不同 backend 跑起来
- 不支持 graph capture 的平台会自动走兼容路径
- 调度器可以按 capability 过滤节点，而不是硬编码平台名

## P2: 支持万卡推理的分布式执行

这一阶段解决的是“很多卡如何当成一个系统”。

### 需要完成的能力

- 分布式并行
  - tensor parallel
  - pipeline parallel
  - data parallel
  - 组合并行
- 通信
  - all-reduce
  - all-gather
  - reduce-scatter
  - broadcast
  - point-to-point transfer
- KV cache / prefix cache 分片
- 长上下文与流式解码的跨卡协作
- 容错
  - 节点重连
  - 局部失效降级
  - 请求重放
  - checkpoint 恢复

### 建议落点

- 优先利用 `src/runtime/distributed/*`
- 优先利用 `src/training/pretrain/distributed_*` 里已有的多机协作经验
- 把推理侧的分布式调度和训练侧的分布式通信分开封装，但共享 collective backend

### P2 验收

- 8 卡、64 卡、256 卡、1024 卡都能稳定跑同一类推理工作负载
- 节点加入/退出不会让整个集群停摆
- 集群层面能按副本扩缩容

## P3: 异构芯片正式支持

这一阶段才是“真正的异构集群”。

### 目标

- 同一集群里可以混跑：
  - CUDA GPU
  - ROCm GPU
  - NPU / Ascend
  - CPU fallback
  - 其他 accelerator
- 调度器能按能力而不是厂商名选择执行节点
- backend 插件可以按芯片族独立演进

### 建议实现方式

#### 1. 统一 capability schema

定义一份全局能力模型，至少包括：

- `device_type`
- `platform`
- `memory_gb`
- `supports_distributed`
- `distributed_backend`
- `supports_graph_capture`
- `supports_speculative_decode`
- `supports_fp8`
- `supports_int4`
- `supports_multimodal`
- `supports_streaming`

#### 2. backend 插件化

把这些能力拆成插件边界：

- device ABI plugin
- kernel pack plugin
- collective backend plugin
- quantization plugin
- decoding plugin

#### 3. 统一 fallback 策略

如果高性能 backend 不可用：

- 先降级到兼容 backend
- 再降级到 CPU
- 再把请求排队或拒绝

不要让上层代码显式知道“哪个厂商失败了”。

### P3 验收

- 同一请求能在不同硬件族之间自动选路
- capability 不满足时，错误明确且可观测
- 新芯片加入只需要新增 backend plugin，不需要改上层调度主逻辑

## P4: 运维和大规模发布

万卡集群的难点不只是能跑，还要能长期稳定运行。

### 必须补的运维能力

- 灰度发布
- 金丝雀验证
- worker 版本兼容矩阵
- 节点池分层
- 自动驱逐和重平衡
- 故障演练
- 指标告警
- 追踪和审计

### 建议优先级

- 先保证控制面幂等
- 再保证节点健康判定准确
- 再保证请求能快速迁移
- 最后才做更复杂的自动优化

## 推荐落地顺序

```text
P0  controller / worker / health / metrics / deployment
  ↓
P1  capability registry / ABI unification / backend selection
  ↓
P2  distributed execution / communication / fault tolerance
  ↓
P3  heterogeneous chip plugins / fallback / topology-aware scheduling
  ↓
P4  rollout / canary / observability / SRE hardening
```

## 直接可执行的下一步

1. 先把 controller / worker 的职责边界写成明确接口。
2. 把 `backend/platform/registry.s` 提升为集群级 capability source of truth。
3. 把 `sys/device_abi*.s` 统一成可插拔 backend ABI。
4. 在推理侧补一个“节点健康 + 能力上报 + 请求路由”的最小闭环。
5. 再开始做 tensor parallel / pipeline parallel / collective 扩展。

## 结论

NeurX 要进入万卡推理阶段，核心不是“再加功能”，而是把现有分散的 registry、scheduler、device ABI、distributed runtime 收敛成三个稳定层：

- 控制面
- 能力面
- 执行面

异构芯片支持也一样，先统一 capability，再统一 ABI，再统一调度。  
这样后续扩展 CUDA、ROCm、NPU、CPU 甚至其他 accelerator，都是沿着同一条架构线前进。
