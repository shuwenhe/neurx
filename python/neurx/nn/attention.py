"""
Attention mechanisms for deep learning models.

This module provides implementations of scaled dot-product attention and 
multi-head attention, which are fundamental components of Transformer models.
"""

import numpy as np
import math
from typing import Optional, Tuple

from neurx.core.neurx import Tensor
from neurx.nn.modules import Module, Parameter
from neurx.nn.functional import softmax, dropout


class ScaledDotProductAttention(Module):
    """
    Scaled Dot-Product Attention mechanism.
    
    Computes attention weights as: Attention(Q, K, V) = softmax(QK^T / sqrt(d_k))V
    
    This is the core mechanism used in multi-head attention layers.
    
    Attributes:
        dropout_p (float): Dropout probability applied to attention weights.
    """
    
    def __init__(self, dropout_p: float = 0.0):
        """
        Initialize ScaledDotProductAttention.
        
        Args:
            dropout_p (float): Dropout probability for attention weights. Default: 0.0
        """
        super().__init__()
        self.dropout_p = dropout_p
    
    def forward(
        self,
        query: Tensor,
        key: Tensor,
        value: Tensor,
        mask: Optional[Tensor] = None,
        is_causal: bool = False,
    ) -> Tuple[Tensor, Tensor]:
        """
        Apply scaled dot-product attention.
        
        Args:
            query (Tensor): Query neurx of shape (batch_size, seq_len_q, d_k)
            key (Tensor): Key neurx of shape (batch_size, seq_len_k, d_k)
            value (Tensor): Value neurx of shape (batch_size, seq_len_v, d_v)
            mask (Optional[Tensor]): Mask neurx for attention weights.
                                     Shape: (batch_size, seq_len_q, seq_len_k)
        
        Returns:
            Tuple[Tensor, Tensor]: Output neurx and attention weights
                - output: Shape (batch_size, seq_len_q, d_v)
                - weights: Shape (batch_size, seq_len_q, seq_len_k)
        """
        d_k = query.shape[-1]

        if self.dropout_p == 0:
            try:
                from neurx.compile.runtime import try_invoke_ops_function

                if is_causal and mask is None:
                    runtime_result = try_invoke_ops_function("causal_attention", query.data, key.data, value.data)
                else:
                    mask_data = mask.data if mask is not None else np.array(0.0, dtype=query.data.dtype)
                    runtime_result = try_invoke_ops_function(
                        "scaled_dot_product_attention",
                        query.data,
                        key.data,
                        value.data,
                        mask_data,
                        mask is not None,
                    )
            except Exception:
                runtime_result = None
            if runtime_result is not None:
                output_data, attention_weights_data = runtime_result
                output = Tensor(output_data, requires_grad=True)
                attention_weights = Tensor(attention_weights_data, requires_grad=True)
                output._runtime_backend = "s"
                attention_weights._runtime_backend = "s"
                return output, attention_weights
        
        # Compute attention scores: QK^T / sqrt(d_k)
        scores = np.matmul(
            query.data,
            np.swapaxes(key.data, -2, -1)
        ) / math.sqrt(d_k)
        scores = Tensor(scores, requires_grad=True)
        
        # Apply mask if provided
        if is_causal and mask is None:
            seq_len_q, seq_len_k = scores.shape[-2], scores.shape[-1]
            row_positions = np.arange(seq_len_q).reshape(-1, 1)
            col_positions = np.arange(seq_len_k).reshape(1, -1)
            offset = max(seq_len_k - seq_len_q, 0)
            mask = Tensor(np.where(col_positions <= (row_positions + offset), 0.0, -1.0e9))
        if mask is not None:
            # Mask should be 0 where we want to attend, -inf where we don't
            scores = scores + mask
        
        # Apply softmax along the last dimension (key dimension)
        # Reshape for softmax
        batch_size, seq_len_q, seq_len_k = scores.shape
        scores_reshaped = scores.data.reshape(-1, seq_len_k)
        
        # Apply softmax
        exp_scores = np.exp(scores_reshaped - np.max(scores_reshaped, axis=1, keepdims=True))
        attention_weights = exp_scores / np.sum(exp_scores, axis=1, keepdims=True)
        attention_weights = attention_weights.reshape(batch_size, seq_len_q, seq_len_k)
        attention_weights = Tensor(attention_weights, requires_grad=True)
        
        # Apply dropout
        if self.dropout_p > 0:
            keep_prob = 1 - self.dropout_p
            mask_dropout = np.random.binomial(1, keep_prob, attention_weights.shape) / keep_prob
            attention_weights = Tensor(
                attention_weights.data * mask_dropout,
                requires_grad=True
            )
        
        # Apply attention weights to values
        output = np.matmul(attention_weights.data, value.data)
        output = Tensor(output, requires_grad=True)
        
        return output, attention_weights


class MultiheadAttention(Module):
    """
    Multi-Head Attention layer.
    
    Applies multiple attention heads in parallel, allowing the model to attend to
    different representation subspaces.
    
    The layer consists of:
    - Linear projections for Query, Key, and Value (in parallel for each head)
    - Scaled dot-product attention
    - Linear projection of concatenated heads
    
    Args:
        embed_dim (int): Total embedding dimension
        num_heads (int): Number of attention heads
        dropout_p (float): Dropout probability. Default: 0.0
        bias (bool): Whether to include bias in linear layers. Default: True
    """
    
    def __init__(
        self,
        embed_dim: int,
        num_heads: int,
        dropout_p: float = 0.0,
        bias: bool = True
    ):
        """
        Initialize MultiheadAttention.
        
        Args:
            embed_dim (int): Total embedding dimension
            num_heads (int): Number of attention heads
            dropout_p (float): Dropout probability. Default: 0.0
            bias (bool): Whether to include bias in projections. Default: True
        
        Raises:
            ValueError: If embed_dim is not divisible by num_heads
        """
        super().__init__()
        
        if embed_dim % num_heads != 0:
            raise ValueError(
                f"embed_dim ({embed_dim}) must be divisible by num_heads ({num_heads})"
            )
        
        self.embed_dim = embed_dim
        self.num_heads = num_heads
        self.head_dim = embed_dim // num_heads
        self.dropout_p = dropout_p
        self.scaling = math.sqrt(self.head_dim)
        
        # Linear projections
        self.W_q = np.random.randn(embed_dim, embed_dim) / math.sqrt(embed_dim)
        self.W_k = np.random.randn(embed_dim, embed_dim) / math.sqrt(embed_dim)
        self.W_v = np.random.randn(embed_dim, embed_dim) / math.sqrt(embed_dim)
        self.W_o = np.random.randn(embed_dim, embed_dim) / math.sqrt(embed_dim)
        
        if bias:
            self.b_q = np.zeros(embed_dim)
            self.b_k = np.zeros(embed_dim)
            self.b_v = np.zeros(embed_dim)
            self.b_o = np.zeros(embed_dim)
        else:
            self.b_q = self.b_k = self.b_v = self.b_o = None
        
        # Store as parameters (in a real implementation)
        self.W_q_param = Tensor(self.W_q, requires_grad=True)
        self.W_k_param = Tensor(self.W_k, requires_grad=True)
        self.W_v_param = Tensor(self.W_v, requires_grad=True)
        self.W_o_param = Tensor(self.W_o, requires_grad=True)
        
        if bias:
            self.b_q_param = Tensor(self.b_q, requires_grad=True)
            self.b_k_param = Tensor(self.b_k, requires_grad=True)
            self.b_v_param = Tensor(self.b_v, requires_grad=True)
            self.b_o_param = Tensor(self.b_o, requires_grad=True)
        
        self.attention = ScaledDotProductAttention(dropout_p=dropout_p)
    
    def _split_heads(self, x: np.ndarray, batch_size: int) -> np.ndarray:
        """
        Split the last dimension into (num_heads, head_dim).
        
        Args:
            x (np.ndarray): Input neurx of shape (batch_size, seq_len, embed_dim)
            batch_size (int): Batch size
        
        Returns:
            np.ndarray: Tensor of shape (batch_size, num_heads, seq_len, head_dim)
        """
        x = x.reshape(batch_size, -1, self.num_heads, self.head_dim)
        return np.transpose(x, (0, 2, 1, 3))
    
    def _combine_heads(self, x: np.ndarray, batch_size: int) -> np.ndarray:
        """
        Combine multiple heads back into single representation.
        
        Args:
            x (np.ndarray): Tensor of shape (batch_size, num_heads, seq_len, head_dim)
            batch_size (int): Batch size
        
        Returns:
            np.ndarray: Tensor of shape (batch_size, seq_len, embed_dim)
        """
        x = np.transpose(x, (0, 2, 1, 3))
        x = x.reshape(batch_size, -1, self.embed_dim)
        return x
    
    def forward(
        self,
        query: Tensor,
        key: Tensor,
        value: Tensor,
        mask: Optional[Tensor] = None,
        key_padding_mask: Optional[Tensor] = None
    ) -> Tuple[Tensor, Tensor]:
        """
        Apply multi-head attention.
        
        Args:
            query (Tensor): Query neurx of shape (batch_size, seq_len_q, embed_dim)
            key (Tensor): Key neurx of shape (batch_size, seq_len_k, embed_dim)
            value (Tensor): Value neurx of shape (batch_size, seq_len_v, embed_dim)
            mask (Optional[Tensor]): Attention mask for causal masking or padding
            key_padding_mask (Optional[Tensor]): Padding mask for key positions
        
        Returns:
            Tuple[Tensor, Tensor]: 
                - output: Shape (batch_size, seq_len_q, embed_dim)
                - attention_weights: Shape (batch_size, num_heads, seq_len_q, seq_len_k)
        """
        batch_size = query.shape[0]
        
        # Linear projections in batch from d_model => h x d_k
        Q = np.matmul(query.data, self.W_q_param.data)
        K = np.matmul(key.data, self.W_k_param.data)
        V = np.matmul(value.data, self.W_v_param.data)
        
        if self.b_q_param is not None:
            Q = Q + self.b_q_param.data
            K = K + self.b_k_param.data
            V = V + self.b_v_param.data
        
        Q = Tensor(Q, requires_grad=True)
        K = Tensor(K, requires_grad=True)
        V = Tensor(V, requires_grad=True)
        
        # Split into multiple heads
        Q = self._split_heads(Q.data, batch_size)
        K = self._split_heads(K.data, batch_size)
        V = self._split_heads(V.data, batch_size)
        
        Q = Tensor(Q, requires_grad=True)
        K = Tensor(K, requires_grad=True)
        V = Tensor(V, requires_grad=True)
        
        # Apply attention separately for each head
        attention_output = []
        attention_weights_list = []
        
        for h in range(self.num_heads):
            Q_h = Q.data[:, h, :, :]
            K_h = K.data[:, h, :, :]
            V_h = V.data[:, h, :, :]
            
            Q_h = Tensor(Q_h, requires_grad=True)
            K_h = Tensor(K_h, requires_grad=True)
            V_h = Tensor(V_h, requires_grad=True)
            
            # Attention for this head
            output_h, weights_h = self.attention(Q_h, K_h, V_h, mask=mask)
            attention_output.append(output_h.data)
            attention_weights_list.append(weights_h.data)
        
        # Stack outputs from all heads: (batch_size, num_heads, seq_len, head_dim)
        attention_output = np.stack(attention_output, axis=1)
        attention_output = Tensor(attention_output, requires_grad=True)
        
        # Combine heads: (batch_size, seq_len, embed_dim)
        attention_output = self._combine_heads(attention_output.data, batch_size)
        attention_output = Tensor(attention_output, requires_grad=True)
        
        # Final linear projection
        output = np.matmul(attention_output.data, self.W_o_param.data)
        if self.b_o_param is not None:
            output = output + self.b_o_param.data
        
        output = Tensor(output, requires_grad=True)
        
        # Average attention weights across heads for output
        avg_weights = np.mean(np.stack(attention_weights_list, axis=0), axis=0)
        avg_weights = Tensor(avg_weights, requires_grad=True)
        
        return output, avg_weights


class AttentionWithPE(Module):
    """
    Attention layer with Positional Encoding support.
    
    Combines multi-head attention with optional positional encoding
    for sequence position awareness.
    """
    
    def __init__(
        self,
        embed_dim: int,
        num_heads: int,
        max_seq_len: int = 512,
        dropout_p: float = 0.0
    ):
        """
        Initialize attention with positional encoding.
        
        Args:
            embed_dim (int): Embedding dimension
            num_heads (int): Number of attention heads
            max_seq_len (int): Maximum sequence length for PE. Default: 512
            dropout_p (float): Dropout probability. Default: 0.0
        """
        super().__init__()
        self.embed_dim = embed_dim
        self.attention = MultiheadAttention(embed_dim, num_heads, dropout_p)
        
        # Positional encoding (static, not trainable)
        self.pe = self._create_positional_encoding(max_seq_len, embed_dim)
    
    def _create_positional_encoding(self, seq_len: int, embed_dim: int) -> np.ndarray:
        """
        Create positional encoding using sine and cosine functions.
        
        Args:
            seq_len (int): Sequence length
            embed_dim (int): Embedding dimension
        
        Returns:
            np.ndarray: Positional encoding of shape (seq_len, embed_dim)
        """
        position = np.arange(seq_len)[:, np.newaxis]
        dim_indices = np.arange(0, embed_dim, 2)
        
        # Compute angle rates
        angle_rates = 1 / np.power(10000, dim_indices / embed_dim)
        
        # Compute PE
        pe = np.zeros((seq_len, embed_dim))
        pe[:, 0::2] = np.sin(position * angle_rates)
        pe[:, 1::2] = np.cos(position * angle_rates[:embed_dim // 2])
        
        return pe
    
    def forward(
        self,
        query: Tensor,
        key: Tensor,
        value: Tensor,
        add_pe: bool = True,
        mask: Optional[Tensor] = None
    ) -> Tuple[Tensor, Tensor]:
        """
        Apply attention with optional positional encoding.
        
        Args:
            query (Tensor): Query neurx
            key (Tensor): Key neurx
            value (Tensor): Value neurx
            add_pe (bool): Whether to add positional encoding. Default: True
            mask (Optional[Tensor]): Attention mask
        
        Returns:
            Tuple[Tensor, Tensor]: Attention output and weights
        """
        if add_pe:
            seq_len_q = query.shape[1]
            seq_len_k = key.shape[1]
            
            if seq_len_q <= self.pe.shape[0]:
                pe_q = self.pe[:seq_len_q]
                query = Tensor(query.data + pe_q, requires_grad=True)
            
            if seq_len_k <= self.pe.shape[0]:
                pe_k = self.pe[:seq_len_k]
                key = Tensor(key.data + pe_k, requires_grad=True)
        
        return self.attention(query, key, value, mask=mask)
