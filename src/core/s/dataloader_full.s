package neurx.data
struct dataloader_config {
    int batch_size
    bool shuffle
    int num_workers
    int prefetch_factor
    bool pin_memory
    bool drop_last
    int persistent_workers
    float timeout_secs
    int max_retries
    int world_size
    int rank
    collator_config collator
}

struct dataloader {
    dataset ds
    sampler samp
    dataloader_config config
    int current_epoch
    int total_batches
    int batches_served
    []batch prefetch_buffer
}

func new_dataloader(
    dataset ds,
    dataloader_config cfg
) dataloader {
    sampler_config samp_cfg {
        total_samples: len_dataset(ds),
        batch_size: cfg.batch_size,
        shuffle: cfg.shuffle,
        seed: uint64(42),
        num_replicas: cfg.world_size if cfg.world_size > 0 else 1,
        rank: cfg.rank,
        drop_last: cfg.drop_last,
    }
    int total_samples = len_dataset(ds)
    if cfg.world_size > 1 {
        total_samples = total_samples / cfg.world_size
    }
    int n_batches = total_samples / cfg.batch_size
    if !cfg.drop_last  t(total_samples - (total_samples / cfg.batch_size) * cfg.batch_size) != 0 {
        n_batches = n_batches + 1
    }
    dataloader {
        ds: ds,
        samp: new_sampler(samp_cfg),
        config: cfg,
        current_epoch: 0,
        total_batches: n_batches,
        batches_served: 0,
        prefetch_buffer: [],
    }
}

func reset_epoch(dataloader dl) dataloader {
    dl.current_epoch = dl.current_epoch + 1
    dl.batches_served = 0
    if dl.config.shuffle {
        dl.samp = reset_random(dl.samp)
    } else {
        dl.samp = reset_sequential(dl.samp)
    }
    dl.prefetch_buffer = []
    dl = fill_prefetch_buffer(dl)
    dl
}

func next_batch(dataloader dl) (batch, bool) {
    if len(dl.prefetch_buffer) > 0 {
        batch b = dl.prefetch_buffer.pop_front()
        dl.batches_served = dl.batches_served + 1
        if len(dl.prefetch_buffer) < dl.config.prefetch_factor {
            dl = fill_prefetch_buffer(dl)
        }
        (b, false)
    } else if dl.batches_served >= dl.total_batches {
        (empty_batch(), true)
    } else {
        ([]int indices, bool has_data) = next_batch_sequential(dl.samp)
        if !has_data || len(indices) == 0 {
            (empty_batch(), true)
        }
        []sample samples = load_samples_for_indices(dl.ds, indices)
        batch b = collate_fn(samples, dl.config.collator)
        dl.batches_served = dl.batches_served + 1
        (b, false)
    }
}

func load_samples_for_indices(dataset ds, []int indices) []sample {
    []sample samples = make([]int, len(indices))
    for idx in indices {
        (sample s, error err) = get_sample(ds, idx)
        if err == nil {
            samples = append(samples, s)
        } else {
            sample { token_ids: [], text: "", label: -1, weight: 1.0, metadata: {} }
        }
    }
    samples
}

func fill_prefetch_buffer(dataloader dl) dataloader {
    int target_count = dl.config.prefetch_factor * 2
    for len(dl.prefetch_buffer) < target_count
          dl.batches_served + len(dl.prefetch_buffer) < dl.total_batches {
        ([]int indices, bool has_data) = next_batch_sequential(dl.samp)
        if !has_data || len(indices) == 0 {
            break
        }
        []sample samples = load_samples_for_indices(dl.ds, indices)
        batch b = collate_fn(samples, dl.config.collator)
        dl.prefetch_buffer = append(dl.prefetch_buffer, b)
    }
    dl
}

struct bucket_config {
    int num_buckets
    int min_bucket_size
    int max_bucket_size
    bool dynamic_buckets
}

struct bucketed_dataloader {
    dataloader base_dl
    bucket_config bconfig
    map[int][]int length_to_samples
    []int current_bucket_order
}

func create_bucketed_dataloader(
    dataset ds,
    dataloader_config dl_cfg,
    bucket_config bcfg
) bucketed_dataloader {
    map[int][]int buckets = {}
    for i in 0..len(ds.samples) {
        int len = len(ds.samples[i].token_ids)
        int bucket_idx = assign_to_bucket(len, bcfg)
        if !(bucket_idx in buckets) {
            buckets[bucket_idx] = []
        }
        buckets[bucket_idx].push(i)
    }
    bucketed_dataloader {
        base_dl: new_dataloader(ds, dl_cfg),
        bconfig: bcfg,
        length_to_samples: buckets,
        current_bucket_order: generate_bucket_order(buckets),
    }
}

func assign_to_bucket(int seq_len, bucket_config bcfg) int {
    float range_val = float(bcfg.max_bucket_size - bcfg.min_bucket_size)
    if range_val <= 0.0 { return 0 }
    float normalized = float(seq_len - bcfg.min_bucket_size) / range_val
    int bucket = int(normalized * float(bcfg.num_buckets))
    if bucket < 0 { bucket = 0 }
    if bucket >= bcfg.num_buckets { bucket = bcfg.num_buckets - 1 }
    bucket
}

func generate_bucket_order(map[int][]int buckets) []int {
    []int order = []
    for key in buckets {
        order = append(order, key)
    }
    for i in 0..len(order)-1 {
        for j in 0..len(order)-i-1 {
            if order[j] > order[j+1] {
                int temp = order[j]
                order[j] = order[j+1]
                order[j+1] = temp
            }
        }
    }
    order
}
