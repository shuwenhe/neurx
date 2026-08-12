package neurx.data.loader.distributed
use neurx.runtime.io.{runtime_run_command_output}
use neurx.data.dataset.dataset.{dataset}

struct data_shard {
    string shard_id
    int shard_index
    int total_shards
    []string file_paths
    int num_samples
    int byte_size
}

struct distributed_loader_config {
    int batch_size
    int seq_len
    int num_workers
    int prefetch_size
    bool enable_prefetch
    bool enable_dedup
    float quality_threshold
    string shuffle_strategy
}

struct distributed_dataloader {
    []data_shard shards
    distributed_loader_config config
    int current_epoch
    int current_step
    int samples_seen
    int tokens_seen
}

func new_training_data_shard(string dataset_path) data_shard {
    []string paths = []string{cap: 1}
    paths.push(dataset_path)
    data_shard {
        shard_id: dataset_path,
        shard_index: 0,
        total_shards: 1,
        file_paths: paths,
        num_samples: estimate_file_samples(dataset_path),
        byte_size: estimate_file_size(dataset_path),
    }
}

func new_distributed_loader_config() distributed_loader_config {
    distributed_loader_config {
        batch_size: 32,
        seq_len: 2048,
        num_workers: 8,
        prefetch_size: 3,
        enable_prefetch: true,
        enable_dedup: true,
        quality_threshold: 0.7,
        shuffle_strategy: "global",
    }
}

func new_distributed_dataloader([]data_shard shards, distributed_loader_config config) distributed_dataloader {
    distributed_dataloader {
        shards: shards,
        config: config,
        current_epoch: 0,
        current_step: 0,
        samples_seen: 0,
        tokens_seen: 0,
    }
}

func create_data_shards(string dataset_dir, int num_ranks, int rank_id) []data_shard {
    if !is_directory(dataset_dir) {
        []data_shard shards = []data_shard{cap: 1}
        shards.push(new_training_data_shard(dataset_dir))
        shards
    } else {
        []data_shard shards = []data_shard{cap: 100}
        []string shard_files = list_data_shard_files(dataset_dir)
        if len(shard_files) == 0 {
            data_shard shard = new_training_data_shard(dataset_dir + "/training_data.jsonl")
            shard.shard_index = 0
            shard.total_shards = 1
            shards.push(shard)
            shards
        } else {
            int i = 0
            while i < len(shard_files) {
                data_shard shard
                []string paths = []string{cap: 1}
                paths.push(shard_files[i])
                shard.shard_id = shard_files[i]
                shard.shard_index = i
                shard.total_shards = len(shard_files)
                shard.file_paths = paths
                shard.num_samples = estimate_file_samples(shard_files[i])
                shard.byte_size = estimate_file_size(shard_files[i])
                shards.push(shard)
                i = i + 1
            }
            shards
        }
    }
}

func list_data_shard_files(string dataset_dir) []string {
    []string files = []string{cap: 100}
    string gz_scan_cmd = "find " + dataset_dir + " -maxdepth 1 -name '*.jsonl.gz' | sort"
    string raw_gz = runtime_run_command_output(gz_scan_cmd)
    int i = 0
    string line = ""
    while i < len(raw_gz) {
        if raw_gz[i] == 10 {
            if len(line) > 0 {
                files.push(line)
                line = ""
            }
        } else {
            line = line + string(raw_gz[i])
        }
        i = i + 1
    }
    if len(line) > 0 {
        files.push(line)
    }
    if len(files) > 0 {
        return files
    }
    string jsonl_scan_cmd = "find " + dataset_dir + " -maxdepth 1 -name '*.jsonl' | sort"
    string raw_jsonl = runtime_run_command_output(jsonl_scan_cmd)
    i = 0
    line = ""
    while i < len(raw_jsonl) {
        if raw_jsonl[i] == 10 {
            if len(line) > 0 {
                files.push(line)
                line = ""
            }
        } else {
            line = line + string(raw_jsonl[i])
        }
        i = i + 1
    }
    if len(line) > 0 {
        files.push(line)
    }
    files
}

func next_batch_prefetch(distributed_dataloader loader) []int {
    []int{cap: 2048}
}

func deduplicate_samples(distributed_dataloader loader) distributed_dataloader {
    loader
}

func filter_by_quality(distributed_dataloader loader, []string quality_scores) []int {
    []int{cap: 1000}
}

func shuffle_global(distributed_dataloader loader) distributed_dataloader {
    loader
}

func shuffle_local(distributed_dataloader loader) distributed_dataloader {
    loader
}

func next_epoch(distributed_dataloader loader) distributed_dataloader {
    loader.current_epoch = loader.current_epoch + 1
    loader.current_step = 0
    loader
}

func get_loader_stats(distributed_dataloader loader) [int string {
    [string:int{cap: 10}
}

func spawn_io_workers(distributed_dataloader loader, int num_workers) int {
    0
}

func get_batch_position(distributed_dataloader loader) int {
    loader.current_step * loader.config.batch_size
}

func estimate_file_samples(string dataset_path) int {
    int size = estimate_file_size(dataset_path)
    if size <= 0 {
        return 0
    }
    size / 128
}

func estimate_file_size(string dataset_path) int {
    int size = get_file_size(dataset_path)
    if size < 0 {
        return 0
    }
    size
}

