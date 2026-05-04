"""
模型定义
演示如何使用 NeurX 框架定义神经网络模型
"""

import neurx
import neurx.nn as nn


class SimpleClassifier(nn.Module):
    """
    简单的分类模式
    
    Args:
        input_dim (int): 输入特征维度，默认 784
        hidden_dim (int): 隐藏层维度，默认 128
        num_classes (int): 类别数，默认 10
        dropout (float): Dropout 比例，默认 0.2
    """
    
    def __init__(self, input_dim=784, hidden_dim=128, num_classes=10, dropout=0.2):
        super().__init__()
        
        # 定义层
        self.fc1 = nn.Linear(input_dim, hidden_dim)
        self.relu = nn.ReLU()
        self.dropout = nn.Dropout(dropout) if dropout > 0 else None
        self.fc2 = nn.Linear(hidden_dim, num_classes)
    
    def forward(self, x):
        """
        前向传播
        
        Args:
            x: 输入张量，形状 (batch_size, input_dim)
            
        Returns:
            输出张量，形状 (batch_size, num_classes)
        """
        # 隐藏层
        x = self.fc1(x)
        x = self.relu(x)
        
        # Dropout
        if self.dropout is not None:
            x = self.dropout(x)
        
        # 输出层
        x = self.fc2(x)
        
        return x


class ConvNet(nn.Module):
    """
    卷积神经网络（演示如何使用 NeurX 的卷积层）
    注意：这是一个简化示例，展示 API 使用
    
    Args:
        num_classes (int): 类别数，默认 10
    """
    
    def __init__(self, num_classes=10):
        super().__init__()
        
        # 如果 NeurX 支持 Conv2d，可以这样使用
        try:
            self.conv1 = nn.Conv2d(1, 32, kernel_size=3, padding=1)
            self.conv2 = nn.Conv2d(32, 64, kernel_size=3, padding=1)
            self.relu = nn.ReLU()
            
            # 全连接层进行分类
            # MNIST 28x28 -> Conv -> MaxPool -> Conv -> MaxPool -> Flatten
            self.fc1 = nn.Linear(64 * 7 * 7, 128)
            self.fc2 = nn.Linear(128, num_classes)
        except AttributeError:
            # 如果不支持 Conv2d，创建简单的全连接网络作为退路
            self.fc1 = nn.Linear(784, 256)
            self.fc2 = nn.Linear(256, 128)
            self.fc3 = nn.Linear(128, num_classes)
            self.relu = nn.ReLU()
    
    def forward(self, x):
        """前向传播"""
        if hasattr(self, 'conv1'):
            # 卷积路径
            x = self.relu(self.conv1(x))
            x = self.relu(self.conv2(x))
            x = x.reshape(x.shape[0], -1)  # Flatten
            x = self.relu(self.fc1(x))
            x = self.fc2(x)
        else:
            # 全连接路径
            if x.ndim > 2:
                x = x.reshape(x.shape[0], -1)  # Flatten if needed
            x = self.relu(self.fc1(x))
            x = self.relu(self.fc2(x))
            x = self.fc3(x)
        
        return x


class VisionTransformerBlock(nn.Module):
    """
    Transformer 注意力块示例
    展示如何使用 NeurX 的高级功能
    """
    
    def __init__(self, embed_dim=64, num_heads=4, ffn_dim=256):
        super().__init__()
        
        # Multi-Head Attention
        if hasattr(nn, 'MultiHeadAttention'):
            self.attention = nn.MultiHeadAttention(embed_dim, num_heads)
        
        # Feed-Forward Network
        self.fc1 = nn.Linear(embed_dim, ffn_dim)
        self.fc2 = nn.Linear(ffn_dim, embed_dim)
        self.relu = nn.ReLU()
        
        # Layer Normalization
        if hasattr(nn, 'LayerNorm'):
            self.norm1 = nn.LayerNorm(embed_dim)
            self.norm2 = nn.LayerNorm(embed_dim)
    
    def forward(self, x):
        """前向传播"""
        # 自注意力
        if hasattr(self, 'attention'):
            attn_out = self.attention(x, x, x)
            if hasattr(self, 'norm1'):
                x = self.norm1(x + attn_out)
            else:
                x = x + attn_out
        
        # Feed-Forward
        ffn_out = self.fc2(self.relu(self.fc1(x)))
        if hasattr(self, 'norm2'):
            x = self.norm2(x + ffn_out)
        else:
            x = x + ffn_out
        
        return x


# 快速使用示例
if __name__ == "__main__":
    import neurx
    
    # 创建简单分类器
    model = SimpleClassifier(input_dim=784, hidden_dim=128, num_classes=10)
    
    # 创建随机输入
    x = neurx.randn(32, 784)  # 批量大小 32，特征维度 784
    
    # 前向传播
    output = model(x)
    print(f"Input shape: {x.shape}")
    print(f"Output shape: {output.shape}")
    
    # 统计参数
    param_count = sum(p.numel() for p in model.parameters())
    print(f"Total parameters: {param_count}")
