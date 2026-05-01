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

func _copy_float([]float values) []float {
    int n = len(values)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func _copy_int([]int values) []int {
    int n = len(values)
    []int out = []int{cap: n}
    int i = 0
    while i < n {
        out[i] = values[i]
        i = i + 1
    }
    out
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

func dataset_slice(dataset_state state, int start, int stop) dataset_state {
    if start < 0 {
        start = 0
    }
    if stop < start {
        stop = start
    }
    int n = len(state.items)
    if start > n {
        start = n
    }
    if stop > n {
        stop = n
    }
    []float items = []float{cap: stop - start}
    int i = start
    int j = 0
    while i < stop {
        items[j] = state.items[i]
        i = i + 1
        j = j + 1
    }
    new_dataset(items)
}

func dataset_take(dataset_state state, []int indices) dataset_state {
    []float items = []float{cap: len(indices)}
    int i = 0
    while i < len(indices) {
        items[i] = state.items[indices[i]]
        i = i + 1
    }
    new_dataset(items)
}

func dataset_extend(dataset_state state, dataset_state other) dataset_state {
    []float items = []float{cap: len(state.items) + len(other.items)}
    int i = 0
    while i < len(state.items) {
        items[i] = state.items[i]
        i = i + 1
    }
    int j = 0
    while j < len(other.items) {
        items[i + j] = other.items[j]
        j = j + 1
    }
    new_dataset(items)
}

func dataset_state_dict(dataset_state state) dataset_state {
    dataset_state {
        items: _copy_float(state.items),
    }
}

func dataset_load_state_dict(dataset_state state, dataset_state other) dataset_state {
    other
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

func iterable_dataset_state_dict(iterable_dataset_state state) iterable_dataset_state {
    iterable_dataset_state {
        items: _copy_float(state.items),
    }
}

func iterable_dataset_load_state_dict(iterable_dataset_state state, iterable_dataset_state other) iterable_dataset_state {
    other
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

func tensor_dataset_state_dict(tensor_dataset_state state) tensor_dataset_state {
    tensor_dataset_state {
        items: _copy_float(state.items),
    }
}

func tensor_dataset_load_state_dict(tensor_dataset_state state, tensor_dataset_state other) tensor_dataset_state {
    other
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

func subset_state_dict(subset_state state) subset_state {
    subset_state {
        dataset: dataset_state_dict(state.dataset),
        indices: _copy_int(state.indices),
    }
}

func subset_load_state_dict(subset_state state, subset_state other) subset_state {
    other
}

func new_concat_dataset([]dataset_state datasets) concat_dataset_state {
    int total = 0
    []int cumulative_sizes = []int{cap: len(datasets)}
    int i = 0
    while i < len(datasets) {
        total = total + len(datasets[i].items)
        cumulative_sizes[i] = total
        i = i + 1
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

func concat_dataset_state_dict(concat_dataset_state state) concat_dataset_state {
    []dataset_state datasets = []dataset_state{cap: len(state.datasets)}
    int i = 0
    while i < len(state.datasets) {
        datasets[i] = dataset_state_dict(state.datasets[i])
        i = i + 1
    }
    concat_dataset_state {
        datasets: datasets,
        cumulative_sizes: _copy_int(state.cumulative_sizes),
    }
}

func concat_dataset_load_state_dict(concat_dataset_state state, concat_dataset_state other) concat_dataset_state {
    other
}

func random_split(dataset_state dataset, []int lengths, int seed) []subset_state {
    del seed
    int offset = 0
    []subset_state splits = []subset_state{cap: len(lengths)}
    int i = 0
    while i < len(lengths) {
        int length = lengths[i]
        []int indices = []int{cap: length}
        int j = 0
        while j < length {
            indices[j] = offset + j
            j = j + 1
        }
        splits[i] = new_subset(dataset, indices)
        offset = offset + length
        i = i + 1
    }
    splits
}

func random_split_equal(dataset_state dataset, int parts, int seed) []subset_state {
    del seed
    if parts <= 0 {
        return []subset_state{cap: 0}
    }
    int total = dataset_len(dataset)
    int base = total / parts
    int remainder = total - base * parts
    []int lengths = []int{cap: parts}
    int i = 0
    while i < parts {
        int length = base
        if i < remainder {
            length = length + 1
        }
        lengths[i] = length
        i = i + 1
    }
    random_split(dataset, lengths, 0)
}
