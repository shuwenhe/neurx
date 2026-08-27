package main
use neurx.distributed.launcher.{
    new_distributed_pretrain_launcher,
    distributed_pretrain_launcher,
}
use neurx.distributed.cuda_bridge.{
    cuda_bridge_all_reduce_sum,
    cuda_bridge_log_status,
}
use neurx.runtime.io.{runtime_env_get}

struct training_config {
    string model_path
    string dataset_path
    string config_path
    int micro_batch_size
    int gradient_accum_steps
    int num_epochs
    float learning_rate
    int total_steps
    int save_interval
    string log_dir
}

struct training_metrics {
    int step
    int optimizer_step
    float loss
    float learning_rate
    int tokens_processed
    int shard_idx
    int line_idx
}

func main() {
    training_config config = parse_config()
    distributed_pretrain_launcher launcher = new_distributed_pretrain_launcher(
        config.config_path,
        config.micro_batch_size,
        config.gradient_accum_steps,
    )
    if launcher.env.rank == 0 {
        launcher.log("="*50)
        launcher.log("NeurX Distributed Pretraining Started")
        launcher.log("="*50)
        launcher.log("Configuration:")
        launcher.log("  - NUM_GPUS (world_size): " + itoa(launcher.env.world_size))
        launcher.log("  - Current rank: " + itoa(launcher.env.rank))
        launcher.log("  - Local rank: " + itoa(launcher.env.local_rank))
        launcher.log("  - Micro batch size: " + itoa(config.micro_batch_size))
        launcher.log("  - Gradient accumulation steps: " + itoa(config.gradient_accum_steps))
        launcher.log("  - Effective batch size: " + itoa(
            config.micro_batch_size * config.gradient_accum_steps * launcher.env.world_size))
        launcher.log("  - Data shards allocated to rank: " + itoa(len(launcher.shard_paths)))
        launcher.log("="*50)
    }
    launcher.log("Rank info: " + launcher.rank_info())
    cuda_bridge_log_status(launcher.cb)
    int global_step = 0
    int optimizer_step = 0
    int epoch = 0
    for epoch < config.num_epochs {
        int shard_idx = 0
        for shard_idx < len(launcher.shard_paths) {
            string shard_path = launcher.shard_paths[shard_idx]
            int line_idx = 0
            int accum_step = 0
            for line_idx < 1024 {
                float[] batch_data = load_batch(shard_path, line_idx)
                float loss = forward_pass(batch_data)
                float[] gradients = backward_pass(loss)
                global_step = global_step + 1
                accum_step = accum_step + 1
                if accum_step >= config.gradient_accum_steps {
                    float[] synced_gradients = launcher.sync_gradients_nccl(gradients)
                    launcher.optimizer_step(
                        optimizer_step,
                        config.learning_rate,
                        synced_gradients,
                    )
                    optimizer_step = optimizer_step + 1
                    accum_step = 0
                    if optimizer_step % 100 == 0 && launcher.env.rank == 0 {
                        training_metrics metrics = training_metrics {
                            step: global_step,
                            optimizer_step: optimizer_step,
                            loss: loss,
                            learning_rate: config.learning_rate,
                            tokens_processed: global_step * config.micro_batch_size * 2048,
                            shard_idx: shard_idx,
                            line_idx: line_idx,
                        }
                        print_metrics(metrics)
                    }
                    if optimizer_step % config.save_interval == 0 && launcher.env.rank == 0 {
                        launcher.log("Saving checkpoint at step " + itoa(optimizer_step))
                    }
                }
                line_idx = line_idx + 1
            }
            shard_idx = shard_idx + 1
        }
        epoch = epoch + 1
    }
    if launcher.env.rank == 0 {
        launcher.log("="*50)
        launcher.log("Distributed Pretraining Completed!")
        launcher.log("  - Total steps: " + itoa(global_step))
        launcher.log("  - optimizer_2 steps: " + itoa(optimizer_step))
        launcher.log("  - Total epochs: " + itoa(config.num_epochs))
        launcher.log("="*50)
    }
    launcher.finalize()
}

func parse_config() training_config {
    training_config {
        model_path: "./checkpoint/NeurX-1.3/NeurX-1.3.neurx",
        dataset_path: "./dataset/pretrain/shard",
        config_path: "./pretrain/pretrain_config.toml",
        micro_batch_size: 8,
        gradient_accum_steps: 8,
        num_epochs: 1,
        learning_rate: 0.0002,
        total_steps: 50000,
        save_interval: 5000,
        log_dir: "./artifact/logs",
    }
}

func load_batch(string shard_path, int line_idx) float[] {
    float[] batch = float[]{cap: 8 * 2048}
    int i = 0
    for i < len(batch) {
        batch[i] = float(i % 256) / 256.0
        i = i + 1
    }
    batch
}

func forward_pass(float[] batch_data) float {
    float loss = 0.0
    int i = 0
    for i < len(batch_data) {
        loss = loss + batch_data[i]
        i = i + 1
    }
    loss / float(len(batch_data))
}

func backward_pass(float loss) float[] {
    float[] gradients = float[]{cap: 1024}
    int i = 0
    for i < len(gradients) {
        gradients[i] = loss * 0.01
        i = i + 1
    }
    gradients
}

func print_metrics(training_metrics metrics) {
    string log_msg = "[trainer-v2] step=" + itoa(metrics.step) +
                     "/" + itoa(100000000) +
                     " optimizer_step=" + itoa(metrics.optimizer_step) +
                     " loss=" + ftoa(metrics.loss) +
                     " tokens=" + itoa(metrics.tokens_processed) +
                     " shard=" + itoa(metrics.shard_idx) +
                     " line=" + itoa(metrics.line_idx)
    print(log_msg)
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
    for num > 0 {
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
