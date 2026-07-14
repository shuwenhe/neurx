#!/usr/bin/env s

// ============================================
// NeurX Multi-Node Distributed Pretraining Entry
// 多节点分布式预训练主入口
// 功能: 多节点协调、NCCL初始化、故障恢复
// ============================================

package main

use neurx.distributed.multi_node_launcher.{
    init_multi_node_config,
    generate_rank_info,
    calculate_global_rank,
    synchronize_across_nodes,
    check_node_health,
    save_distributed_checkpoint,
    load_distributed_checkpoint,
}
use neurx.distributed.nccl_id_manager.{
    generate_nccl_unique_id,
    save_nccl_id_to_shared_storage,
    load_nccl_id_from_shared_storage,
}
use neurx.runtime.io.{runtime_env_get}

// ============================================
// 主函数
// ============================================

func main() {
    
    print("="*60)
    print("NeurX Multi-Node Distributed Pretraining Entry")
    print("="*60)
    
    // 1. 初始化多节点配置
    multi_node_config config = init_multi_node_config()
    
    // 2. 确定当前rank的信息
    int local_rank = parse_int(runtime_env_get("LOCAL_RANK", "0"), 0)
    rank_info rank = generate_rank_info(config, local_rank)
    
    print("[MAIN] Multi-Node Configuration:")
    print("  - Total nodes: " + itoa(config.num_nodes))
    print("  - Current node rank: " + itoa(config.node_rank))
    print("  - GPUs per node: " + itoa(config.gpus_per_node))
    print("  - World size: " + itoa(config.world_size))
    print("  - Current global rank: " + itoa(rank.global_rank))
    print("  - Current local rank: " + itoa(rank.local_rank))
    print("  - Master address: " + config.master_addr + ":" + itoa(config.master_port))
    print("  - NCCL store path: " + config.nccl_store_path)
    
    // 3. 主节点生成并保存NCCL Unique ID
    nccl_unique_id nccl_id = {}
    
    if rank.global_rank == 0 {
        print("[MAIN] Rank 0 is master, generating NCCL Unique ID...")
        
        // 生成NCCL ID
        nccl_id = generate_nccl_unique_id()
        
        // 保存到共享存储供其他rank读取
        bool saved = save_nccl_id_to_shared_storage(nccl_id, config.nccl_store_path)
        if !saved {
            print("[ERROR] Failed to save NCCL ID!")
            return
        }
        
        print("[MAIN] NCCL ID saved and ready for other ranks")
    }
    
    // 4. 第一道同步屏障：等待NCCL ID就绪
    print("[MAIN] Rank " + itoa(rank.global_rank) + " waiting for NCCL ID...")
    
    (nccl_unique_id loaded_id, bool success) := load_nccl_id_from_shared_storage(
        config.nccl_store_path,
        300,  // 5分钟超时
    )
    
    if !success {
        print("[ERROR] Failed to load NCCL ID!")
        return
    }
    
    nccl_id = loaded_id
    print("[MAIN] Rank " + itoa(rank.global_rank) + " loaded NCCL ID from shared storage")
    
    // 5. 第二道同步屏障：所有rank准备就绪
    print("[MAIN] Rank " + itoa(rank.global_rank) + " reached sync barrier")
    
    bool synced = synchronize_across_nodes(rank, config.nccl_store_path)
    if !synced {
        print("[ERROR] Failed to synchronize!")
        return
    }
    
    // 6. 初始化NCCL Communicator
    print("[MAIN] Rank " + itoa(rank.global_rank) + " initializing NCCL communicator...")
    
    // 实际调用: ncclCommInitRank(&comm, world_size, id, rank)
    // 这里只是日志记录
    
    // 7. 加载或创建checkpoint
    int resume_step = 0
    float resume_loss = 0.0
    
    string resume_mode = runtime_env_get("NEURX_PRETRAIN_RESUME", "auto")
    
    if resume_mode == "auto" {
        (resume_step, resume_loss, success) := load_distributed_checkpoint(
            rank,
            config.nccl_store_path + "/checkpoints",
        )
        
        if success && resume_step > 0 {
            print("[MAIN] Resuming from checkpoint at step " + itoa(resume_step))
        } else {
            print("[MAIN] Starting fresh training")
        }
    }
    
    // 8. 开始训练循环
    print("[MAIN] Starting training loop...")
    
    int max_steps = parse_int(runtime_env_get("NEURX_PRETRAIN_STEPS", "50000"), 50000)
    int save_interval = parse_int(runtime_env_get("NEURX_PRETRAIN_SAVE_INTERVAL", "5000"), 5000)
    int log_interval = parse_int(runtime_env_get("NEURX_PRETRAIN_LOG_INTERVAL", "100"), 100)
    
    int step = resume_step
    while step < max_steps {
        
        // 模拟训练步
        float loss = simulate_training_step(step)
        
        // 日志
        if step % log_interval == 0 && rank.global_rank == 0 {
            print("[TRAIN] step=" + itoa(step) + " loss=" + ftoa(loss))
        }
        
        // 定期保存checkpoint
        if step > 0 && step % save_interval == 0 {
            print("[CHECKPOINT] Rank " + itoa(rank.global_rank) +
                  " saving checkpoint at step " + itoa(step))
            
            bool saved = save_distributed_checkpoint(
                rank,
                step,
                loss,
                config.nccl_store_path + "/checkpoints",
            )
            
            if !saved && rank.global_rank == 0 {
                print("[WARNING] Failed to save checkpoint")
            }
        }
        
        // 定期检查节点健康状态
        if step % (save_interval / 2) == 0 {
            node_health_status health = check_node_health(rank, 30)
            if !health.is_healthy {
                print("[WARNING] Rank " + itoa(rank.global_rank) + " health check failed!")
            }
        }
        
        step = step + 1
    }
    
    print("[MAIN] Training completed!")
    print("  - Final step: " + itoa(step))
    print("  - Rank: " + itoa(rank.global_rank))
}

// ============================================
// 模拟训练步
// ============================================

func simulate_training_step(int step) float {
    // 模拟损失下降
    float base_loss = 10.0
    float loss = base_loss * (1.0 / float(step + 1))
    loss
}

// ============================================
// 辅助函数
// ============================================

func parse_int(string s, int fallback) int {
    int result = 0
    int i = 0
    
    while i < len(s) {
        byte b = s[i]
        if b >= '0' && b <= '9' {
            result = result * 10 + int(b - '0')
        }
        i = i + 1
    }
    
    if result == 0 {
        result = fallback
    }
    result
}

func itoa(int n) string {
    if n == 0 {
        return "0"
    }
    
    string s = ""
    int num = n
    
    if num < 0 {
        s = "-"
        num = -num
    }
    
    while num > 0 {
        byte digit = byte('0' + (num % 10))
        s = string(digit) + s
        num = num / 10
    }
    
    s
}

func ftoa(float f) string {
    int int_part = int(f)
    int frac_part = int((f - float(int_part)) * 1000000)
    itoa(int_part) + "." + itoa(frac_part)
}
