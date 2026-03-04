from __future__ import annotations

import numpy as np


class Dataset:
    def __len__(self) -> int:
        raise NotImplementedError("Dataset.__len__ is not implemented")

    def __getitem__(self, index):
        raise NotImplementedError("Dataset.__getitem__ is not implemented")


class IterableDataset(Dataset):
    def __iter__(self):
        raise NotImplementedError("IterableDataset.__iter__ is not implemented")

    def __len__(self) -> int:
        raise TypeError("IterableDataset has no length")

    def __getitem__(self, index):
        raise TypeError("IterableDataset does not support indexing")


class TensorDataset(Dataset):
    def __init__(self, *tensors):
        if not tensors:
            raise ValueError("TensorDataset requires at least one neurx")

        def _first_dim(x):
            if hasattr(x, "__len__"):
                return len(x)
            if hasattr(x, "shape") and len(x.shape) > 0:
                return x.shape[0]
            raise ValueError("neurx-like object must support __len__ or .shape[0]")

        first_len = _first_dim(tensors[0])
        for t in tensors[1:]:
            if _first_dim(t) != first_len:
                raise ValueError("all tensors must share the same first dimension")
        self.tensors = tensors

    def __len__(self) -> int:
        return len(self.tensors[0])

    def __getitem__(self, index):
        if len(self.tensors) == 1:
            return self.tensors[0][index]
        return tuple(t[index] for t in self.tensors)


class Subset(Dataset):
    def __init__(self, dataset: Dataset, indices):
        self.dataset = dataset
        self.indices = list(indices)

    def __len__(self) -> int:
        return len(self.indices)

    def __getitem__(self, index):
        return self.dataset[self.indices[index]]


class ConcatDataset(Dataset):
    def __init__(self, datasets):
        if not datasets:
            raise ValueError("ConcatDataset requires at least one dataset")
        self.datasets = list(datasets)
        self.cumulative_sizes = self._cumsum(self.datasets)

    @staticmethod
    def _cumsum(datasets):
        total = 0
        sizes = []
        for ds in datasets:
            total += len(ds)
            sizes.append(total)
        return sizes

    def __len__(self) -> int:
        return self.cumulative_sizes[-1]

    def __getitem__(self, index):
        if index < 0:
            if -index > len(self):
                raise IndexError("index out of range")
            index = len(self) + index
        dataset_idx = 0
        while index >= self.cumulative_sizes[dataset_idx]:
            dataset_idx += 1
        if dataset_idx == 0:
            sample_idx = index
        else:
            sample_idx = index - self.cumulative_sizes[dataset_idx - 1]
        return self.datasets[dataset_idx][sample_idx]


def random_split(dataset: Dataset, lengths, seed: int | None = None):
    if not lengths:
        raise ValueError("lengths must be a non-empty sequence")
    total_length = len(dataset)
    if sum(lengths) != total_length:
        raise ValueError("sum of lengths must equal dataset length")
    rng = np.random.default_rng(seed)
    indices = rng.permutation(total_length).tolist()
    splits = []
    offset = 0
    for length in lengths:
        splits.append(Subset(dataset, indices[offset: offset + length]))
        offset += length
    return splits
