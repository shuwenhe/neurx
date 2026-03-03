"""
Transformer layers and components.

This module provides Transformer encoder, decoder, and related components
that are fundamental to modern NLP and vision models.
"""

import numpy as np
import math
from typing import Optional

from tensor.core.tensor import Tensor
from tensor.nn.modules import Module
from tensor.nn.normalization import LayerNorm
from tensor.nn.attention import MultiheadAttention


class FeedForwardNetwork(Module):
    """
    Position-wise Feed-Forward Network (FFN).
    
    Consists of two linear transformations with ReLU activation in between.
    Applied position-wise (separately to each position).
    
    FFN(x) = max(0, xW1 + b1)W2 + b2
    
    Args:
        embed_dim (int): Embedding dimension
        hidden_dim (int): Hidden dimension of the feed-forward network
        dropout_p (float): Dropout probability. Default: 0.1
    """
    
    def __init__(
        self,
        embed_dim: int,
        hidden_dim: int,
        dropout_p: float = 0.1
    ):
        """
        Initialize Feed-Forward Network.
        
        Args:
            embed_dim (int): Embedding dimension
            hidden_dim (int): Hidden dimension
            dropout_p (float): Dropout probability. Default: 0.1
        """
        super().__init__()
        self.embed_dim = embed_dim
        self.hidden_dim = hidden_dim
        self.dropout_p = dropout_p
        
        # Two linear layers with ReLU activation
        self.W1 = np.random.randn(embed_dim, hidden_dim) / math.sqrt(embed_dim)
        self.b1 = np.zeros(hidden_dim)
        self.W2 = np.random.randn(hidden_dim, embed_dim) / math.sqrt(hidden_dim)
        self.b2 = np.zeros(embed_dim)
        
        # Store as parameters
        self.W1_param = Tensor(self.W1, requires_grad=True)
        self.b1_param = Tensor(self.b1, requires_grad=True)
        self.W2_param = Tensor(self.W2, requires_grad=True)
        self.b2_param = Tensor(self.b2, requires_grad=True)
    
    def forward(self, x: Tensor) -> Tensor:
        """
        Apply feed-forward network.
        
        Args:
            x (Tensor): Input tensor of shape (batch_size, seq_len, embed_dim)
        
        Returns:
            Tensor: Output tensor of same shape as input
        """
        # First linear transformation + ReLU
        hidden = np.matmul(x.data, self.W1_param.data) + self.b1_param.data
        # ReLU activation
        hidden = np.maximum(0, hidden)
        
        # Apply dropout if specified
        if self.dropout_p > 0:
            keep_prob = 1 - self.dropout_p
            mask = np.random.binomial(1, keep_prob, hidden.shape) / keep_prob
            hidden = hidden * mask
        
        hidden = Tensor(hidden, requires_grad=True)
        
        # Second linear transformation
        output = np.matmul(hidden.data, self.W2_param.data) + self.b2_param.data
        output = Tensor(output, requires_grad=True)
        
        return output


class TransformerEncoderLayer(Module):
    """
    Single Transformer Encoder Layer.
    
    Consists of:
    1. Multi-head self-attention
    2. Add & Norm (residual connection + layer normalization)
    3. Position-wise feed-forward network
    4. Add & Norm
    
    Args:
        embed_dim (int): Embedding dimension
        num_heads (int): Number of attention heads
        hidden_dim (int): Hidden dimension of FFN. Default: 4 * embed_dim
        dropout_p (float): Dropout probability. Default: 0.1
        activation (str): Activation function. Default: 'relu'
    """
    
    def __init__(
        self,
        embed_dim: int,
        num_heads: int,
        hidden_dim: Optional[int] = None,
        dropout_p: float = 0.1,
        activation: str = 'relu'
    ):
        """
        Initialize Transformer Encoder Layer.
        
        Args:
            embed_dim (int): Embedding dimension
            num_heads (int): Number of attention heads
            hidden_dim (Optional[int]): Hidden dimension of FFN
            dropout_p (float): Dropout probability. Default: 0.1
            activation (str): Activation function. Default: 'relu'
        """
        super().__init__()
        
        if hidden_dim is None:
            hidden_dim = 4 * embed_dim
        
        self.embed_dim = embed_dim
        self.num_heads = num_heads
        self.hidden_dim = hidden_dim
        self.dropout_p = dropout_p
        
        # Self-attention
        self.self_attn = MultiheadAttention(
            embed_dim=embed_dim,
            num_heads=num_heads,
            dropout_p=dropout_p
        )
        
        # Layer normalization
        self.norm1 = LayerNorm(embed_dim)
        
        # Feed-forward network
        self.ffn = FeedForwardNetwork(
            embed_dim=embed_dim,
            hidden_dim=hidden_dim,
            dropout_p=dropout_p
        )
        
        # Second layer normalization
        self.norm2 = LayerNorm(embed_dim)
    
    def forward(
        self,
        x: Tensor,
        mask: Optional[Tensor] = None
    ) -> Tensor:
        """
        Apply transformer encoder layer.
        
        Args:
            x (Tensor): Input tensor of shape (batch_size, seq_len, embed_dim)
            mask (Optional[Tensor]): Attention mask
        
        Returns:
            Tensor: Output tensor of same shape as input
        """
        # Self-attention with residual connection
        attn_output, _ = self.self_attn(x, x, x, mask=mask)
        x = Tensor(x.data + attn_output.data, requires_grad=True)
        
        # Layer normalization
        x = self.norm1.forward(x)
        
        # Feed-forward network with residual connection
        ffn_output = self.ffn.forward(x)
        x = Tensor(x.data + ffn_output.data, requires_grad=True)
        
        # Layer normalization
        x = self.norm2.forward(x)
        
        return x


class TransformerEncoder(Module):
    """
    Transformer Encoder - stack of N encoder layers.
    
    Args:
        embed_dim (int): Embedding dimension
        num_heads (int): Number of attention heads
        num_layers (int): Number of encoder layers
        hidden_dim (int): Hidden dimension of FFN. Default: 4 * embed_dim
        dropout_p (float): Dropout probability. Default: 0.1
        activation (str): Activation function. Default: 'relu'
    """
    
    def __init__(
        self,
        embed_dim: int,
        num_heads: int,
        num_layers: int,
        hidden_dim: Optional[int] = None,
        dropout_p: float = 0.1,
        activation: str = 'relu'
    ):
        """
        Initialize Transformer Encoder.
        
        Args:
            embed_dim (int): Embedding dimension
            num_heads (int): Number of attention heads
            num_layers (int): Number of encoder layers
            hidden_dim (Optional[int]): Hidden dimension of FFN
            dropout_p (float): Dropout probability. Default: 0.1
            activation (str): Activation function. Default: 'relu'
        """
        super().__init__()
        
        self.embed_dim = embed_dim
        self.num_heads = num_heads
        self.num_layers = num_layers
        
        if hidden_dim is None:
            hidden_dim = 4 * embed_dim
        
        # Stack of encoder layers
        self.layers = [
            TransformerEncoderLayer(
                embed_dim=embed_dim,
                num_heads=num_heads,
                hidden_dim=hidden_dim,
                dropout_p=dropout_p,
                activation=activation
            )
            for _ in range(num_layers)
        ]
        
        # Final layer normalization
        self.norm = LayerNorm(embed_dim)
    
    def forward(
        self,
        x: Tensor,
        mask: Optional[Tensor] = None
    ) -> Tensor:
        """
        Apply transformer encoder.
        
        Args:
            x (Tensor): Input tensor of shape (batch_size, seq_len, embed_dim)
            mask (Optional[Tensor]): Attention mask
        
        Returns:
            Tensor: Encoded tensor of same shape as input
        """
        for layer in self.layers:
            x = layer.forward(x, mask=mask)
        
        # Final layer normalization
        x = self.norm.forward(x)
        
        return x


class TransformerDecoderLayer(Module):
    """
    Single Transformer Decoder Layer.
    
    Consists of:
    1. Masked multi-head self-attention
    2. Add & Norm
    3. Multi-head cross-attention (with encoder output)
    4. Add & Norm
    5. Position-wise feed-forward network
    6. Add & Norm
    
    Args:
        embed_dim (int): Embedding dimension
        num_heads (int): Number of attention heads
        hidden_dim (int): Hidden dimension of FFN. Default: 4 * embed_dim
        dropout_p (float): Dropout probability. Default: 0.1
        activation (str): Activation function. Default: 'relu'
    """
    
    def __init__(
        self,
        embed_dim: int,
        num_heads: int,
        hidden_dim: Optional[int] = None,
        dropout_p: float = 0.1,
        activation: str = 'relu'
    ):
        """
        Initialize Transformer Decoder Layer.
        
        Args:
            embed_dim (int): Embedding dimension
            num_heads (int): Number of attention heads
            hidden_dim (Optional[int]): Hidden dimension of FFN
            dropout_p (float): Dropout probability. Default: 0.1
            activation (str): Activation function. Default: 'relu'
        """
        super().__init__()
        
        if hidden_dim is None:
            hidden_dim = 4 * embed_dim
        
        self.embed_dim = embed_dim
        self.num_heads = num_heads
        self.hidden_dim = hidden_dim
        
        # Self-attention
        self.self_attn = MultiheadAttention(
            embed_dim=embed_dim,
            num_heads=num_heads,
            dropout_p=dropout_p
        )
        
        # Cross-attention
        self.cross_attn = MultiheadAttention(
            embed_dim=embed_dim,
            num_heads=num_heads,
            dropout_p=dropout_p
        )
        
        # Layer normalization
        self.norm1 = LayerNorm(embed_dim)
        self.norm2 = LayerNorm(embed_dim)
        
        # Feed-forward network
        self.ffn = FeedForwardNetwork(
            embed_dim=embed_dim,
            hidden_dim=hidden_dim,
            dropout_p=dropout_p
        )
        
        # Third layer normalization
        self.norm3 = LayerNorm(embed_dim)
    
    def forward(
        self,
        x: Tensor,
        encoder_output: Tensor,
        self_attn_mask: Optional[Tensor] = None,
        cross_attn_mask: Optional[Tensor] = None
    ) -> Tensor:
        """
        Apply transformer decoder layer.
        
        Args:
            x (Tensor): Decoder input of shape (batch_size, seq_len_tgt, embed_dim)
            encoder_output (Tensor): Encoder output of shape (batch_size, seq_len_src, embed_dim)
            self_attn_mask (Optional[Tensor]): Self-attention mask (causal mask)
            cross_attn_mask (Optional[Tensor]): Cross-attention mask
        
        Returns:
            Tensor: Output tensor of same shape as input
        """
        # Self-attention with residual connection
        attn_output, _ = self.self_attn(x, x, x, mask=self_attn_mask)
        x = Tensor(x.data + attn_output.data, requires_grad=True)
        x = self.norm1.forward(x)
        
        # Cross-attention with encoder output
        cross_output, _ = self.cross_attn(x, encoder_output, encoder_output, mask=cross_attn_mask)
        x = Tensor(x.data + cross_output.data, requires_grad=True)
        x = self.norm2.forward(x)
        
        # Feed-forward network with residual connection
        ffn_output = self.ffn.forward(x)
        x = Tensor(x.data + ffn_output.data, requires_grad=True)
        x = self.norm3.forward(x)
        
        return x


class TransformerDecoder(Module):
    """
    Transformer Decoder - stack of N decoder layers.
    
    Args:
        embed_dim (int): Embedding dimension
        num_heads (int): Number of attention heads
        num_layers (int): Number of decoder layers
        hidden_dim (int): Hidden dimension of FFN. Default: 4 * embed_dim
        dropout_p (float): Dropout probability. Default: 0.1
        activation (str): Activation function. Default: 'relu'
    """
    
    def __init__(
        self,
        embed_dim: int,
        num_heads: int,
        num_layers: int,
        hidden_dim: Optional[int] = None,
        dropout_p: float = 0.1,
        activation: str = 'relu'
    ):
        """
        Initialize Transformer Decoder.
        
        Args:
            embed_dim (int): Embedding dimension
            num_heads (int): Number of attention heads
            num_layers (int): Number of decoder layers
            hidden_dim (Optional[int]): Hidden dimension of FFN
            dropout_p (float): Dropout probability. Default: 0.1
            activation (str): Activation function. Default: 'relu'
        """
        super().__init__()
        
        self.embed_dim = embed_dim
        self.num_heads = num_heads
        self.num_layers = num_layers
        
        if hidden_dim is None:
            hidden_dim = 4 * embed_dim
        
        # Stack of decoder layers
        self.layers = [
            TransformerDecoderLayer(
                embed_dim=embed_dim,
                num_heads=num_heads,
                hidden_dim=hidden_dim,
                dropout_p=dropout_p,
                activation=activation
            )
            for _ in range(num_layers)
        ]
        
        # Final layer normalization
        self.norm = LayerNorm(embed_dim)
    
    def forward(
        self,
        x: Tensor,
        encoder_output: Tensor,
        self_attn_mask: Optional[Tensor] = None,
        cross_attn_mask: Optional[Tensor] = None
    ) -> Tensor:
        """
        Apply transformer decoder.
        
        Args:
            x (Tensor): Decoder input of shape (batch_size, seq_len_tgt, embed_dim)
            encoder_output (Tensor): Encoder output of shape (batch_size, seq_len_src, embed_dim)
            self_attn_mask (Optional[Tensor]): Self-attention mask
            cross_attn_mask (Optional[Tensor]): Cross-attention mask
        
        Returns:
            Tensor: Decoded tensor of same shape as input
        """
        for layer in self.layers:
            x = layer.forward(
                x, 
                encoder_output, 
                self_attn_mask=self_attn_mask,
                cross_attn_mask=cross_attn_mask
            )
        
        # Final layer normalization
        x = self.norm.forward(x)
        
        return x


class Transformer(Module):
    """
    Complete Transformer model combining encoder and decoder.
    
    A full transformer architecture with:
    - Encoder stack (N layers)
    - Decoder stack (N layers)
    - Positional encodings
    - Shared embedding space
    
    Args:
        embed_dim (int): Embedding dimension
        num_heads (int): Number of attention heads
        num_encoder_layers (int): Number of encoder layers
        num_decoder_layers (int): Number of decoder layers
        hidden_dim (int): Hidden dimension of FFN. Default: 4 * embed_dim
        max_seq_len (int): Maximum sequence length. Default: 512
        dropout_p (float): Dropout probability. Default: 0.1
        activation (str): Activation function. Default: 'relu'
    """
    
    def __init__(
        self,
        embed_dim: int,
        num_heads: int,
        num_encoder_layers: int,
        num_decoder_layers: int,
        hidden_dim: Optional[int] = None,
        max_seq_len: int = 512,
        dropout_p: float = 0.1,
        activation: str = 'relu'
    ):
        """
        Initialize Transformer.
        
        Args:
            embed_dim (int): Embedding dimension
            num_heads (int): Number of attention heads
            num_encoder_layers (int): Number of encoder layers
            num_decoder_layers (int): Number of decoder layers
            hidden_dim (Optional[int]): Hidden dimension of FFN
            max_seq_len (int): Maximum sequence length. Default: 512
            dropout_p (float): Dropout probability. Default: 0.1
            activation (str): Activation function. Default: 'relu'
        """
        super().__init__()
        
        self.embed_dim = embed_dim
        self.num_heads = num_heads
        
        if hidden_dim is None:
            hidden_dim = 4 * embed_dim
        
        # Encoder
        self.encoder = TransformerEncoder(
            embed_dim=embed_dim,
            num_heads=num_heads,
            num_layers=num_encoder_layers,
            hidden_dim=hidden_dim,
            dropout_p=dropout_p,
            activation=activation
        )
        
        # Decoder
        self.decoder = TransformerDecoder(
            embed_dim=embed_dim,
            num_heads=num_heads,
            num_layers=num_decoder_layers,
            hidden_dim=hidden_dim,
            dropout_p=dropout_p,
            activation=activation
        )
        
        # Positional encoding (static)
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
        
        angle_rates = 1 / np.power(10000, dim_indices / embed_dim)
        
        pe = np.zeros((seq_len, embed_dim))
        pe[:, 0::2] = np.sin(position * angle_rates)
        pe[:, 1::2] = np.cos(position * angle_rates[:embed_dim // 2])
        
        return pe
    
    def forward(
        self,
        src: Tensor,
        tgt: Tensor,
        src_mask: Optional[Tensor] = None,
        tgt_mask: Optional[Tensor] = None,
        memory_mask: Optional[Tensor] = None
    ) -> Tensor:
        """
        Apply transformer.
        
        Args:
            src (Tensor): Source sequence of shape (batch_size, src_len, embed_dim)
            tgt (Tensor): Target sequence of shape (batch_size, tgt_len, embed_dim)
            src_mask (Optional[Tensor]): Source padding mask
            tgt_mask (Optional[Tensor]): Target causal mask
            memory_mask (Optional[Tensor]): Cross-attention mask
        
        Returns:
            Tensor: Output of shape (batch_size, tgt_len, embed_dim)
        """
        # Add positional encoding
        src_len = src.shape[1]
        tgt_len = tgt.shape[1]
        
        if src_len <= self.pe.shape[0]:
            pe_src = self.pe[:src_len]
            src = Tensor(src.data + pe_src, requires_grad=True)
        
        if tgt_len <= self.pe.shape[0]:
            pe_tgt = self.pe[:tgt_len]
            tgt = Tensor(tgt.data + pe_tgt, requires_grad=True)
        
        # Encode source
        encoder_output = self.encoder(src, mask=src_mask)
        
        # Decode with encoder output as memory
        decoder_output = self.decoder(
            tgt,
            encoder_output,
            self_attn_mask=tgt_mask,
            cross_attn_mask=memory_mask
        )
        
        return decoder_output


class BertLike(Module):
    """
    BERT-like encoder model for text representation learning.
    
    Combines:
    - Token embedding
    - Positional encoding
    - Transformer encoder stack
    - Output projection heads (optional)
    
    Args:
        vocab_size (int): Vocabulary size
        embed_dim (int): Embedding dimension
        num_heads (int): Number of attention heads
        num_layers (int): Number of encoder layers
        max_seq_len (int): Maximum sequence length. Default: 512
        hidden_dim (int): Hidden dimension of FFN. Default: 4 * embed_dim
        dropout_p (float): Dropout probability. Default: 0.1
    """
    
    def __init__(
        self,
        vocab_size: int,
        embed_dim: int,
        num_heads: int,
        num_layers: int,
        max_seq_len: int = 512,
        hidden_dim: Optional[int] = None,
        dropout_p: float = 0.1
    ):
        """
        Initialize BERT-like model.
        
        Args:
            vocab_size (int): Vocabulary size
            embed_dim (int): Embedding dimension
            num_heads (int): Number of attention heads
            num_layers (int): Number of encoder layers
            max_seq_len (int): Maximum sequence length. Default: 512
            hidden_dim (Optional[int]): Hidden dimension of FFN
            dropout_p (float): Dropout probability. Default: 0.1
        """
        super().__init__()
        
        self.vocab_size = vocab_size
        self.embed_dim = embed_dim
        self.max_seq_len = max_seq_len
        
        if hidden_dim is None:
            hidden_dim = 4 * embed_dim
        
        # Token embedding
        self.token_embedding = np.random.randn(vocab_size, embed_dim) / math.sqrt(embed_dim)
        self.token_embedding = Tensor(self.token_embedding, requires_grad=True)
        
        # Positional encoding
        self.pe = self._create_positional_encoding(max_seq_len, embed_dim)
        
        # Transformer encoder
        self.encoder = TransformerEncoder(
            embed_dim=embed_dim,
            num_heads=num_heads,
            num_layers=num_layers,
            hidden_dim=hidden_dim,
            dropout_p=dropout_p
        )
        
        # Embedding layer norm (BERT-style)
        self.embedding_norm = LayerNorm(embed_dim)
    
    def _create_positional_encoding(self, seq_len: int, embed_dim: int) -> np.ndarray:
        """Create positional encoding."""
        position = np.arange(seq_len)[:, np.newaxis]
        dim_indices = np.arange(0, embed_dim, 2)
        
        angle_rates = 1 / np.power(10000, dim_indices / embed_dim)
        
        pe = np.zeros((seq_len, embed_dim))
        pe[:, 0::2] = np.sin(position * angle_rates)
        pe[:, 1::2] = np.cos(position * angle_rates[:embed_dim // 2])
        
        return pe
    
    def forward(
        self,
        input_ids: np.ndarray,
        attention_mask: Optional[np.ndarray] = None
    ) -> Tensor:
        """
        Apply BERT-like model.
        
        Args:
            input_ids (np.ndarray): Token IDs of shape (batch_size, seq_len)
            attention_mask (Optional[np.ndarray]): Attention mask
        
        Returns:
            Tensor: Sequence representations of shape (batch_size, seq_len, embed_dim)
        """
        batch_size, seq_len = input_ids.shape
        
        # Get token embeddings
        embeddings = np.zeros((batch_size, seq_len, self.embed_dim))
        for i in range(batch_size):
            for j in range(seq_len):
                token_id = int(input_ids[i, j])
                if 0 <= token_id < self.vocab_size:
                    embeddings[i, j] = self.token_embedding.data[token_id]
        
        embeddings = Tensor(embeddings, requires_grad=True)
        
        # Add positional encoding
        if seq_len <= self.pe.shape[0]:
            pe = self.pe[:seq_len]
            embeddings = Tensor(embeddings.data + pe, requires_grad=True)
        
        # Apply layer norm
        embeddings = self.embedding_norm.forward(embeddings)
        
        # Create attention mask if provided
        attn_mask = None
        if attention_mask is not None:
            # attention_mask shape: (batch_size, seq_len)
            # Convert to attention weights mask
            attn_mask = (1 - attention_mask[:, np.newaxis, :]) * -10000
            attn_mask = Tensor(attn_mask, requires_grad=False)
        
        # Apply encoder
        output = self.encoder.forward(embeddings, mask=attn_mask)
        
        return output
