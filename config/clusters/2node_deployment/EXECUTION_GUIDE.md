# NeurX 2-Node 分布式推理部署 - 执行指南

## 📍 目标机器

- **Controller**: 192.168.10.39 (用户: shuwen)
- **Worker**: 192.168.10.75 (用户: shuwen)

## 🔑 SSH 凭证

```
Controller (192.168.10.39):
  User: shuwen
  Password: (已配置)

Worker (192.168.10.75):
  User: shuwen
  Password: Linux@_2026..
```

## 📋 部署步骤

### 步骤 1：在 Controller 上部署 (192.168.10.39)

#### 1.1 SSH 连接到 Controller

```bash
ssh shuwen@192.168.10.39
# 输入密码时使用之前配置的密码
```

#### 1.2 克隆/更新 NeurX 代码

如果还没有 NeurX 代码，clone 一份：

```bash
# 如果已经有了，更新到最新
cd ~/neurx
git pull origin main

# 如果没有，clone 新的
git clone https://github.com/shuwenhe/neurx.git
cd neurx
```

#### 1.3 部署 Controller

在 Controller 机器上执行：

```bash
# 方式 1: 使用部署脚本（推荐）
cd ~/neurx
NEURX_ROLE=controller bash config/clusters/2node_deployment/deploy.sh

# 方式 2: 手动启动
cd ~/neurx
source config/clusters/2node_deployment/controller.env
mkdir -p /tmp/neurx_cluster/{heartbeat,logs}
mkdir -p artifact/{checkpoints,inference_output}

# 如果有编译好的二进制
./build/neurx-controller

# 如果只有源代码（需要 S 编译器）
s ./cmd/controller/main.s
```

**预期输出：**
```
[neurx-controller] discovery result:
[neurx-controller] placement ready
[neurx-controller] listening on 0.0.0.0:8000
```

**保持 Controller 运行**：不要关闭这个终端！

---

### 步骤 2：在 Worker 上部署 (192.168.10.75)

#### 2.1 在新的终端中 SSH 连接到 Worker

```bash
ssh shuwen@192.168.10.75
# 输入密码: Linux@_2026..
```

#### 2.2 准备 Worker 机器

```bash
# 更新代码（如果需要）
cd ~/neurx
git pull origin main

# 或者从 Controller 上复制配置
# (如果代码不在 Worker 上，先克隆)
```

#### 2.3 在 Worker 上启动 Worker 进程

在 Worker 机器的新终端中执行：

```bash
# 方式 1: 使用部署脚本（推荐）
cd ~/neurx
NEURX_ROLE=worker bash config/clusters/2node_deployment/deploy.sh

# 方式 2: 手动启动
cd ~/neurx
source config/clusters/2node_deployment/worker_rank0.env
mkdir -p /tmp/neurx_cluster/{heartbeat,logs}

# 如果有编译好的二进制
./build/neurx-worker

# 如果只有源代码（需要 S 编译器）
s ./cmd/worker/main.s
```

**预期输出：**
```
[neurx-worker] rank=0 local_rank=0
[neurx-worker] master=192.168.10.39:29500
[neurx-worker] heartbeat ready
```

**保持 Worker 运行**：不要关闭这个终端！

---

### 步骤 3：验证部署 (从任何机器)

在第三个终端中（或者在 Controller 上），验证集群状态：

```bash
# 方式 1: 使用监控脚本
bash ~/neurx/config/clusters/2node_deployment/monitor.sh

# 方式 2: 手动检查
# 检查 Controller API
curl http://192.168.10.39:8000/v1/models

# 检查网络连接
ping 192.168.10.39
ping 192.168.10.75
```

**预期输出：**
```
✅ NCCL Port (29500):    LISTENING
✅ API Server (8000):    LISTENING
✅ NCCL Port (29501):    LISTENING
💓 HEARTBEAT: 1 file(s) found
```

---

### 步骤 4：测试推理

```bash
# 简单测试（获取模型列表）
curl http://192.168.10.39:8000/v1/models

# 完整推理测试
curl -X POST http://192.168.10.39:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-0.5B-Instruct",
    "prompt": "What is machine learning?",
    "max_tokens": 100
  }'
```

---

## 🎯 完整执行流程（总结）

### 终端 1：Controller 机器

```bash
ssh shuwen@192.168.10.39
cd ~/neurx
NEURX_ROLE=controller bash config/clusters/2node_deployment/deploy.sh
# 保持运行...
```

### 终端 2：Worker 机器

```bash
ssh shuwen@192.168.10.75
cd ~/neurx
NEURX_ROLE=worker bash config/clusters/2node_deployment/deploy.sh
# 保持运行...
```

### 终端 3：验证和测试

```bash
# 检查集群状态
bash ~/neurx/config/clusters/2node_deployment/monitor.sh

# 测试推理
curl -X POST http://192.168.10.39:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "Qwen/Qwen2.5-0.5B-Instruct", "prompt": "Hi!", "max_tokens": 50}'
```

---

## 📊 监控和调试

### 实时监控集群

```bash
# 在任何机器上运行
bash ~/neurx/config/clusters/2node_deployment/monitor.sh

# 或持续监控
watch bash ~/neurx/config/clusters/2node_deployment/monitor.sh
```

### 查看日志

```bash
# Controller 日志
ssh shuwen@192.168.10.39 'tail -f /tmp/neurx_cluster/logs/*.log'

# Worker 日志
ssh shuwen@192.168.10.75 'tail -f /tmp/neurx_cluster/logs/*.log'

# 实时查看两端日志
ssh shuwen@192.168.10.39 'tail -f /tmp/neurx_cluster/logs/controller.log' &
ssh shuwen@192.168.10.75 'tail -f /tmp/neurx_cluster/logs/worker.log' &
```

### 检查心跳

```bash
# Controller 上
ssh shuwen@192.168.10.39 'watch ls -la /tmp/neurx_cluster/heartbeat/'

# Worker 上
ssh shuwen@192.168.10.75 'watch ls -la /tmp/neurx_cluster/heartbeat/'
```

---

## 🐛 常见问题

### Q1: Worker 无法连接到 Controller

**症状**: Worker 日志显示连接超时

**解决**:
```bash
# 在 Controller 上检查
ssh shuwen@192.168.10.39 'netstat -tlnp | grep 29500'

# 检查防火墙
ssh shuwen@192.168.10.39 'sudo firewall-cmd --add-port=29500/tcp --permanent && sudo firewall-cmd --reload'

# 在 Worker 上测试连接
ssh shuwen@192.168.10.75 'telnet 192.168.10.39 29500'
```

### Q2: GPU 不可用

**症状**: nvidia-smi 失败或返回 0 GPU

**解决**:
```bash
# 检查 Controller
ssh shuwen@192.168.10.39 'nvidia-smi'

# 检查 Worker
ssh shuwen@192.168.10.75 'nvidia-smi'

# 检查驱动版本
ssh shuwen@192.168.10.39 'nvidia-smi --query | grep "Driver Version"'
ssh shuwen@192.168.10.75 'nvidia-smi --query | grep "Driver Version"'
```

### Q3: 模型未找到

**症状**: 推理返回 "Model not found"

**解决**:
```bash
# 检查 Controller
ssh shuwen@192.168.10.39 'ls -la /model/Qwen2.5-0.5B-Instruct/'

# 检查 Worker
ssh shuwen@192.168.10.75 'ls -la /model/'

# 下载模型
ssh shuwen@192.168.10.39 'python -c "
from transformers import AutoModel, AutoTokenizer
model = AutoModel.from_pretrained(\"Qwen/Qwen2.5-0.5B-Instruct\", cache_dir=\"/model\")
tokenizer = AutoTokenizer.from_pretrained(\"Qwen/Qwen2.5-0.5B-Instruct\", cache_dir=\"/model\")
"'

# 同步到 Worker
ssh shuwen@192.168.10.39 'rsync -azv /model/ shuwen@192.168.10.75:/model/'
```

### Q4: S 编译器未找到

**症状**: 错误 "s: command not found"

**解决**:
```bash
# 安装 S 编译器（需要根据系统选择）
# 或使用预编译的二进制（如果有 build/ 目录）

ssh shuwen@192.168.10.39 'ls -la ~/neurx/build/neurx-controller'
ssh shuwen@192.168.10.75 'ls -la ~/neurx/build/neurx-worker'
```

---

## ✅ 部署检查清单

启动前请检查：

- [ ] 两台机器都能 ping 通
- [ ] SSH 连接可用
- [ ] 两台机器都有 NVIDIA GPU (`nvidia-smi`)
- [ ] 模型已下载到 `/model` 目录
- [ ] NeurX 代码已同步到两台机器
- [ ] 配置文件已生成到 `config/clusters/2node_deployment/`

启动后请检查：

- [ ] Controller 进程启动无错误
- [ ] Worker 进程启动无错误
- [ ] `monitor.sh` 显示所有服务 LISTENING
- [ ] 心跳文件已生成
- [ ] API 测试成功

---

## 📁 配置文件位置

所有配置文件位于：
```
~/neurx/config/clusters/2node_deployment/
├── controller.env              # Controller 环境变量
├── worker_rank0.env            # Worker 环境变量
├── deploy.sh                   # 部署脚本
├── monitor.sh                  # 监控脚本
├── README.md                   # 快速参考
├── DEPLOYMENT_GUIDE.md         # 详细指南
└── (本文件)
```

---

## 🔗 快速命令

```bash
# 一键启动 Controller
ssh shuwen@192.168.10.39 'cd ~/neurx && NEURX_ROLE=controller bash config/clusters/2node_deployment/deploy.sh'

# 一键启动 Worker
ssh shuwen@192.168.10.75 'cd ~/neurx && NEURX_ROLE=worker bash config/clusters/2node_deployment/deploy.sh'

# 一键监控
bash ~/neurx/config/clusters/2node_deployment/monitor.sh

# 一键测试
curl -X POST http://192.168.10.39:8000/v1/completions -H "Content-Type: application/json" -d '{"model": "Qwen/Qwen2.5-0.5B-Instruct", "prompt": "Hi", "max_tokens": 50}'
```

---

## 💡 提示

1. **先启动 Controller**：Worker 依赖 Controller
2. **保持进程运行**：不要关闭任何终端
3. **查看日志**：有问题时检查日志文件
4. **逐步验证**：先验证单台机器，再连接集群

---

**现在准备好启动部署了！** 🚀

