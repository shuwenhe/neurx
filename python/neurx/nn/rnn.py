"""
Recurrent Neural Network layers (RNN, LSTM, GRU).

This module provides implementations of:
- RNNCell and RNN (basic recurrent cells and layers)
- LSTMCell and LSTM (long short-term memory)
- GRUCell and GRU (gated recurrent unit)

All support bidirectional processing and multiple layers.
"""

import numpy as np
import math
from typing import Optional, Tuple, List

from neurx.core.neurx import Tensor
from neurx.nn.modules import Module


class RNNCell(Module):
    """
    Basic RNN Cell.
    
    h_{t} = tanh(W_{ih} * x_t + b_{ih} + W_{hh} * h_{t-1} + b_{hh})
    
    Args:
        input_size (int): Size of input features
        hidden_size (int): Size of hidden state
        bias (bool): Whether to use bias. Default: True
    """
    
    def __init__(self, input_size: int, hidden_size: int, bias: bool = True):
        super().__init__()
        self.input_size = input_size
        self.hidden_size = hidden_size
        self.bias = bias
        
        # Input-hidden weights
        self.W_ih = np.random.randn(input_size, hidden_size) / math.sqrt(input_size)
        self.W_hh = np.random.randn(hidden_size, hidden_size) / math.sqrt(hidden_size)
        
        self.W_ih = Tensor(self.W_ih, requires_grad=True)
        self.W_hh = Tensor(self.W_hh, requires_grad=True)
        
        # Add aliases for compatibility
        self.weight_ih = self.W_ih
        self.weight_hh = self.W_hh
        
        if bias:
            self.b_ih = Tensor(np.zeros(hidden_size), requires_grad=True)
            self.b_hh = Tensor(np.zeros(hidden_size), requires_grad=True)
        else:
            self.b_ih = None
            self.b_hh = None
    
    def forward(self, x: Tensor, h_prev: Optional[Tensor] = None) -> Tensor:
        """
        Apply RNN cell.
        
        Args:
            x (Tensor): Input of shape (batch_size, input_size) or (input_size,)
            h_prev (Optional[Tensor]): Previous hidden state of shape (batch_size, hidden_size) or (hidden_size,)
        
        Returns:
            Tensor: Hidden state of shape (batch_size, hidden_size) or (hidden_size,)
        """
        # Handle unbatched input
        unbatched = False
        if x.ndim == 1:
            unbatched = True
            x = Tensor(x.data[np.newaxis, :], requires_grad=x.requires_grad)
            if h_prev is not None:
                h_prev = Tensor(h_prev.data[np.newaxis, :], requires_grad=h_prev.requires_grad)
        
        batch_size = x.shape[0]
        
        # Initialize hidden state if not provided
        if h_prev is None:
            h_prev = np.zeros((batch_size, self.hidden_size))
            h_prev = Tensor(h_prev, requires_grad=True)
        
        # Compute new hidden state
        gi = np.matmul(x.data, self.W_ih.data)
        gh = np.matmul(h_prev.data, self.W_hh.data)
        
        if self.bias:
            gi = gi + self.b_ih.data
            gh = gh + self.b_hh.data
        
        h = np.tanh(gi + gh)
        h = Tensor(h, requires_grad=True)
        
        # Remove batch dimension if input was unbatched
        if unbatched:
            h = Tensor(h.data[0], requires_grad=True)
        
        return h


class LSTMCell(Module):
    """
    LSTM Cell.
    
    Implements the LSTM cell equations with input, forget, cell, and output gates.
    
    Args:
        input_size (int): Size of input features
        hidden_size (int): Size of hidden state and cell state
        bias (bool): Whether to use bias. Default: True
    """
    
    def __init__(self, input_size: int, hidden_size: int, bias: bool = True):
        super().__init__()
        self.input_size = input_size
        self.hidden_size = hidden_size
        self.bias = bias
        
        # Gates: input, forget, cell, output (4 * hidden_size total)
        self.W_ih = np.random.randn(input_size, 4 * hidden_size) / math.sqrt(input_size)
        self.W_hh = np.random.randn(hidden_size, 4 * hidden_size) / math.sqrt(hidden_size)
        
        self.W_ih = Tensor(self.W_ih, requires_grad=True)
        self.W_hh = Tensor(self.W_hh, requires_grad=True)
        
        # Add aliases for compatibility
        self.weight_ih = self.W_ih
        self.weight_hh = self.W_hh
        
        if bias:
            self.b_ih = Tensor(np.zeros(4 * hidden_size), requires_grad=True)
            self.b_hh = Tensor(np.zeros(4 * hidden_size), requires_grad=True)
        else:
            self.b_ih = None
            self.b_hh = None
    
    def forward(
        self,
        x: Tensor,
        state: Optional[Tuple[Tensor, Tensor]] = None
    ) -> Tuple[Tensor, Tensor]:
        """
        Apply LSTM cell.
        
        Args:
            x (Tensor): Input of shape (batch_size, input_size)
            state (Optional[Tuple]): Tuple of (h, c) where:
                - h: hidden state of shape (batch_size, hidden_size)
                - c: cell state of shape (batch_size, hidden_size)
        
        Returns:
            Tuple[Tensor, Tensor]: (h_new, c_new)
        """
        batch_size = x.shape[0]
        
        # Initialize state if not provided
        if state is None:
            h = np.zeros((batch_size, self.hidden_size))
            c = np.zeros((batch_size, self.hidden_size))
            h = Tensor(h, requires_grad=True)
            c = Tensor(c, requires_grad=True)
        else:
            h, c = state
        
        # Compute gates
        gi = np.matmul(x.data, self.W_ih.data)
        gh = np.matmul(h.data, self.W_hh.data)
        
        if self.bias:
            gates = gi + gh + self.b_ih.data + self.b_hh.data
        else:
            gates = gi + gh
        
        # Split into 4 gates
        i_t = gates[:, :self.hidden_size]  # input gate
        f_t = gates[:, self.hidden_size:2*self.hidden_size]  # forget gate
        g_t = gates[:, 2*self.hidden_size:3*self.hidden_size]  # cell gate
        o_t = gates[:, 3*self.hidden_size:]  # output gate
        
        # Apply activations
        i_t = 1 / (1 + np.exp(-i_t))  # sigmoid
        f_t = 1 / (1 + np.exp(-f_t))  # sigmoid
        g_t = np.tanh(g_t)  # tanh
        o_t = 1 / (1 + np.exp(-o_t))  # sigmoid
        
        # Update cell state
        c_new = f_t * c.data + i_t * g_t
        c_new = Tensor(c_new, requires_grad=True)
        
        # Update hidden state
        h_new = o_t * np.tanh(c_new.data)
        h_new = Tensor(h_new, requires_grad=True)
        
        return h_new, c_new


class GRUCell(Module):
    """
    GRU Cell (Gated Recurrent Unit).
    
    Implements the GRU cell equations with reset and update gates.
    
    Args:
        input_size (int): Size of input features
        hidden_size (int): Size of hidden state
        bias (bool): Whether to use bias. Default: True
    """
    
    def __init__(self, input_size: int, hidden_size: int, bias: bool = True):
        super().__init__()
        self.input_size = input_size
        self.hidden_size = hidden_size
        self.bias = bias
        
        # Reset and update gates (2 * hidden_size)
        self.W_ih = np.random.randn(input_size, 3 * hidden_size) / math.sqrt(input_size)
        self.W_hh = np.random.randn(hidden_size, 3 * hidden_size) / math.sqrt(hidden_size)
        
        self.W_ih = Tensor(self.W_ih, requires_grad=True)
        self.W_hh = Tensor(self.W_hh, requires_grad=True)
        
        # Add aliases for compatibility
        self.weight_ih = self.W_ih
        self.weight_hh = self.W_hh
        
        if bias:
            self.b_ih = Tensor(np.zeros(3 * hidden_size), requires_grad=True)
            self.b_hh = Tensor(np.zeros(3 * hidden_size), requires_grad=True)
        else:
            self.b_ih = None
            self.b_hh = None
    
    def forward(self, x: Tensor, h_prev: Optional[Tensor] = None) -> Tensor:
        """
        Apply GRU cell.
        
        Args:
            x (Tensor): Input of shape (batch_size, input_size)
            h_prev (Optional[Tensor]): Previous hidden state of shape (batch_size, hidden_size)
        
        Returns:
            Tensor: Hidden state of shape (batch_size, hidden_size)
        """
        batch_size = x.shape[0]
        
        # Initialize hidden state if not provided
        if h_prev is None:
            h_prev = np.zeros((batch_size, self.hidden_size))
            h_prev = Tensor(h_prev, requires_grad=True)
        
        # Compute gates
        gi = np.matmul(x.data, self.W_ih.data)
        gh = np.matmul(h_prev.data, self.W_hh.data)
        
        if self.bias:
            gi = gi + self.b_ih.data
            gh = gh + self.b_hh.data
        
        # Reset gate
        r_t = 1 / (1 + np.exp(-(gi[:, :self.hidden_size] + gh[:, :self.hidden_size])))
        
        # Update gate
        z_t = 1 / (1 + np.exp(-(gi[:, self.hidden_size:2*self.hidden_size] + 
                                  gh[:, self.hidden_size:2*self.hidden_size])))
        
        # Candidate hidden state
        h_candidate = np.tanh(gi[:, 2*self.hidden_size:] + r_t * gh[:, 2*self.hidden_size:])
        
        # New hidden state
        h_new = (1 - z_t) * h_candidate + z_t * h_prev.data
        h_new = Tensor(h_new, requires_grad=True)
        
        return h_new


class RNN(Module):
    """
    Multi-layer RNN.
    
    Args:
        input_size (int): Size of input features
        hidden_size (int): Size of hidden state
        num_layers (int): Number of RNN layers. Default: 1
        bias (bool): Whether to use bias. Default: True
        batch_first (bool): Whether batch is the first dimension. Default: False
        bidirectional (bool): Whether to use bidirectional RNN. Default: False
        nonlinearity (str): Type of nonlinearity. Default: 'tanh'
        dropout (float): Dropout rate. Default: 0.0
    """
    
    def __init__(
        self,
        input_size: int,
        hidden_size: int,
        num_layers: int = 1,
        bias: bool = True,
        batch_first: bool = False,
        bidirectional: bool = False,
        nonlinearity: str = 'tanh',
        dropout: float = 0.0
    ):
        super().__init__()
        self.input_size = input_size
        self.hidden_size = hidden_size
        self.num_layers = num_layers
        self.bias = bias
        self.batch_first = batch_first
        self.bidirectional = bidirectional
        self.nonlinearity = nonlinearity
        self.dropout = dropout
        
        # Create RNN cells for each layer
        self.cells = []
        self.weight_names = {}
        
        for layer in range(num_layers):
            # For layer > 0, if bidirectional, input size should be 2 * hidden_size
            if layer == 0:
                layer_input_size = input_size
            else:
                layer_input_size = hidden_size * (2 if bidirectional else 1)
            
            # Forward direction
            cell = RNNCell(layer_input_size, hidden_size, bias=bias)
            self.cells.append(cell)
            setattr(self, f'weight_ih_l{layer}', cell.W_ih)
            setattr(self, f'weight_hh_l{layer}', cell.W_hh)
            if bias:
                setattr(self, f'bias_ih_l{layer}', cell.b_ih)
                setattr(self, f'bias_hh_l{layer}', cell.b_hh)
            
            # Backward direction (if bidirectional)
            if bidirectional:
                cell_bwd = RNNCell(layer_input_size, hidden_size, bias=bias)
                self.cells.append(cell_bwd)
                setattr(self, f'weight_ih_l{layer}_reverse', cell_bwd.W_ih)
                setattr(self, f'weight_hh_l{layer}_reverse', cell_bwd.W_hh)
                if bias:
                    setattr(self, f'bias_ih_l{layer}_reverse', cell_bwd.b_ih)
                    setattr(self, f'bias_hh_l{layer}_reverse', cell_bwd.b_hh)
    
    def forward(
        self,
        x: Tensor,
        h: Optional[Tensor] = None
    ) -> Tuple[Tensor, Tensor]:
        """
        Apply RNN.
        
        Args:
            x (Tensor): Input of shape:
                - (seq_len, batch_size, input_size) if batch_first=False
                - (batch_size, seq_len, input_size) if batch_first=True
            h (Optional[Tensor]): Initial hidden state of shape
                (num_layers * num_directions, batch_size, hidden_size)
        
        Returns:
            Tuple[Tensor, Tensor]: (output, h_n) where:
                - output: all hidden states
                - h_n: final hidden state
        """
        if self.batch_first:
            x = np.transpose(x.data, (1, 0, 2))
            x = Tensor(x, requires_grad=True)
        
        seq_len, batch_size, _ = x.shape
        
        # Initialize hidden states if not provided
        if h is None:
            num_directions = 2 if self.bidirectional else 1
            h = np.zeros((self.num_layers * num_directions, batch_size, self.hidden_size))
            h = Tensor(h, requires_grad=True)
        
        # Process sequence
        output = []
        h_list = list(h.data)
        
        for t in range(seq_len):
            x_t = x.data[t]  # (batch_size, input_size)
            x_t = Tensor(x_t, requires_grad=True)
            
            # Process through layers
            for layer in range(self.num_layers):
                layer_input_size = self.input_size if layer == 0 else (self.hidden_size * (2 if self.bidirectional else 1))
                cell_idx = layer * 2 if self.bidirectional else layer
                h_idx = layer * 2 if self.bidirectional else layer
                
                # Forward pass
                h_new = self.cells[cell_idx](x_t, Tensor(h_list[h_idx], requires_grad=True))
                h_list[h_idx] = h_new.data
                
                x_t_next = h_new
                
                # Backward pass (if bidirectional)
                if self.bidirectional:
                    h_idx_bwd = layer * 2 + 1
                    h_new_bwd = self.cells[cell_idx + 1](x_t, Tensor(h_list[h_idx_bwd], requires_grad=True))
                    h_list[h_idx_bwd] = h_new_bwd.data
                    
                    # Concatenate forward and backward
                    x_t_next = np.concatenate([h_new.data, h_new_bwd.data], axis=1)
                    x_t_next = Tensor(x_t_next, requires_grad=True)
                
                x_t = x_t_next
            
            output.append(x_t.data)
        
        # Stack outputs
        output = np.stack(output, axis=0)
        output = Tensor(output, requires_grad=True)
        
        # Convert h_list back to neurx
        h_final = np.stack(h_list, axis=0)
        h_final = Tensor(h_final, requires_grad=True)
        
        if self.batch_first:
            output = np.transpose(output.data, (1, 0, 2))
            output = Tensor(output, requires_grad=True)
        
        return output, h_final


class LSTM(Module):
    """
    Multi-layer LSTM.
    
    Args:
        input_size (int): Size of input features
        hidden_size (int): Size of hidden and cell state
        num_layers (int): Number of LSTM layers. Default: 1
        bias (bool): Whether to use bias. Default: True
        batch_first (bool): Whether batch is the first dimension. Default: False
        bidirectional (bool): Whether to use bidirectional LSTM. Default: False
        dropout (float): Dropout rate. Default: 0.0
    """
    
    def __init__(
        self,
        input_size: int,
        hidden_size: int,
        num_layers: int = 1,
        bias: bool = True,
        batch_first: bool = False,
        bidirectional: bool = False,
        dropout: float = 0.0
    ):
        super().__init__()
        self.input_size = input_size
        self.hidden_size = hidden_size
        self.num_layers = num_layers
        self.bias = bias
        self.batch_first = batch_first
        self.bidirectional = bidirectional
        self.dropout = dropout
        
        # Create LSTM cells for each layer
        self.cells = []
        
        for layer in range(num_layers):
            layer_input_size = input_size if layer == 0 else (hidden_size * (2 if bidirectional else 1))
            
            cell = LSTMCell(layer_input_size, hidden_size, bias=bias)
            self.cells.append(cell)
            setattr(self, f'weight_ih_l{layer}', cell.W_ih)
            setattr(self, f'weight_hh_l{layer}', cell.W_hh)
            if bias:
                setattr(self, f'bias_ih_l{layer}', cell.b_ih)
                setattr(self, f'bias_hh_l{layer}', cell.b_hh)
            
            if bidirectional:
                cell_bwd = LSTMCell(layer_input_size, hidden_size, bias=bias)
                self.cells.append(cell_bwd)
                setattr(self, f'weight_ih_l{layer}_reverse', cell_bwd.W_ih)
                setattr(self, f'weight_hh_l{layer}_reverse', cell_bwd.W_hh)
                if bias:
                    setattr(self, f'bias_ih_l{layer}_reverse', cell_bwd.b_ih)
                    setattr(self, f'bias_hh_l{layer}_reverse', cell_bwd.b_hh)
    
    def forward(
        self,
        x: Tensor,
        state: Optional[Tuple[Tensor, Tensor]] = None
    ) -> Tuple[Tensor, Tuple[Tensor, Tensor]]:
        """
        Apply LSTM.
        
        Args:
            x (Tensor): Input neurx
            state (Optional[Tuple]): Initial (h, c) state
        
        Returns:
            Tuple: (output, (h_n, c_n))
        """
        if self.batch_first:
            x = np.transpose(x.data, (1, 0, 2))
            x = Tensor(x, requires_grad=True)
        
        seq_len, batch_size, _ = x.shape
        
        # Initialize states if not provided
        if state is None:
            num_directions = 2 if self.bidirectional else 1
            h = np.zeros((self.num_layers * num_directions, batch_size, self.hidden_size))
            c = np.zeros((self.num_layers * num_directions, batch_size, self.hidden_size))
            h = Tensor(h, requires_grad=True)
            c = Tensor(c, requires_grad=True)
        else:
            h, c = state
        
        # Process sequence
        output = []
        h_list = list(h.data)
        c_list = list(c.data)
        
        for t in range(seq_len):
            x_t = x.data[t]
            x_t = Tensor(x_t, requires_grad=True)
            
            for layer in range(self.num_layers):
                layer_input_size = self.input_size if layer == 0 else (self.hidden_size * (2 if self.bidirectional else 1))
                cell_idx = layer * 2 if self.bidirectional else layer
                state_idx = layer * 2 if self.bidirectional else layer
                
                h_new, c_new = self.cells[cell_idx](
                    x_t,
                    (Tensor(h_list[state_idx], requires_grad=True),
                     Tensor(c_list[state_idx], requires_grad=True))
                )
                h_list[state_idx] = h_new.data
                c_list[state_idx] = c_new.data
                
                x_t_next = h_new
                
                if self.bidirectional:
                    state_idx_bwd = layer * 2 + 1
                    h_bwd, c_bwd = self.cells[cell_idx + 1](
                        x_t,
                        (Tensor(h_list[state_idx_bwd], requires_grad=True),
                         Tensor(c_list[state_idx_bwd], requires_grad=True))
                    )
                    h_list[state_idx_bwd] = h_bwd.data
                    c_list[state_idx_bwd] = c_bwd.data
                    
                    x_t_next = np.concatenate([h_new.data, h_bwd.data], axis=1)
                    x_t_next = Tensor(x_t_next, requires_grad=True)
                
                x_t = x_t_next
            
            output.append(x_t.data)
        
        output = np.stack(output, axis=0)
        output = Tensor(output, requires_grad=True)
        
        h_final = np.stack(h_list, axis=0)
        c_final = np.stack(c_list, axis=0)
        h_final = Tensor(h_final, requires_grad=True)
        c_final = Tensor(c_final, requires_grad=True)
        
        if self.batch_first:
            output = np.transpose(output.data, (1, 0, 2))
            output = Tensor(output, requires_grad=True)
        
        return output, (h_final, c_final)


class GRU(Module):
    """
    Multi-layer GRU.
    
    Args:
        input_size (int): Size of input features
        hidden_size (int): Size of hidden state
        num_layers (int): Number of GRU layers. Default: 1
        bias (bool): Whether to use bias. Default: True
        batch_first (bool): Whether batch is the first dimension. Default: False
        bidirectional (bool): Whether to use bidirectional GRU. Default: False
        dropout (float): Dropout rate. Default: 0.0
    """
    
    def __init__(
        self,
        input_size: int,
        hidden_size: int,
        num_layers: int = 1,
        bias: bool = True,
        batch_first: bool = False,
        bidirectional: bool = False,
        dropout: float = 0.0
    ):
        super().__init__()
        self.input_size = input_size
        self.hidden_size = hidden_size
        self.num_layers = num_layers
        self.bias = bias
        self.batch_first = batch_first
        self.bidirectional = bidirectional
        self.dropout = dropout
        
        self.cells = []
        
        for layer in range(num_layers):
            layer_input_size = input_size if layer == 0 else (hidden_size * (2 if bidirectional else 1))
            
            cell = GRUCell(layer_input_size, hidden_size, bias=bias)
            self.cells.append(cell)
            setattr(self, f'weight_ih_l{layer}', cell.W_ih)
            setattr(self, f'weight_hh_l{layer}', cell.W_hh)
            if bias:
                setattr(self, f'bias_ih_l{layer}', cell.b_ih)
                setattr(self, f'bias_hh_l{layer}', cell.b_hh)
            
            if bidirectional:
                cell_bwd = GRUCell(layer_input_size, hidden_size, bias=bias)
                self.cells.append(cell_bwd)
                setattr(self, f'weight_ih_l{layer}_reverse', cell_bwd.W_ih)
                setattr(self, f'weight_hh_l{layer}_reverse', cell_bwd.W_hh)
                if bias:
                    setattr(self, f'bias_ih_l{layer}_reverse', cell_bwd.b_ih)
                    setattr(self, f'bias_hh_l{layer}_reverse', cell_bwd.b_hh)
    
    def forward(
        self,
        x: Tensor,
        h: Optional[Tensor] = None
    ) -> Tuple[Tensor, Tensor]:
        """
        Apply GRU.
        
        Args:
            x (Tensor): Input neurx
            h (Optional[Tensor]): Initial hidden state
        
        Returns:
            Tuple: (output, h_n)
        """
        if self.batch_first:
            x = np.transpose(x.data, (1, 0, 2))
            x = Tensor(x, requires_grad=True)
        
        seq_len, batch_size, _ = x.shape
        
        if h is None:
            num_directions = 2 if self.bidirectional else 1
            h = np.zeros((self.num_layers * num_directions, batch_size, self.hidden_size))
            h = Tensor(h, requires_grad=True)
        
        output = []
        h_list = list(h.data)
        
        for t in range(seq_len):
            x_t = x.data[t]
            x_t = Tensor(x_t, requires_grad=True)
            
            for layer in range(self.num_layers):
                layer_input_size = self.input_size if layer == 0 else (self.hidden_size * (2 if self.bidirectional else 1))
                cell_idx = layer * 2 if self.bidirectional else layer
                h_idx = layer * 2 if self.bidirectional else layer
                
                h_new = self.cells[cell_idx](x_t, Tensor(h_list[h_idx], requires_grad=True))
                h_list[h_idx] = h_new.data
                
                x_t_next = h_new
                
                if self.bidirectional:
                    h_idx_bwd = layer * 2 + 1
                    h_new_bwd = self.cells[cell_idx + 1](x_t, Tensor(h_list[h_idx_bwd], requires_grad=True))
                    h_list[h_idx_bwd] = h_new_bwd.data
                    
                    x_t_next = np.concatenate([h_new.data, h_new_bwd.data], axis=1)
                    x_t_next = Tensor(x_t_next, requires_grad=True)
                
                x_t = x_t_next
            
            output.append(x_t.data)
        
        output = np.stack(output, axis=0)
        output = Tensor(output, requires_grad=True)
        
        h_final = np.stack(h_list, axis=0)
        h_final = Tensor(h_final, requires_grad=True)
        
        if self.batch_first:
            output = np.transpose(output.data, (1, 0, 2))
            output = Tensor(output, requires_grad=True)
        
        return output, h_final
