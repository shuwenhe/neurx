# NeurX 语法优化优先级清单

目标：让 `s` 更适合编译训练/推理类深度学习框架，减少 NeurX 里为了兼容语法而写出的绕路代码。

## P0: 必须先统一

### 1. 绑定语法

建议统一为：

```s
let x: int = 1
var y: []float = []
```

保留类型推断：

```s
let x = 1
var y = []int{1, 2, 3}
```

原因：

- 训练和推理代码里配置项、循环索引、cache/state 变量非常多
- 现在 NeurX 中 `let` / `var` / 类型标注风格不完全一致
- 绑定可变性需要在语义层明确区分，否则 optimizer、checkpoint、transformer 状态更新会反复踩坑

优先文件：

- `neurx/model/transformer/transformer.s`
- `neurx/train/optimizer.s`
- `neurx/train/checkpoint_manager.s`
- `neurx/data/tokenizer_pipeline.s`

### 2. 数组 / 切片 / 固定数组

建议统一为：

```s
[]T
[N]T
[]T{...}
[N]T{...}
```

原因：

- 训练输入 batch、token 序列、attention mask、KV cache 都高度依赖这套写法
- 推理路径里生成结果、beam、scores、prompt cache 也都依赖容器语法

优先文件：

- `neurx/infer/text_generator.s`
- `neurx/infer/sampling_beam.s`
- `neurx/attention/attention.s`
- `neurx/data/tokenizer_pipeline.s`

### 3. Map / 字典

建议统一为：

```s
map[K]V
map[K]V{}
map[K]V{ "k": v }
```

原因：

- tokenizer vocab、merge ranks、cache、metrics、registry 都大量用 map
- 训练/推理框架里 map 是配置和索引的基础容器

优先文件：

- `neurx/data/tokenizer_pipeline.s`
- `neurx/train/optimizer.s`
- `neurx/infer/text_generator.s`
- `neurx/logging/*.s`

### 4. 成员 / 下标左值赋值

建议必须支持：

```s
state.cache[i] = value
model.layers[j].weight = w
tokens[idx] = next_id
```

原因：

- 这是训练里更新参数、状态、缓存的核心动作
- 没有这项，NeurX 很多实现只能靠 workaround

优先文件：

- `neurx/train/optimizer.s`
- `neurx/model/transformer/transformer.s`
- `neurx/attention/attention.s`
- `neurx/distributed/*`

### 5. 条件表达式 / 分支表达式

建议统一为：

```s
let v = if cond { a } else { b }
```

原因：

- 配置选择、fallback、采样策略、mask 选择都很常见
- 能减少临时变量和重复分支

优先文件：

- `neurx/infer/text_generator.s`
- `neurx/infer/sampling_core.s`
- `neurx/train/loss.s`

## P1: 强烈建议统一

### 6. 结构体字面量

建议统一为：

```s
Config {
    field: value,
}
```

原因：

- transformer、optimizer、dataloader、checkpoint 的配置对象非常多
- 这是 NeurX 最常见的初始化方式之一

### 7. 函数参数与返回类型

建议统一为：

```s
func f(x: int, y: []float) map[string]int {
    ...
}
```

原因：

- 训练/推理代码函数签名长，返回类型复杂
- 统一能明显降低阅读成本

### 8. 范围循环 / 计数循环

建议只保留一种主写法：

```s
for i in 0..n {
    ...
}
```

或：

```s
var i = 0
while i < n {
    ...
    i = i + 1
}
```

原因：

- 当前 NeurX 里两种风格混用
- 对 tokenizer、attention、optimizer 的迭代结构尤其明显

## P2: 可后做

### 9. 可空 / 可选值

建议统一 `option[T]` / `result[T, E]` / `?` 传播。

### 10. 复合返回值

建议统一多返回值、tuple destructuring、函数调用参数解包。

### 11. 宏观容器 API

建议补齐：

- `push`
- `pop`
- `len`
- `contains`
- `reserve`
- `clear`

这类 API 在 tokenizer cache、beam search、dataloader 和 checkpoint 路径都高频出现。

## 对 NeurX 最该先改的文件

1. `neurx/model/transformer/transformer.s`
2. `neurx/attention/attention.s`
3. `neurx/train/optimizer.s`
4. `neurx/train/checkpoint_manager.s`
5. `neurx/data/tokenizer_pipeline.s`
6. `neurx/infer/text_generator.s`
7. `neurx/infer/sampling_beam.s`
8. `neurx/logging/logger_core.s`

## 推荐落地顺序

1. 绑定语法 + 不可变性检查
2. 数组 / map 容器统一
3. 左值赋值统一
4. 结构体字面量统一
5. 条件表达式与循环风格统一

如果目标是“让 NeurX 真正稳定编译训练/推理大模型”，这五项的收益最高。
