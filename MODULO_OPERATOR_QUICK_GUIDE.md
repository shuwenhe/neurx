# S 语言 % 操作符 - 快速使用指南

## 基本用法

### 简单模运算
```s
let result = 10 % 3      // result = 1
let remainder = 20 % 6   // remainder = 2
let zero = 7 % 7         // zero = 0
```

### 检查数字是否为偶数/奇数
```s
let num = 15
if num % 2 == 0 {
    println("偶数")
} else {
    println("奇数")
}
```

### 循环中使用（每 N 步执行）
```s
let step = 0
for step < 500 {
    // 每 50 步打印进度
    let step_mod = (step + 1) % 50
    if step_mod == 0 || step == 0 {
        println("Step: " + int_to_string(step + 1))
    }
    step = step + 1
}
```

### 数字转字符串（提取各位数字）
```s
func int_to_string(x int) string {
    let result = ""
    let temp = x
    for temp > 0 {
        let digit = temp % 10          // 获取个位数字
        result = string_char(digit + 48) + result
        temp = temp / 10                // 去掉个位
    }
    return result
}
```

### 循环索引
```s
// 在 10 个元素的数组中循环
let idx = current_idx % 10

// 二维数组访问
let row = index / width
let col = index % width
```

## 注意事项

### ✅ 推荐写法
```s
// 使用中间变量存储结果
let mod_result = value % divisor
if mod_result == target_value {
    // ...
}
```

### ❌ 避免写法
```s
// 在复杂表达式中直接使用可能有问题
if (a + b) % c == 0 && condition {
    // 可能导致解析错误
}

// 推荐改为：
let mod_result = (a + b) % c
if mod_result == 0 && condition {
    // ...
}
```

## 实际应用示例

### 示例 1: 步长进度监控
```s
let epoch = 0
for epoch < 10 {
    let step = 0
    for step < 100 {
        // 每 10 步记录一次
        let step_mod = (step + 1) % 10
        if step_mod == 0 {
            println("Epoch " + int_to_string(epoch) + 
                   " Step " + int_to_string(step + 1))
        }
        step = step + 1
    }
    epoch = epoch + 1
}
```

### 示例 2: 循环缓冲区
```s
type RingBuffer struct {
    data [100]int
    size int
    pos  int
}

func append_to_buffer(buf RingBuffer, value int) {
    buf.data[buf.pos] = value
    buf.pos = (buf.pos + 1) % buf.size    // 环形索引
}
```

### 示例 3: 批处理
```s
let batch_size = 32
let data_points = 1000

let batch = 0
for batch * batch_size < data_points {
    let idx = 0
    for idx < batch_size {
        let data_idx = batch * batch_size + idx
        if data_idx < data_points {
            // 处理数据点
            let sample_id = data_idx % 100
        }
        idx = idx + 1
    }
    batch = batch + 1
}
```

### 示例 4: 哈希分桶
```s
func hash_mod(value int, num_buckets int) int {
    return value % num_buckets
}

// 使用
let bucket = hash_mod(my_value, 16)    // 分到 0-15 号桶
```

## 性能特点

- **操作速度**: 原生 % 比 modulo() 函数调用快
- **编译时优化**: 编译器可能优化特殊情况
  - `x % 2` 可能优化为按位与
  - `x % 256` 可能优化为低 8 位掩码
- **内存效率**: 直接机器指令，无函数调用开销

## 兼容性

| 操作数类型 | 支持 | 说明 |
|-----------|------|------|
| int % int | ✅ | 完全支持 |
| float % float | ❌ | 使用浮点版 modulo() |
| int % float | ❌ | 转换为 int 后再运算 |

## 迁移指南（从旧的 modulo() 到新的 %）

### 之前
```s
func modulo(a int, b int) int {
    result := a
    for result >= b {
        result = result - b
    }
    return result
}

let targets[i] = modulo(i + step, vocab_size)
```

### 现在
```s
// modulo() 函数已删除，直接使用 %
let targets[i] = (i + step) % vocab_size
```

## 故障排除

| 错误 | 原因 | 解决方案 |
|------|------|--------|
| "expected expression, got %" | 语法上下文问题 | 使用中间变量 |
| "modulo by zero" | 除数为 0 | 检查 divisor > 0 |
| 类型不匹配 | 非整数操作数 | 转换为 int |

## 编译和运行

```bash
# 编译包含 % 的 S 程序
/Users/feifei/train/s/bin/s myprogram.s build/myprogram.ir

# 检查 IR 中是否有 MOD 指令
grep MOD build/myprogram.ir

# 生成二进制（需要在 S 源目录）
cd /Users/feifei/train/s
./bin/s --emit-bin /path/to/myprogram.ir build/myprogram.bin
```

## 总结

✅ 现在 S 语言完全支持原生 % 操作符
✅ 比旧的 modulo() 函数更高效和优雅
✅ 遵循 C 风格语言的标准约定

快乐编码！🚀
