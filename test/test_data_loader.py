import numpy as np

from neurx.data import DataLoader, TensorDataset


class ToyDataset:
    def __init__(self, n):
        self.n = n

    def __len__(self):
        return self.n

    def __getitem__(self, index):
        return index


def test_dataloader_basic_batching():
    dataset = ToyDataset(10)
    loader = DataLoader(dataset, batch_size=4, shuffle=False, drop_last=False)
    batches = list(loader)
    assert len(batches) == 3
    assert np.array_equal(batches[0], np.array([0, 1, 2, 3]))
    assert np.array_equal(batches[1], np.array([4, 5, 6, 7]))
    assert np.array_equal(batches[2], np.array([8, 9]))


def test_dataloader_deterministic_shuffle():
    dataset = ToyDataset(9)
    loader1 = DataLoader(dataset, batch_size=3, shuffle=True, seed=123)
    loader2 = DataLoader(dataset, batch_size=3, shuffle=True, seed=123)
    order1 = np.concatenate(list(loader1))
    order2 = np.concatenate(list(loader2))
    assert np.array_equal(order1, order2)
    assert set(order1.tolist()) == set(range(9))


def test_tensor_dataset():
    x = np.arange(12).reshape(6, 2)
    y = np.arange(6)
    ds = TensorDataset(x, y)
    loader = DataLoader(ds, batch_size=2, shuffle=False)
    x_batch, y_batch = next(iter(loader))
    assert x_batch.shape == (2, 2)
    assert y_batch.shape == (2,)
    assert np.array_equal(x_batch, x[:2])
    assert np.array_equal(y_batch, y[:2])

