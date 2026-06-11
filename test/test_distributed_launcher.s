package neurx.test_distributed_launcher

use neurx.distributed.launcher.{distributed_config, new_distributed_config, detect_distributed_config, distributed_config_state_dict, distributed_config_load_state_dict, validate_distributed_config, is_distributed}

func main() int {
    distributed_config cfg = new_distributed_config(8, 2, 2, "127.0.0.1", 29500, "nccl")
    if !validate_distributed_config(cfg) {
        println("validate_distributed_config failed")
        return 1
    }
    if !is_distributed(cfg) {
        println("is_distributed failed")
        return 1
    }

    distributed_config snapshot = distributed_config_state_dict(cfg)
    distributed_config restored = distributed_config_load_state_dict(cfg, snapshot)
    if restored.world_size != 8 {
        println("state_dict round trip failed")
        return 1
    }

    distributed_config auto_cfg = detect_distributed_config()
    if !validate_distributed_config(auto_cfg) {
        println("detect_distributed_config failed")
        return 1
    }

    distributed_config bad_cfg = new_distributed_config(0, -1, -1, "", 70000, "invalid")
    if validate_distributed_config(bad_cfg) {
        println("invalid cfg should not pass")
        return 1
    }

    println("distributed launcher test passed")
    0
}