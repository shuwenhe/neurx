"""
训练脚本示例
演示如何使用 NeurX 框架进行模型训练
"""

import neurx
import neurx.nn as nn
import neurx.optim as optim
from my_project.models import SimpleClassifier


def create_dummy_data(num_samples=1000, input_dim=784, num_classes=10):
    """创建随机训练数据"""
    x = neurx.randn(num_samples, input_dim)
    y = neurx.randint(0, num_classes, (num_samples,))
    return x, y


def train_epoch(model, optimizer, loss_fn, x_train, y_train, batch_size=32):
    """训练一个 epoch"""
    model.train()
    total_loss = 0
    num_batches = 0
    
    # 简单的批处理
    for i in range(0, len(x_train), batch_size):
        x_batch = x_train[i:i+batch_size]
        y_batch = y_train[i:i+batch_size]
        
        # 前向传播
        logits = model(x_batch)
        loss = loss_fn(logits, y_batch)
        
        # 反向传播
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()
        
        total_loss += loss.item()
        num_batches += 1
    
    return total_loss / num_batches


def evaluate(model, loss_fn, x_val, y_val, batch_size=32):
    """评估模型"""
    model.eval()
    total_loss = 0
    correct = 0
    total = 0
    
    with neurx.no_grad():
        for i in range(0, len(x_val), batch_size):
            x_batch = x_val[i:i+batch_size]
            y_batch = y_val[i:i+batch_size]
            
            logits = model(x_batch)
            loss = loss_fn(logits, y_batch)
            
            total_loss += loss.item()
            
            # 计算准确率
            pred = logits.argmax(axis=-1)
            correct += (pred == y_batch.reshape(-1)).sum().item()
            total += y_batch.shape[0]
    
    accuracy = correct / total
    avg_loss = total_loss / (len(x_val) // batch_size + 1)
    
    return avg_loss, accuracy


def main():
    """主训练函数"""
    print("=" * 60)
    print("NeurX 框架模板项目 - 训练脚本")
    print("=" * 60)
    
    # 超参数
    input_dim = 784
    hidden_dim = 128
    num_classes = 10
    batch_size = 32
    learning_rate = 0.001
    num_epochs = 5
    
    # 创建模型
    print(f"\n创建模型...")
    model = SimpleClassifier(
        input_dim=input_dim,
        hidden_dim=hidden_dim,
        num_classes=num_classes,
        dropout=0.2
    )
    
    # 统计参数
    param_count = sum(p.numel() for p in model.parameters())
    print(f"模型参数数量: {param_count:,}")
    
    # 优化器和损失函数
    optimizer = optim.Adam(model.parameters(), lr=learning_rate)
    loss_fn = nn.CrossEntropyLoss()
    
    # 创建数据
    print(f"\n创建训练和验证数据...")
    x_train, y_train = create_dummy_data(num_samples=1000, input_dim=input_dim, num_classes=num_classes)
    x_val, y_val = create_dummy_data(num_samples=200, input_dim=input_dim, num_classes=num_classes)
    
    print(f"训练集: {x_train.shape}")
    print(f"验证集: {x_val.shape}")
    
    # 训练循环
    print(f"\n开始训练...")
    print("-" * 60)
    
    for epoch in range(num_epochs):
        # 训练
        train_loss = train_epoch(model, optimizer, loss_fn, x_train, y_train, batch_size)
        
        # 验证
        val_loss, val_acc = evaluate(model, loss_fn, x_val, y_val, batch_size)
        
        print(f"Epoch {epoch+1}/{num_epochs}")
        print(f"  Train Loss: {train_loss:.4f}")
        print(f"  Val Loss:   {val_loss:.4f}")
        print(f"  Val Acc:    {val_acc:.4f}")
    
    print("-" * 60)
    print("\n训练完成！")
    
    # 演示新功能
    print("\n演示 NeurX 新功能:")
    print("-" * 60)
    
    # 1. dtype 转换
    print("\n1. dtype 转换演示:")
    x_sample = neurx.randn(4, 784)
    print(f"  原始: {x_sample.dtype}")
    if hasattr(x_sample, 'float16'):
        x_fp16 = x_sample.float16()
        print(f"  float16: {x_fp16.dtype}")
    if hasattr(x_sample, 'double'):
        x_fp64 = x_sample.double()
        print(f"  double: {x_fp64.dtype}")
    
    # 2. scatter 操作演示
    print("\n2. Scatter 操作演示:")
    try:
        indices = neurx.array([[0, 2], [1, 3]])
        values = neurx.array([[10.0, 20.0], [30.0, 40.0]])
        shape = (4, 2)
        result = neurx.scatter(values, indices, shape=shape)
        print(f"  Scatter 结果形状: {result.shape}")
        print(f"  结果:\n{result}")
    except Exception as e:
        print(f"  Scatter 演示跳过: {e}")
    
    # 3. 矩阵约简演示
    print("\n3. 矩阵约简演示:")
    x_sample = neurx.randn(8, 16)
    print(f"  原始形状: {x_sample.shape}")
    if hasattr(x_sample, 'sum'):
        result = x_sample.sum(axis=0, keepdim=True)
        print(f"  sum(axis=0, keepdim=True): {result.shape}")


if __name__ == "__main__":
    main()
