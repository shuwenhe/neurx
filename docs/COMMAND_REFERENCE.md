# 💻 NeurX Command Reference Card

Quick copy-paste commands for compilation, testing, and deployment.

---

## 🔧 Compilation Commands

### Compile Single Component
```bash
neurx compile scaled_training_system.s -o bin/scaled_train --optimize=2
neurx compile real_data_loader.s -o bin/data_loader --optimize=2
neurx compile cuda_accelerated_training.s -o bin/cuda_train --optimize=2
neurx compile ddp_distributed_training.s -o bin/ddp_train --optimize=2
```

### Compile All at Once
```bash
neurx compile *.s --optimize=2 -o bin/
```

### Compile with Debug Info
```bash
neurx compile scaled_training_system.s -o bin/scaled_train --debug
```

---

## 🧪 Testing Commands

### Run Compilation Suite
```bash
neurx run compile_and_test.s
```

### Run Performance Benchmark
```bash
neurx run performance_benchmark.s
```

### Run System Verification
```bash
neurx run system_verification.s
```

### Generate Deployment Configs
```bash
neurx run generate_deployment_configs.s
```

---

## ⚙️ Execution Commands

### Local Testing (CPU)
```bash
./bin/scaled_training_system --epochs=1 --steps=5 --batch_size=16 --device=cpu
```

### Single GPU Testing
```bash
export CUDA_VISIBLE_DEVICES=0
./bin/scaled_training_system --epochs=1 --batch_size=32 --device=cuda:0
```

### Multi-GPU Testing (4 GPUs)
```bash
export CUDA_VISIBLE_DEVICES=0,1,2,3
./bin/scaled_training_system --epochs=1 --batch_size=128 --device=cuda
```

### Data Loader Test
```bash
./bin/real_data_loader --dataset=wikitext --batch_size=32 --num_batches=5
```

### CUDA Backend Test
```bash
./bin/cuda_accelerated_training --device_count=4 --memory_test=true
```

### DDP Training (Local, 1 process)
```bash
./bin/ddp_distributed_training --rank=0 --world_size=1 --num_steps=10
```

---

## 🚀 Deployment Commands

### SLURM (HPC Cluster)
```bash
# Generate script
neurx run generate_deployment_configs.s

# Submit job
sbatch deploy/production/scripts/slurm_submit.sh

# Check status
squeue -j <job_id>

# Cancel job
scancel <job_id>

# View output
tail -f logs/slurm-<job_id>.out
```

### Docker (Local Multi-GPU)
```bash
# Start training
docker-compose -f deploy/production/docker-compose.yml up

# Run in background
docker-compose -f deploy/production/docker-compose.yml up -d

# Stop containers
docker-compose -f deploy/production/docker-compose.yml down

# Check logs
docker-compose -f deploy/production/docker-compose.yml logs -f
```

### Kubernetes (Cloud/On-Prem)
```bash
# Apply deployment
kubectl apply -f deploy/production/kubernetes_deployment.yaml

# Check job status
kubectl get jobs

# View pod logs
kubectl logs -f <pod_name>

# Delete job
kubectl delete job neurx-training

# Scale replicas
kubectl scale job neurx-training --replicas=4
```

---

## 📊 Monitoring Commands

### GPU Usage
```bash
nvidia-smi
nvidia-smi -l 1  # Update every 1 second
nvidia-smi -pm 1 # Show Power Management
```

### Training Progress (SLURM)
```bash
# Monitor real-time
./deploy/production/scripts/monitor_training.sh

# View recent output
tail -100 logs/slurm-<job_id>.out

# Watch GPU usage
watch -n 1 nvidia-smi
```

### Docker Container Stats
```bash
docker stats
docker stats training-node-0
docker logs training-node-0 -f
```

### Kubernetes Pod Metrics
```bash
kubectl top pods
kubectl describe pod <pod_name>
kubectl logs <pod_name> -f
```

---

## 🔍 Debugging Commands

### Check File Compilation
```bash
# Verify syntax
neurx check scaled_training_system.s

# Show compilation details
neurx compile scaled_training_system.s -v

# Generate intermediate representation
neurx compile scaled_training_system.s --ir
```

### Profile Performance
```bash
# CPU profiling
neurx run scaled_training_system.s --profile

# GPU profiling (if nvprof available)
nvprof ./bin/scaled_training_system

# Generate flamegraph
perf record -F 99 ./bin/scaled_training_system
perf report
```

### Check Memory
```bash
# Monitor memory usage
top -p <process_id>

# GPU memory
nvidia-smi --query-gpu=memory.used,memory.free --format=csv,noheader

# System memory
free -h
```

### View Logs
```bash
# Compilation logs
cat logs/scaled_training_system_compile.log

# Test output
cat test_output/scaled_training_system_output.txt

# Training logs
tail -f deploy/production/logs/training.log
```

---

## 🔄 Build Pipeline

### Complete Build & Test
```bash
#!/bin/bash
set -e

# Compile
for file in scaled_training_system.s real_data_loader.s cuda_accelerated_training.s ddp_distributed_training.s; do
    neurx compile $file -o bin/$(basename $file .s) --optimize=2
done

# Test
neurx run compile_and_test.s
neurx run performance_benchmark.s
neurx run system_verification.s

# Deploy
neurx run generate_deployment_configs.s

echo "✅ All done!"
```

### Local Multi-GPU Test
```bash
#!/bin/bash
export CUDA_VISIBLE_DEVICES=0,1,2,3
./bin/scaled_training_system \
    --epochs=3 \
    --batch_size=32 \
    --dataset=synthetic \
    --device=cuda \
    --output=results/test_checkpoint
```

---

## 📦 Environment Setup

### Set NeurX Path
```bash
export PATH="/opt/neurx/bin:$PATH"
# or
export PATH="$HOME/.neurx/bin:$PATH"
```

### Set CUDA
```bash
export CUDA_VISIBLE_DEVICES=0,1,2,3
export CUDA_LAUNCH_BLOCKING=1  # For debugging
export NCCL_DEBUG=INFO  # For NCCL debugging
```

### Set Python (if needed)
```bash
export PYTHONPATH="/usr/local/lib/python3.9/dist-packages:$PYTHONPATH"
```

---

## 🎯 Quick Workflows

### Workflow 1: Local Development
```bash
# 1. Compile
neurx compile scaled_training_system.s -o bin/scaled_train

# 2. Test on CPU
./bin/scaled_train --epochs=1 --device=cpu

# 3. Test on GPU
export CUDA_VISIBLE_DEVICES=0
./bin/scaled_train --epochs=1 --device=cuda:0

# 4. Benchmark
neurx run performance_benchmark.s
```

### Workflow 2: Multi-GPU Testing
```bash
# 1. Compile all
for f in *.s; do neurx compile $f; done

# 2. Test on 4 GPUs
export CUDA_VISIBLE_DEVICES=0,1,2,3
./bin/scaled_train --epochs=3 --batch_size=128

# 3. Check performance
neurx run performance_benchmark.s
```

### Workflow 3: Production Deployment
```bash
# 1. Generate configs
neurx run generate_deployment_configs.s

# 2. Deploy to SLURM
sbatch deploy/production/scripts/slurm_submit.sh

# 3. Monitor
./deploy/production/scripts/monitor_training.sh

# 4. View results
tail -f deploy/production/logs/training.log
```

### Workflow 4: Docker Deployment
```bash
# 1. Build image (if needed)
docker build -t neurx:latest .

# 2. Start training
docker-compose -f deploy/production/docker-compose.yml up

# 3. Monitor
docker-compose logs -f

# 4. Stop
docker-compose down
```

---

## 🆘 Common Issues & Fixes

### Issue: Compiler Not Found
```bash
# Fix 1: Add to PATH
export PATH="/opt/neurx/bin:$PATH"

# Fix 2: Use full path
/opt/neurx/bin/neurx compile file.s

# Fix 3: Install from source
git clone https://github.com/neurx/compiler.git
cd compiler && make install
```

### Issue: GPU Not Found
```bash
# Check NVIDIA drivers
nvidia-smi

# Update drivers
# Ubuntu
sudo apt-get install nvidia-driver-XXX

# Set CUDA path
export CUDA_HOME=/usr/local/cuda
export PATH=$CUDA_HOME/bin:$PATH
```

### Issue: Out of Memory
```bash
# Reduce batch size
./bin/scaled_train --batch_size=16

# Use CPU
./bin/scaled_train --device=cpu

# Enable gradient checkpointing
./bin/scaled_train --gradient_checkpointing=true
```

### Issue: Slow Training
```bash
# Enable optimizations
neurx compile file.s --optimize=3

# Use cuDNN
export CUDNN_ENABLED=1

# Profile
nvprof ./bin/scaled_train
```

---

## 📋 Checklist Commands

### Verify Installation
```bash
# Check all required tools
command -v neurx && echo "✅ NeurX"
command -v python3 && echo "✅ Python"
command -v docker && echo "✅ Docker"
command -v nvidia-smi && echo "✅ NVIDIA"
command -v kubectl && echo "✅ Kubernetes"
```

### Verify Files
```bash
# Check all .s files exist
for f in scaled_training_system real_data_loader cuda_accelerated_training ddp_distributed_training compile_and_test generate_deployment_configs performance_benchmark system_verification; do
    [ -f $f.s ] && echo "✅ $f.s" || echo "❌ $f.s"
done
```

### Pre-Deployment Checklist
```bash
# Compile all
neurx compile *.s --optimize=2

# Run tests
neurx run compile_and_test.s
neurx run performance_benchmark.s
neurx run system_verification.s

# Generate configs
neurx run generate_deployment_configs.s

# Verify outputs
[ -d production_deployment ] && echo "✅ Ready to deploy!"
```

---

## 📞 Useful Resources

**Documentation**:
- `QUICK_REFERENCE.md` - This quick guide
- `PRODUCTION_SYSTEM_COMPLETE.md` - Full documentation
- `FULL_IMPLEMENTATION_SUMMARY.md` - Implementation details

**Commands by Task**:
- Compilation: See "Compilation Commands"
- Testing: See "Testing Commands"
- Deployment: See "Deployment Commands"
- Troubleshooting: See "Common Issues & Fixes"

---

**Last Updated**: 2026-07-01  
**Status**: ✅ Production Ready
