import numpy as np
import pytest

from neurx.data import ConcatDataset, Subset, TensorDataset, random_split


def test_concat_dataset_supports_negative_index():
    ds = ConcatDataset([TensorDataset(np.array([1, 2]), np.array([10, 20])), TensorDataset(np.array([3]), np.array([30]))])
    assert ds[-1] == (3, 30)
    assert ds[-3] == (1, 10)


def test_random_split_rejects_mismatched_lengths():
    ds = TensorDataset(np.array([1, 2, 3]), np.array([10, 20, 30]))
    with pytest.raises(ValueError):
        random_split(ds, [1, 1], seed=123)


def test_subset_and_tensor_dataset_support_negative_index():
    ds = TensorDataset(np.array([1, 2, 3]), np.array([10, 20, 30]))
    subset = Subset(ds, [2, 0, 1])
    assert ds[-1] == (3, 30)
    assert subset[-1] == (2, 20)


def test_subset_negative_inner_index_uses_base_dataset():
    ds = TensorDataset(np.array([1, 2, 3]), np.array([10, 20, 30]))
    subset = Subset(ds, [0, -1, 1])
    assert subset[1] == (3, 30)
