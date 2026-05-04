"""
示例：使用 NeurX 的深度学习项目
演示如何在实际项目中集成和使用 neurx 框架
"""

import neurx
import neurx.nn as nn
import neurx.optim as optim
from neurx import Tensor
import numpy as np


class ClassificationModel(nn.Module):
    """
    简单的分类模型，演示 NeurX 框架的使用
    
    Args:
        input_dim (int): 输入特征维度
        hidden_dim (int): 隐层维度
        output_dim (int): 输出类别数
    """
    
    def __init__(self, input_dim=784, hidden_dim=128, output_dim=10):
        super().__init__()
        
        # 定义层
        self.encoder = nn.Sequential([
            nn.Linear(input_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, 64),
            nn.ReLU(),
        ])
        
        self.classifier = nn.Linear(64, output_dim)
    
    def forward(self, x):
        """前向传播"""
        # 展平输入
        x = x.reshape(x.shape[0], -1)
        
        # 特征编码
        features = self.encoder(x)
        
        # 分类输出
        logits = self.classifier(features)
        
        return logits


class TrainingPipeline:
    """模型训练管道"""
    
    def __init__(self, model, learning_rate=0.001, device='cpu'):
        self.model = model
        self.device = device
        
        # 定义损失函数和优化器
        self.loss_fn = nn.CrossEntropyLoss()
        self.optimizer = optim.Adam(
            self.model.parameters(),
            lr=learning_rate
        )
        
        # 学习率调度器
        self.scheduler = optim.schedulers.StepLR(
            self.optimizer,
            step_size=10,
            gamma=0.1
        )
        
        self.train_losses = []
        self.val_losses = []
    
    def train_epoch(self, train_loader, epoch=0):
        """训练一个 epoch"""
        self.model.train()
        total_loss = 0
        num_batches = 0
        
        for batch_idx, (x, y) in enumerate(train_loader):
            # 前向传播
            logits = self.model(x)
            loss = self.loss_fn(logits, y)
            
            # 反向传播
            self.optimizer.zero_grad()
            loss.backward()
            self.optimizer.step()
            
            total_loss += loss.item()
            num_batches += 1
            
            if (batch_idx + 1) % 10 == 0:
                print(f"Epoch {epoch}, Batch {batch_idx+1}, "
                      f"Loss: {loss.item():.4f}")
        
        avg_loss = total_loss / num_batches
        self.train_losses.append(avg_loss)
        
        return avg_loss
    
    def validate(self, val_loader):
        """验证模型"""
        self.model.eval()
        total_loss = 0
        correct = 0
        total = 0
        
        with neurx.no_grad():
            for x, y in val_loader:
                logits = self.model(x)
                loss = self.loss_fn(logits, y)
                
                total_loss += loss.item()
                
                # 计算准确率
                predictions = logits.argmax(dim=1)
                correct += (predictions.data == y.data).sum()
                total += y.shape[0]
        
        avg_loss = total_loss / len(val_loader)
        accuracy = correct / total
        self.val_losses.append(avg_loss)
        
        print(f"Validation Loss: {avg_loss:.4f}, Accuracy: {accuracy:.4f}")
        
        return avg_loss, accuracy
    
    def train(self, train_loader, val_loader, num_epochs=20):
        """完整训练流程"""
        print("="*50)
        print("开始训练...")
        print("="*50)
        
        for epoch in range(num_epochs):
            # 训练
            train_loss = self.train_epoch(train_loader, epoch)
            
            # 验证
            val_loss, val_acc = self.validate(val_loader)
            
            # 学习率调度
            self.scheduler.step()
            
            print(f"Epoch {epoch+1}/{num_epochs} - "
                  f"Train Loss: {train_loss:.4f}, "
                  f"Val Loss: {val_loss:.4f}, "
                  f"Val Acc: {val_acc:.4f}\n")
        
        print("="*50)
        print("训练完成！")
        print("="*50)


# ============================================================
# 使用示例
# ============================================================

def create_dummy_data(num_samples=100, input_dim=784, output_dim=10):
    """创建虚拟数据用于演示"""
    X = neurx.randn(num_samples, input_dim)
    y = neurx.randint(0, output_dim, (num_samples,))
    return X, y


def main():
    """主函数"""
    print("\n" + "="*50)
    print("NeurX 深度学习框架示例项目")
    print("="*50 + "\n")
    
    # 超参数
    BATCH_SIZE = 32
    LEARNING_RATE = 0.001
    NUM_EPOCHS = 5  # 演示用较少 epoch
    INPUT_DIM = 784
    HIDDEN_DIM = 128
    OUTPUT_DIM = 10
    
    # 创建虚拟数据
    print("📊 创建训练数据...")
    X_train, y_train = create_dummy_data(200, INPUT_DIM, OUTPUT_DIM)
    X_val, y_val = create_dummy_data(50, INPUT_DIM, OUTPUT_DIM)
    
    # 简单的数据加载器模拟
    class DummyDataLoader:
        def __init__(self, X, y, batch_size):
            self.X = X
            self.y = y
            self.batch_size = batch_size
            self.num_batches = len(X) // batch_size
        
        def __iter__(self):
            indices = np.random.permutation(len(self.X))
            for i in range(0, len(self.X), self.batch_size):
                batch_idx = indices[i:i+self.batch_size]
                yield self.X[batch_idx], self.y[batch_idx]
        
        def __len__(self):
            return self.num_batches
    
    train_loader = DummyDataLoader(X_train, y_train, BATCH_SIZE)
    val_loader = DummyDataLoader(X_val, y_val, BATCH_SIZE)
    
    # 创建模型
    print("\n🏗️  构建模型...")
    model = ClassificationModel(
        input_dim=INPUT_DIM,
        hidden_dim=HIDDEN_DIM,
        output_dim=OUTPUT_DIM
    )
    print(f"✅ 模型创建完成")
    
    # 训练
    print(f"\n🚀 开始训练...")
    pipeline = TrainingPipeline(model, learning_rate=LEARNING_RATE)
    pipeline.train(train_loader, val_loader, num_epochs=NUM_EPOCHS)
    
    # 测试数据上评估
    print("\n📈 在测试数据上评估...")
    X_test, y_test = create_dummy_data(30, INPUT_DIM, OUTPUT_DIM)
    
    model.eval()
    with neurx.no_grad():
        logits = model(X_test)
        predictions = logits.argmax(dim=1)
        test_loss = pipeline.loss_fn(logits, y_test)
    
    test_accuracy = (predictions.data == y_test.data).sum() / len(y_test)
    print(f"📊 测试集 - Loss: {test_loss.item():.4f}, "
          f"Accuracy: {test_accuracy:.4f}")
    
    # 演示新特性
    print("\n✨ 演示 NeurX 新特性...")
    
    # 混合精度演示
    print("\n1️⃣  混合精度训练示例:")
    x_fp32 = neurx.randn(4, 784)
    x_fp16 = x_fp32.float16()  # 转换为 float16
    x_back = x_fp16.float32()  # 转换回 float32
    print(f"   原始 dtype: {x_fp32.dtype}")
    print(f"   float16 dtype: {x_fp16.dtype}")
    print(f"   转换回 dtype: {x_back.dtype}")
    
    # Scatter/Gather 演示
    print("\n2️⃣  Scatter/Gather 操作示例:")
    t = neurx.ones(3, 5)
    idx = neurx.Tensor(np.array([[0, 2], [1, 3], [2, 4]], dtype=np.int64))
    src = neurx.ones(3, 2) * 5
    
    scattered = t.scatter(1, idx, src)
    print(f"   Scatter 结果形状: {scattered.shape}")
    print(f"   Scatter 结果:\n{scattered.data}")
    
    gathered = t.gather(1, idx)
    print(f"   Gather 结果形状: {gathered.shape}")
    
    # dtype 转换演示
    print("\n3️⃣  数据类型支持:")
    x = neurx.randn(2, 3)
    print(f"   float32 (默认): {x.dtype}")
    print(f"   float64 (double): {x.double().dtype}")
    print(f"   float16 (half): {x.half().dtype}")
    print(f"   int32: {x.int32().dtype}")
    print(f"   int64: {x.int64().dtype}")
    
    print("\n" + "="*50)
    print("✅ 示例完成！")
    print("="*50 + "\n")


if __name__ == "__main__":
    main()
