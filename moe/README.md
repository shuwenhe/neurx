# MoE models

该目录集中保存 NeurX 的 Mixture-of-Experts 引擎与模型代码。

| 文件 | 职责 |
|---|---|
| `moe_core.s` | 可执行的共享路由、Top-K、共享专家和路由专家核心 |
| `hybrid_moe.s` | KDA、Gated MLA、AttnRes 与共享MoE核心组成的混合骨干 |
| `transformer_moe.s` | Transformer MoE层 |
| `transformer_moe_backward.s` | Router与Expert FFN反向传播 |
| `llm_moe.s` | GPT/LLM MoE模型 |
| `llm_moe_1t.s` | 1T级稀疏模型配置与拓扑 |
| `llm_moe_1t_loss.s` | MoE损失与梯度 |
| `fine_grained_moe.s` | 细粒度路由、共享专家和无辅助损失均衡 |
| `trae_moe.s` | 自适应路由MoE实验实现 |
| `moe_optimizer.s` | 专家专业化、剪枝、合并和效率分析设计 |

模型、训练和测试代码通过 `neurx.moe.*` 包路径引用这些模块。
