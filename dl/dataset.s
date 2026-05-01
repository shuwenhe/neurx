package neurx.dl.dataset

struct dataset_state {
    []float items
}

struct iterable_dataset_state {
    []float items
}

struct tensor_dataset_state {
    []float items
}

struct subset_state {
    dataset_state dataset
    []int indices
}

struct concat_dataset_state {
    []dataset_state datasets
    []int cumulative_sizes
}

func new_dataset([]float items) dataset_state {
    dataset_state {
        items: items,
    }
}

func dataset_len(dataset_state state) int {
    len(state.items)
}

func dataset_getitem(dataset_state state, int index) float {
    state.items[index]
}

func new_iterable_dataset([]float items) iterable_dataset_state {
    iterable_dataset_state {
        items: items,
    }
}

func iterable_dataset_len(iterable_dataset_state state) int {
    len(state.items)
}

func iterable_dataset_getitem(iterable_dataset_state state, int index) float {
    state.items[index]
}

func new_tensor_dataset([]float items) tensor_dataset_state {
    tensor_dataset_state {
        items: items,
    }
}

func tensor_dataset_len(tensor_dataset_state state) int {
    len(state.items)
}

func tensor_dataset_getitem(tensor_dataset_state state, int index) float {
    state.items[index]
}

func new_subset(dataset_state dataset, []int indices) subset_state {
    subset_state {
        dataset: dataset,
        indices: indices,
    }
}

func subset_len(subset_state state) int {
    len(state.indices)
}

func subset_getitem(subset_state state, int index) float {
    state.dataset.items[state.indices[index]]
}

func new_concat_dataset([]dataset_state datasets) concat_dataset_state {
    int total = 0
    []int cumulative_sizes = []int{cap: len(datasets)}
    for i in 0..len(datasets) {
        total = total + len(datasets[i].items)
        cumulative_sizes.push(total)
    }
    concat_dataset_state {
        datasets: datasets,
        cumulative_sizes: cumulative_sizes,
    }
}

func concat_dataset_len(concat_dataset_state state) int {
    if len(state.cumulative_sizes) == 0 {
        return 0
    }
    state.cumulative_sizes[len(state.cumulative_sizes) - 1]
}

func concat_dataset_getitem(concat_dataset_state state, int index) float {
    int dataset_idx = 0
    while dataset_idx < len(state.cumulative_sizes) && index >= state.cumulative_sizes[dataset_idx] {
        dataset_idx = dataset_idx + 1
    }
    int sample_idx = index
    if dataset_idx > 0 {
        sample_idx = index - state.cumulative_sizes[dataset_idx - 1]
    }
    state.datasets[dataset_idx].items[sample_idx]
}

func random_split(dataset_state dataset, []int lengths, int seed) []subset_state {
    del seed
    int offset = 0
    []subset_state splits = []subset_state{cap: len(lengths)}
    for i in 0..len(lengths) {
        int length = lengths[i]
        []int indices = []int{cap: length}
        for j in 0..length {
            indices.push(offset + j)
        }
        splits.push(new_subset(dataset, indices))
        offset = offset + length
    }
    splits
}
