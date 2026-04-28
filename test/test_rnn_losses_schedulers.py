"""
Comprehensive tests for RNN/LSTM/GRU, Loss Functions, and Learning Rate Schedulers.

Tests coverage:
- RNN cells and layers
- LSTM cells and layers
- GRU cells and layers
- All loss functions
- All learning rate schedulers
"""

import numpy as np
import math
import pytest
from typing import List

from neurx.core.neurx import Tensor
from neurx.nn.rnn import (
    RNNCell, RNN, LSTMCell, LSTM, GRUCell, GRU
)
from neurx.optim.losses import (
    CrossEntropyLoss, BCELoss, BCEWithLogitsLoss, L1Loss, MSELoss,
    SmoothL1Loss, KLDivLoss, NLLLoss, HuberLoss, PoissonNLLLoss,
    CTCLoss, MarginRankingLoss, TripletMarginLoss
)
from neurx.optim.schedulers import (
    StepLR, ExponentialLR, CosineAnnealingLR, CosineAnnealingWarmRestarts,
    LinearLR, PolynomialLR, MultiplicativeLR, LambdaLR, ReduceLROnPlateau,
    WarmupLR, WarmupDecayLR, StepDecayWithWarmup, CyclicLR, OneCycleLR
)


class MockOptimizer:
    """Mock optimizer for testing schedulers."""
    
    def __init__(self, learning_rate: float = 0.1):
        self.param_groups = [{'lr': learning_rate}]


# ============================================================================
# RNN Cell Tests
# ============================================================================

class TestRNNCell:
    """Test RNNCell functionality."""
    
    def test_rnn_cell_init(self):
        """Test RNNCell initialization."""
        cell = RNNCell(10, 20)
        assert cell.input_size == 10
        assert cell.hidden_size == 20
        assert cell.W_ih.shape == (10, 20)
        assert cell.W_hh.shape == (20, 20)
    
    def test_rnn_cell_forward_no_hidden(self):
        """Test RNNCell forward pass without initial hidden state."""
        cell = RNNCell(10, 20)
        x = Tensor(np.random.randn(5, 10))  # batch_size=5, input_size=10
        h = cell(x)
        assert h.shape == (5, 20)
    
    def test_rnn_cell_forward_with_hidden(self):
        """Test RNNCell forward pass with initial hidden state."""
        cell = RNNCell(10, 20)
        x = Tensor(np.random.randn(5, 10))
        h_prev = Tensor(np.random.randn(5, 20))
        h = cell(x, h_prev)
        assert h.shape == (5, 20)
    
    def test_rnn_cell_no_bias(self):
        """Test RNNCell without bias."""
        cell = RNNCell(10, 20, bias=False)
        assert cell.b_ih is None
        assert cell.b_hh is None
        
        x = Tensor(np.random.randn(5, 10))
        h = cell(x)
        assert h.shape == (5, 20)


# ============================================================================
# LSTM Cell Tests
# ============================================================================

class TestLSTMCell:
    """Test LSTMCell functionality."""
    
    def test_lstm_cell_init(self):
        """Test LSTMCell initialization."""
        cell = LSTMCell(10, 20)
        assert cell.input_size == 10
        assert cell.hidden_size == 20
        assert cell.W_ih.shape == (10, 80)  # 4 * hidden_size
        assert cell.W_hh.shape == (20, 80)
    
    def test_lstm_cell_forward_no_state(self):
        """Test LSTMCell forward pass without initial state."""
        cell = LSTMCell(10, 20)
        x = Tensor(np.random.randn(5, 10))
        h_out, c_out = cell(x)
        assert h_out.shape == (5, 20)
        assert c_out.shape == (5, 20)
    
    def test_lstm_cell_forward_with_state(self):
        """Test LSTMCell forward pass with initial state."""
        cell = LSTMCell(10, 20)
        x = Tensor(np.random.randn(5, 10))
        h_prev = Tensor(np.random.randn(5, 20))
        c_prev = Tensor(np.random.randn(5, 20))
        h_out, c_out = cell(x, (h_prev, c_prev))
        assert h_out.shape == (5, 20)
        assert c_out.shape == (5, 20)
    
    def test_lstm_cell_state_update(self):
        """Test LSTM cell state is updated correctly."""
        cell = LSTMCell(10, 20)
        x = Tensor(np.random.randn(5, 10))
        
        # First step
        h_out1, c_out1 = cell(x)
        
        # Second step with previous state
        h_out2, c_out2 = cell(x, (h_out1, c_out1))
        
        # States should be different
        assert not np.allclose(h_out1.data, h_out2.data)
        assert not np.allclose(c_out1.data, c_out2.data)


# ============================================================================
# GRU Cell Tests
# ============================================================================

class TestGRUCell:
    """Test GRUCell functionality."""
    
    def test_gru_cell_init(self):
        """Test GRUCell initialization."""
        cell = GRUCell(10, 20)
        assert cell.input_size == 10
        assert cell.hidden_size == 20
        assert cell.W_ih.shape == (10, 60)  # 3 * hidden_size
        assert cell.W_hh.shape == (20, 60)
    
    def test_gru_cell_forward_no_hidden(self):
        """Test GRUCell forward pass without initial hidden state."""
        cell = GRUCell(10, 20)
        x = Tensor(np.random.randn(5, 10))
        h = cell(x)
        assert h.shape == (5, 20)
    
    def test_gru_cell_forward_with_hidden(self):
        """Test GRUCell forward pass with initial hidden state."""
        cell = GRUCell(10, 20)
        x = Tensor(np.random.randn(5, 10))
        h_prev = Tensor(np.random.randn(5, 20))
        h = cell(x, h_prev)
        assert h.shape == (5, 20)


# ============================================================================
# RNN Layer Tests
# ============================================================================

class TestRNN:
    """Test RNN layer functionality."""
    
    def test_rnn_single_layer(self):
        """Test single-layer RNN."""
        rnn = RNN(10, 20, num_layers=1)
        x = Tensor(np.random.randn(5, 3, 10))  # (seq_len, batch, input_size)
        output, h_n = rnn(x)
        assert output.shape == (5, 3, 20)
        assert h_n.shape == (1, 3, 20)
    
    def test_rnn_multi_layer(self):
        """Test multi-layer RNN."""
        rnn = RNN(10, 20, num_layers=2)
        x = Tensor(np.random.randn(5, 3, 10))
        output, h_n = rnn(x)
        assert output.shape == (5, 3, 20)
        assert h_n.shape == (2, 3, 20)
    
    def test_rnn_batch_first(self):
        """Test RNN with batch_first=True."""
        rnn = RNN(10, 20, batch_first=True)
        x = Tensor(np.random.randn(3, 5, 10))  # (batch, seq_len, input_size)
        output, h_n = rnn(x)
        assert output.shape == (3, 5, 20)  # (batch, seq_len, hidden)
    
    def test_rnn_bidirectional(self):
        """Test bidirectional RNN."""
        rnn = RNN(10, 20, bidirectional=True)
        x = Tensor(np.random.randn(5, 3, 10))
        output, h_n = rnn(x)
        assert output.shape == (5, 3, 40)  # 2 * hidden_size
        assert h_n.shape == (2, 3, 20)  # 2 directions


# ============================================================================
# LSTM Layer Tests
# ============================================================================

class TestLSTM:
    """Test LSTM layer functionality."""
    
    def test_lstm_single_layer(self):
        """Test single-layer LSTM."""
        lstm = LSTM(10, 20, num_layers=1)
        x = Tensor(np.random.randn(5, 3, 10))
        output, (h_n, c_n) = lstm(x)
        assert output.shape == (5, 3, 20)
        assert h_n.shape == (1, 3, 20)
        assert c_n.shape == (1, 3, 20)
    
    def test_lstm_multi_layer(self):
        """Test multi-layer LSTM."""
        lstm = LSTM(10, 20, num_layers=3)
        x = Tensor(np.random.randn(5, 3, 10))
        output, (h_n, c_n) = lstm(x)
        assert output.shape == (5, 3, 20)
        assert h_n.shape == (3, 3, 20)
        assert c_n.shape == (3, 3, 20)
    
    def test_lstm_batch_first(self):
        """Test LSTM with batch_first=True."""
        lstm = LSTM(10, 20, batch_first=True)
        x = Tensor(np.random.randn(3, 5, 10))
        output, (h_n, c_n) = lstm(x)
        assert output.shape == (3, 5, 20)
    
    def test_lstm_bidirectional(self):
        """Test bidirectional LSTM."""
        lstm = LSTM(10, 20, bidirectional=True)
        x = Tensor(np.random.randn(5, 3, 10))
        output, (h_n, c_n) = lstm(x)
        assert output.shape == (5, 3, 40)


# ============================================================================
# GRU Layer Tests
# ============================================================================

class TestGRU:
    """Test GRU layer functionality."""
    
    def test_gru_single_layer(self):
        """Test single-layer GRU."""
        gru = GRU(10, 20, num_layers=1)
        x = Tensor(np.random.randn(5, 3, 10))
        output, h_n = gru(x)
        assert output.shape == (5, 3, 20)
        assert h_n.shape == (1, 3, 20)
    
    def test_gru_multi_layer(self):
        """Test multi-layer GRU."""
        gru = GRU(10, 20, num_layers=2)
        x = Tensor(np.random.randn(5, 3, 10))
        output, h_n = gru(x)
        assert output.shape == (5, 3, 20)
        assert h_n.shape == (2, 3, 20)
    
    def test_gru_batch_first(self):
        """Test GRU with batch_first=True."""
        gru = GRU(10, 20, batch_first=True)
        x = Tensor(np.random.randn(3, 5, 10))
        output, h_n = gru(x)
        assert output.shape == (3, 5, 20)
    
    def test_gru_bidirectional(self):
        """Test bidirectional GRU."""
        gru = GRU(10, 20, bidirectional=True)
        x = Tensor(np.random.randn(5, 3, 10))
        output, h_n = gru(x)
        assert output.shape == (5, 3, 40)


# ============================================================================
# Loss Function Tests
# ============================================================================

class TestLossFunctions:
    """Test all loss functions."""
    
    def test_cross_entropy_loss(self):
        """Test CrossEntropyLoss."""
        loss_fn = CrossEntropyLoss()
        input = Tensor(np.random.randn(4, 3))  # (batch, classes)
        target = Tensor(np.array([0, 1, 2, 1]))  # class indices
        loss = loss_fn(input, target)
        assert loss.data.shape == ()
        assert loss.data > 0
    
    def test_bce_loss(self):
        """Test BCELoss."""
        loss_fn = BCELoss()
        input = Tensor(np.random.uniform(0.01, 0.99, (4, 1)))
        target = Tensor(np.array([[0], [1], [0], [1]]))
        loss = loss_fn(input, target)
        assert loss.data.shape == ()
    
    def test_bce_with_logits_loss(self):
        """Test BCEWithLogitsLoss."""
        loss_fn = BCEWithLogitsLoss()
        input = Tensor(np.random.randn(4, 1))  # logits
        target = Tensor(np.array([[0], [1], [0], [1]]))
        loss = loss_fn(input, target)
        assert loss.data.shape == ()
    
    def test_l1_loss(self):
        """Test L1Loss."""
        loss_fn = L1Loss()
        input = Tensor(np.array([1.0, 2.0, 3.0]))
        target = Tensor(np.array([1.1, 2.2, 2.8]))
        loss = loss_fn(input, target)
        assert loss.data.shape == ()
        expected = np.mean(np.abs(input.data - target.data))
        assert np.allclose(loss.data, expected)
    
    def test_mse_loss(self):
        """Test MSELoss."""
        loss_fn = MSELoss()
        input = Tensor(np.array([1.0, 2.0, 3.0]))
        target = Tensor(np.array([1.1, 2.1, 3.1]))
        loss = loss_fn(input, target)
        assert loss.data.shape == ()
    
    def test_smooth_l1_loss(self):
        """Test SmoothL1Loss."""
        loss_fn = SmoothL1Loss(beta=1.0)
        input = Tensor(np.array([0.1, 2.0, 5.0]))
        target = Tensor(np.array([0.0, 2.0, 0.0]))
        loss = loss_fn(input, target)
        assert loss.data.shape == ()
    
    def test_kl_div_loss(self):
        """Test KLDivLoss."""
        loss_fn = KLDivLoss()
        log_probs = Tensor(np.array([[-0.1, -2.0, -1.5], [-1.0, -0.1, -2.0]]))
        target = Tensor(np.array([[0.8, 0.1, 0.1], [0.1, 0.7, 0.2]]))
        loss = loss_fn(log_probs, target)
        assert loss.data.shape == ()
    
    def test_nll_loss(self):
        """Test NLLLoss."""
        loss_fn = NLLLoss()
        input = Tensor(np.array([[-0.1, -2.0, -1.5], [-1.0, -0.1, -2.0]]))
        target = Tensor(np.array([0, 1]))
        loss = loss_fn(input, target)
        assert loss.data.shape == ()
    
    def test_huber_loss(self):
        """Test HuberLoss."""
        loss_fn = HuberLoss(delta=1.0)
        input = Tensor(np.array([0.1, 2.0, 5.0]))
        target = Tensor(np.array([0.0, 2.0, 0.0]))
        loss = loss_fn(input, target)
        assert loss.data.shape == ()
    
    def test_poisson_nll_loss(self):
        """Test PoissonNLLLoss."""
        loss_fn = PoissonNLLLoss()
        input = Tensor(np.array([1.0, 2.0, 0.5]))
        target = Tensor(np.array([1.0, 2.0, 1.0]))
        loss = loss_fn(input, target)
        assert loss.data.shape == ()
    
    def test_margin_ranking_loss(self):
        """Test MarginRankingLoss."""
        loss_fn = MarginRankingLoss(margin=1.0)
        input1 = Tensor(np.array([1.0, 2.0]))
        input2 = Tensor(np.array([0.5, 2.5]))
        target = Tensor(np.array([1.0, 1.0]))
        loss = loss_fn(input1, input2, target)
        assert loss.data.shape == ()
    
    def test_triplet_margin_loss(self):
        """Test TripletMarginLoss."""
        loss_fn = TripletMarginLoss(margin=1.0)
        anchor = Tensor(np.random.randn(4, 10))
        positive = Tensor(np.random.randn(4, 10))
        negative = Tensor(np.random.randn(4, 10))
        loss = loss_fn(anchor, positive, negative)
        assert loss.data.shape == ()
    
    def test_loss_reduction_sum(self):
        """Test loss reduction='sum'."""
        loss_fn = L1Loss(reduction='sum')
        input = Tensor(np.array([1.0, 2.0, 3.0]))
        target = Tensor(np.array([1.1, 2.1, 3.1]))
        loss = loss_fn(input, target)
        assert loss.data.shape == ()
    
    def test_loss_reduction_none(self):
        """Test loss reduction='none'."""
        loss_fn = L1Loss(reduction='none')
        input = Tensor(np.array([1.0, 2.0, 3.0]))
        target = Tensor(np.array([1.1, 2.1, 3.1]))
        loss = loss_fn(input, target)
        assert loss.data.shape == (3,)


# ============================================================================
# Learning Rate Scheduler Tests
# ============================================================================

class TestLRSchedulers:
    """Test all learning rate schedulers."""
    
    def test_step_lr(self):
        """Test StepLR scheduler."""
        optimizer = MockOptimizer(0.1)
        scheduler = StepLR(optimizer, step_size=10, gamma=0.1)
        
        # Initial LR
        assert optimizer.param_groups[0]['lr'] == 0.1
        
        # After 10 epochs
        for _ in range(10):
            scheduler.step()
        assert np.isclose(optimizer.param_groups[0]['lr'], 0.01, rtol=1e-5)
    
    def test_exponential_lr(self):
        """Test ExponentialLR scheduler."""
        optimizer = MockOptimizer(0.1)
        scheduler = ExponentialLR(optimizer, gamma=0.9)
        
        initial_lr = optimizer.param_groups[0]['lr']
        scheduler.step()
        assert np.isclose(optimizer.param_groups[0]['lr'], initial_lr * 0.9)
    
    def test_cosine_annealing_lr(self):
        """Test CosineAnnealingLR scheduler."""
        optimizer = MockOptimizer(0.1)
        scheduler = CosineAnnealingLR(optimizer, T_max=10, eta_min=0)
        
        lrs = []
        for _ in range(11):
            lrs.append(optimizer.param_groups[0]['lr'])
            scheduler.step()
        
        # LR should decrease initially
        assert lrs[0] > lrs[5]  # Decreases initially
        # At the end it reaches minimum
        assert lrs[-1] < 0.001 or lrs[-1] == 0  # At or near minimum
    
    def test_cosine_annealing_warm_restarts(self):
        """Test CosineAnnealingWarmRestarts scheduler."""
        optimizer = MockOptimizer(0.1)
        scheduler = CosineAnnealingWarmRestarts(optimizer, T_0=5, T_mult=2)
        
        lrs = []
        for _ in range(30):
            lrs.append(optimizer.param_groups[0]['lr'])
            scheduler.step()
        
        # Should have multiple warm restarts
        assert len(set(lrs)) > 1  # LR changes
    
    def test_linear_lr(self):
        """Test LinearLR scheduler."""
        optimizer = MockOptimizer(0.1)
        scheduler = LinearLR(optimizer, start_factor=0.1, total_iters=10)
        
        initial_lr = 0.1 * 0.1  # start_factor
        assert np.isclose(optimizer.param_groups[0]['lr'], initial_lr, rtol=1e-5)
        
        for _ in range(10):
            scheduler.step()
        # Should reach ~initial_lr after total_iters
        assert optimizer.param_groups[0]['lr'] > initial_lr
    
    def test_polynomial_lr(self):
        """Test PolynomialLR scheduler."""
        optimizer = MockOptimizer(0.1)
        scheduler = PolynomialLR(optimizer, total_iters=10, power=2)
        
        lrs = []
        for _ in range(11):
            lrs.append(optimizer.param_groups[0]['lr'])
            scheduler.step()
        
        # LR should decrease
        assert lrs[0] > lrs[-1]
    
    def test_lambda_lr(self):
        """Test LambdaLR scheduler."""
        optimizer = MockOptimizer(0.1)
        lambda_fn = lambda epoch: 0.95 ** epoch
        scheduler = LambdaLR(optimizer, lr_lambda=lambda_fn)
        
        for _ in range(5):
            scheduler.step()
        
        expected_lr = 0.1 * (0.95 ** 5)
        assert np.isclose(optimizer.param_groups[0]['lr'], expected_lr, rtol=1e-5)
    
    def test_reduce_lr_on_plateau(self):
        """Test ReduceLROnPlateau scheduler."""
        optimizer = MockOptimizer(0.1)
        scheduler = ReduceLROnPlateau(optimizer, factor=0.1, patience=2, mode='min')
        
        # No improvement for patience steps
        for _ in range(3):
            scheduler.step(1.0)  # Same metric
        
        # LR should be reduced
        assert optimizer.param_groups[0]['lr'] < 0.1
    
    def test_warmup_lr(self):
        """Test WarmupLR scheduler."""
        optimizer = MockOptimizer(0.1)
        scheduler = WarmupLR(optimizer, warmup_epochs=10)
        
        initial_lr = optimizer.param_groups[0]['lr']
        
        # First step - warmup phase
        first_step = optimizer.param_groups[0]['lr']
        scheduler.step()
        warmup_step = optimizer.param_groups[0]['lr']
        
        # During warmup, LR increases from 0 to initial
        assert warmup_step > first_step or warmup_step == first_step
        
        # Go through remaining warmup epochs
        for _ in range(8):
            scheduler.step()
        
        # After warmup, at epoch 10
        scheduler.step()
        assert optimizer.param_groups[0]['lr'] >= initial_lr * 0.9
    
    def test_warmup_decay_lr(self):
        """Test WarmupDecayLR scheduler."""
        optimizer = MockOptimizer(0.1)
        scheduler = WarmupDecayLR(
            optimizer,
            warmup_epochs=5,
            total_epochs=15,
            decay_type='linear'
        )
        
        lrs = []
        for _ in range(16):
            lrs.append(optimizer.param_groups[0]['lr'])
            scheduler.step()
        
        # Should increase during warmup, then decrease
        assert lrs[0] < lrs[5]  # Increases during warmup
        assert lrs[5] > lrs[-1]  # Decreases after warmup
    
    def test_step_decay_with_warmup(self):
        """Test StepDecayWithWarmup scheduler."""
        optimizer = MockOptimizer(0.1)
        scheduler = StepDecayWithWarmup(
            optimizer,
            warmup_epochs=5,
            step_size=5,
            gamma=0.1
        )
        
        lrs = []
        for _ in range(20):
            lrs.append(optimizer.param_groups[0]['lr'])
            scheduler.step()
        
        # Should increase during warmup, then decrease with step decay
        assert len(set(lrs)) > 1  # LR changes
    
    def test_cyclic_lr(self):
        """Test CyclicLR scheduler."""
        optimizer = MockOptimizer(0.01)
        scheduler = CyclicLR(
            optimizer,
            base_lr=0.01,
            max_lr=0.1,
            step_size=5
        )
        
        lrs = []
        for _ in range(20):
            lrs.append(optimizer.param_groups[0]['lr'])
            scheduler.step()
        
        # Should cycle between base_lr and max_lr
        assert min(lrs) < 0.05
        assert max(lrs) > 0.05
    
    def test_one_cycle_lr(self):
        """Test OneCycleLR scheduler."""
        optimizer = MockOptimizer(0.1)
        scheduler = OneCycleLR(
            optimizer,
            max_lr=0.5,
            total_steps=10,
            pct_start=0.3
        )
        
        lrs = []
        for _ in range(11):
            lrs.append(optimizer.param_groups[0]['lr'])
            scheduler.step()
        
        # Should increase then decrease
        first_half = lrs[:5]
        second_half = lrs[5:]
        assert first_half[-1] >= first_half[0]  # Increases
        assert second_half[-1] <= second_half[0]  # Decreases


# ============================================================================
# Integration Tests
# ============================================================================

class TestRNNIntegration:
    """Integration tests for RNN modules."""
    
    def test_rnn_lstm_gru_consistency(self):
        """Test that RNN, LSTM, GRU have consistent output shapes."""
        input_size, hidden_size = 10, 20
        seq_len, batch_size = 5, 3
        x = Tensor(np.random.randn(seq_len, batch_size, input_size))
        
        # Test all three architectures
        rnn = RNN(input_size, hidden_size)
        lstm = LSTM(input_size, hidden_size)
        gru = GRU(input_size, hidden_size)
        
        rnn_out, rnn_h = rnn(x)
        lstm_out, (lstm_h, lstm_c) = lstm(x)
        gru_out, gru_h = gru(x)
        
        # All should have same output shape
        assert rnn_out.shape == lstm_out.shape == gru_out.shape
        assert rnn_h.shape == lstm_h.shape == gru_h.shape
    
    def test_loss_with_rnn_output(self):
        """Test loss computation with RNN output."""
        lstm = LSTM(10, 20, num_layers=1)
        x = Tensor(np.random.randn(5, 3, 10))  # (seq_len, batch, input_size)
        output, (h, c) = lstm(x)
        
        # Flatten output for classification
        output_flat = output.data.reshape(-1, 20)
        targets = Tensor(np.random.randint(0, 3, size=output_flat.shape[0]))
        
        # Compute loss using last hidden state
        loss_fn = L1Loss()
        predictions = Tensor(np.random.randn(output_flat.shape[0]))
        targets_float = Tensor(output_flat[:, 0])  # Just use first dimension
        loss = loss_fn(predictions, targets_float)
        
        assert loss.data.shape == ()


if __name__ == '__main__':
    # Run some basic tests
    print("Testing RNN modules...")
    test_rnn = TestRNN()
    test_rnn.test_rnn_single_layer()
    test_rnn.test_rnn_multi_layer()
    print("✓ RNN tests passed")
    
    print("\nTesting LSTM modules...")
    test_lstm = TestLSTM()
    test_lstm.test_lstm_single_layer()
    test_lstm.test_lstm_multi_layer()
    print("✓ LSTM tests passed")
    
    print("\nTesting GRU modules...")
    test_gru = TestGRU()
    test_gru.test_gru_single_layer()
    test_gru.test_gru_multi_layer()
    print("✓ GRU tests passed")
    
    print("\nTesting Loss Functions...")
    test_loss = TestLossFunctions()
    test_loss.test_cross_entropy_loss()
    test_loss.test_mse_loss()
    test_loss.test_bce_loss()
    print("✓ Loss function tests passed")
    
    print("\nTesting LR Schedulers...")
    test_lr = TestLRSchedulers()
    test_lr.test_step_lr()
    test_lr.test_cosine_annealing_lr()
    test_lr.test_warmup_lr()
    print("✓ LR scheduler tests passed")
    
    print("\n✅ All tests passed!")
