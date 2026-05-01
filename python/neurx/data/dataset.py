from __future__ import annotations

import random
from abc import ABC, abstractmethod

from neurx.core import Tensor


class Dataset(ABC):
    @abstractmethod
    def __getitem__(self, index):
        raise NotImplementedError

    @abstractmethod
    def __len__(self):
        raise NotImplementedError


class IterableDataset(Dataset):
    def __iter__(self):
        raise NotImplementedError


class TensorDataset(Dataset):
    def __init__(self, *tensors):
        self.tensors = tuple(tensors)
        if not self.tensors:
            raise ValueError("TensorDataset requires at least one tensor")
        length = len(self.tensors[0])
        for tensor in self.tensors[1:]:
            if len(tensor) != length:
                raise ValueError("all tensors must have the same length")

    def __getitem__(self, index):
        return tuple(tensor[index] for tensor in self.tensors)

    def __len__(self):
        return len(self.tensors[0])


class Subset(Dataset):
    def __init__(self, dataset, indices):
        self.dataset = dataset
        self.indices = list(indices)

    def __getitem__(self, index):
        return self.dataset[self.indices[index]]

    def __len__(self):
        return len(self.indices)


class ConcatDataset(Dataset):
    def __init__(self, datasets):
        self.datasets = list(datasets)
        self._sizes = [len(dataset) for dataset in self.datasets]
        self._cumulative_sizes = []
        total = 0
        for size in self._sizes:
            total += size
            self._cumulative_sizes.append(total)

    def __getitem__(self, index):
        if index < 0:
            index += len(self)
        if index < 0 or index >= len(self):
            raise IndexError(index)
        for dataset_idx, cumulative_size in enumerate(self._cumulative_sizes):
            if index < cumulative_size:
                previous = 0 if dataset_idx == 0 else self._cumulative_sizes[dataset_idx - 1]
                return self.datasets[dataset_idx][index - previous]
        raise IndexError(index)

    def __len__(self):
        return self._cumulative_sizes[-1] if self._cumulative_sizes else 0


def random_split(dataset, lengths, seed=None):
    lengths = [int(length) for length in lengths]
    if sum(lengths) != len(dataset):
        raise ValueError("lengths must sum to the dataset length")
    indices = list(range(len(dataset)))
    rng = random.Random(seed)
    rng.shuffle(indices)
    result = []
    cursor = 0
    for length in lengths:
        result.append(Subset(dataset, indices[cursor:cursor + length]))
        cursor += length
    return tuple(result)
