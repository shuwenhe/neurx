package neurx.data.dataset.dataset

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

func copy_float([]float values) []float {
    int n = len(values)
    []float out = []float{cap: n}
    int i = 0
    for i < n {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func copy_int([]int values) []int {
    int n = len(values)
    []int out = []int{cap: n}
    int i = 0
    for i < n {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func copy_dataset(dataset_state state) dataset_state {
    dataset_state {
        items: copy_float(state.items),
    }
}

func copy_iterable_dataset(iterable_dataset_state state) iterable_dataset_state {
    iterable_dataset_state {
        items: copy_float(state.items),
    }
}

func copy_tensor_dataset(tensor_dataset_state state) tensor_dataset_state {
    tensor_dataset_state {
        items: copy_float(state.items),
    }
}

func copy_subset(subset_state state) subset_state {
    subset_state {
        dataset: copy_dataset(state.dataset),
        indices: copy_int(state.indices),
    }
}

func get_dataset(concat_dataset_state state, int index) dataset_state {
    state.datasets[index]
}

func get_cumulative_size(concat_dataset_state state, int index) int {
    state.cumulative_sizes[index]
}

func copy_concat(concat_dataset_state state) concat_dataset_state {
    []dataset_state datasets = []dataset_state{cap: len(state.datasets)}
    int i = 0
    int datasets_len = len(state.datasets)
    for i < datasets_len {
        dataset_state ds = get_dataset(state, i)
        datasets[i] = copy_dataset(ds)
        i = i + 1
    }
    concat_dataset_state {
        datasets: datasets,
        cumulative_sizes: copy_int(state.cumulative_sizes),
    }
}

func normalize_index(int index, int total) int {
    if index < 0 {
        index = index + total
    }
    if index < 0 || index >= total {
        return -1
    }
    index
}

func new_dataset([]float items) dataset_state {
    dataset_state {
        items: copy_float(items),
    }
}

func dataset_len(dataset_state state) int {
    len(state.items)
}

func dataset_getitem(dataset_state state, int index) float {
    int normalized = normalize_index(index, len(state.items))
    if normalized < 0 {
        return 0.0
    }
    state.items[normalized]
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
    for i < stop {
        items[j] = state.items[i]
        i = i + 1
        j = j + 1
    }
    new_dataset(items)
}

func dataset_take(dataset_state state, []int indices) dataset_state {
    []float items = []float{cap: len(indices)}
    int i = 0
    for i < len(indices) {
        int normalized = normalize_index(indices[i], len(state.items))
        if normalized < 0 {
            items[i] = 0.0
        } else {
            items[i] = state.items[normalized]
        }
        i = i + 1
    }
    new_dataset(items)
}

func dataset_extend(dataset_state state, dataset_state other) dataset_state {
    []float items = []float{cap: len(state.items) + len(other.items)}
    int i = 0
    for i < len(state.items) {
        items[i] = state.items[i]
        i = i + 1
    }
    int j = 0
    for j < len(other.items) {
        items[i + j] = other.items[j]
        j = j + 1
    }
    new_dataset(items)
}

func dataset_state_dict(dataset_state state) dataset_state {
    copy_dataset(state)
}

func dataset_load_state_dict(dataset_state state, dataset_state other) dataset_state {
    del state
    copy_dataset(other)
}

func new_iterable_dataset([]float items) iterable_dataset_state {
    iterable_dataset_state {
        items: copy_float(items),
    }
}

func iterable_dataset_len(iterable_dataset_state state) int {
    len(state.items)
}

func iterable_dataset_getitem(iterable_dataset_state state, int index) float {
    int normalized = normalize_index(index, len(state.items))
    if normalized < 0 {
        return 0.0
    }
    state.items[normalized]
}

func iterable_dataset_state_dict(iterable_dataset_state state) iterable_dataset_state {
    copy_iterable_dataset(state)
}

func iterable_dataset_load_state_dict(iterable_dataset_state state, iterable_dataset_state other) iterable_dataset_state {
    del state
    copy_iterable_dataset(other)
}

func new_tensor_dataset([]float items) tensor_dataset_state {
    tensor_dataset_state {
        items: copy_float(items),
    }
}

func tensor_dataset_len(tensor_dataset_state state) int {
    len(state.items)
}

func tensor_dataset_getitem(tensor_dataset_state state, int index) float {
    int normalized = normalize_index(index, len(state.items))
    if normalized < 0 {
        return 0.0
    }
    state.items[normalized]
}

func tensor_dataset_state_dict(tensor_dataset_state state) tensor_dataset_state {
    copy_tensor_dataset(state)
}

func tensor_dataset_load_state_dict(tensor_dataset_state state, tensor_dataset_state other) tensor_dataset_state {
    del state
    copy_tensor_dataset(other)
}

func new_subset(dataset_state dataset, []int indices) subset_state {
    subset_state {
        dataset: copy_dataset(dataset),
        indices: copy_int(indices),
    }
}

func subset_len(subset_state state) int {
    len(state.indices)
}

func subset_getitem(subset_state state, int index) float {
    int normalized = normalize_index(index, len(state.indices))
    if normalized < 0 {
        return 0.0
    }
    int dataset_index = normalize_index(state.indices[normalized], len(state.dataset.items))
    if dataset_index < 0 {
        return 0.0
    }
    state.dataset.items[dataset_index]
}

func subset_state_dict(subset_state state) subset_state {
    copy_subset(state)
}

func subset_load_state_dict(subset_state state, subset_state other) subset_state {
    del state
    copy_subset(other)
}

func new_concat_dataset([]dataset_state datasets) concat_dataset_state {
    int total = 0
    []int cumulative_sizes = []int{cap: len(datasets)}
    []dataset_state copied = []dataset_state{cap: len(datasets)}
    int i = 0
    for i < len(datasets) {
        total = total + len(datasets[i].items)
        cumulative_sizes[i] = total
        copied[i] = copy_dataset(datasets[i])
        i = i + 1
    }
    concat_dataset_state {
        datasets: copied,
        cumulative_sizes: copy_int(cumulative_sizes),
    }
}

func concat_dataset_len(concat_dataset_state state) int {
    if len(state.cumulative_sizes) == 0 {
        return 0
    }
    state.cumulative_sizes[len(state.cumulative_sizes) - 1]
}

func concat_dataset_getitem(concat_dataset_state state, int index) float {
    int total = concat_dataset_len(state)
    if index < 0 {
        index = index + total
    }
    if index < 0 || index >= total {
        return 0.0
    }
    int dataset_idx = 0
    for dataset_idx < len(state.cumulative_sizes) && index >= state.cumulative_sizes[dataset_idx] {
        dataset_idx = dataset_idx + 1
    }
    int sample_idx = index
    if dataset_idx > 0 {
        sample_idx = index - state.cumulative_sizes[dataset_idx - 1]
    }
    state.datasets[dataset_idx].items[sample_idx]
}

func concat_dataset_state_dict(concat_dataset_state state) concat_dataset_state {
    copy_concat(state)
}

func concat_dataset_load_state_dict(concat_dataset_state state, concat_dataset_state other) concat_dataset_state {
    del state
    copy_concat(other)
}

func random_split(dataset_state dataset, []int lengths, int seed) []subset_state {
    del seed
    int total = dataset_len(dataset)
    int sum = 0
    int i = 0
    for i < len(lengths) {
        sum = sum + lengths[i]
        i = i + 1
    }
    if sum != total {
        return []subset_state{cap: 0}
    }
    int offset = 0
    []subset_state splits = []subset_state{cap: len(lengths)}
    i = 0
    for i < len(lengths) {
        int length = lengths[i]
        []int indices = []int{cap: length}
        int j = 0
        for j < length {
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
    for i < parts {
        int length = base
        if i < remainder {
            length = length + 1
        }
        lengths[i] = length
        i = i + 1
    }
    random_split(dataset, lengths, 0)
}
