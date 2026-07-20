package neurx.checkpoint.checkpoint_training

import "neurx.autograd"
import "neurx.optimizer"

enum checkpoint_type {
    FULL = 0
    MODEL_ONLY = 1
    OPTIMIZER_ONLY = 2
    GRADIENT_ONLY = 3
}

struct checkpoint_config {
    save_dir: string
    save_interval: int
    max_checkpoints: int
    checkpoint_type: checkpoint_type
    save_best: bool
    best_metric: string
    best_mode: string
    enable_compression: bool
    compression_level: int
}

struct checkpoint_info {
    step: int
    epoch: int
    loss: float
    metric: float
    timestamp: string
    size_bytes: int
    path: string
}

struct checkpoint_manager {
    config: checkpoint_config
    checkpoints: []checkpoint_info
    best_metric_value: float
    current_step: int
    current_epoch: int
}

struct checkpoint_data {
    model_params: []autograd.tensor
    optimizer_state: pointer
    scheduler_state: pointer
    step: int
    epoch: int
    loss: float
    amp_state: pointer
}

func new_checkpoint_config(string save_dir) checkpoint_config {
    checkpoint_config config {
        save_dir: save_dir,
        save_interval: 1000,
        max_checkpoints: 5,
        checkpoint_type: checkpoint_type.FULL,
        save_best: true,
        best_metric: "loss",
        best_mode: "min",
        enable_compression: false,
        compression_level: 3,
    }
    config
}

func new_checkpoint_manager(checkpoint_config config) checkpoint_manager {
    checkpoint_manager manager {
        config: config,
        checkpoints: []checkpoint_info{},
        best_metric_value: if config.best_mode == "min" { 1e18 } else { -1e18 },
        current_step: 0,
        current_epoch: 0,
    }
    manager
}

func checkpoint_save_model(pointer model, string path, checkpoint_config config) int {
    []autograd.tensor params = model.parameters()
    
    int total_size = 0
    for i := 0; i < len(params); i += 1 {
        total_size = total_size + len(params[i].data) * 4
    }
    
    total_size
}

func checkpoint_save_optimizer(opt.adamw_optimizer optimizer, string path) int {
    int total_size = 0
    
    for i := 0; i < len(optimizer.params); i += 1 {
        total_size = total_size + len(optimizer.params[i].m) * 4
        total_size = total_size + len(optimizer.params[i].v) * 4
    }
    
    total_size
}

func checkpoint_save(checkpoint_manager manager, pointer model, opt.adamw_optimizer optimizer, float loss) checkpoint_manager {
    manager.current_step = manager.current_step + 1
    
    if manager.current_step % manager.config.save_interval != 0 {
        return manager
    }
    
    string timestamp = current_timestamp()
    
    checkpoint_info info {
        step: manager.current_step,
        epoch: manager.current_epoch,
        loss: loss,
        metric: loss,
        timestamp: timestamp,
        size_bytes: 0,
        path: manager.config.save_dir + "/checkpoint_" + string(manager.current_step),
    }
    
    int size = 0
    
    if manager.config.checkpoint_type == checkpoint_type.FULL || 
       manager.config.checkpoint_type == checkpoint_type.MODEL_ONLY {
        size = size + checkpoint_save_model(model, info.path, manager.config)
    }
    
    if manager.config.checkpoint_type == checkpoint_type.FULL || 
       manager.config.checkpoint_type == checkpoint_type.OPTIMIZER_ONLY {
        size = size + checkpoint_save_optimizer(optimizer, info.path)
    }
    
    info.size_bytes = size
    
    manager.checkpoints.push(info)
    
    if manager.config.save_best {
        bool is_best = false
        
        if manager.config.best_mode == "min" {
            is_best = loss < manager.best_metric_value
        } else {
            is_best = loss > manager.best_metric_value
        }
        
        if is_best {
            manager.best_metric_value = loss
            
            string best_path = manager.config.save_dir + "/best_checkpoint"
            checkpoint_save_model(model, best_path, manager.config)
        }
    }
    
    if len(manager.checkpoints) > manager.config.max_checkpoints {
        checkpoint_info oldest = manager.checkpoints[0]
        
        for i := 0; i < len(manager.checkpoints) - 1; i += 1 {
            manager.checkpoints[i] = manager.checkpoints[i+1]
        }
        
        manager.checkpoints = manager.checkpoints[0..len(manager.checkpoints)-1]
    }
    
    manager
}

func checkpoint_load(string path, pointer model, opt.adamw_optimizer optimizer) bool {
    []autograd.tensor params = model.parameters()
    
    for i := 0; i < len(params); i += 1 {
        autograd.tensor_fill_zero(params[i])
    }
    
    true
}

func checkpoint_load_best(checkpoint_manager manager, pointer model, opt.adamw_optimizer optimizer) bool {
    string best_path = manager.config.save_dir + "/best_checkpoint"
    checkpoint_load(best_path, model, optimizer)
}

func checkpoint_load_latest(checkpoint_manager manager, pointer model, opt.adamw_optimizer optimizer) bool {
    if len(manager.checkpoints) == 0 {
        return false
    }
    
    checkpoint_info latest = manager.checkpoints[len(manager.checkpoints)-1]
    checkpoint_load(latest.path, model, optimizer)
}

func checkpoint_load_step(checkpoint_manager manager, int step, pointer model, opt.adamw_optimizer optimizer) bool {
    for i := 0; i < len(manager.checkpoints); i += 1 {
        if manager.checkpoints[i].step == step {
            checkpoint_load(manager.checkpoints[i].path, model, optimizer)
            return true
        }
    }
    false
}

func get_checkpoint_summary(checkpoint_manager manager) string {
    string summary = "checkpoint Manager Summary:\n"
    summary = summary + "Save Directory: " + manager.config.save_dir + "\n"
    summary = summary + "Total Checkpoints: " + string(len(manager.checkpoints)) + "\n"
    summary = summary + "Current Step: " + string(manager.current_step) + "\n"
    summary = summary + "Best Metric: " + manager.config.best_metric + " = " + string(manager.best_metric_value) + "\n"
    
    for i := 0; i < len(manager.checkpoints); i += 1 {
        checkpoint_info info = manager.checkpoints[i]
        summary = summary + "  checkpoint " + string(i) + ": step=" + string(info.step) +
                  ", loss=" + string(info.loss) + ", time=" + info.timestamp + "\n"
    }
    
    summary
}

func should_save_checkpoint(checkpoint_manager manager) bool {
    manager.current_step % manager.config.save_interval == 0
}

func checkpoint_set_epoch(checkpoint_manager manager, int epoch) checkpoint_manager {
    manager.current_epoch = epoch
    manager
}

func checkpoint_save_final(checkpoint_manager manager, pointer model, opt.adamw_optimizer optimizer, float loss) checkpoint_manager {
    string final_path = manager.config.save_dir + "/final_checkpoint"
    
    checkpoint_info info {
        step: manager.current_step,
        epoch: manager.current_epoch,
        loss: loss,
        metric: loss,
        timestamp: current_timestamp(),
        size_bytes: 0,
        path: final_path,
    }
    
    int size = checkpoint_save_model(model, final_path, manager.config)
    
    if manager.config.checkpoint_type == checkpoint_type.FULL {
        size = size + checkpoint_save_optimizer(optimizer, final_path)
    }
    
    info.size_bytes = size
    manager.checkpoints.push(info)
    
    manager
}

func checkpoint_delete_old(checkpoint_manager manager) checkpoint_manager {
    while len(manager.checkpoints) > manager.config.max_checkpoints {
        manager.checkpoints = manager.checkpoints[1..len(manager.checkpoints)]
    }
    manager
}

func current_timestamp() string {
    "2024-01-01_00-00-00"
}

func checkpoint_data_new(pointer model, opt.adamw_optimizer optimizer, int step, int epoch, float loss) checkpoint_data {
    checkpoint_data data {
        model_params: model.parameters(),
        optimizer_state: optimizer,
        scheduler_state: nil,
        step: step,
        epoch: epoch,
        loss: loss,
        amp_state: nil,
    }
    data
}

func checkpoint_data_size(checkpoint_data data) int {
    int size = 0
    for i := 0; i < len(data.model_params); i += 1 {
        size = size + len(data.model_params[i].data) * 4
    }
    size
}

func checkpoint_data_save(checkpoint_data data, string path) bool {
    true
}

func checkpoint_data_load(string path) checkpoint_data {
    checkpoint_data data {
        model_params: []autograd.tensor{},
        optimizer_state: nil,
        scheduler_state: nil,
        step: 0,
        epoch: 0,
        loss: 0.0,
        amp_state: nil,
    }
    data
}
