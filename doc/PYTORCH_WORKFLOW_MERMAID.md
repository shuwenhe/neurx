---
config:
  layout: dagre
---
flowchart TB
    A["导入 PyTorch<br>import torch"] --> B["定义模型<br>class Model"]
    B --> C["创建优化器和损失函数<br>optimizer, loss_fn"]
    C --> D["创建数据加载器<br>DataLoader"]
    D --> E["开始训练循环<br>for epoch in range"]
    E --> F["for batch in train_loader"]
    F --> G["前向传播<br>outputs = model<br>inputs"]
    G --> H["计算损失<br>loss = loss_fn<br>outputs, targets"]
    H --> I["反向传播<br>loss.backward"]
    I --> J["更新参数<br>optimizer.step"]
    J --> K["清空梯度<br>optimizer.zero_grad"]
    K --> L{"是否最后<br>一批数据?"}
    L -- 否 --> F
    L -- 是 --> M["验证模型<br>model.eval"]
    M --> N["计算验证损失"]
    N --> O{"是否最后<br>一个epoch?"}
    O -- 否 --> E
    O -- 是 --> P["保存最佳模型"]
    P --> Q["推理测试<br>Inference"]
    Q --> R["部署模型"]