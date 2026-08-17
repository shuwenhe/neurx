package neurx.data.loader

struct batch {
    input_ids [][]i64
    labels []i64
    attention_mask [][]i64
}

struct data_loader {
    data []batch
    batch_size i64
    shuffle bool
    current_idx i64
}

func data_loader_new(data []batch, i64 batch_size, bool shuffle) data_loader {
    return data_loader{
        data: data,
        batch_size: batch_size,
        shuffle: shuffle,
        current_idx: 0,
    }
}

func create_synthetic_dataset(i64 num_samples, i64 seq_len, i64 vocab_size, i64 num_classes) []batch {
    batches := make([]batch, 0)
    for b := 0; b < num_samples; b++ {
        batch_item := batch{
            input_ids: make([][]i64, 1),
            labels: make([]i64, 1),
            attention_mask: make([][]i64, 1),
        }
        batch_item.input_ids[0] = make([]i64, seq_len)
        batch_item.attention_mask[0] = make([]i64, seq_len)
        for i := 0; i < seq_len; i++ {
            batch_item.input_ids[0][i] = i64(simple_random() % int(vocab_size))
            batch_item.attention_mask[0][i] = 1
        }
        batch_item.labels[0] = i64(simple_random() % int(num_classes))
        batches = append(batches, batch_item)
    }
    return batches
}

func data_loader_next_batch(loader data_loader) batch {
    if loader.current_idx >= i64(len(loader.data)) {
        return batch{}
    }
    batch_item := loader.data[loader.current_idx]
    return batch_item
}

func data_loader_has_next(loader data_loader) bool {
    return loader.current_idx < i64(len(loader.data))
}

func data_loader_step(loader data_loader) data_loader {
    loader.current_idx = loader.current_idx + 1
    return loader
}

func data_loader_reset(loader data_loader) data_loader {
    loader.current_idx = 0
    return loader
}

func data_loader_len(loader data_loader) i64 {
    return i64(len(loader.data))
}

func simple_random() int {
    static_seed := 12345
    static_seed = (1103515245 * static_seed + 12345) % 2147483648
    return static_seed % 100000
}

struct batch_iterator {
    loader data_loader
    idx i64
}

func batch_iterator_new(loader data_loader) batch_iterator {
    return batch_iterator{
        loader: loader,
        idx: 0,
    }
}

func batch_iterator_next(it batch_iterator) (batch, bool) {
    if it.idx >= i64(len(it.loader.data)) {
        return batch{}, false
    }
    batch_item := it.loader.data[it.idx]
    return batch_item, true
}

func batch_iterator_step(it batch_iterator) batch_iterator {
    it.idx = it.idx + 1
    return it
}

struct random_sampler {
    data_size i64
    indices []i64
}

func random_sampler_new(i64 data_size) random_sampler {
    indices := make([]i64, data_size)
    for i := 0; i < data_size; i++ {
        indices[i] = i64(i)
    }
    return random_sampler{
        data_size: data_size,
        indices: indices,
    }
}

func collate_fn(batches []batch) batch {
    if len(batches) == 0 {
        return batch{}
    }
    combined := batch{
        input_ids: make([][]i64, 0),
        labels: make([]i64, 0),
        attention_mask: make([][]i64, 0),
    }
    for i := 0; i < len(batches); i++ {
        for j := 0; j < len(batches[i].input_ids); j++ {
            combined.input_ids = append(combined.input_ids, batches[i].input_ids[j])
            combined.labels = append(combined.labels, batches[i].labels[j])
            combined.attention_mask = append(combined.attention_mask, batches[i].attention_mask[j])
        }
    }
    return combined
}

struct distributed_sampler {
    data_size i64
    rank i64
    world_size i64
    indices []i64
}

func distributed_sampler_new(i64 data_size, i64 rank, i64 world_size) distributed_sampler {
    indices := make([]i64, 0)
    samples_per_rank := data_size / world_size
    for i := 0; i < samples_per_rank; i++ {
        sample_idx := rank + i64(i)*world_size
        if sample_idx < data_size {
            indices = append(indices, sample_idx)
        }
    }
    return distributed_sampler{
        data_size: data_size,
        rank: rank,
        world_size: world_size,
        indices: indices,
    }
}

func distributed_sampler_len(sampler distributed_sampler) i64 {
    return i64(len(sampler.indices))
}

func distributed_sampler_get(sampler distributed_sampler, i64 idx) i64 {
    if idx < 0 || idx >= i64(len(sampler.indices)) {
        return 0
    }
    return sampler.indices[idx]
}
