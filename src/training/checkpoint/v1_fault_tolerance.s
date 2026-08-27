package v1

type checkpoint_type string

const (
    checkpoint_full         checkpoint_type = "full"
    checkpoint_incremental  checkpoint_type = "incremental"
    checkpoint_async        checkpoint_type = "async"
)

struct checkpoint {
    checkpoint_type type
    string checkpoint_id
    int32 timestamp
    int32 batch_id
    string state_data
    int32 checkpoint_size_mb
}

struct fault_tolerance_config {
    bool enable_checkpointing
    checkpoint_type checkpoint_type_mode
    int32 checkpoint_interval
    int32 max_checkpoints
    string checkpoint_dir
}

struct v1_fault_tolerance {
    fault_tolerance_config config

    vec[checkpoint*] checkpoints
    map[string]checkpoint* checkpoint_map

    int32 total_checkpoints_created
    int32 total_checkpoints_restored

    int32 last_checkpoint_id
}

func create_v1_fault_tolerance() v1_fault_tolerance* {
    return *v1_fault_tolerance{
        config: fault_tolerance_config{
            enable_checkpointing: true,
            checkpoint_type_mode: checkpoint_full,
            checkpoint_interval: 1000,
            max_checkpoints: 5,
            checkpoint_dir: "/tmp/checkpoints",
        },
        checkpoints: make(vec[checkpoint*]),
        checkpoint_map: make(map[string]checkpoint*),
        total_checkpoints_created: 0,
        total_checkpoints_restored: 0,
        last_checkpoint_id: 0,
    }
}

func (v1_fault_tolerance* ft) create_checkpoint(int32 batch_id, string state_data) string {
    if !ft.config.enable_checkpointing {
        return ""
    }

    checkpoint_id := "ckpt_" + string(ft.last_checkpoint_id)
    ft.last_checkpoint_id = ft.last_checkpoint_id + 1

    ckpt := *checkpoint{
        type: ft.config.checkpoint_type_mode,
        checkpoint_id: checkpoint_id,
        timestamp: 0,
        batch_id: batch_id,
        state_data: state_data,
        checkpoint_size_mb: len(state_data) / (1024 * 1024),
    }

    ft.checkpoints = append(ft.checkpoints, ckpt)
    ft.checkpoint_map[checkpoint_id] = ckpt
    ft.total_checkpoints_created = ft.total_checkpoints_created + 1

    if len(ft.checkpoints) > ft.config.max_checkpoints {
        old_ckpt := ft.checkpoints[0]
        ft.checkpoints = ft.checkpoints[1:]
        delete(ft.checkpoint_map, old_ckpt.checkpoint_id)
    }

    return checkpoint_id
}

func (v1_fault_tolerance* ft) restore_checkpoint(string checkpoint_id) option[checkpoint*] {
    if ckpt, exists := ft.checkpoint_map[checkpoint_id]; exists {
        ft.total_checkpoints_restored = ft.total_checkpoints_restored + 1
        return option[checkpoint*]{value: ckpt}
    }
    return option[checkpoint*]{}
}

func (v1_fault_tolerance* ft) get_latest_checkpoint() option[checkpoint*] {
    if len(ft.checkpoints) == 0 {
        return option[checkpoint*]{}
    }

    latest := ft.checkpoints[len(ft.checkpoints) - 1]
    return option[checkpoint*]{value: latest}
}

func (v1_fault_tolerance* ft) list_checkpoints() vec[checkpoint*] {
    return ft.checkpoints
}

func (v1_fault_tolerance* ft) delete_checkpoint(string checkpoint_id) bool {
    if _, exists := ft.checkpoint_map[checkpoint_id]; exists {
        delete(ft.checkpoint_map, checkpoint_id)

        for i := 0; i < len(ft.checkpoints); i = i + 1 {
            if ft.checkpoints[i].checkpoint_id == checkpoint_id {
                ft.checkpoints = append(ft.checkpoints[:i], ft.checkpoints[i+1:]...)
                break
            }
        }

        return true
    }
    return false
}

func (v1_fault_tolerance* ft) enable_async_checkpoint() {
    ft.config.checkpoint_type_mode = checkpoint_async
}

func (v1_fault_tolerance* ft) set_checkpoint_interval(int32 interval) {
    ft.config.checkpoint_interval = interval
}

func (v1_fault_tolerance* ft) get_fault_tolerance_stats() map[string]interface{} {
    stats := make(map[string]interface{})
    stats["checkpointing_enabled"] = ft.config.enable_checkpointing
    stats["total_checkpoints"] = ft.total_checkpoints_created
    stats["total_restored"] = ft.total_checkpoints_restored
    stats["num_current_checkpoints"] = len(ft.checkpoints)
    stats["max_checkpoints"] = ft.config.max_checkpoints
    return stats
}
