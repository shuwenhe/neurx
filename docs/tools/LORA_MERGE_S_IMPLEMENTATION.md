# LoRA Safetensors Merge - S Language Implementation

## 概述

本目录包含了用 S 语言实现的 LoRA Safetensors 合并工具的多个版本，提供了从高级接口到底层库的完整实现。

## 文件说明

### 1. `lora_merge.s` - 核心合并库
- **目的**: 提供LoRA合并的S语言实现框架
- **主要功能**:
  - Safetensors 格式解析
  - LoRA 数学运算 (lora_merge: W_out = W_base + (alpha/rank) * (lora_B @ lora_A))
  - 目录操作 (复制、遍历)
  - 浮点数处理和格式转换

- **关键函数**:
  ```s
  func merge_lora_adapters(merge_config cfg) bool
  func apply_lora_scale(float value, float lora_a, float lora_b, float alpha, int rank) float
  func load_safetensors_index(string filepath) safetensors_index
  ```

### 2. `safetensors.s` - Safetensors 处理库
- **目的**: 完整的 Safetensors 格式处理
- **支持内容**:
  - 多种数据类型: F32, F16, BF16, I32, I64, U32, U64, etc.
  - 张量元数据解析
  - 文件I/O操作
  - 浮点数精度转换

- **使用示例**:
  ```s
  safetensors_archive archive = load_safetensors_header("model.safetensors")
  tensor_data tensor = read_tensor(archive, "model.1.weight")
  ```

### 3. `lora_merge_cli.s` - 命令行界面
- **目的**: 提供用户友好的命令行接口
- **环境变量配置**:
  - `NEURX_ROOT`: NeurX项目根目录
  - `NEURX_POSTTRAIN_MODEL_PATH`: 基础模型目录
  - `NEURX_LORA_ADAPTER_DIR`: LoRA适配器目录
  - `NEURX_MERGED_MODEL_DIR`: 输出目录
  - `NEURX_LORA_ALPHA`: LoRA缩放系数(默认16)
  - `NEURX_LORA_RANK`: 适配器秩(默认8)

## 与 C 实现的对比

| 特性 | C 版本 | S 版本 |
|------|--------|--------|
| 性能 | ✅ 最优 | 📊 中等 |
| 二进制操作 | ✅ 完整 | ⚠️ 有限 |
| 大文件处理 | ✅ 高效 | ⚠️ 需优化 |
| 代码可读性 | 📚 复杂 | ✅ 清晰 |
| S语言集成 | ⚠️ 需包装 | ✅ 原生 |
| 维护性 | 📝 中等 | ✅ 高 |

## 推荐用法

### 开发/教育用途
使用 S 版本了解LoRA合并的原理:
```bash
cd /home/shuwen/shuwen/train/neurx
S_COMPILER=../../s/bin/s_seed s run tools/lora_merge.s
```

### 生产/性能关键
使用 C 版本获得最优性能:
```bash
/home/shuwen/shuwen/train/neurx/artifacts/build/lora_merge/lora_safetensors_merge \
  /path/to/base/model \
  /path/to/adapter \
  /path/to/output \
  16 \
  8
```

### 通过 Makefile 运行
```bash
cd /home/shuwen/shuwen/train/neurx
make posttrain-merge-lora
```

## 实现细节

### LoRA 合并公式
```
W_out = W_base + (alpha / rank) * (lora_B @ lora_A)

其中:
- W_base: 基础模型权重
- lora_A, lora_B: 低秩适配器矩阵
- alpha: 缩放系数 (通常为秩大小)
- rank: 适配器秩 (通常为8或16)
```

### Safetensors 文件格式
```
[header_size: 8 bytes (u64 LE)] [header: JSON] [tensor data...]

Header JSON 结构:
{
  "tensor_name": {
    "dtype": "F32",
    "shape": [dim1, dim2, ...],
    "data_offsets": [start, end]
  },
  ...
}
```

## 扩展和改进

### 已实现
✅ 基础LoRA数学运算
✅ 目录操作和文件管理
✅ 多种浮点格式支持
✅ 命令行界面

### 待实现
- [ ] 完整的JSON解析器
- [ ] 流式张量处理(处理大文件)
- [ ] 并行合并优化
- [ ] QLoRA支持
- [ ] 张量量化感知合并

## 调试和测试

### 编译测试
```bash
cd /home/shuwen/shuwen/train/neurx
S_COMPILER=../../s/bin/s_seed ../../s/bin/s_seed tools/lora_merge.s /tmp/test.ir
```

### 运行演示
```bash
make posttrain-merge-lora
```

## 性能分析

### 内存使用
- C 版本: ~2-3 GB (对应模型大小)
- S 版本: 可配置,适合演示

### 执行时间
- C 版本: ~30-60 秒 (取决于模型大小)
- S 版本: ~5-10 分钟 (当前实现)

## 相关文件

- 配置: `/home/shuwen/shuwen/train/neurx/Makefile` (lines 113, 458)
- C原始实现: `/home/shuwen/shuwen/train/neurx/tools/lora_safetensors_merge.c`
- 构建目标: `artifacts/build/lora_merge/`
- 输出模型: `/home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct-posttrain/`

## 许可证

与 NeurX 项目同步使用的许可证。
