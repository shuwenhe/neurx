package neurx.distributed.inference.dynamic_load_balancer

struct gpu_resource {
    int gpu_id
    float utilization_percent
    float memory_used_gb
    float memory_available_gb
    int task_queue_length
    float network_congestion
    int64 last_update_ns
    bool is_available
}

struct gpu_score {
    int gpu_id
    float load_score
    float queue_score
    float memory_score
    float network_score
    float total_score
}

struct dynamic_load_balancer {
    int num_gpus
    gpu_resource[] resources
    gpu_score[] scores
    float[] score_weights
    int[] gpu_assignment_history
    int64 last_rebalance_time_ns
    int rebalance_interval_ms
}

func new_dynamic_load_balancer(int num_gpus) dynamic_load_balancer {
    
    weights := make(float[], 4)
    weights[0] = 0.4
    weights[1] = 0.3
    weights[2] = 0.2
    weights[3] = 0.1
    
    balancer := dynamic_load_balancer {
        num_gpus: num_gpus,
        resources: gpu_resource[]{cap: num_gpus},
        scores: gpu_score[]{cap: num_gpus},
        score_weights: weights,
        gpu_assignment_history: int[]{cap: 1000},
        last_rebalance_time_ns: 0,
        rebalance_interval_ms: 100,
    }
    
    int i = 0
    for i < num_gpus {
        resource := gpu_resource {
            gpu_id: i,
            utilization_percent: 0.0,
            memory_used_gb: 0.0,
            memory_available_gb: 40.0,
            task_queue_length: 0,
            network_congestion: 0.0,
            last_update_ns: 0,
            is_available: true,
        }
        balancer.resources = append(balancer.resources, resource)
        
        score := gpu_score {
            gpu_id: i,
            load_score: 1.0,
            queue_score: 1.0,
            memory_score: 1.0,
            network_score: 1.0,
            total_score: 1.0,
        }
        balancer.scores = append(balancer.scores, score)
        
        i = i + 1
    }
    
    return balancer
}

func (dynamic_load_balancer* balancer) update_gpu_metrics(
    int gpu_id,
    float utilization,
    float memory_used,
    int queue_length,
    float network_congestion
) {
    
    if gpu_id < 0 || gpu_id >= len(balancer.resources) {
        return
    }
    
    gpu_resource* resource = &balancer.resources[gpu_id]
    
    resource.utilization_percent = utilization
    resource.memory_used_gb = memory_used
    resource.task_queue_length = queue_length
    resource.network_congestion = network_congestion
    resource.last_update_ns = 0
    
    if memory_used < 38.0 {
        resource.memory_available_gb = 40.0 - memory_used
        resource.is_available = true
    } else {
        resource.is_available = false
    }
}

func (dynamic_load_balancer* balancer) calculate_gpu_scores() {
    
    float max_utilization = 100.0
    float max_queue_length = 100.0
    float max_memory_available = 40.0
    float max_congestion = 1.0
    
    int i = 0
    for i < len(balancer.resources) {
        gpu_resource* resource = &balancer.resources[i]
        gpu_score* score = &balancer.scores[i]
        
        score.gpu_id = resource.gpu_id
        
        score.load_score = (max_utilization - resource.utilization_percent) / max_utilization
        if score.load_score < 0.0 {
            score.load_score = 0.0
        }
        
        score.queue_score = (max_queue_length - float(resource.task_queue_length)) / max_queue_length
        if score.queue_score < 0.0 {
            score.queue_score = 0.0
        }
        
        score.memory_score = (resource.memory_available_gb) / max_memory_available
        if score.memory_score < 0.0 {
            score.memory_score = 0.0
        }
        
        score.network_score = 1.0 - (resource.network_congestion / max_congestion)
        if score.network_score < 0.0 {
            score.network_score = 0.0
        }
        
        score.total_score = balancer.score_weights[0] * score.load_score
                          + balancer.score_weights[1] * score.queue_score
                          + balancer.score_weights[2] * score.memory_score
                          + balancer.score_weights[3] * score.network_score
        
        i = i + 1
    }
}

func (dynamic_load_balancer* balancer) select_best_gpu_for_request(
    int kv_cache_size_mb,
    int min_available_memory_gb
) int {
    
    balancer.calculate_gpu_scores()
    
    int best_gpu = -1
    float best_score = -1.0
    
    int i = 0
    for i < len(balancer.scores) {
        gpu_score* score = &balancer.scores[i]
        gpu_resource* resource = &balancer.resources[i]
        
        if !resource.is_available {
            i = i + 1
            continue
        }
        
        if resource.memory_available_gb < float(min_available_memory_gb) {
            i = i + 1
            continue
        }
        
        if score.total_score > best_score {
            best_score = score.total_score
            best_gpu = score.gpu_id
        }
        
        i = i + 1
    }
    
    if best_gpu == -1 && len(balancer.resources) > 0 {
        best_gpu = 0
    }
    
    return best_gpu
}

func (dynamic_load_balancer* balancer) select_gpu_least_loaded() int {
    
    int least_loaded_gpu = 0
    int min_queue_length = 1000000
    
    int i = 0
    for i < len(balancer.resources) {
        gpu_resource* resource = &balancer.resources[i]
        
        if resource.task_queue_length < min_queue_length {
            min_queue_length = resource.task_queue_length
            least_loaded_gpu = resource.gpu_id
        }
        
        i = i + 1
    }
    
    return least_loaded_gpu
}

func (dynamic_load_balancer* balancer) detect_overloaded_gpus(float threshold_percent) int[] {
    
    overloaded := int[]{cap: len(balancer.resources)}
    
    int i = 0
    for i < len(balancer.resources) {
        gpu_resource* resource = &balancer.resources[i]
        
        if resource.utilization_percent > threshold_percent {
            overloaded = append(overloaded, resource.gpu_id)
        }
        
        i = i + 1
    }
    
    return overloaded
}

func (dynamic_load_balancer* balancer) detect_idle_gpus(float threshold_percent) int[] {
    
    idle := int[]{cap: len(balancer.resources)}
    
    int i = 0
    for i < len(balancer.resources) {
        gpu_resource* resource = &balancer.resources[i]
        
        if resource.utilization_percent < threshold_percent {
            idle = append(idle, resource.gpu_id)
        }
        
        i = i + 1
    }
    
    return idle
}

func (dynamic_load_balancer* balancer) can_migrate_task(int from_gpu, int to_gpu) bool {
    
    if from_gpu < 0 || from_gpu >= len(balancer.resources) {
        return false
    }
    if to_gpu < 0 || to_gpu >= len(balancer.resources) {
        return false
    }
    
    gpu_resource* from_resource = &balancer.resources[from_gpu]
    gpu_resource* to_resource = &balancer.resources[to_gpu]
    
    if !to_resource.is_available {
        return false
    }
    
    if to_resource.memory_available_gb < 2.0 {
        return false
    }
    
    if to_resource.utilization_percent > 80.0 {
        return false
    }
    
    return true
}

func (dynamic_load_balancer* balancer) get_load_statistics() (float, float, float) {
    
    float avg_utilization = 0.0
    float max_utilization = 0.0
    float min_utilization = 100.0
    
    int i = 0
    for i < len(balancer.resources) {
        gpu_resource* resource = &balancer.resources[i]
        
        avg_utilization = avg_utilization + resource.utilization_percent
        
        if resource.utilization_percent > max_utilization {
            max_utilization = resource.utilization_percent
        }
        
        if resource.utilization_percent < min_utilization {
            min_utilization = resource.utilization_percent
        }
        
        i = i + 1
    }
    
    avg_utilization = avg_utilization / float(len(balancer.resources))
    
    return avg_utilization, max_utilization, min_utilization
}

func (dynamic_load_balancer* balancer) get_imbalance_ratio() float {
    
    avg, max_util, min_util := balancer.get_load_statistics()
    
    if avg <= 0.0 {
        return 0.0
    }
    
    float imbalance = (max_util - min_util) / avg
    
    return imbalance
}

func (dynamic_load_balancer* balancer) suggest_rebalance_actions() (int[], int[], int[]) {
    
    overloaded := balancer.detect_overloaded_gpus(85.0)
    idle := balancer.detect_idle_gpus(20.0)
    migrate_from := int[]{cap: len(overloaded)}
    migrate_to := int[]{cap: len(idle)}
    
    int i = 0
    for i < len(overloaded) {
        gpu_id := overloaded[i]
        
        if balancer.resources[gpu_id].task_queue_length > 5 {
            migrate_from = append(migrate_from, gpu_id)
        }
        
        i = i + 1
    }
    
    return overloaded, idle, migrate_from
}

func (dynamic_load_balancer* balancer) get_all_gpu_resources() gpu_resource[] {
    return balancer.resources
}

func (dynamic_load_balancer* balancer) get_all_scores() gpu_score[] {
    return balancer.scores
}

func (dynamic_load_balancer* balancer) set_score_weights(float[] weights) {
    if len(weights) == 4 {
        balancer.score_weights = weights
    }
}

func (dynamic_load_balancer* balancer) get_num_gpus() int {
    return balancer.num_gpus
}

func (dynamic_load_balancer* balancer) record_assignment(int gpu_id) {
    if len(balancer.gpu_assignment_history) < 1000 {
        balancer.gpu_assignment_history = append(balancer.gpu_assignment_history, gpu_id)
    }
}
