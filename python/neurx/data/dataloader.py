from __future__ import annotations

import random
import numpy as np

from neurx.core import Tensor


def default_collate(batch):
    if not batch:
        return batch
    first = batch[0]
    if isinstance(first, Tensor):
        return Tensor(np.stack([item.data for item in batch], axis=0), requires_grad=first.requires_grad, device=first.device)
    if isinstance(first, (tuple, list)):
        transposed = list(zip(*batch))
        return type(first)(default_collate(list(items)) for items in transposed)
    return batch


class Sampler:
    def __iter__(self):
        raise NotImplementedError

    def __len__(self):
        raise NotImplementedError


class SequentialSampler(Sampler):
    def __init__(self, data_source):
        self.data_source = data_source

    def __iter__(self):
        return iter(range(len(self.data_source)))

    def __len__(self):
        return len(self.data_source)


class RandomSampler(Sampler):
    def __init__(self, data_source, seed=None):
        self.data_source = data_source
        self.seed = seed

    def __iter__(self):
        indices = list(range(len(self.data_source)))
        rng = random.Random(self.seed)
        rng.shuffle(indices)
        return iter(indices)

    def __len__(self):
        return len(self.data_source)


class BatchSampler(Sampler):
    def __init__(self, sampler, batch_size, drop_last=False):
        self.sampler = sampler
        self.batch_size = int(batch_size)
        self.drop_last = bool(drop_last)

    def __iter__(self):
        batch = []
        for index in self.sampler:
            batch.append(index)
            if len(batch) == self.batch_size:
                yield batch
                batch = []
        if batch and not self.drop_last:
            yield batch

    def __len__(self):
        n = len(self.sampler)
        if self.drop_last:
            return n // self.batch_size
        return (n + self.batch_size - 1) // self.batch_size


class DataLoader:
    def __init__(self, dataset, batch_size=1, shuffle=False, sampler=None, batch_sampler=None, drop_last=False, collate_fn=None):
        self.dataset = dataset
        self.batch_size = int(batch_size)
        self.shuffle = bool(shuffle)
        self.sampler = sampler
        self.batch_sampler = batch_sampler
        self.drop_last = bool(drop_last)
        self.collate_fn = collate_fn or default_collate

    def __iter__(self):
        if self.batch_sampler is not None:
            for batch_indices in self.batch_sampler:
                yield self.collate_fn([self.dataset[i] for i in batch_indices])
            return
        if self.sampler is not None:
            indices = list(iter(self.sampler))
        elif self.shuffle:
            indices = list(range(len(self.dataset)))
            random.shuffle(indices)
        else:
            indices = list(range(len(self.dataset)))
        batch = []
        for index in indices:
            batch.append(self.dataset[index])
            if len(batch) == self.batch_size:
                yield self.collate_fn(batch)
                batch = []
        if batch and not self.drop_last:
            yield self.collate_fn(batch)

    def __len__(self):
        if self.batch_sampler is not None:
            return len(self.batch_sampler)
        n = len(self.dataset)
        if self.drop_last:
            return n // self.batch_size
        return (n + self.batch_size - 1) // self.batch_size
