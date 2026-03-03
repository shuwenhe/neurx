from tensor.nn.modules import *
from tensor.nn.normalization import LayerNorm, GroupNorm, InstanceNorm, BatchNorm1d, BatchNorm2d, BatchNorm3d
from tensor.nn.attention import (
    ScaledDotProductAttention,
    MultiheadAttention,
    AttentionWithPE,
)
from tensor.nn.transformer import (
    FeedForwardNetwork,
    TransformerEncoderLayer,
    TransformerEncoder,
    TransformerDecoderLayer,
    TransformerDecoder,
    Transformer,
    BertLike,
)
from tensor.nn.rnn import (
    RNNCell, RNN,
    LSTMCell, LSTM,
    GRUCell, GRU,
)
from tensor.nn.conv import (
    Conv1d, Conv2d, Conv3d,
    ConvTranspose1d, ConvTranspose2d, ConvTranspose3d,
)
from tensor.nn.pooling import (
    MaxPool1d, MaxPool2d, MaxPool3d,
    AvgPool1d, AvgPool2d, AvgPool3d,
    AdaptiveMaxPool2d, AdaptiveAvgPool2d,
)
from tensor.nn.init import (
    xavier_uniform, xavier_normal, kaiming_uniform, kaiming_normal,
    orthogonal, uniform, normal,
    xavier_uniform_, xavier_normal_, kaiming_uniform_, kaiming_normal_,
    orthogonal_, uniform_, normal_,
)
from tensor.nn.grad_utils import (
    get_grad_norm, clip_grad_norm_, clip_grad_value_, zero_grad, GradientClipper,
)
from tensor.nn.utils import (
    count_parameters, count_flops, model_size, summary, analyze_network, ModelAnalyzer,
)
from tensor.nn.activations import (
    relu, leaky_relu, elu, selu, sigmoid, tanh, softmax, log_softmax,
    softplus, softsign, swish, mish, gelu, hardshrink, softshrink, hardtanh,
    threshold, glu, prelu, rrelu,
    ReLU, LeakyReLU, ELU, SELU, Sigmoid, Tanh, Softmax, LogSoftmax,
    Softplus, Softsign, Swish, Mish, GELU, HardShrink, SoftShrink, HardTanh,
    Threshold, GLU, PReLU, RReLU,
)
from tensor.nn.optim_utils import (
    constant_lr, step_lr, exponential_lr, polynomial_lr, cosine_lr, cosine_restart_lr,
    linear_warmup_lr, linear_warmup_cosine_lr, cyclic_lr, one_cycle_lr,
    apply_weight_decay, clip_grad_norm, compute_grad_norm,
    adam_momentum_update, sgd_momentum_update,
    LRScheduler, WarmupScheduler, GradientAccumulator,
)
from tensor.nn.loss_extended import (
    focal_loss, focal_loss_multi, hinge_loss, smooth_l1_loss, huber_loss, margin_ranking_loss,
    kullback_leibler_divergence, jensen_shannon_divergence, wasserstein_loss,
    triplet_loss, contrastive_loss, ntxent_loss, center_loss, arcface_loss,
)
from tensor.nn import functional
from tensor.nn.functional import (
    # Activation functions
    relu, leaky_relu, sigmoid, tanh, elu, selu, prelu, rrelu, hardtanh, hardswish, mish,
    silu, gelu,
    # Normalization
    softmax, log_softmax, layer_norm, rms_norm, batch_norm, group_norm, instance_norm,
    # Operations
    linear, rnn_cell, lstm_cell, gru_cell, rnn, lstm, gru, conv1d, conv_transpose1d, conv2d, conv_transpose2d, conv3d, conv_transpose3d,
    max_pool1d, max_pool2d, avg_pool1d, avg_pool2d,
    adaptive_avg_pool1d, adaptive_max_pool1d, adaptive_avg_pool2d, adaptive_max_pool2d,
    adaptive_avg_pool3d, adaptive_max_pool3d,
    dropout, embedding,
    # Loss functions
    mse_loss, cross_entropy, nll_loss,
    bce_loss, bce_with_logits_loss, l1_loss, smooth_l1_loss, kl_div_loss,
)

__all__ = [
    "Parameter",
    "Module",
    "ModuleList",
    "ModuleDict",
    "Embedding",
    "Linear",
    "RNNCell",
    "LSTMCell",
    "GRUCell",
    "RNN",
    "LSTM",
    "GRU",
    "Conv1d",
    "Conv2d",
    "Conv3d",
    "ConvTranspose1d",
    "ConvTranspose2d",
    "ConvTranspose3d",
    "BatchNorm1d",
    "BatchNorm2d",
    "BatchNorm3d",
    "GroupNorm",
    "InstanceNorm1d",
    "InstanceNorm2d",
    "InstanceNorm3d",
    "MaxPool1d",
    "MaxPool2d",
    "MaxPool3d",
    "AvgPool1d",
    "AvgPool2d",
    "AvgPool3d",
    "AdaptiveAvgPool1d",
    "AdaptiveAvgPool2d",
    "AdaptiveAvgPool3d",
    "AdaptiveMaxPool1d",
    "AdaptiveMaxPool2d",
    "AdaptiveMaxPool3d",
    "LayerNorm",
    "RMSNorm",
    "Dropout",
    "CrossEntropyLoss",
    "NLLLoss",
    "MSELoss",
    "L1Loss",
    "SmoothL1Loss",
    "BCELoss",
    "BCEWithLogitsLoss",
    "KLDivLoss",
    "Softmax",
    "GELU",
    "Sigmoid",
    "SiLU",
    # Attention and Transformer modules
    "ScaledDotProductAttention",
    "MultiheadAttention",
    "AttentionWithPE",
    "FeedForwardNetwork",
    "TransformerEncoderLayer",
    "TransformerEncoder",
    "TransformerDecoderLayer",
    "TransformerDecoder",
    "Transformer",
    "BertLike",
    # Weight Initialization (Week 5)
    "xavier_uniform", "xavier_normal", "kaiming_uniform", "kaiming_normal",
    "orthogonal", "uniform", "normal",
    "xavier_uniform_", "xavier_normal_", "kaiming_uniform_", "kaiming_normal_",
    "orthogonal_", "uniform_", "normal_",
    # Gradient Operations (Week 5)
    "get_grad_norm", "clip_grad_norm_", "clip_grad_value_", "zero_grad", "GradientClipper",
    # Model Analysis (Week 5)
    "count_parameters", "count_flops", "model_size", "summary", "analyze_network", "ModelAnalyzer",
    # Legacy names
    "MultiHeadAttention",
    "MLP",
    "MoE",
    "TransformerBlock",
    "functional",
    # Activation functions
    "relu", "leaky_relu", "sigmoid", "tanh", "elu", "selu", "prelu", "rrelu", 
    "hardtanh", "hardswish", "mish", "silu", "gelu",
    # Normalization
    "softmax", "log_softmax", "layer_norm", "rms_norm", "batch_norm", "group_norm", "instance_norm",
    # Operations
    "linear", "rnn_cell", "lstm_cell", "gru_cell", "rnn", "lstm", "gru", "conv1d", "conv_transpose1d", "conv2d", "conv_transpose2d", "conv3d", "conv_transpose3d",
    "max_pool1d", "max_pool2d", "avg_pool1d", "avg_pool2d",
    "adaptive_avg_pool1d", "adaptive_max_pool1d", "adaptive_avg_pool2d", "adaptive_max_pool2d",
    "adaptive_avg_pool3d", "adaptive_max_pool3d",
    "dropout", "embedding",
    # Loss functions
    "mse_loss", "cross_entropy", "nll_loss",
    "bce_loss", "bce_with_logits_loss", "l1_loss", "smooth_l1_loss", "kl_div_loss",
]
