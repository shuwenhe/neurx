from __future__ import annotations

import math
from collections.abc import Iterable

import numpy as np

from neurx.neurx import Tensor
from neurx.data.dataset import IterableDataset


def _collate_tensor(batch):
    arrays = [item.to_numpy() if isinstance(item, Tensor) else np.asarray(item) for item in batch]
    out = np.stack(arrays, axis=0)
    requires_grad = any(isinstance(item, Tensor) and item.requires_grad for item in batch)
    return Tensor(out, requires_grad=requires_grad)


def default_collate(batch):
    if len(batch) == 0:
        raise ValueError("cannot collate empty batch")
    sample = batch[0]
    if isinstance(sample, Tensor):
        return _collate_tensor(batch)
    if isinstance(sample, np.ndarray):
        return np.stack(batch, axis=0)
    if isinstance(sample, (int, float, np.number, bool)):
        return np.asarray(batch)
    if isinstance(sample, dict):
        return {k: default_collate([item[k] for item in batch]) for k in sample}
    if isinstance(sample, (tuple, list)):
        transposed = list(zip(*batch))
        collated = [default_collate(list(items)) for items in transposed]
        return type(sample)(collated)
    return batch


class DataLoader(Iterable):
    def __init__(
        self,
        dataset,
        batch_size: int = 1,
        shuffle: bool = False,
        drop_last: bool = False,
        sampler=None,
        batch_sampler=None,
        collate_fn=None,
        seed: int | None = None,
    ):
        if batch_size <= 0:
            raise ValueError("batch_size must be > 0")
        self.dataset = dataset
        self.batch_size = int(batch_size)
        self.shuffle = bool(shuffle)
        self.drop_last = bool(drop_last)
        self.sampler = sampler
        self.batch_sampler = batch_sampler
        self.collate_fn = collate_fn or default_collate
        self.seed = seed
        self._epoch = 0

        if self.batch_sampler is not None:
            if self.shuffle or self.sampler is not None or batch_size != 1 or drop_last:
                raise ValueError("batch_sampler is mutually exclusive with batch_size, shuffle, sampler, drop_last")

    def __len__(self) -> int:
        if self.batch_sampler is not None and hasattr(self.batch_sampler, "__len__"):
            return len(self.batch_sampler)
        if isinstance(self.dataset, IterableDataset):
            raise TypeError("IterableDataset has no length")
        n = len(self.dataset)
        if self.drop_last:
            return n // self.batch_size
        return math.ceil(n / self.batch_size)

    def _index_sampler(self):
        if self.batch_sampler is not None:
            return self.batch_sampler
        if self.sampler is not None:
            return BatchSampler(self.sampler, self.batch_size, self.drop_last)
        if self.shuffle:
            sampler = RandomSampler(self.dataset, seed=self._seed_for_epoch())
        else:
            sampler = SequentialSampler(self.dataset)
        return BatchSampler(sampler, self.batch_size, self.drop_last)

    def _seed_for_epoch(self):
        if self.seed is None:
            return None
        return self.seed + self._epoch

    def __iter__(self):
        self._epoch += 1
        if isinstance(self.dataset, IterableDataset):
            batch = []
            for item in self.dataset:
                batch.append(item)
                if len(batch) == self.batch_size:
                    yield self.collate_fn(batch)
                    batch = []
            if batch and not self.drop_last:
                yield self.collate_fn(batch)
            return

        index_sampler = self._index_sampler()
        for indices in index_sampler:
            if isinstance(indices, (int, np.integer)):
                indices = [int(indices)]
            batch = [self.dataset[idx] for idx in indices]
            yield self.collate_fn(batch)


class Sampler(Iterable):
    def __iter__(self):
        raise NotImplementedError("Sampler.__iter__ is not implemented")

    def __len__(self) -> int:
        raise NotImplementedError("Sampler.__len__ is not implemented")


class SequentialSampler(Sampler):
    def __init__(self, dataset):
        self.dataset = dataset

    def __iter__(self):
        return iter(range(len(self.dataset)))

    def __len__(self) -> int:
        return len(self.dataset)


class RandomSampler(Sampler):
    def __init__(self, dataset, replacement: bool = False, num_samples: int | None = None, seed: int | None = None):
        self.dataset = dataset
        self.replacement = bool(replacement)
        self.num_samples = num_samples
        self.seed = seed

        if self.replacement and self.num_samples is None:
            raise ValueError("num_samples must be specified when replacement=True")

    def __len__(self) -> int:
        if self.replacement:
            return int(self.num_samples)
        return len(self.dataset)

    def __iter__(self):
        n = len(self.dataset)
        rng = np.random.default_rng(self.seed)
        if self.replacement:
            for _ in range(self.num_samples):
                yield int(rng.integers(0, n))
        else:
            indices = rng.permutation(n)
            for idx in indices:
                yield int(idx)


class BatchSampler(Sampler):
    def __init__(self, sampler: Sampler, batch_size: int, drop_last: bool):
        if batch_size <= 0:
            raise ValueError("batch_size must be > 0")
        self.sampler = sampler
        self.batch_size = int(batch_size)
        self.drop_last = bool(drop_last)

    def __iter__(self):
        batch = []
        for idx in self.sampler:
            batch.append(idx)
            if len(batch) == self.batch_size:
                yield batch
                batch = []
        if batch and not self.drop_last:
            yield batch

    def __len__(self) -> int:
        if not hasattr(self.sampler, "__len__"):
            raise TypeError("sampler has no length")
        if self.drop_last:
            return len(self.sampler) // self.batch_size
        return math.ceil(len(self.sampler) / self.batch_size)

