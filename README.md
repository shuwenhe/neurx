# NeurX

NeurX 是一个使用 S 语言实现的 LLM 训练与推理框架，覆盖训练、后训练、推理、分布式通信、量化、KV cache、调度、监控与部署等能力。

## 目录概览

- `inference/`：推理引擎、服务、调度、优化与运行时
- `distributed/`：分布式通信与容错能力
- `checkpoint/`：权重加载、保存与检查点管理
- `model/`、`models/`、`nn/`：模型定义与基础算子
- `posttrain/`、`pretrain/`、`trainer/`：训练与对齐相关流程
- `quantization/`：量化相关实现
- `tokenizer/`：分词器实现
- `serving/`、`api/`：对外服务与接口
- `tests/`：编译、回归与系统验证
- `scripts/`：历史脚本与兼容工具

## 常用命令

先查看全部目标：

```bash
make help
```

常见目标包括：

```bash
make quickstart-s
make verify-setup-s
make production-inference
make production-chat
make posttrain-phase2a
make runtime-test
make test-golden
```

## 约定

- 代码以 S 语言为主
- 标识符统一使用 `snake_case`
- 方法放在 `impl` 块中定义
- 参数书写遵循 `type name` 形式

## 说明

仓库中的实现会持续演进，具体能力以各目录下的 `.s` 文件和 `Makefile` 目标为准。
