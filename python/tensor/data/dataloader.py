from __future__ import annotations

import math
from collections.abc import Iterable

import numpy as np

from tensor.tensor import Tensor


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
        collate_fn=None,
        seed: int | None = None,
    ):
        if batch_size <= 0:
            raise ValueError("batch_size must be > 0")
        self.dataset = dataset
        self.batch_size = int(batch_size)
        self.shuffle = bool(shuffle)
        self.drop_last = bool(drop_last)
        self.collate_fn = collate_fn or default_collate
        self.seed = seed
        self._epoch = 0

    def __len__(self) -> int:
        n = len(self.dataset)
        if self.drop_last:
            return n // self.batch_size
        return math.ceil(n / self.batch_size)

    def _indices(self):
        n = len(self.dataset)
        indices = np.arange(n)
        if self.shuffle:
            if self.seed is None:
                np.random.shuffle(indices)
            else:
                rng = np.random.default_rng(self.seed + self._epoch)
                rng.shuffle(indices)
        return indices.tolist()

    def __iter__(self):
        self._epoch += 1
        indices = self._indices()
        n = len(indices)
        for start in range(0, n, self.batch_size):
            end = min(start + self.batch_size, n)
            if self.drop_last and (end - start) < self.batch_size:
                continue
            batch = [self.dataset[idx] for idx in indices[start:end]]
            yield self.collate_fn(batch)

